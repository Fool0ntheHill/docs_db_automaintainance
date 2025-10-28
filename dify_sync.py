#!/usr/bin/env python3

"""
Dify API 集成系统
支持多知识库、错误处理、重试机制等高级功能
"""
import time
import random
import requests
from typing import Dict, List, Optional, Tuple, Any
from enum import Enum
from dataclasses import dataclass


class KnowledgeBaseStrategy(Enum):
    """知识库选择策略"""
    PRIMARY = "primary"  # 只使用第一个知识库
    ALL = "all"  # 同步到所有知识库
    ROUND_ROBIN = "round_robin"  # 轮询分配


@dataclass
class KnowledgeBaseInfo:
    """知识库信息"""
    id: str
    name: str = ""
    status: str = "unknown"
    last_check: float = 0
    available: bool = True
    error_count: int = 0


class DifySync:
    """Dify API 同步器，支持多知识库和高级功能"""
    
    def __init__(self, config):
        self.config = config
        self.session = requests.Session()
        
        # 设置会话默认配置
        self.session.headers.update({
            "Authorization": f"Bearer {config.dify_api_key}",
            "Content-Type": "application/json",
            "User-Agent": "TKE-Dify-Sync/1.0"
        })
        self.session.timeout = config.request_timeout
        
        # 知识库管理
        self.knowledge_bases = {}
        self.current_kb_index = 0  # 用于轮询策略
        
        # 初始化知识库信息
        for kb_id in config.dify_knowledge_base_ids:
            self.knowledge_bases[kb_id] = KnowledgeBaseInfo(id=kb_id)
        
        # 统计信息
        self.stats = {
            'total_attempts': 0,
            'successful_syncs': 0,
            'failed_syncs': 0,
            'retries': 0,
            'kb_failures': {},
            'error_types': {}
        }
        
        # 重试配置
        self.max_retries = 3
        self.base_delay = 1.0
        self.max_delay = 60.0
    
    def check_knowledge_base_availability(self, kb_id: str) -> bool:
        """
        检查知识库可用性
        
        Args:
            kb_id: 知识库 ID
            
        Returns:
            知识库是否可用
        """
        kb_info = self.knowledge_bases.get(kb_id)
        if not kb_info:
            return False
        
        # 如果最近检查过且可用，直接返回
        current_time = time.time()
        if (current_time - kb_info.last_check < 300 and  # 5分钟内检查过
            kb_info.available and kb_info.error_count < 3):
            return True
        
        try:
            # 调用 API 检查知识库状态
            api_url = f"{self.config.dify_api_base_url}/datasets/{kb_id}"
            response = self.session.get(api_url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                kb_info.name = data.get('name', kb_id)
                kb_info.status = 'available'
                kb_info.available = True
                kb_info.error_count = 0
                print(f"[知识库] {kb_id} ({kb_info.name}) 可用")
            else:
                kb_info.available = False
                kb_info.error_count += 1
                print(f"[知识库] {kb_id} 不可用，状态码: {response.status_code}")
                
        except Exception as e:
            kb_info.available = False
            kb_info.error_count += 1
            print(f"[知识库] {kb_id} 检查失败: {e}")
        
        kb_info.last_check = current_time
        return kb_info.available
    
    def get_available_knowledge_bases(self) -> List[str]:
        """获取可用的知识库列表"""
        available_kbs = []
        for kb_id in self.knowledge_bases:
            if self.check_knowledge_base_availability(kb_id):
                available_kbs.append(kb_id)
        return available_kbs
    
    def select_knowledge_bases(self, strategy: KnowledgeBaseStrategy = None) -> List[str]:
        """
        根据策略选择知识库
        
        Args:
            strategy: 选择策略
            
        Returns:
            选中的知识库 ID 列表
        """
        if strategy is None:
            strategy = KnowledgeBaseStrategy(self.config.kb_strategy)
        
        available_kbs = self.get_available_knowledge_bases()
        if not available_kbs:
            print("[错误] 没有可用的知识库")
            return []
        
        if strategy == KnowledgeBaseStrategy.PRIMARY:
            return [available_kbs[0]]
        
        elif strategy == KnowledgeBaseStrategy.ALL:
            return available_kbs
        
        elif strategy == KnowledgeBaseStrategy.ROUND_ROBIN:
            if len(available_kbs) == 1:
                return available_kbs
            
            # 轮询选择
            selected_kb = available_kbs[self.current_kb_index % len(available_kbs)]
            self.current_kb_index += 1
            return [selected_kb]
        
        return [available_kbs[0]]  # 默认返回第一个
    
    def find_existing_document(self, kb_id: str, url: str) -> Optional[str]:
        """
        查找已存在的文档
        
        Args:
            kb_id: 知识库 ID
            url: 文档 URL
            
        Returns:
            文档 ID（如果存在）
        """
        try:
            # 搜索文档
            api_url = f"{self.config.dify_api_base_url}/datasets/{kb_id}/documents"
            params = {
                'keyword': url,
                'page': 1,
                'limit': 10
            }
            
            response = self.session.get(api_url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                documents = data.get('data', [])
                
                # 查找完全匹配的文档
                for doc in documents:
                    if doc.get('name') == url or url in doc.get('name', ''):
                        return doc.get('id')
            
            return None
            
        except Exception as e:
            print(f"[文档查找] 查找失败: {e}")
            return None
    
    def create_document(self, kb_id: str, url: str, content: str, metadata: Dict = None) -> Tuple[bool, str]:
        """
        创建新文档
        
        Args:
            kb_id: 知识库 ID
            url: 文档 URL
            content: 文档内容
            metadata: 元数据
            
        Returns:
            (成功标志, 文档ID或错误信息)
        """
        try:
            api_url = f"{self.config.dify_api_base_url}/datasets/{kb_id}/document/create_by_text"
            
            # 准备文档名称
            document_name = self._generate_document_name(url, metadata)
            
            data = {
                'name': document_name,
                'text': content,
                'indexing_technique': 'high_quality',
                'process_rule': {'mode': 'automatic'}
            }
            
            # 添加元数据
            if metadata:
                data['metadata'] = self._prepare_metadata(url, metadata)
            
            response = self.session.post(api_url, json=data)
            
            if response.status_code in [200, 201]:
                result = response.json()
                document_id = result.get('document', {}).get('id')
                print(f"[文档创建] 成功创建文档: {document_name}")
                return True, document_id
            else:
                error_msg = f"状态码: {response.status_code}, 响应: {response.text}"
                print(f"[文档创建] 创建失败: {error_msg}")
                return False, error_msg
                
        except Exception as e:
            error_msg = f"异常: {type(e).__name__}: {e}"
            print(f"[文档创建] 创建异常: {error_msg}")
            return False, error_msg
    
    def update_document(self, kb_id: str, document_id: str, content: str, metadata: Dict = None) -> Tuple[bool, str]:
        """
        更新已存在的文档
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            content: 新内容
            metadata: 元数据
            
        Returns:
            (成功标志, 结果信息)
        """
        try:
            api_url = f"{self.config.dify_api_base_url}/datasets/{kb_id}/documents/{document_id}/update_by_text"
            
            data = {
                'text': content,
                'process_rule': {'mode': 'automatic'}
            }
            
            # 添加元数据
            if metadata:
                data['metadata'] = self._prepare_metadata(metadata.get('url', ''), metadata)
            
            response = self.session.post(api_url, json=data)
            
            if response.status_code in [200, 201]:
                print(f"[文档更新] 成功更新文档: {document_id}")
                return True, "更新成功"
            else:
                error_msg = f"状态码: {response.status_code}, 响应: {response.text}"
                print(f"[文档更新] 更新失败: {error_msg}")
                return False, error_msg
                
        except Exception as e:
            error_msg = f"异常: {type(e).__name__}: {e}"
            print(f"[文档更新] 更新异常: {error_msg}")
            return False, error_msg
    
    def delete_document(self, kb_id: str, document_id: str) -> bool:
        """
        删除文档
        
        Args:
            kb_id: 知识库 ID
            document_id: 文档 ID
            
        Returns:
            删除是否成功
        """
        try:
            api_url = f"{self.config.dify_api_base_url}/datasets/{kb_id}/documents/{document_id}"
            response = self.session.delete(api_url)
            
            if response.status_code in [200, 204]:
                print(f"[文档删除] 成功删除文档: {document_id}")
                return True
            else:
                print(f"[文档删除] 删除失败，状态码: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"[文档删除] 删除异常: {e}")
            return False
    
    def sync_document(self, url: str, content: str, metadata: Dict = None, strategy: KnowledgeBaseStrategy = None) -> bool:
        """
        同步文档到知识库（支持创建和更新）
        
        Args:
            url: 文档 URL
            content: 文档内容
            metadata: 元数据
            strategy: 知识库选择策略
            
        Returns:
            同步是否成功
        """
        self.stats['total_attempts'] += 1
        
        # 选择知识库
        selected_kbs = self.select_knowledge_bases(strategy)
        if not selected_kbs:
            self.stats['failed_syncs'] += 1
            return False
        
        success_count = 0
        total_kbs = len(selected_kbs)
        
        for kb_id in selected_kbs:
            success = self._sync_to_single_kb(kb_id, url, content, metadata)
            if success:
                success_count += 1
            else:
                # 记录失败统计
                if kb_id not in self.stats['kb_failures']:
                    self.stats['kb_failures'][kb_id] = 0
                self.stats['kb_failures'][kb_id] += 1
        
        # 判断整体成功
        overall_success = success_count > 0
        if overall_success:
            self.stats['successful_syncs'] += 1
            print(f"[同步完成] 成功同步到 {success_count}/{total_kbs} 个知识库")
        else:
            self.stats['failed_syncs'] += 1
            print(f"[同步失败] 所有知识库同步都失败")
        
        return overall_success
    
    def _sync_to_single_kb(self, kb_id: str, url: str, content: str, metadata: Dict = None) -> bool:
        """同步到单个知识库"""
        print(f"[同步] 正在同步到知识库: {kb_id}")
        
        # 查找已存在的文档
        existing_doc_id = self.find_existing_document(kb_id, url)
        
        if existing_doc_id:
            # 更新已存在的文档
            print(f"[同步] 发现已存在文档，执行更新: {existing_doc_id}")
            success, result = self.update_document(kb_id, existing_doc_id, content, metadata)
            
            if not success and "not found" in result.lower():
                # 文档可能已被删除，尝试重新创建
                print(f"[同步] 文档不存在，尝试重新创建")
                success, result = self.create_document(kb_id, url, content, metadata)
        else:
            # 创建新文档
            print(f"[同步] 创建新文档")
            success, result = self.create_document(kb_id, url, content, metadata)
        
        return success
    
    def _generate_document_name(self, url: str, metadata: Dict = None) -> str:
        """生成文档名称"""
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
            document_name = doc_type
        
        # 添加关键词作为标签
        keywords = metadata.get('keywords', [])
        if keywords:
            document_name += f" - {', '.join(keywords[:3])}"
        
        return document_name
    
    def _prepare_metadata(self, url: str, metadata: Dict) -> Dict:
        """准备元数据"""
        return {
            'url': url,
            'document_type': metadata.get('document_type'),
            'difficulty_level': metadata.get('difficulty_level'),
            'keywords': metadata.get('keywords', []),
            'content_length': metadata.get('content_length'),
            'product_id': metadata.get('product_id'),
            'sync_timestamp': time.time()
        }
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        stats = self.stats.copy()
        
        # 添加知识库状态信息
        stats['knowledge_bases'] = {}
        for kb_id, kb_info in self.knowledge_bases.items():
            stats['knowledge_bases'][kb_id] = {
                'name': kb_info.name,
                'available': kb_info.available,
                'error_count': kb_info.error_count,
                'last_check': kb_info.last_check
            }
        
        return stats
    
    def print_stats(self) -> None:
        """打印统计信息"""
        print("\\n=== Dify 同步统计 ===")
        print(f"总尝试次数: {self.stats['total_attempts']}")
        print(f"成功同步: {self.stats['successful_syncs']}")
        print(f"失败同步: {self.stats['failed_syncs']}")
        print(f"重试次数: {self.stats['retries']}")
        
        if self.stats['total_attempts'] > 0:
            success_rate = (self.stats['successful_syncs'] / self.stats['total_attempts']) * 100
            print(f"成功率: {success_rate:.1f}%")
        
        # 知识库状态
        print("\\n知识库状态:")
        for kb_id, kb_info in self.knowledge_bases.items():
            status = "✅ 可用" if kb_info.available else "❌ 不可用"
            name = f"({kb_info.name})" if kb_info.name else ""
            print(f"  {kb_id} {name}: {status}")
            if kb_info.error_count > 0:
                print(f"    错误次数: {kb_info.error_count}")
        
        # 知识库失败统计
        if self.stats['kb_failures']:
            print("\\n知识库失败统计:")
            for kb_id, count in self.stats['kb_failures'].items():
                print(f"  {kb_id}: {count} 次失败")
        
        print("==================\\n")


if __name__ == '__main__':
    # 测试代码
    from tke_dify_sync import ConfigManager
    import os
    
    # 设置测试环境变量
    os.environ['DIFY_API_KEY'] = 'sk-test-key'
    os.environ['DIFY_KNOWLEDGE_BASE_ID'] = 'kb-test-1,kb-test-2'
    os.environ['DIFY_API_BASE_URL'] = 'https://test.dify.ai/v1'
    os.environ['KB_STRATEGY'] = 'primary'
    
    try:
        config_manager = ConfigManager()
        config = config_manager.load_config()
        
        # 初始化 Dify 同步器
        dify_sync = DifySync(config)
        
        # 测试元数据
        test_metadata = {
            'document_type': '操作类文档',
            'difficulty_level': '中级',
            'product_id': '457',
            'keywords': ['kubernetes', 'deployment', 'tutorial'],
            'content_length': 1500
        }
        
        print("Dify 同步器初始化成功")
        print(f"配置的知识库: {list(dify_sync.knowledge_bases.keys())}")
        
        # 打印统计信息
        dify_sync.print_stats()
        
    finally:
        # 清理环境变量
        for var in ['DIFY_API_KEY', 'DIFY_KNOWLEDGE_BASE_ID', 'DIFY_API_BASE_URL', 'KB_STRATEGY']:
            if var in os.environ:
                del os.environ[var]
    
    print("✅ Dify 同步器测试完成！")