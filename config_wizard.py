#!/usr/bin/env python3
"""
TKE 文档同步系统配置向导
帮助用户快速配置系统
"""

import os
import sys
import re
from pathlib import Path

class ConfigWizard:
    def __init__(self):
        self.config = {}
        self.config_file = ".env"
        
    def print_header(self):
        print("🔧 TKE 文档同步系统配置向导")
        print("=" * 50)
        print("本向导将帮助您配置 TKE 文档同步系统")
        print()
    
    def validate_api_key(self, api_key):
        """验证 API Key 格式"""
        if not api_key:
            return False, "API Key 不能为空"
        
        if not api_key.startswith('dataset-'):
            return False, "API Key 应该以 'dataset-' 开头"
        
        if len(api_key) < 20:
            return False, "API Key 长度太短"
        
        return True, "API Key 格式正确"
    
    def validate_kb_id(self, kb_id):
        """验证知识库 ID 格式"""
        if not kb_id:
            return False, "知识库 ID 不能为空"
        
        # UUID 格式验证
        uuid_pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        if not re.match(uuid_pattern, kb_id, re.IGNORECASE):
            return False, "知识库 ID 应该是 UUID 格式（如：8c6b8e3c-f69c-48ea-b34e-a71798c800ed）"
        
        return True, "知识库 ID 格式正确"
    
    def validate_url(self, url):
        """验证 URL 格式"""
        if not url:
            return False, "URL 不能为空"
        
        if not url.startswith(('http://', 'https://')):
            return False, "URL 应该以 http:// 或 https:// 开头"
        
        return True, "URL 格式正确"
    
    def get_input_with_validation(self, prompt, validator=None, default=None):
        """获取用户输入并验证"""
        while True:
            if default:
                user_input = input(f"{prompt} [{default}]: ").strip()
                if not user_input:
                    user_input = default
            else:
                user_input = input(f"{prompt}: ").strip()
            
            if validator:
                is_valid, message = validator(user_input)
                if is_valid:
                    print(f"✅ {message}")
                    return user_input
                else:
                    print(f"❌ {message}")
                    print("请重新输入")
            else:
                return user_input
    
    def collect_dify_config(self):
        """收集 Dify 配置"""
        print("📋 Dify API 配置")
        print("-" * 30)
        
        print("\n1. 获取 Dify API Key:")
        print("   - 登录 Dify 控制台 (https://dify.ai)")
        print("   - 进入 '设置' → 'API Keys'")
        print("   - 创建新的 API Key")
        
        self.config['DIFY_API_KEY'] = self.get_input_with_validation(
            "\n请输入 Dify API Key",
            self.validate_api_key
        )
        
        print("\n2. 获取知识库 ID:")
        print("   - 进入 Dify 知识库页面")
        print("   - 选择目标知识库")
        print("   - 从 URL 中获取知识库 ID")
        print("   - 格式：8c6b8e3c-f69c-48ea-b34e-a71798c800ed")
        
        self.config['DIFY_KNOWLEDGE_BASE_ID'] = self.get_input_with_validation(
            "\n请输入知识库 ID",
            self.validate_kb_id
        )
        
        print("\n3. Dify API 基础 URL:")
        self.config['DIFY_API_BASE_URL'] = self.get_input_with_validation(
            "请输入 Dify API 基础 URL",
            self.validate_url,
            "https://api.dify.ai/v1"
        )
    
    def collect_sync_config(self):
        """收集同步配置"""
        print("\n📋 同步策略配置")
        print("-" * 30)
        
        print("\n知识库同步策略:")
        print("  primary     - 只使用第一个知识库（推荐）")
        print("  all         - 同步到所有知识库")
        print("  round_robin - 轮询分配到不同知识库")
        
        while True:
            strategy = input("请选择同步策略 [primary]: ").strip().lower()
            if not strategy:
                strategy = "primary"
            
            if strategy in ['primary', 'all', 'round_robin']:
                self.config['KB_STRATEGY'] = strategy
                print(f"✅ 已选择策略: {strategy}")
                break
            else:
                print("❌ 无效的策略，请选择 primary、all 或 round_robin")
    
    def collect_network_config(self):
        """收集网络配置"""
        print("\n📋 网络配置")
        print("-" * 30)
        
        # 请求超时
        while True:
            timeout = input("请求超时时间（秒）[30]: ").strip()
            if not timeout:
                timeout = "30"
            
            try:
                timeout_int = int(timeout)
                if 5 <= timeout_int <= 300:
                    self.config['REQUEST_TIMEOUT'] = timeout
                    print(f"✅ 超时时间设置为: {timeout} 秒")
                    break
                else:
                    print("❌ 超时时间应该在 5-300 秒之间")
            except ValueError:
                print("❌ 请输入有效的数字")
        
        # 重试次数
        while True:
            retries = input("重试次数 [3]: ").strip()
            if not retries:
                retries = "3"
            
            try:
                retries_int = int(retries)
                if 0 <= retries_int <= 10:
                    self.config['RETRY_ATTEMPTS'] = retries
                    print(f"✅ 重试次数设置为: {retries}")
                    break
                else:
                    print("❌ 重试次数应该在 0-10 之间")
            except ValueError:
                print("❌ 请输入有效的数字")
        
        # 重试延迟
        while True:
            delay = input("重试延迟（秒）[2]: ").strip()
            if not delay:
                delay = "2"
            
            try:
                delay_int = int(delay)
                if 1 <= delay_int <= 60:
                    self.config['RETRY_DELAY'] = delay
                    print(f"✅ 重试延迟设置为: {delay} 秒")
                    break
                else:
                    print("❌ 重试延迟应该在 1-60 秒之间")
            except ValueError:
                print("❌ 请输入有效的数字")
    
    def collect_file_config(self):
        """收集文件配置"""
        print("\n📋 文件配置")
        print("-" * 30)
        
        # 获取当前目录
        current_dir = os.getcwd()
        
        # 状态文件
        default_state_file = os.path.join(current_dir, "data", "crawl_state.json")
        state_file = input(f"状态文件路径 [{default_state_file}]: ").strip()
        if not state_file:
            state_file = default_state_file
        self.config['STATE_FILE'] = state_file
        
        # 日志文件
        default_log_file = os.path.join(current_dir, "logs", "tke_sync.log")
        log_file = input(f"日志文件路径 [{default_log_file}]: ").strip()
        if not log_file:
            log_file = default_log_file
        self.config['LOG_FILE'] = log_file
        
        # 创建目录
        os.makedirs(os.path.dirname(state_file), exist_ok=True)
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        print(f"✅ 状态文件: {state_file}")
        print(f"✅ 日志文件: {log_file}")
    
    def collect_tke_config(self):
        """收集 TKE 配置"""
        print("\n📋 TKE 文档配置")
        print("-" * 30)
        
        # 基础 URL
        self.config['BASE_URL'] = self.get_input_with_validation(
            "TKE 基础 URL",
            self.validate_url,
            "https://cloud.tencent.com"
        )
        
        # 起始 URL
        self.config['START_URL'] = self.get_input_with_validation(
            "TKE 文档起始 URL",
            self.validate_url,
            "https://cloud.tencent.com/document/product/457"
        )
    
    def show_config_summary(self):
        """显示配置摘要"""
        print("\n📋 配置摘要")
        print("=" * 50)
        
        print(f"Dify API Key: {self.config['DIFY_API_KEY'][:20]}...")
        print(f"知识库 ID: {self.config['DIFY_KNOWLEDGE_BASE_ID']}")
        print(f"API 基础 URL: {self.config['DIFY_API_BASE_URL']}")
        print(f"同步策略: {self.config['KB_STRATEGY']}")
        print(f"请求超时: {self.config['REQUEST_TIMEOUT']} 秒")
        print(f"重试次数: {self.config['RETRY_ATTEMPTS']}")
        print(f"重试延迟: {self.config['RETRY_DELAY']} 秒")
        print(f"状态文件: {self.config['STATE_FILE']}")
        print(f"日志文件: {self.config['LOG_FILE']}")
        print(f"TKE 基础 URL: {self.config['BASE_URL']}")
        print(f"TKE 起始 URL: {self.config['START_URL']}")
    
    def save_config(self):
        """保存配置到文件"""
        config_content = f"""# TKE 文档同步系统配置文件
# 由配置向导自动生成

# === Dify API 配置 ===
DIFY_API_KEY={self.config['DIFY_API_KEY']}
DIFY_KNOWLEDGE_BASE_ID={self.config['DIFY_KNOWLEDGE_BASE_ID']}
DIFY_API_BASE_URL={self.config['DIFY_API_BASE_URL']}

# === 同步策略 ===
KB_STRATEGY={self.config['KB_STRATEGY']}

# === 网络配置 ===
REQUEST_TIMEOUT={self.config['REQUEST_TIMEOUT']}
RETRY_ATTEMPTS={self.config['RETRY_ATTEMPTS']}
RETRY_DELAY={self.config['RETRY_DELAY']}

# === 文件配置 ===
STATE_FILE={self.config['STATE_FILE']}
LOG_FILE={self.config['LOG_FILE']}

# === TKE 文档配置 ===
BASE_URL={self.config['BASE_URL']}
START_URL={self.config['START_URL']}
"""
        
        # 备份现有配置文件
        if os.path.exists(self.config_file):
            backup_file = f"{self.config_file}.backup"
            os.rename(self.config_file, backup_file)
            print(f"📄 已备份现有配置文件为: {backup_file}")
        
        # 保存新配置
        with open(self.config_file, 'w', encoding='utf-8') as f:
            f.write(config_content)
        
        # 设置文件权限
        os.chmod(self.config_file, 0o600)
        
        print(f"✅ 配置已保存到: {self.config_file}")
    
    def run_wizard(self):
        """运行配置向导"""
        try:
            self.print_header()
            
            # 收集各项配置
            self.collect_dify_config()
            self.collect_sync_config()
            self.collect_network_config()
            self.collect_file_config()
            self.collect_tke_config()
            
            # 显示配置摘要
            self.show_config_summary()
            
            # 确认保存
            print("\n" + "=" * 50)
            confirm = input("确认保存配置？(y/N): ").strip().lower()
            
            if confirm in ['y', 'yes']:
                self.save_config()
                
                print("\n🎉 配置完成！")
                print("\n📋 下一步操作:")
                print("1. 测试配置: python test_config.py")
                print("2. 运行同步: python tke_dify_sync.py")
                print("3. 查看日志: tail -f logs/tke_sync.log")
                
                return True
            else:
                print("❌ 配置已取消")
                return False
                
        except KeyboardInterrupt:
            print("\n\n⚠️ 配置向导已中断")
            return False
        except Exception as e:
            print(f"\n❌ 配置过程中发生错误: {e}")
            return False

def main():
    """主函数"""
    wizard = ConfigWizard()
    success = wizard.run_wizard()
    
    if success:
        print("\n✅ 配置向导执行成功")
        sys.exit(0)
    else:
        print("\n❌ 配置向导执行失败")
        sys.exit(1)

if __name__ == "__main__":
    main()