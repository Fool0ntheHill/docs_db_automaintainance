#!/usr/bin/env python3

"""
Dify API 集成管理器
支持多知识库、智能重试和完整的文档生命周期管理
"""
import requests
import time
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from enum import Enum
import json
from smart_retry_manager import SmartRetryManager, RetryConfig


class KnowledgeBaseStrategy(Enum):
    """知识库选择策略"""
    PRIMARY = "primary"      # 只使用第一个知识库
    ALL = "all"             # 同步到所有知识库
    ROUND_ROBIN = "round_robin"  # 轮询分配


@dataclass
class DifyDocument:
    """Dify 文档信息"""
    document_id: str
    name: str
    character_count: int
    hit_count: int
    word_count: int
    position: int
    enabled: bool
    disabled_at: Optional[str] = None
    disabled_by: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    archived: bool = False


@dataclass
class KnowledgeBaseInfo:
    """知识库信息"""
    kb_id: str
    name: str
    description: str
    permission: str
    data_source_type: str
    indexing_technique: str
    app_count: int
    document_count: int
    word_count: int
    created_by: str
    created_at: str
    updated_by: str
    updated_at: str
    embedding_model: str
    embedding_model_provider: str
    embedding_available: bool = True


class DifyAPIError(Exception):
    """Dify API 错误"""
    def __init__(self, message: str, status_code: int = None, response_data: Dict = None):
        super().__init__(message)
        self.status_code = status_code
        self.response_data = response_data or {}


class DifySyncManager:
    """Dify 同步管理器"""
    
    def __init__(self, config):
        self.config = config
        self.kb_strategy = KnowledgeBaseStrategy.PRIMARY
        self.round_robin_index = 0
        
        # 初始化智能重试管理器
        retry_config = RetryConfig(
            max_attempts=3,
            base_delay=2.0,
            max_delay=60.0,
            failure_threshold=3,
            recovery_timeout=120.0
        )
        self.retry_manager = SmartRetryManager(retry_config)
        
        # 知识库信息缓存
        self.kb_info_cache = {}
        self.kb_settings_cache = {}
        
        # 加载知识库配置
        self.kb_configs = self._load_kb_configs()
        
        # 统计信息
        self.stats = {
            'documents_created': 0,
            'documents_updated': 0,
            'documents_failed': 0,
            'api_calls': 0,
            'kb_failures': {},
            'total_sync_time': 0.0
        }
    
    def _load_kb_configs(self) -> Dict:
        """加载知识库配置（使用默认配置）"""
        return {
            "knowledge_bases": {},
            "default_process_rule": {"mode": "automatic"},
            "default_config": {
                "indexing_technique": "high_quality",
                "doc_form": "text_model",
                "doc_language": "中文",
                "process_rule": {"mode": "automatic"}
            }
        }
    
    def set_strategy(self, strategy: KnowledgeBaseStrategy):
        """设置知识库选择策略"""
        self.kb_strategy = strategy
        print(f"[Dify] 知识库策略设置为: {strategy.value}")
    
    def _make_api_request(self, method: str, endpoint: str, kb_id: str = None, **kwargs) -> requests.Response:
        """
        发送 API 请求（带重试）
        
        Args:
            method: HTTP 方法
            endpoint: API 端点
            kb_id: 知识库 ID（可选）
            **kwargs: 请求参数
            
        Returns:
            响应对象
            
        Raises:
            DifyAPIError: API 错误
        """
        if kb_id:
            if endpoint:
                url = f"{self.config.dify_api_base_url}/datasets/{kb_id}/{endpoint}"
            else:
                url = f"{self.config.dify_api_base_url}/datasets/{kb_id}"
        else:
            url = f"{self.config.dify_api_base_url}/{endpoint}"
        
        headers = {
            "Authorization": f"Bearer {self.config.dify_api_key}",
            "Content-Type": "application/json"
        }
        
        def _do_request():
            self.stats['api_calls'] += 1
            
            response = requests.request(
                method=method,
                url=url,
                headers=headers,
                timeout=self.config.request_timeout,
                **kwargs
            )
            
            # 检查响应状态
            if response.status_code in [200, 201]:
                return response
            elif response.status_code == 401:
                try:
                    error_data = response.json()
                except:
                    error_data = {}
                raise DifyAPIError("认证失败：API Key 无效", response.status_code, error_data)
            elif response.status_code == 403:
                try:
                    error_data = response.json()
                except:
                    error_data = {}
                raise DifyAPIError("权限不足：无法访问该资源", response.status_code, error_data)
            elif response.status_code == 404:
                try:
                    error_data = response.json()
                except:
                    error_data = {}
                raise DifyAPIError("资源不存在", response.status_code, error_data)
            elif response.status_code == 429:
                # 限流，适合重试
                response.raise_for_status()
            elif 500 <= response.status_code < 600:
                # 服务器错误，适合重试
                response.raise_for_status()
            else:
                # 其他错误
                try:
                    error_data = response.json()
                    error_msg = error_data.get('message', f'HTTP {response.status_code}')
                except:
                    error_msg = f'HTTP {response.status_code}: {response.text}'
                raise DifyAPIError(error_msg, response.status_code, error_data if 'error_data' in locals() else {})
        
        try:
            return self.retry_manager.execute_with_retry(
                _do_request,
                endpoint_key=f"dify_{kb_id or 'global'}"
            )
        except Exception as e:
            if isinstance(e, DifyAPIError):
                raise
            else:
                raise DifyAPIError(f"API 请求失败: {str(e)}")
    
    def get_knowledge_base_info(self, kb_id: str, force_refresh: bool = False) -> KnowledgeBaseInfo:
        """
        获取知识库信息
        
        Args:
            kb_id: 知识库 ID
            force_refresh: 强制刷新缓存
            
        Returns:
            知识库信息
        """
        if not force_refresh and kb_id in self.kb_info_cache:
            return self.kb_info_cache[kb_id]
        
        try:
            response = self._make_api_request("GET", "", kb_id)
            try:
                data = response.json()
            except json.JSONDecodeError as e:
                print(f"[Dify] JSON解析失败: {e}")
                print(f"[Dify] 响应状态码: {response.status_code}")
                print(f"[Dify] 响应内容: {response.text[:200]}")
                raise DifyAPIError(f"JSON解析失败: {e}")
            
            kb_info = KnowledgeBaseInfo(
                kb_id=kb_id,
                name=data.get('name', ''),
                description=data.get('description', ''),
                permission=data.get('permission', ''),
                data_source_type=data.get('data_source_type', ''),
                indexing_technique=data.get('indexing_technique', ''),
                app_count=data.get('app_count', 0),
                document_count=data.get('document_count', 0),
                word_count=data.get('word_count', 0),
                created_by=data.get('created_by', ''),
                created_at=data.get('created_at', ''),
                updated_by=data.get('updated_by', ''),
                updated_at=data.get('updated_at', ''),
                embedding_model=data.get('embedding_model', ''),
                embedding_model_provider=data.get('embedding_model_provider', ''),
                embedding_available=data.get('embedding_available', True)
            )
            
            self.kb_info_cache[kb_id] = kb_info
            return kb_info
            
        except DifyAPIError as e:
            print(f"[Dify] 获取知识库信息失败 {kb_id}: {e}")
            raise
    
    def get_knowledge_base_settings(self, kb_id: str, force_refresh: bool = False) -> Dict:
        """
        获取知识库处理设置
        
        Args:
            kb_id: 知识库 ID
            force_refresh: 强制刷新缓存
            
        Returns:
            知识库设置
        """
        if not force_refresh and kb_id in self.kb_settings_cache:
            return self.kb_settings_cache[kb_id]
        
        # 首先检查本地配置
        kb_configs = self.kb_configs.get("knowledge_bases", {})
        if kb_id in kb_configs and "process_rule" in kb_configs[kb_id]:
            settings = kb_configs[kb_id]["process_rule"]
            print(f"[Dify] 使用本地配置的知识库设置: {kb_id}")
            self.kb_settings_cache[kb_id] = settings
            return settings
        
        # 如果本地没有配置，尝试从 API 获取
        try:
            response = self._make_api_request("GET", "process-rule", kb_id)
            settings = response.json()
            
            self.kb_settings_cache[kb_id] = settings
            return settings
            
        except DifyAPIError as e:
            print(f"[Dify] 获取知识库设置失败 {kb_id}: {e}")
            # 返回默认设置
            default_settings = self.kb_configs.get("default_process_rule", {
                'mode': 'automatic',
                'rules': {
                    'pre_processing_rules': [],
                    'segmentation': {
                        'separator': '\n\n',
                        'max_tokens': 1000
                    }
                }
            })
            return default_settings
    
    def _get_kb_full_config(self, kb_id: str) -> Dict:
        """
        获取知识库的完整配置
        
        Args:
            kb_id: 知识库 ID
            
        Returns:
            完整的知识库配置
        """
        # 首先检查本地配置
        kb_configs = self.kb_configs.get("knowledge_bases", {})
        if kb_id in kb_configs:
            config = kb_configs[kb_id].copy()
            print(f"[Dify] 使用本地完整配置: {kb_id}")
            return config
        
        # 如果本地没有配置，使用默认配置
        default_config = self.kb_configs.get("default_config", {
            "indexing_technique": "high_quality",
            "doc_form": "text_model",
            "doc_language": "中文",
            "process_rule": {"mode": "automatic"},
            "retrieval_model": {
                "search_method": "hybrid_search",
                "reranking_enable": True,
                "top_k": 10,
                "score_threshold_enabled": False
            }
        })
        
        print(f"[Dify] 使用默认完整配置: {kb_id}")
        return default_config
    
    def check_knowledge_base_availability(self, kb_id: str) -> bool:
        """
        检查知识库可用性
        
        Args:
            kb_id: 知识库 ID
            
        Returns:
            是否可用
        """
        try:
            kb_info = self.get_knowledge_base_info(kb_id)
            return kb_info.embedding_available
        except Exception as e:
            print(f"[Dify] 知识库 {kb_id} 不可用: {e}")
            return False
    
    def get_available_knowledge_bases(self) -> List[str]:
        """
        获取可用的知识库列表
        
        Returns:
            可用知识库 ID 列表
        """
        available_kbs = []
        failed_kbs = []
        
        print(f"[Dify] 🔍 检查 {len(self.config.dify_knowledge_base_ids)} 个知识库的可用性...")
        
        for kb_id in self.config.dify_knowledge_base_ids:
            if self.check_knowledge_base_availability(kb_id):
                available_kbs.append(kb_id)
                print(f"[Dify] ✅ 知识库可用: {kb_id}")
            else:
                failed_kbs.append(kb_id)
                print(f"[Dify] ❌ 知识库不可用: {kb_id}")
                # 记录失败的知识库
                if kb_id not in self.stats['kb_failures']:
                    self.stats['kb_failures'][kb_id] = 0
                self.stats['kb_failures'][kb_id] += 1
        
        # 如果没有可用的知识库，提供详细的诊断信息
        if not available_kbs:
            self._handle_no_available_knowledge_bases(failed_kbs)
        
        return available_kbs
    
    def _handle_no_available_knowledge_bases(self, failed_kbs: List[str]):
        """处理没有可用知识库的情况"""
        print("\n" + "="*60)
        print("⚠️  没有可用的知识库")
        print("="*60)
        
        print(f"📋 检查的知识库数量: {len(failed_kbs)}")
        print(f"📋 失败的知识库: {', '.join(failed_kbs)}")
        
        print("\n🔍 可能的原因:")
        print("  1. 网络连接问题")
        print("  2. API Key 无效或已过期")
        print("  3. 知识库 ID 配置错误")
        print("  4. Dify 服务暂时不可用")
        print("  5. 知识库权限不足")
        
        print("\n💡 建议的解决方案:")
        print("  1. 检查网络连接是否正常")
        print("  2. 验证 API Key 是否有效:")
        print("     - 登录 Dify 控制台")
        print("     - 检查 API Key 是否正确")
        print("     - 确认 API Key 权限")
        print("  3. 验证知识库 ID:")
        print("     - 登录 Dify 控制台")
        print("     - 检查知识库是否存在")
        print("     - 从 URL 中获取正确的知识库 ID")
        print("  4. 检查 Dify API 基础 URL 是否正确")
        print("  5. 稍后重试或联系管理员")
        
        print("\n🛠️  调试步骤:")
        print("  1. 运行配置测试: python test_config.py")
        print("  2. 检查日志文件获取详细错误信息")
        print("  3. 尝试手动访问 Dify API")
        print("="*60)
    
    def select_knowledge_base(self) -> str:
        """
        根据策略选择知识库
        
        Returns:
            选中的知识库 ID
            
        Raises:
            DifyAPIError: 没有可用的知识库
        """
        available_kbs = self.get_available_knowledge_bases()
        
        if not available_kbs:
            raise DifyAPIError("没有可用的知识库")
        
        if self.kb_strategy == KnowledgeBaseStrategy.PRIMARY:
            return available_kbs[0]
        elif self.kb_strategy == KnowledgeBaseStrategy.ROUND_ROBIN:
            kb_id = available_kbs[self.round_robin_index % len(available_kbs)]
            self.round_robin_index += 1
            return kb_id
        else:  # ALL 策略在调用方处理
            return available_kbs[0]
    
    def find_document_by_url(self, kb_id: str, url: str) -> Optional[DifyDocument]:
        """
        根据URL查找文档（通过元数据中的URL字段）
        
        Args:
            kb_id: 知识库 ID
            url: 文档 URL
            
        Returns:
            文档信息，如果不存在返回 None
        """
        try:
            # 获取文档列表，分页查询
            page = 1
            limit = 50
            
            while True:
                response = self._make_api_request("GET", "documents", kb_id, params={
                    'page': page,
                    'limit': limit
                })
                
                data = response.json()
                documents = data.get('data', [])
                
                if not documents:
                    break
                
                # 查找匹配URL的文档
                for doc_data in documents:
                    # 检查元数据中的URL（新格式：列表形式）
                    doc_metadata_list = doc_data.get('doc_metadata', [])
                    if doc_metadata_list:
                        # 将元数据列表转换为字典
                        metadata_dict = {}
                        for item in doc_metadata_list:
                            if item.get('name'):
                                metadata_dict[item['name']] = item.get('value')
                        
                        if metadata_dict.get('url') == url:
                            return DifyDocument(
                                document_id=doc_data['id'],
                                name=doc_data['name'],
                                character_count=doc_data.get('character_count', 0),
                                hit_count=doc_data.get('hit_count', 0),
                                word_count=doc_data.get('word_count', 0),
                                position=doc_data.get('position', 0),
                                enabled=doc_data.get('enabled', True),
                                disabled_at=doc_data.get('disabled_at'),
                                disabled_by=doc_data.get('disabled_by'),
                                created_at=doc_data.get('created_at'),
                                updated_at=doc_data.get('updated_at'),
                                archived=doc_data.get('archived', False)
                            )
                
                # 检查是否还有更多页面
                if len(documents) < limit:
                    break
                page += 1
            
            return None
            
        except DifyAPIError as e:
            print(f"[Dify] 查找文档失败 {kb_id}/{url}: {e}")
            return None
    
    def find_document_by_name(self, kb_id: str, document_name: str) -> Optional[DifyDocument]:
        """
        根据名称查找文档（保留兼容性）
        
        Args:
            kb_id: 知识库 ID
            document_name: 文档名称
            
        Returns:
            文档信息，如果不存在返回 None
        """
        try:
            # 获取文档列表
            response = self._make_api_request("GET", "documents", kb_id, params={
                'keyword': document_name,
                'page': 1,
                'limit': 20
            })
            
            data = response.json()
            documents = data.get('data', [])
            
            # 查找完全匹配的文档
            for doc_data in documents:
                if doc_data.get('name') == document_name:
                    return DifyDocument(
                        document_id=doc_data['id'],
                        name=doc_data['name'],
                        character_count=doc_data.get('character_count', 0),
                        hit_count=doc_data.get('hit_count', 0),
                        word_count=doc_data.get('word_count', 0),
                        position=doc_data.get('position', 0),
                        enabled=doc_data.get('enabled', True),
                        disabled_at=doc_data.get('disabled_at'),
                        disabled_by=doc_data.get('disabled_by'),
                        created_at=doc_data.get('created_at'),
                        updated_at=doc_data.get('updated_at'),
                        archived=doc_data.get('archived', False)
                    )
            
            return None
            
        except DifyAPIError as e:
            print(f"[Dify] 查找文档失败 {kb_id}/{document_name}: {e}")
            return None
    
    def create_document(self, kb_id: str, name: str, content: str, metadata: Dict = None) -> Optional[str]:
        """
        创建新文档（两步式：先创建文档，再设置元数据）
        
        Args:
            kb_id: 知识库 ID
            name: 文档名称
            content: 文档内容
            metadata: 元数据
            
        Returns:
            文档ID，如果失败返回None
        """
        try:
            # 第一步：创建文档
            document_id = self._create_document_only(kb_id, name, content)
            if not document_id:
                return None
            
            # 第二步：设置元数据（如果提供了元数据）
            if metadata:
                if not self._set_document_metadata(kb_id, document_id, metadata):
                    print(f"[Dify] 警告：文档创建成功但元数据设置失败: {name}")
                    # 不返回失败，因为文档已经创建成功
            
            print(f"[Dify] 文档创建成功: {name} -> {document_id}")
            self.stats['documents_created'] += 1
            return document_id
                
        except DifyAPIError as e:
            print(f"[Dify] 文档创建失败 {name}: {e}")
            self.stats['documents_failed'] += 1
            return None
    
    def _create_document_only(self, kb_id: str, name: str, content: str) -> Optional[str]:
        """
        仅创建文档（不设置元数据）
        
        Args:
            kb_id: 知识库 ID
            name: 文档名称
            content: 文档内容
            
        Returns:
            文档ID，如果失败返回None
        """
        try:
            # 获取知识库完整配置
            kb_config = self._get_kb_full_config(kb_id)
            
            # 准备请求数据
            data = {
                'name': name,
                'text': content,
                'indexing_technique': kb_config.get('indexing_technique', 'high_quality'),
                'doc_form': kb_config.get('doc_form', 'text_model'),
                'doc_language': kb_config.get('doc_language', '中文'),
                'process_rule': kb_config.get('process_rule', {'mode': 'automatic'})
            }
            
            # 添加检索模型配置
            if 'retrieval_model' in kb_config:
                data['retrieval_model'] = kb_config['retrieval_model']
            
            # 发送创建请求
            response = self._make_api_request("POST", "document/create_by_text", kb_id, json=data)
            
            result = response.json()
            document_id = result.get('document', {}).get('id')
            
            if document_id:
                print(f"[Dify] 文档创建成功: {name} -> {document_id}")
                print(f"[Dify] 使用配置: doc_form={data['doc_form']}, mode={data['process_rule']['mode']}")
                return document_id
            else:
                print(f"[Dify] 文档创建失败: {name} - 未返回文档 ID")
                return None
                
        except DifyAPIError as e:
            print(f"[Dify] 文档创建失败 {name}: {e}")
            return None
    
    def _set_document_metadata(self, kb_id: str, document_id: str, metadata: Dict) -> bool:
        """
        设置文档元数据
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            metadata: 元数据字典
            
        Returns:
            是否成功
        """
        try:
            # 首先获取知识库的元数据字段配置
            metadata_fields = self._get_metadata_fields(kb_id)
            if not metadata_fields:
                print(f"[Dify] 警告：知识库 {kb_id} 没有配置元数据字段")
                return False
            
            # 构建元数据列表
            metadata_list = []
            
            # 处理标准元数据字段
            standard_fields = {
                'url': metadata.get('url'),
                'content_hash': metadata.get('content_hash'),
                'doc_type': self._normalize_doc_type(metadata.get('document_type', '概述类文档'))
            }
            
            for field_name, field_value in standard_fields.items():
                if field_value and field_name in metadata_fields:
                    metadata_list.append({
                        "id": metadata_fields[field_name],
                        "value": str(field_value),
                        "name": field_name
                    })
            
            if not metadata_list:
                print(f"[Dify] 警告：没有有效的元数据字段可设置")
                return False
            
            # 构建更新请求
            update_data = {
                "operation_data": [
                    {
                        "document_id": document_id,
                        "metadata_list": metadata_list
                    }
                ]
            }
            
            # 发送元数据更新请求
            response = self._make_api_request("POST", "documents/metadata", kb_id, json=update_data)
            
            result = response.json()
            if result.get('result') == 'success':
                print(f"[Dify] 元数据设置成功: {document_id}")
                return True
            else:
                print(f"[Dify] 元数据设置失败: {document_id}")
                return False
                
        except DifyAPIError as e:
            print(f"[Dify] 元数据设置失败 {document_id}: {e}")
            return False
    
    def _get_metadata_fields(self, kb_id: str) -> Dict[str, str]:
        """
        获取知识库的元数据字段配置
        
        Args:
            kb_id: 知识库 ID
            
        Returns:
            字段名到字段ID的映射
        """
        try:
            response = self._make_api_request("GET", "metadata", kb_id)
            result = response.json()
            
            field_mapping = {}
            doc_metadata = result.get('doc_metadata', [])
            for field in doc_metadata:
                field_mapping[field['name']] = field['id']
            
            return field_mapping
            
        except DifyAPIError as e:
            print(f"[Dify] 获取元数据字段失败 {kb_id}: {e}")
            return {}
    
    def _get_document_hash(self, kb_id: str, document_id: str) -> Optional[str]:
        """
        获取文档的内容哈希值
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            
        Returns:
            文档的content_hash值，如果获取失败返回None
        """
        try:
            response = self._make_api_request("GET", f"documents/{document_id}", kb_id)
            doc_details = response.json()
            
            # 从元数据中获取哈希值
            doc_metadata_list = doc_details.get('doc_metadata', [])
            if doc_metadata_list:
                for item in doc_metadata_list:
                    if item.get('name') == 'content_hash':
                        hash_value = item.get('value')
                        if hash_value:
                            print(f"[Dify] 获取到现有文档哈希: {hash_value}")
                            return hash_value
            
            print(f"[Dify] 文档 {document_id} 没有找到content_hash元数据")
            return None
            
        except DifyAPIError as e:
            print(f"[Dify] 获取文档哈希失败 {document_id}: {e}")
            return None

    def _normalize_doc_type(self, doc_type: str) -> str:
        """
        标准化文档类型，确保只返回两种标准值
        
        Args:
            doc_type: 原始文档类型
            
        Returns:
            标准化的文档类型
        """
        if not doc_type:
            return '概述类文档'
        
        doc_type_lower = doc_type.lower()
        
        # 操作类关键词
        operation_keywords = ['操作', '教程', '指南', '步骤', '如何', '怎么', 'tutorial', 'guide', 'how', 'step']
        
        # 检查是否包含操作类关键词
        for keyword in operation_keywords:
            if keyword in doc_type_lower:
                return '操作类文档'
        
        # 默认返回概述类
        return '概述类文档'

    def update_document(self, kb_id: str, document_id: str, name: str, content: str, metadata: Dict = None) -> bool:
        """
        更新现有文档（包括内容和元数据）
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            name: 文档名称
            content: 文档内容
            metadata: 元数据
            
        Returns:
            是否成功
        """
        try:
            # 第一步：更新文档内容
            content_updated = self._update_document_content(kb_id, document_id, name, content)
            if not content_updated:
                return False
            
            # 第二步：更新元数据（如果提供了元数据）
            if metadata:
                if not self._set_document_metadata(kb_id, document_id, metadata):
                    print(f"[Dify] 警告：文档内容更新成功但元数据更新失败: {name}")
                    # 不返回失败，因为内容已经更新成功
            
            print(f"[Dify] 文档更新成功: {name}")
            self.stats['documents_updated'] += 1
            return True
                
        except DifyAPIError as e:
            print(f"[Dify] 文档更新失败 {name}: {e}")
            self.stats['documents_failed'] += 1
            return False
    
    def _update_document_content(self, kb_id: str, document_id: str, name: str, content: str) -> bool:
        """
        仅更新文档内容（不更新元数据）
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            name: 文档名称
            content: 文档内容
            
        Returns:
            是否成功
        """
        try:
            # 获取知识库完整配置
            kb_config = self._get_kb_full_config(kb_id)
            
            # 准备请求数据
            data = {
                'name': name,
                'text': content,
                'doc_form': kb_config.get('doc_form', 'text_model'),
                'doc_language': kb_config.get('doc_language', '中文'),
                'process_rule': kb_config.get('process_rule', {'mode': 'automatic'})
            }
            
            # 添加检索模型配置
            if 'retrieval_model' in kb_config:
                data['retrieval_model'] = kb_config['retrieval_model']
            
            # 发送更新请求
            response = self._make_api_request("POST", f"documents/{document_id}/update_by_text", kb_id, json=data)
            
            result = response.json()
            
            if result.get('document'):
                print(f"[Dify] 文档内容更新成功: {name}")
                print(f"[Dify] 使用配置: doc_form={data['doc_form']}, mode={data['process_rule']['mode']}")
                return True
            else:
                print(f"[Dify] 文档内容更新失败: {name}")
                return False
                
        except DifyAPIError as e:
            print(f"[Dify] 文档内容更新失败 {name}: {e}")
            return False
    
    def delete_document(self, kb_id: str, document_id: str) -> bool:
        """
        删除文档
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            
        Returns:
            是否成功
        """
        try:
            response = self._make_api_request("DELETE", f"documents/{document_id}", kb_id)
            
            # 检查响应状态码
            if response.status_code in [200, 201, 204]:
                print(f"[Dify] 文档删除成功: {document_id}")
                return True
            
            # 尝试解析JSON响应
            try:
                result = response.json()
                if isinstance(result, dict) and result.get('result') == 'success':
                    print(f"[Dify] 文档删除成功: {document_id}")
                    return True
                else:
                    print(f"[Dify] 文档删除失败: {document_id} - {result}")
                    return False
            except:
                # 如果无法解析JSON，根据状态码判断
                print(f"[Dify] 文档删除响应状态码: {response.status_code}")
                return response.status_code in [200, 201, 204]
                
        except DifyAPIError as e:
            print(f"[Dify] 文档删除失败 {document_id}: {e}")
            return False
    
    def sync_document(self, url: str, content_with_title: str, metadata: Dict = None) -> bool:
        """
        同步文档到知识库（创建或更新）
        
        Args:
            url: 文档 URL
            content_with_title: 包含标题和内容的字符串
            metadata: 元数据
            
        Returns:
            是否成功
        """
        start_time = time.time()
        
        try:
            # 解析标题和内容
            try:
                title, content = self._parse_title_and_content(content_with_title)
            except Exception as e:
                print(f"[Dify] ❌ 解析文档内容失败: {e}")
                print(f"[Dify] 📄 文档 URL: {url}")
                return False
            
            # 确保元数据包含URL
            if metadata is None:
                metadata = {}
            metadata['url'] = url
            
            # 获取可用的知识库
            try:
                available_kbs = self.get_available_knowledge_bases()
                if not available_kbs:
                    print(f"[Dify] ⚠️ 跳过文档同步（没有可用的知识库）: {title}")
                    return False
            except Exception as e:
                print(f"[Dify] ❌ 获取可用知识库失败: {e}")
                return False
            
            if self.kb_strategy == KnowledgeBaseStrategy.ALL:
                # 同步到所有可用知识库
                success_count = 0
                failed_kbs = []
                
                for kb_id in available_kbs:
                    try:
                        if self._sync_to_single_kb(kb_id, title, content, url, metadata):
                            success_count += 1
                        else:
                            failed_kbs.append(kb_id)
                    except Exception as e:
                        print(f"[Dify] ❌ 同步到知识库 {kb_id} 失败: {e}")
                        failed_kbs.append(kb_id)
                
                success = success_count > 0
                
                if success:
                    print(f"[Dify] ✅ 多知识库同步完成: {success_count}/{len(available_kbs)} 成功")
                    if failed_kbs:
                        print(f"[Dify] ⚠️ 失败的知识库: {', '.join(failed_kbs)}")
                else:
                    print(f"[Dify] ❌ 多知识库同步全部失败")
                    print(f"[Dify] 📋 失败的知识库: {', '.join(failed_kbs)}")
                
            else:
                # 同步到单个知识库
                try:
                    kb_id = self.select_knowledge_base()
                    if not kb_id:
                        print(f"[Dify] ❌ 无法选择知识库进行同步")
                        return False
                    
                    success = self._sync_to_single_kb(kb_id, title, content, url, metadata)
                    
                    if success:
                        print(f"[Dify] ✅ 文档同步成功: {title}")
                    else:
                        print(f"[Dify] ❌ 文档同步失败: {title}")
                        
                except Exception as e:
                    print(f"[Dify] ❌ 文档同步异常: {e}")
                    print(f"[Dify] 📄 文档: {title}")
                    success = False
            
            return success
            
        except Exception as e:
            print(f"[Dify] ❌ 文档同步过程异常: {e}")
            print(f"[Dify] 📄 URL: {url}")
            return False
            
        finally:
            elapsed_time = time.time() - start_time
            self.stats['total_sync_time'] += elapsed_time
    
    def _parse_title_and_content(self, content_with_title: str) -> Tuple[str, str]:
        """
        解析包含标题和内容的字符串
        
        Args:
            content_with_title: 格式为 "TITLE:标题\nCONTENT:内容" 的字符串
            
        Returns:
            (标题, 内容) 元组
        """
        try:
            if content_with_title.startswith("TITLE:"):
                lines = content_with_title.split('\n', 2)
                if len(lines) >= 2:
                    title = lines[0][6:]  # 去掉 "TITLE:" 前缀
                    content = lines[1][8:] if lines[1].startswith("CONTENT:") else lines[1]  # 去掉 "CONTENT:" 前缀
                    if len(lines) > 2:
                        content += '\n' + lines[2]
                    return title, content
            
            # 如果格式不匹配，返回默认值
            return "TKE 文档", content_with_title
            
        except Exception as e:
            print(f"[Dify] 解析标题和内容失败: {e}")
            return "TKE 文档", content_with_title
    
    def _sync_to_single_kb(self, kb_id: str, document_title: str, content: str, url: str, metadata: Dict = None) -> bool:
        """
        同步到单个知识库（带智能哈希对比）
        
        Args:
            kb_id: 知识库 ID
            document_title: 文档标题
            content: 文档内容
            url: 文档URL
            metadata: 元数据
            
        Returns:
            是否成功
        """
        try:
            # 确保元数据包含必要信息
            if metadata is None:
                metadata = {}
            
            # 确保URL在元数据中
            metadata['url'] = url
            
            # 1. 计算新内容的哈希
            import hashlib
            new_content_hash = hashlib.md5(content.encode('utf-8')).hexdigest()
            metadata['content_hash'] = new_content_hash
            
            # 2. 根据URL查找现有文档
            existing_doc = self.find_document_by_url(kb_id, url)
            
            if existing_doc:
                # 3. 获取现有文档的哈希值
                existing_hash = self._get_document_hash(kb_id, existing_doc.document_id)
                
                # 4. 比较哈希值
                if existing_hash and existing_hash == new_content_hash:
                    # 内容相同，跳过同步
                    print(f"[Dify] 内容未变更，跳过同步: {document_title}")
                    print(f"[Dify] 哈希值: {new_content_hash}")
                    return True
                else:
                    # 内容不同，执行更新
                    if existing_hash:
                        print(f"[Dify] 检测到内容变更: {document_title}")
                        print(f"[Dify] 旧哈希: {existing_hash}")
                        print(f"[Dify] 新哈希: {new_content_hash}")
                    else:
                        print(f"[Dify] 无法获取现有哈希，执行更新: {document_title}")
                    
                    success = self.update_document(kb_id, existing_doc.document_id, document_title, content, metadata)
                    
                    if not success:
                        # 更新失败，尝试删除后重建
                        print(f"[Dify] 更新失败，尝试删除重建: {document_title}")
                        if self.delete_document(kb_id, existing_doc.document_id):
                            print(f"[Dify] 文档删除成功，开始重建")
                            document_id = self.create_document(kb_id, document_title, content, metadata)
                            success = document_id is not None
                        else:
                            print(f"[Dify] 文档删除失败，无法重建")
                            success = False
                    
                    return success
                
            else:
                # 5. 没找到现有文档，创建新文档
                print(f"[Dify] 创建新文档: {document_title}")
                print(f"[Dify] 内容哈希: {new_content_hash}")
                document_id = self.create_document(kb_id, document_title, content, metadata)
                success = document_id is not None
                return success
            
        except Exception as e:
            print(f"[Dify] 同步到知识库失败 {kb_id}: {e}")
            return False
    
    def _generate_document_name(self, url: str, metadata: Dict = None) -> str:
        """
        生成文档名称
        
        Args:
            url: 文档 URL
            metadata: 元数据
            
        Returns:
            文档名称
        """
        if not metadata:
            return url
        
        # 使用元数据生成更好的文档名称
        doc_type = metadata.get('document_type', '文档')
        difficulty = metadata.get('difficulty_level', '')
        product_id = metadata.get('product_id', '')
        
        if product_id:
            document_name = f"[{product_id}] {doc_type}"
            if difficulty:
                document_name += f" ({difficulty})"
        else:
            document_name = f"{doc_type}"
            if difficulty:
                document_name += f" ({difficulty})"
        
        # 添加关键词作为标签
        keywords = metadata.get('keywords', [])
        if keywords:
            document_name += f" - {', '.join(keywords[:3])}"
        
        return document_name
    
    def get_stats(self) -> Dict:
        """获取统计信息"""
        stats = self.stats.copy()
        
        # 添加重试统计
        retry_stats = self.retry_manager.get_global_stats()
        stats.update({
            'retry_attempts': retry_stats.get('total_attempts', 0),
            'retry_successes': retry_stats.get('successful_attempts', 0),
            'retry_failures': retry_stats.get('failed_attempts', 0),
            'circuit_breaker_trips': retry_stats.get('circuit_breaker_trips', 0)
        })
        
        return stats
    
    def print_stats(self):
        """打印统计信息"""
        stats = self.get_stats()
        
        print("\\n=== Dify 同步统计 ===")
        print(f"文档创建: {stats['documents_created']}")
        print(f"文档更新: {stats['documents_updated']}")
        print(f"文档失败: {stats['documents_failed']}")
        print(f"API 调用: {stats['api_calls']}")
        print(f"总同步时间: {stats['total_sync_time']:.2f}秒")
        
        if stats['kb_failures']:
            print("\\n知识库失败:")
            for kb_id, count in stats['kb_failures'].items():
                print(f"  {kb_id}: {count} 次")
        
        print(f"\\n重试统计:")
        print(f"  总尝试: {stats['retry_attempts']}")
        print(f"  成功: {stats['retry_successes']}")
        print(f"  失败: {stats['retry_failures']}")
        print(f"  熔断器触发: {stats['circuit_breaker_trips']}")
        
        print("==================\\n")


if __name__ == '__main__':
    # 测试代码
    import os
    from dataclasses import dataclass
    
    @dataclass
    class TestConfig:
        dify_api_key: str = "sk-test-key"
        dify_knowledge_base_ids: List[str] = None
        dify_api_base_url: str = "https://api.dify.ai/v1"
        request_timeout: int = 30
        
        def __post_init__(self):
            if self.dify_knowledge_base_ids is None:
                self.dify_knowledge_base_ids = ["kb-test-123", "kb-test-456"]
    
    # 创建测试配置
    config = TestConfig()
    
    # 创建同步管理器
    sync_manager = DifySyncManager(config)
    
    # 设置策略
    sync_manager.set_strategy(KnowledgeBaseStrategy.PRIMARY)
    
    print("✅ Dify 同步管理器创建成功！")
    print(f"知识库策略: {sync_manager.kb_strategy.value}")
    print(f"知识库列表: {config.dify_knowledge_base_ids}")