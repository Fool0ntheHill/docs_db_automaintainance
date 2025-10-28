import os
import json
import hashlib
import time
import shutil
import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from urllib.parse import urljoin
from typing import Set, Dict, List, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path
from enhanced_metadata_generator import EnhancedMetadataGenerator
from dify_sync_manager import DifySyncManager, KnowledgeBaseStrategy
from tke_logger import setup_logger, get_logger, LogLevel
from secure_temp_manager import setup_temp_manager, get_temp_manager


class ConfigurationError(Exception):
    """配置相关异常"""
    def __init__(self, message: str, suggestions: List[str] = None):
        super().__init__(message)
        self.suggestions = suggestions or []
    
    def __str__(self):
        msg = super().__str__()
        if self.suggestions:
            msg += "\n\n💡 建议："
            for i, suggestion in enumerate(self.suggestions, 1):
                msg += f"\n  {i}. {suggestion}"
        return msg


@dataclass
class Config:
    """配置数据类"""
    dify_api_key: str
    dify_knowledge_base_ids: List[str]
    dify_api_base_url: str
    kb_strategy: str = "primary"
    request_timeout: int = 10
    retry_attempts: int = 3
    retry_delay: int = 1
    state_file: str = "crawl_state.json"
    log_file: str = "tke_sync.log"
    base_url: str = "https://cloud.tencent.com"
    start_url: str = "https://cloud.tencent.com/document/product/457"


class ConfigManager:
    """配置管理器，支持环境变量和 .env 文件"""
    
    def __init__(self, env_file: str = ".env"):
        self.env_file = env_file
        self.config: Optional[Config] = None
    
    def load_config(self) -> Config:
        """加载配置，优先级：环境变量 > .env 文件"""
        try:
            # 首先尝试从 .env 文件加载
            self._load_env_file()
            
            # 获取配置值
            dify_api_key = self._get_config_value("DIFY_API_KEY")
            dify_kb_ids_str = self._get_config_value("DIFY_KNOWLEDGE_BASE_ID")
            dify_api_base_url = self._get_config_value("DIFY_API_BASE_URL")
            
            # 检查必需配置并收集缺失项
            missing_configs = []
            config_suggestions = []
            
            if not dify_api_key or dify_api_key.strip() == "":
                missing_configs.append("DIFY_API_KEY")
                config_suggestions.extend([
                    "登录 Dify 控制台 → 设置 → API Keys",
                    "创建新的 API Key 并复制到配置文件"
                ])
            
            if not dify_kb_ids_str or dify_kb_ids_str.strip() == "":
                missing_configs.append("DIFY_KNOWLEDGE_BASE_ID")
                config_suggestions.extend([
                    "进入 Dify 知识库页面",
                    "从 URL 中获取知识库 ID（格式：8c6b8e3c-f69c-48ea-b34e-a71798c800ed）"
                ])
            
            if not dify_api_base_url or dify_api_base_url.strip() == "":
                missing_configs.append("DIFY_API_BASE_URL")
                config_suggestions.append("设置 Dify API 基础 URL（通常为：https://api.dify.ai/v1）")
            
            # 如果有缺失配置，抛出详细的错误信息
            if missing_configs:
                suggestions = [
                    f"检查 {self.env_file} 文件是否存在",
                    "确保配置文件使用正确的格式：KEY=VALUE",
                    "参考项目中的 .env.example 文件"
                ] + config_suggestions + [
                    "运行 'python test_config.py' 验证配置"
                ]
                
                raise ConfigurationError(
                    f"❌ 缺少必需的配置项: {', '.join(missing_configs)}",
                    suggestions
                )
            
            # 解析知识库 ID（支持逗号分隔的多个 ID）
            try:
                dify_kb_ids = self._parse_knowledge_base_ids(dify_kb_ids_str)
                if not dify_kb_ids:
                    raise ConfigurationError(
                        "❌ 知识库 ID 解析失败：未找到有效的知识库 ID",
                        [
                            "检查 DIFY_KNOWLEDGE_BASE_ID 的格式",
                            "单个知识库：DIFY_KNOWLEDGE_BASE_ID=8c6b8e3c-f69c-48ea-b34e-a71798c800ed",
                            "多个知识库：DIFY_KNOWLEDGE_BASE_ID=kb1-id,kb2-id,kb3-id",
                            "确保知识库 ID 不为空且格式正确"
                        ]
                    )
            except Exception as e:
                if isinstance(e, ConfigurationError):
                    raise
                raise ConfigurationError(
                    f"❌ 知识库 ID 解析错误: {e}",
                    [
                        "检查知识库 ID 格式是否正确",
                        "确保没有多余的空格或特殊字符",
                        "多个知识库 ID 用英文逗号分隔"
                    ]
                )
            
            # 验证数值配置
            try:
                request_timeout = int(self._get_config_value("REQUEST_TIMEOUT", "10"))
                retry_attempts = int(self._get_config_value("RETRY_ATTEMPTS", "3"))
                retry_delay = int(self._get_config_value("RETRY_DELAY", "1"))
                
                if request_timeout <= 0:
                    raise ValueError("REQUEST_TIMEOUT 必须大于 0")
                if retry_attempts < 0:
                    raise ValueError("RETRY_ATTEMPTS 不能为负数")
                if retry_delay < 0:
                    raise ValueError("RETRY_DELAY 不能为负数")
                    
            except ValueError as e:
                raise ConfigurationError(
                    f"❌ 数值配置错误: {e}",
                    [
                        "REQUEST_TIMEOUT: 请求超时时间（秒），建议值：10-60",
                        "RETRY_ATTEMPTS: 重试次数，建议值：1-5",
                        "RETRY_DELAY: 重试延迟（秒），建议值：1-10",
                        "确保所有数值配置都是正整数"
                    ]
                )
            
            # 验证策略配置
            kb_strategy = self._get_config_value("KB_STRATEGY", "primary")
            valid_strategies = ["primary", "all", "round_robin"]
            if kb_strategy not in valid_strategies:
                raise ConfigurationError(
                    f"❌ 无效的知识库策略: {kb_strategy}",
                    [
                        f"有效的策略选项: {', '.join(valid_strategies)}",
                        "primary: 只使用第一个知识库（推荐）",
                        "all: 同步到所有知识库",
                        "round_robin: 轮询分配到不同知识库"
                    ]
                )
            
            # 创建配置对象
            self.config = Config(
                dify_api_key=dify_api_key,
                dify_knowledge_base_ids=dify_kb_ids,
                dify_api_base_url=dify_api_base_url,
                kb_strategy=kb_strategy,
                request_timeout=request_timeout,
                retry_attempts=retry_attempts,
                retry_delay=retry_delay,
                state_file=self._get_config_value("STATE_FILE", "crawl_state.json"),
                log_file=self._get_config_value("LOG_FILE", "tke_sync.log"),
                base_url=self._get_config_value("BASE_URL", "https://cloud.tencent.com"),
                start_url=self._get_config_value("START_URL", "https://cloud.tencent.com/document/product/457")
            )
            
            print(f"[配置] ✅ 成功加载配置，知识库数量: {len(dify_kb_ids)}, 策略: {self.config.kb_strategy}")
            return self.config
            
        except ConfigurationError:
            raise  # 重新抛出配置错误
        except Exception as e:
            # 处理其他未预期的错误
            suggestions = [
                f"检查 {self.env_file} 文件是否存在且可读",
                "确保配置文件使用 UTF-8 编码",
                "检查配置文件中是否有语法错误",
                "尝试重新创建配置文件"
            ]
            raise ConfigurationError(f"❌ 配置加载失败: {e}", suggestions)
    
    def _load_env_file(self):
        """加载 .env 文件"""
        env_path = Path(self.env_file)
        if not env_path.exists():
            # 配置文件不存在，给出友好提示
            if self.env_file == ".env":
                suggestions = [
                    "创建 .env 配置文件",
                    "复制 .env.example 为 .env（如果存在）",
                    "参考 README.md 中的配置说明",
                    "运行 'python test_config.py' 获取配置帮助"
                ]
                raise ConfigurationError(f"❌ 配置文件不存在: {env_path}", suggestions)
            else:
                # 自定义配置文件不存在
                raise ConfigurationError(
                    f"❌ 指定的配置文件不存在: {env_path}",
                    [
                        "检查文件路径是否正确",
                        "确保文件存在且可读",
                        "检查文件名拼写"
                    ]
                )
        
        try:
            line_count = 0
            config_count = 0
            
            with open(env_path, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    line_count += 1
                    original_line = line
                    line = line.strip()
                    
                    # 跳过空行和注释
                    if not line or line.startswith('#'):
                        continue
                    
                    # 检查是否包含等号
                    if '=' not in line:
                        print(f"[配置] ⚠️ 第 {line_num} 行格式可能有误: {original_line.strip()}")
                        continue
                    
                    try:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        
                        # 检查键名是否有效
                        if not key:
                            print(f"[配置] ⚠️ 第 {line_num} 行：配置项名称为空")
                            continue
                        
                        # 检查值长度（Windows 环境变量限制）
                        if len(value) > 32000:
                            print(f"[配置] ⚠️ 配置项 {key} 的值过长 ({len(value)} 字符)，可能导致问题")
                            value = value[:32000]  # 截断
                        
                        # 配置文件中的值优先于环境变量
                        os.environ[key] = value
                        config_count += 1
                        
                    except Exception as e:
                        print(f"[配置] ⚠️ 第 {line_num} 行解析失败: {e}")
                        continue
            
            print(f"[配置] ✅ 已加载配置文件: {env_path} ({config_count} 个配置项)")
            
            # 设置适当的文件权限
            try:
                os.chmod(env_path, 0o600)
            except:
                pass  # 权限设置失败不影响功能
                
        except UnicodeDecodeError as e:
            raise ConfigurationError(
                f"❌ 配置文件编码错误: {e}",
                [
                    "确保配置文件使用 UTF-8 编码保存",
                    "检查文件中是否有特殊字符",
                    "尝试用文本编辑器重新保存文件"
                ]
            )
        except PermissionError:
            raise ConfigurationError(
                f"❌ 无权限读取配置文件: {env_path}",
                [
                    "检查文件权限设置",
                    "确保当前用户有读取权限",
                    "尝试以管理员身份运行"
                ]
            )
        except Exception as e:
            raise ConfigurationError(
                f"❌ 读取配置文件失败: {e}",
                [
                    "检查文件是否被其他程序占用",
                    "确保文件没有损坏",
                    "尝试重新创建配置文件"
                ]
            )
    
    def _get_config_value(self, key: str, default: str = None) -> str:
        """获取配置值，优先从环境变量获取"""
        return os.environ.get(key, default)
    
    def _parse_knowledge_base_ids(self, kb_ids_str: str) -> List[str]:
        """解析知识库 ID 配置（支持单个或多个）"""
        if not kb_ids_str:
            return []
        
        # 支持逗号分隔的多个 ID
        ids = [kb_id.strip() for kb_id in kb_ids_str.split(',') if kb_id.strip()]
        return ids
    
    def get_config(self) -> Config:
        """获取配置对象"""
        if self.config is None:
            self.config = self.load_config()
        return self.config
    
    def validate_config(self) -> bool:
        """验证配置是否有效"""
        try:
            config = self.get_config()
            
            # 验证必需字段
            if not config.dify_api_key or config.dify_api_key == "sk-YOUR_DIFY_API_KEY" or config.dify_api_key.strip() == "":
                print("[配置] 错误：DIFY_API_KEY 未正确设置或为空")
                return False
            
            if not config.dify_knowledge_base_ids or len(config.dify_knowledge_base_ids) == 0:
                print("[配置] 错误：DIFY_KNOWLEDGE_BASE_ID 未正确设置或为空")
                return False
            
            # 检查知识库ID是否为空
            for kb_id in config.dify_knowledge_base_ids:
                if not kb_id or kb_id.strip() == "":
                    print("[配置] 错误：发现空的知识库ID")
                    return False
            
            if not config.dify_api_base_url or "your-dify-domain.com" in config.dify_api_base_url or config.dify_api_base_url.strip() == "":
                print("[配置] 错误：DIFY_API_BASE_URL 未正确设置或为空")
                return False
            
            # 验证策略
            valid_strategies = ["primary", "all", "round_robin"]
            if config.kb_strategy not in valid_strategies:
                print(f"[配置] 错误：KB_STRATEGY 必须是 {valid_strategies} 之一")
                return False
            
            # 验证数值配置
            if config.request_timeout <= 0:
                print("[配置] 错误：REQUEST_TIMEOUT 必须大于0")
                return False
                
            if config.retry_attempts < 0:
                print("[配置] 错误：RETRY_ATTEMPTS 不能为负数")
                return False
            
            print("[配置] 配置验证通过")
            return True
            
        except Exception as e:
            print(f"[配置] 配置验证失败: {e}")
            return False


def get_all_doc_urls(start_url: str, base_url: str = "https://cloud.tencent.com") -> Set[str]:
    """
    [任务 1] 抓取所有 TKE 文档 URL (已验证的 V7 逻辑)
    !!! Kiro 注意：请勿修改此函数的内部逻辑 !!!
    """
    print("[任务 1] 正在启动 Selenium (有头模式)...")
    options = webdriver.ChromeOptions()
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)

    print(f"[任务 1] 正在访问: {start_url}")

    try:
        driver.get(start_url)
        
        print("[任务 1] 页面加载。硬性等待 5 秒钟，让所有 JS 资源先生效...")
        time.sleep(5) 

        # --- V7 核心逻辑：使用最精确的选择器 ---
        
        # 根容器
        nav_container_selector = "div.rno-column-aside-bd-2"
        
        # 通用选择器 (匹配 div 和 li)
        expandable_link_selector_text = (
            ".J-expandable:not(.active) "
            "a[href='javascript:void 0;']"
        )
        
        first_link_inside_nav = (By.CSS_SELECTOR, 
                                 f"{nav_container_selector} {expandable_link_selector_text}")
        
        print(f"[任务 1] 正在等待 TKE 菜单内的第一个'未展开'链接变为可点击状态...")
        
        WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable(first_link_inside_nav)
        )
        print("[任务 1] TKE 菜单内容已加载并可点击。开始迭代展开所有子菜单...")

        while True:
            links_selector = (By.CSS_SELECTOR, 
                              f"{nav_container_selector} {expandable_link_selector_text}")
            
            try:
                links_to_expand = driver.find_elements(*links_selector)
                
                if not links_to_expand:
                    print("[任务 1] 找不到更多 *未展开* 的菜单。菜单已完全展开。")
                    break
                
                print(f"[任务 1] 发现 {len(links_to_expand)} 个 *未展开* 项。正在点击第一个...")
                
                link_to_click = links_to_expand[0]
                driver.execute_script("arguments[0].click();", link_to_click)
                time.sleep(0.3) 

            except Exception as e:
                print(f"[任务 1] 展开时遇到一个临时错误 (正常现象，可忽略): {e}")
                time.sleep(0.5)

        print("[任务 1] 菜单展开完毕。正在解析所有 URL...")
        
        page_source = driver.page_source
        soup = BeautifulSoup(page_source, 'html.parser')
        
        doc_urls: Set[str] = set()
        
        nav_wrapper = soup.find('div', class_='rno-column-aside-bd-2')
        if not nav_wrapper:
            print("[任务 1] 警告：找不到 'rno-column-aside-bd-2' 容器。将从整个页面解析。")
            nav_wrapper = soup 
        
        for a_tag in nav_wrapper.find_all('a'):
            url = a_tag.get('data-link') or a_tag.get('href')
            
            if url and url.startswith('/document/product/457'):
                full_url = urljoin(base_url, url)
                doc_urls.add(full_url)

        return doc_urls

    finally:
        driver.quit()
        print("[任务 1] Selenium 已关闭。")


class ContentScraper:
    """增强的内容抓取器，具有健壮的错误处理"""
    
    def __init__(self, config: Config):
        self.config = config
        self.session = requests.Session()
        # 设置会话的默认配置
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        # 设置连接池
        adapter = requests.adapters.HTTPAdapter(
            pool_connections=10,
            pool_maxsize=20,
            max_retries=0  # 我们自己处理重试
        )
        self.session.mount('http://', adapter)
        self.session.mount('https://', adapter)
    
    def scrape_content(self, url: str) -> Optional[str]:
        """
        抓取并清洗指定 URL 的核心内容
        
        Args:
            url: 要抓取的 URL
            
        Returns:
            str: 清洗后的内容，失败时返回 None
        """
        for attempt in range(self.config.retry_attempts):
            try:
                return self._attempt_scrape(url, attempt + 1)
            except requests.exceptions.Timeout:
                print(f"[内容抓取] 超时 (尝试 {attempt + 1}/{self.config.retry_attempts}): {url}")
                if attempt < self.config.retry_attempts - 1:
                    time.sleep(self.config.retry_delay * (attempt + 1))
                continue
            except requests.exceptions.ConnectionError as e:
                print(f"[内容抓取] 连接错误 (尝试 {attempt + 1}/{self.config.retry_attempts}): {url} - {e}")
                if attempt < self.config.retry_attempts - 1:
                    time.sleep(self.config.retry_delay * (attempt + 1))
                continue
            except requests.exceptions.HTTPError as e:
                status_code = e.response.status_code if e.response else 'Unknown'
                print(f"[内容抓取] HTTP 错误 {status_code}: {url} - {e}")
                
                # 对于某些错误码不重试
                if status_code in [404, 403, 401, 410]:
                    print(f"[内容抓取] 不可重试的错误，跳过: {url}")
                    break
                
                # 对于服务器错误，重试
                if attempt < self.config.retry_attempts - 1 and status_code >= 500:
                    time.sleep(self.config.retry_delay * (attempt + 1))
                    continue
                break
            except Exception as e:
                print(f"[内容抓取] 未预期错误 (尝试 {attempt + 1}/{self.config.retry_attempts}): {url} - {type(e).__name__}: {e}")
                if attempt < self.config.retry_attempts - 1:
                    time.sleep(self.config.retry_delay * (attempt + 1))
                continue
        
        print(f"[内容抓取] 所有尝试失败，跳过: {url}")
        return None
    
    def _attempt_scrape(self, url: str, attempt_num: int) -> Optional[str]:
        """
        单次抓取尝试
        
        Args:
            url: 要抓取的 URL
            attempt_num: 尝试次数
            
        Returns:
            str: 清洗后的内容
            
        Raises:
            各种 requests 异常
        """
        print(f"[内容抓取] 开始抓取 (尝试 {attempt_num}): {url}")
        
        # 发送请求
        response = self.session.get(
            url, 
            timeout=self.config.request_timeout,
            allow_redirects=True
        )
        response.raise_for_status()
        
        # 检查响应内容类型
        content_type = response.headers.get('content-type', '').lower()
        if 'text/html' not in content_type:
            print(f"[内容抓取] 警告：非 HTML 内容类型 {content_type}: {url}")
        
        # 检查响应大小
        content_length = len(response.content)
        if content_length == 0:
            print(f"[内容抓取] 警告：响应内容为空: {url}")
            return None
        
        if content_length > 10 * 1024 * 1024:  # 10MB
            print(f"[内容抓取] 警告：响应内容过大 ({content_length} bytes): {url}")
        
        # 解析 HTML
        try:
            soup = BeautifulSoup(response.text, 'html.parser')
        except Exception as e:
            print(f"[内容抓取] HTML 解析失败: {url} - {e}")
            return None
        
        # 提取内容和标题
        content = self._extract_content(soup, url)
        title = self._extract_title(soup, url)
        
        if content:
            print(f"[内容抓取] 成功提取内容 ({len(content)} 字符): {url}")
            print(f"[标题提取] 提取标题: {title}")
            # 将标题和内容组合返回，使用特殊分隔符
            return f"TITLE:{title}\nCONTENT:{content}"
        else:
            print(f"[内容抓取] 未找到有效内容: {url}")
            return None
    
    def _extract_content(self, soup: BeautifulSoup, url: str) -> Optional[str]:
        """
        从 BeautifulSoup 对象中提取内容
        
        Args:
            soup: BeautifulSoup 对象
            url: 原始 URL（用于日志）
            
        Returns:
            str: 提取的内容，失败时返回 None
        """
        # 主要选择器
        primary_selector = 'div.content-layout-container'
        
        # 备用选择器（按优先级排序）
        fallback_selectors = [
            'div.content-container',
            'div.main-content',
            'article',
            'div.content',
            'main',
            'div#content'
        ]
        
        # 尝试主要选择器
        content_div = soup.find('div', class_='content-layout-container')
        if content_div:
            content = self._clean_content(content_div.get_text(separator='\n', strip=True))
            if content and len(content.strip()) > 50:  # 至少 50 个字符
                return content
            else:
                print(f"[内容抓取] 主选择器找到内容但太短: {url}")
        
        # 尝试备用选择器
        for selector in fallback_selectors:
            try:
                if '.' in selector:
                    class_name = selector.split('.')[1]
                    element = soup.find('div', class_=class_name)
                elif '#' in selector:
                    id_name = selector.split('#')[1]
                    element = soup.find('div', id=id_name)
                else:
                    element = soup.find(selector)
                
                if element:
                    content = self._clean_content(element.get_text(separator='\n', strip=True))
                    if content and len(content.strip()) > 50:
                        print(f"[内容抓取] 使用备用选择器 {selector}: {url}")
                        return content
            except Exception as e:
                print(f"[内容抓取] 备用选择器 {selector} 失败: {url} - {e}")
                continue
        
        # 最后尝试：提取 body 内容
        try:
            body = soup.find('body')
            if body:
                # 移除脚本和样式标签
                for script in body(["script", "style", "nav", "header", "footer"]):
                    script.decompose()
                
                content = self._clean_content(body.get_text(separator='\n', strip=True))
                if content and len(content.strip()) > 100:  # body 内容要求更长
                    print(f"[内容抓取] 使用 body 内容作为后备: {url}")
                    return content
        except Exception as e:
            print(f"[内容抓取] body 内容提取失败: {url} - {e}")
        
        return None
    
    def _clean_content(self, content: str) -> str:
        """
        清洗提取的内容
        
        Args:
            content: 原始内容
            
        Returns:
            str: 清洗后的内容
        """
        if not content:
            return ""
        
        # 移除多余的空白字符
        lines = []
        for line in content.split('\n'):
            line = line.strip()
            if line:  # 跳过空行
                lines.append(line)
        
        # 合并连续的短行（可能是被错误分割的）
        merged_lines = []
        i = 0
        while i < len(lines):
            current_line = lines[i]
            
            # 如果当前行很短且下一行存在，尝试合并
            while (i + 1 < len(lines) and 
                   len(current_line) < 100 and 
                   not current_line.endswith(('。', '！', '？', '.', '!', '?', ':', '：'))):
                current_line += ' ' + lines[i + 1]
                i += 1
            
            merged_lines.append(current_line)
            i += 1
        
        return '\n'.join(merged_lines)
    
    def _extract_title(self, soup: BeautifulSoup, url: str) -> str:
        """
        从页面中提取标题
        
        Args:
            soup: BeautifulSoup 对象
            url: 原始 URL（用于日志）
            
        Returns:
            str: 提取的标题
        """
        # 尝试多种标题选择器，按优先级排序
        title_selectors = [
            'h1',                                    # 主标题
            '.content-layout-container h1',          # 内容区域的主标题
            '.content-layout-container h2',          # 内容区域的副标题
            'title',                                 # 页面标题
            '.page-title',                           # 页面标题类
            '.article-title',                        # 文章标题类
            '.doc-title'                             # 文档标题类
        ]
        
        for selector in title_selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    title = element.get_text(strip=True)
                    if title and len(title) > 0:
                        # 清理标题
                        title = title.replace('\n', ' ').replace('\r', ' ')
                        title = ' '.join(title.split())  # 合并多个空格
                        if len(title) <= 200:  # 标题长度限制
                            print(f"[标题提取] 使用选择器 {selector} 提取标题: {title}")
                            return title
            except Exception as e:
                print(f"[标题提取] 选择器 {selector} 失败: {e}")
                continue
        
        # 如果都失败了，从 URL 生成标题
        try:
            from urllib.parse import urlparse
            parsed = urlparse(url)
            path_parts = [part for part in parsed.path.split('/') if part]
            
            if len(path_parts) >= 3 and path_parts[0] == 'document' and path_parts[1] == 'product':
                product_id = path_parts[2]
                doc_id = path_parts[3] if len(path_parts) >= 4 else 'unknown'
                title = f"TKE 文档 - {product_id} - {doc_id}"
            else:
                title = f"TKE 文档 - {url.split('/')[-1]}"
            
            print(f"[标题提取] 使用 URL 生成标题: {title}")
            return title
            
        except Exception as e:
            print(f"[标题提取] URL 解析失败: {e}")
            return f"TKE 文档 - {url}"
    
    def close(self):
        """关闭会话"""
        if self.session:
            self.session.close()


def scrape_content(url: str, config: Config = None) -> Optional[str]:
    """
    向后兼容的内容抓取函数
    
    Args:
        url: 要抓取的 URL
        config: 配置对象，如果为 None 则使用默认配置
        
    Returns:
        str: 抓取的内容，失败时返回 None
    """
    if config is None:
        # 创建默认配置
        config = Config(
            dify_api_key="dummy",
            dify_knowledge_base_ids=["dummy"],
            dify_api_base_url="dummy"
        )
    
    scraper = ContentScraper(config)
    try:
        return scraper.scrape_content(url)
    finally:
        scraper.close()

def get_content_hash(content: str) -> str:
    """[任务 3 辅助] 计算内容的 MD5 哈希值"""
    return hashlib.md5(content.encode('utf-8')).hexdigest()

class StateManager:
    """原子性状态管理器，确保状态文件的完整性和一致性"""
    
    def __init__(self, state_file: str):
        self.state_file = state_file
        self.backup_file = f"{state_file}.backup"
        self.temp_file = f"{state_file}.tmp"
        
        # 统计信息
        self.stats = {
            'load_attempts': 0,
            'load_successes': 0,
            'save_attempts': 0,
            'save_successes': 0,
            'corruption_recoveries': 0,
            'backup_recoveries': 0
        }
    
    def load_state(self) -> Dict[str, str]:
        """
        加载状态文件，支持损坏检测和自动恢复
        
        Returns:
            状态字典，失败时返回空字典
        """
        self.stats['load_attempts'] += 1
        
        # 首先尝试加载主状态文件
        state = self._load_file(self.state_file)
        if state is not None:
            self.stats['load_successes'] += 1
            return state
        
        print(f"[任务 3] 主状态文件损坏或不存在: {self.state_file}")
        
        # 尝试从备份文件恢复
        if os.path.exists(self.backup_file):
            print(f"[任务 3] 尝试从备份文件恢复: {self.backup_file}")
            backup_state = self._load_file(self.backup_file)
            if backup_state is not None:
                self.stats['backup_recoveries'] += 1
                self.stats['load_successes'] += 1
                print(f"[任务 3] 成功从备份恢复状态，包含 {len(backup_state)} 个条目")
                
                # 尝试修复主状态文件
                try:
                    self._atomic_save(self.state_file, backup_state)
                    print(f"[任务 3] 主状态文件已修复")
                except Exception as e:
                    print(f"[任务 3] 警告：无法修复主状态文件 - {e}")
                
                return backup_state
        
        # 所有恢复尝试都失败，返回空状态
        print(f"[任务 3] 无法恢复状态，将从空状态开始")
        self.stats['corruption_recoveries'] += 1
        self.stats['load_successes'] += 1  # 返回空状态也算成功
        return {}
    
    def save_state(self, state: Dict[str, str]) -> bool:
        """
        原子性保存状态文件
        
        Args:
            state: 要保存的状态字典
            
        Returns:
            保存是否成功
        """
        self.stats['save_attempts'] += 1
        
        try:
            # 创建备份（如果主文件存在且有效）
            if os.path.exists(self.state_file):
                current_state = self._load_file(self.state_file)
                if current_state is not None:
                    try:
                        shutil.copy2(self.state_file, self.backup_file)
                        print(f"[任务 3] 已创建状态文件备份")
                    except Exception as e:
                        print(f"[任务 3] 警告：无法创建备份 - {e}")
            
            # 原子性保存到主文件
            success = self._atomic_save(self.state_file, state)
            if success:
                self.stats['save_successes'] += 1
                print(f"[任务 3] 状态已保存，包含 {len(state)} 个条目")
                return True
            else:
                print(f"[任务 3] 状态保存失败")
                return False
                
        except Exception as e:
            print(f"[任务 3] 状态保存异常: {type(e).__name__}: {e}")
            return False
    
    def _load_file(self, file_path: str) -> Optional[Dict[str, str]]:
        """
        安全加载 JSON 文件
        
        Args:
            file_path: 文件路径
            
        Returns:
            解析的字典，失败时返回 None
        """
        if not os.path.exists(file_path):
            return None
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if not content:
                    print(f"[任务 3] 文件为空: {file_path}")
                    return None
                
                data = json.loads(content)
                if not isinstance(data, dict):
                    print(f"[任务 3] 文件格式错误，不是字典: {file_path}")
                    return None
                
                # 验证所有键值都是字符串
                for key, value in data.items():
                    if not isinstance(key, str) or not isinstance(value, str):
                        print(f"[任务 3] 状态文件包含非字符串键值对: {file_path}")
                        return None
                
                return data
                
        except json.JSONDecodeError as e:
            print(f"[任务 3] JSON 解析错误: {file_path} - {e}")
            return None
        except Exception as e:
            print(f"[任务 3] 文件读取错误: {file_path} - {type(e).__name__}: {e}")
            return None
    
    def _atomic_save(self, file_path: str, state: Dict[str, str]) -> bool:
        """
        原子性保存文件（先写临时文件，再重命名）
        
        Args:
            file_path: 目标文件路径
            state: 要保存的状态
            
        Returns:
            保存是否成功
        """
        try:
            # 确保目录存在
            dir_path = os.path.dirname(file_path)
            if dir_path:  # 只有当目录路径不为空时才创建
                os.makedirs(dir_path, exist_ok=True)
            
            # 写入临时文件
            with open(self.temp_file, 'w', encoding='utf-8') as f:
                json.dump(state, f, indent=2, ensure_ascii=False)
                f.flush()  # 确保数据写入磁盘
                os.fsync(f.fileno())  # 强制同步到磁盘
            
            # 验证临时文件
            temp_state = self._load_file(self.temp_file)
            if temp_state != state:
                print(f"[任务 3] 临时文件验证失败")
                return False
            
            # 原子性重命名
            if os.name == 'nt':  # Windows
                # Windows 不支持原子性重命名到已存在的文件
                if os.path.exists(file_path):
                    os.remove(file_path)
                os.rename(self.temp_file, file_path)
            else:  # Unix/Linux
                os.rename(self.temp_file, file_path)
            
            return True
            
        except Exception as e:
            print(f"[任务 3] 原子性保存失败: {type(e).__name__}: {e}")
            # 清理临时文件
            try:
                if os.path.exists(self.temp_file):
                    os.remove(self.temp_file)
            except:
                pass
            return False
    
    def cleanup_temp_files(self) -> None:
        """清理临时文件"""
        for temp_path in [self.temp_file]:
            try:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                    print(f"[任务 3] 已清理临时文件: {temp_path}")
            except Exception as e:
                print(f"[任务 3] 清理临时文件失败: {temp_path} - {e}")
    
    def get_stats(self) -> Dict[str, int]:
        """获取状态管理统计信息"""
        return self.stats.copy()
    
    def print_stats(self) -> None:
        """打印状态管理统计信息"""
        print("\\n=== 状态管理统计 ===")
        print(f"加载尝试: {self.stats['load_attempts']}")
        print(f"加载成功: {self.stats['load_successes']}")
        print(f"保存尝试: {self.stats['save_attempts']}")
        print(f"保存成功: {self.stats['save_successes']}")
        print(f"损坏恢复: {self.stats['corruption_recoveries']}")
        print(f"备份恢复: {self.stats['backup_recoveries']}")
        
        if self.stats['load_attempts'] > 0:
            load_rate = (self.stats['load_successes'] / self.stats['load_attempts']) * 100
            print(f"加载成功率: {load_rate:.1f}%")
        
        if self.stats['save_attempts'] > 0:
            save_rate = (self.stats['save_successes'] / self.stats['save_attempts']) * 100
            print(f"保存成功率: {save_rate:.1f}%")
        
        print("==================\\n")


def load_state(file_path: str) -> Dict[str, str]:
    """
    向后兼容的状态加载函数
    
    Args:
        file_path: 状态文件路径
        
    Returns:
        状态字典
    """
    manager = StateManager(file_path)
    return manager.load_state()


def save_state(file_path: str, state: Dict[str, str]) -> None:
    """
    向后兼容的状态保存函数
    
    Args:
        file_path: 状态文件路径
        state: 状态字典
    """
    manager = StateManager(file_path)
    manager.save_state(state)

class TKEDifySync:
    """TKE 文档同步器，使用智能哈希对比"""
    
    def __init__(self, config: Config):
        self.config = config
        self.dify_manager = DifySyncManager(config)
        self.metadata_generator = EnhancedMetadataGenerator()
    
    def sync_to_dify(self, url: str, content: str, metadata: Dict = None) -> bool:
        """
        将文档同步到 Dify 知识库（使用智能哈希对比）
        
        Args:
            url: 文档 URL
            content: 文档内容
            metadata: 元数据
            
        Returns:
            是否成功
        """
        print(f"[同步] 准备同步到 Dify: {url}")
        
        try:
            # 解析标题和内容
            if content.startswith("TITLE:") and "\nCONTENT:" in content:
                parts = content.split("\nCONTENT:", 1)
                title = parts[0].replace("TITLE:", "").strip()
                actual_content = parts[1].strip()
            else:
                # 如果没有标题分隔符，从URL生成标题
                from urllib.parse import urlparse
                parsed = urlparse(url)
                path_parts = [part for part in parsed.path.split('/') if part]
                
                if len(path_parts) >= 4 and path_parts[0] == 'document' and path_parts[1] == 'product':
                    doc_id = path_parts[3]
                    title = f"TKE 文档 - {doc_id}"
                else:
                    title = f"TKE 文档 - {url.split('/')[-1]}"
                
                actual_content = content
            
            # 如果没有提供元数据，生成元数据
            if metadata is None:
                metadata = self.metadata_generator.generate_metadata(url, actual_content)
            
            # 使用 DifySyncManager 的智能同步功能
            success = self.dify_manager.sync_document(url, f"TITLE:{title}\nCONTENT:{actual_content}", metadata)
            
            if success:
                print(f"[同步] ✅ 成功：{url} 已同步到 Dify（使用智能哈希对比）")
            else:
                print(f"[同步] ❌ 失败：{url} 同步失败")
            
            return success
            
        except Exception as e:
            print(f"[同步] ❌ 异常：{url} 同步时发生错误: {type(e).__name__}: {e}")
            return False
    
    def sync_documents(self, documents: List[Tuple[str, str, Dict]]) -> bool:
        """
        批量同步文档
        
        Args:
            documents: 文档列表，每个元素为 (url, content, metadata)
            
        Returns:
            是否全部成功
        """
        print(f"[同步] 开始批量同步 {len(documents)} 个文档")
        
        success_count = 0
        total_count = len(documents)
        
        for i, (url, content, metadata) in enumerate(documents, 1):
            print(f"\n[同步] 处理文档 {i}/{total_count}: {url}")
            
            if self.sync_to_dify(url, content, metadata):
                success_count += 1
        
        print(f"\n[同步] 批量同步完成: {success_count}/{total_count} 成功")
        
        # 打印统计信息
        self.dify_manager.print_stats()
        
        return success_count == total_count
    
    def get_stats(self) -> Dict:
        """获取同步统计信息"""
        return self.dify_manager.get_stats()


def sync_to_dify(url: str, content: str, config: Config, metadata: Dict = None) -> bool:
    """
    [任务 4] 将新/变更的文档同步到 Dify 知识库。
    Kiro 任务：请根据 API 文档重写此函数，实现“更新”逻辑并处理所有 API 错误。
    """
    print(f"[任务 4] 准备同步到 Dify: {url}")
    
    # Kiro 注意：以下是“创建”逻辑的草案，你需要实现“更新”逻辑
    


    # 准备 API 请求
    # 使用第一个知识库 ID（primary 策略）
    kb_id = config.dify_knowledge_base_ids[0]
    api_url = f"{config.dify_api_base_url}/datasets/{kb_id}/document/create_by_text"
    headers = {"Authorization": f"Bearer {config.dify_api_key}", "Content-Type": "application/json"}
    
    # 准备请求数据
    document_name = url
    if metadata:
        # 使用元数据生成更好的文档名称
        doc_type = metadata.get('document_type', '文档')
        difficulty = metadata.get('difficulty_level', '')
        product_id = metadata.get('product_id', '')
        
        if product_id:
            document_name = f"[{product_id}] {doc_type}"
            if difficulty:
                document_name += f" ({difficulty})"
        
        # 添加关键词作为标签
        keywords = metadata.get('keywords', [])
        if keywords:
            document_name += f" - {', '.join(keywords[:3])}"
    
    data = {
        'name': document_name,
        'text': content,
        'indexing_technique': 'high_quality',
        'process_rule': {'mode': 'automatic'}
    }
    
    # 如果有元数据，添加到请求中
    if metadata:
        data['metadata'] = {
            'url': url,
            'document_type': metadata.get('document_type'),
            'difficulty_level': metadata.get('difficulty_level'),
            'keywords': metadata.get('keywords', []),
            'content_length': metadata.get('content_length'),
            'product_id': metadata.get('product_id')
        }
    
    try:
        # 发送 POST 请求
        response = requests.post(api_url, headers=headers, json=data, timeout=config.request_timeout)

        # 处理响应
        if response.status_code == 201 or response.status_code == 200:
            print(f"[任务 4] 成功：{url} 已同步到 Dify。")
            return True
        else:
            # Kiro：请在此处添加更详细的错误处理
            print(f"[任务 4] 失败：{url} 同步失败。状态码: {response.status_code}, 响应: {response.text}")
            return False
            
    except requests.RequestException as e:
        print(f"[任务 4] 失败：{url} 同步时发生网络错误: {e}")
        return False



def main():
    """
    主执行函数：编排所有任务
    """
    # 初始化日志系统
    logger = setup_logger(
        name="TKE_SYNC",
        log_level=LogLevel.INFO,
        console_output=True,
        file_output=True
    )
    
    # 初始化临时文件管理器
    temp_manager = setup_temp_manager(
        base_prefix="tke_sync_",
        max_age_hours=24,
        max_total_size_mb=512
    )
    
    logger.log_task_start("TKE 文档同步", version="2.0")
    
    try:
        # 初始化配置管理器
        logger.info("初始化配置管理器...")
        config_manager = ConfigManager()
        
        # 验证配置
        if not config_manager.validate_config():
            logger.error("配置验证失败，程序终止")
            return
        
        config = config_manager.get_config()
        logger.info(f"配置加载成功，知识库数量: {len(config.dify_knowledge_base_ids)}")
        
        # 初始化状态管理器
        logger.info(f"从 {config.state_file} 加载状态...")
        state_manager = StateManager(config.state_file)
        crawl_state = state_manager.load_state()
        new_state = crawl_state.copy()
        
        # 初始化内容抓取器
        logger.info("初始化内容抓取器...")
        content_scraper = ContentScraper(config)
        
        # 初始化元数据生成器
        logger.info("初始化元数据生成器...")
        metadata_generator = EnhancedMetadataGenerator()
        
        # 初始化 Dify 同步管理器
        logger.info("初始化 Dify 同步管理器...")
        dify_sync_manager = DifySyncManager(config)
        
        # 设置知识库策略
        if config.kb_strategy == "all":
            dify_sync_manager.set_strategy(KnowledgeBaseStrategy.ALL)
        elif config.kb_strategy == "round_robin":
            dify_sync_manager.set_strategy(KnowledgeBaseStrategy.ROUND_ROBIN)
        else:
            dify_sync_manager.set_strategy(KnowledgeBaseStrategy.PRIMARY)
        
        # 构建 TF-IDF 语料库
        logger.info("开始构建 TF-IDF 语料库...")
        corpus_built = False
    
        # 获取所有 URL
        logger.log_task_start("URL 发现")
        all_urls = get_all_doc_urls(config.start_url, config.base_url)
        if not all_urls:
            logger.error("未能获取到任何 URL，任务终止")
            return
        logger.log_task_complete("URL 发现", 0, url_count=len(all_urls))

        to_update_queue = []  # 待更新列表

        # 遍历、抓取、对比哈希值
        logger.log_task_start("内容抓取和变更检测", total_urls=len(all_urls))
        
        for i, url in enumerate(all_urls):
            logger.info(f"处理进度 {i+1}/{len(all_urls)}: {url}")
            
            # 抓取内容
            content = content_scraper.scrape_content(url)
            if not content:
                logger.warning(f"跳过 {url} (无法抓取内容)")
                continue
            
            # 将内容添加到语料库（用于 TF-IDF 计算）
            if not corpus_built:
                metadata_generator.add_document_to_corpus(content)
                
            # 计算哈希并对比
            new_hash = get_content_hash(content)
            old_hash = crawl_state.get(url)

            if new_hash == old_hash:
                logger.debug(f"内容未变更: {url}")
                # 即使未变更，也必须将其保留在 new_state 中
                new_state[url] = old_hash
            else:
                if old_hash is None:
                    logger.info(f"发现新文档: {url}")
                else:
                    logger.info(f"内容已变更: {url}")
                
                # 生成元数据
                metadata = metadata_generator.generate_metadata(url, content)
                logger.debug(f"生成元数据: 类型={metadata.get('document_type')}, 难度={metadata.get('difficulty_level')}")
                
                # 加入待同步队列
                to_update_queue.append({
                    "url": url,
                    "content": content,
                    "hash": new_hash,
                    "metadata": metadata
                })

        # 标记语料库构建完成
        corpus_built = True
        logger.log_task_complete("内容抓取和变更检测", 0, 
                               processed_urls=len(all_urls), 
                               changed_docs=len(to_update_queue))
        
        # 执行同步
        if not to_update_queue:
            logger.info("没有文档需要同步")
        else:
            logger.log_task_start("Dify 同步", documents_to_sync=len(to_update_queue))
            
            sync_success_count = 0
            sync_failure_count = 0
            
            for i, item in enumerate(to_update_queue):
                url = item['url']
                content = item['content']
                new_hash = item['hash']
                metadata = item['metadata']
                
                logger.info(f"同步进度 {i+1}/{len(to_update_queue)}: {url}")
                logger.debug(f"元数据 - 类型: {metadata.get('document_type')}, "
                           f"难度: {metadata.get('difficulty_level')}, "
                           f"关键词: {', '.join(metadata.get('keywords', [])[:3])}")
                
                # 关键逻辑：只有在 Dify 确认上传成功后，才更新本地状态
                try:
                    success = dify_sync_manager.sync_document(url, content, metadata)
                    
                    if success:
                        # 确认成功，更新 new_state 中的哈希值
                        new_state[url] = new_hash
                        sync_success_count += 1
                        logger.info(f"同步成功: {url}")
                    else:
                        sync_failure_count += 1
                        logger.error(f"同步失败: {url} - 本地状态将不被更新，下次运行将重试")
                        
                except Exception as e:
                    sync_failure_count += 1
                    logger.log_exception(f"同步异常: {url}", e)
            
            logger.log_task_complete("Dify 同步", 0, 
                                   success_count=sync_success_count,
                                   failure_count=sync_failure_count)

        # 保存最终状态
        logger.log_task_start("状态保存")
        success = state_manager.save_state(new_state)
        if success:
            logger.info(f"状态已更新到 {config.state_file}")
        else:
            logger.error(f"状态保存失败，请检查 {config.state_file}")
        
        # 清理临时文件
        state_manager.cleanup_temp_files()
        logger.log_task_complete("状态保存", 0)
        
        # 输出统计信息
        logger.info("输出统计信息...")
        content_scraper.print_stats()
        dify_sync_manager.print_stats()
        state_manager.print_stats()
        temp_manager.print_stats()
        
        # 打印执行摘要
        logger.print_execution_summary()
        
    except Exception as e:
        logger.log_exception("主程序执行异常", e)
        raise
    finally:
        # 清理资源
        logger.info("清理资源...")
        temp_manager.cleanup_all()
        logger.close()


if __name__ == "__main__":
    try:
        main()
    except ConfigurationError as e:
        print(f"\n{e}")
        print(f"\n🔧 配置帮助:")
        print(f"   运行 'python test_config.py' 获取详细的配置指导")
        exit(1)
    except KeyboardInterrupt:
        print(f"\n\n⚠️ 用户中断了程序执行")
        print(f"💡 程序已安全退出")
        exit(0)
    except Exception as e:
        print(f"\n❌ 程序执行异常: {e}")
        print(f"\n🔍 调试信息:")
        print(f"   1. 检查配置文件是否正确")
        print(f"   2. 确认网络连接正常")
        print(f"   3. 查看日志文件获取详细信息")
        print(f"   4. 运行 'python test_config.py' 验证配置")
        import traceback
        traceback.print_exc()
        exit(1)