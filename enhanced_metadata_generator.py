#!/usr/bin/env python3

"""
增强的元数据生成器
实现 TF-IDF 关键词提取、文档难度评估和完整的元数据生成
"""
import re
import math
import hashlib
import jieba
from collections import Counter, defaultdict
from typing import Dict, List, Optional, Tuple, Set
from urllib.parse import urlparse


class TFIDFKeywordExtractor:
    """TF-IDF 关键词提取器"""
    
    def __init__(self):
        # 停用词列表
        self.stop_words = {
            '的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一', '一个', '上', '也', '很', '到', '说', '要', '去', '你',
            '会', '着', '没有', '看', '好', '自己', '这', '那', '它', '他', '她', '们', '我们', '你们', '他们', '她们', '它们',
            '这个', '那个', '这些', '那些', '什么', '怎么', '为什么', '哪里', '哪个', '多少', '几个', '第一', '第二', '第三',
            '可以', '能够', '应该', '需要', '必须', '如果', '但是', '然后', '因为', '所以', '虽然', '虽说', '尽管', '不过',
            '或者', '还是', '以及', '以上', '以下', '之前', '之后', '当前', '目前', '现在', '将来', '过去', '已经', '正在',
            '通过', '根据', '按照', '依据', '基于', '关于', '对于', '由于', '为了', '除了', '包括', '包含', '具有', '拥有',
            '进行', '执行', '操作', '处理', '管理', '控制', '监控', '检查', '验证', '确认', '保证', '确保', '实现', '完成'
        }
        
        # 文档语料库（用于计算 IDF）
        self.document_corpus = []
        self.idf_cache = {}
    
    def add_document_to_corpus(self, content: str) -> None:
        """将文档添加到语料库中"""
        words = self._tokenize(content)
        self.document_corpus.append(set(words))
        # 清空 IDF 缓存，因为语料库已更新
        self.idf_cache.clear()
    
    def _tokenize(self, text: str) -> List[str]:
        """分词并过滤停用词"""
        # 使用 jieba 分词
        words = jieba.lcut(text.lower())
        
        # 过滤停用词、单字符词和纯数字
        filtered_words = []
        for word in words:
            word = word.strip()
            if (len(word) > 1 and 
                word not in self.stop_words and 
                not word.isdigit() and 
                re.match(r'^[\u4e00-\u9fa5a-zA-Z]+$', word)):
                filtered_words.append(word)
        
        return filtered_words
    
    def _calculate_tf(self, words: List[str]) -> Dict[str, float]:
        """计算词频 (TF)"""
        word_count = Counter(words)
        total_words = len(words)
        
        tf_scores = {}
        for word, count in word_count.items():
            tf_scores[word] = count / total_words
        
        return tf_scores
    
    def _calculate_idf(self, word: str) -> float:
        """计算逆文档频率 (IDF)"""
        if word in self.idf_cache:
            return self.idf_cache[word]
        
        if not self.document_corpus:
            # 如果没有语料库，返回默认值
            return 1.0
        
        # 计算包含该词的文档数量
        doc_count = sum(1 for doc_words in self.document_corpus if word in doc_words)
        
        if doc_count == 0:
            idf = math.log(len(self.document_corpus) + 1)
        else:
            idf = math.log(len(self.document_corpus) / doc_count)
        
        self.idf_cache[word] = idf
        return idf
    
    def extract_keywords(self, content: str, top_k: int = 10) -> List[Tuple[str, float]]:
        """
        提取关键词
        
        Args:
            content: 文档内容
            top_k: 返回前 k 个关键词
            
        Returns:
            关键词列表，每个元素为 (词, TF-IDF分数)
        """
        words = self._tokenize(content)
        if not words:
            return []
        
        # 计算 TF
        tf_scores = self._calculate_tf(words)
        
        # 计算 TF-IDF
        tfidf_scores = {}
        for word, tf in tf_scores.items():
            idf = self._calculate_idf(word)
            tfidf_scores[word] = tf * idf
        
        # 排序并返回前 k 个
        sorted_keywords = sorted(tfidf_scores.items(), key=lambda x: x[1], reverse=True)
        return sorted_keywords[:top_k]


class DifficultyAssessor:
    """文档难度评估器"""
    
    def __init__(self):
        # 技术复杂度关键词
        self.complexity_keywords = {
            'high': [
                '架构', '设计模式', '算法', '优化', '性能调优', '源码', '底层', '原理', '机制', '协议',
                '分布式', '微服务', '容器化', '云原生', 'DevOps', 'CI/CD', '自动化', '编排',
                '高可用', '容灾', '备份', '恢复', '监控', '告警', '日志分析', '故障排查',
                'API开发', 'SDK开发', '插件开发', '扩展开发', '自定义', '二次开发',
                '网络配置', '安全配置', '权限管理', '认证授权', '加密', '证书',
                '数据库', '存储', '缓存', '消息队列', '负载均衡', '代理',
                'Kubernetes', 'Docker', 'Helm', 'Istio', 'Prometheus', 'Grafana'
            ],
            'medium': [
                '配置', '部署', '安装', '升级', '迁移', '集成', '对接', '接入',
                '管理', '维护', '运维', '操作', '使用', '应用', '实践',
                '创建', '删除', '修改', '更新', '查询', '列表', '详情',
                '设置', '参数', '选项', '功能', '特性', '服务', '组件',
                '网络', '存储', '计算', '资源', '节点', '集群', '命名空间',
                '镜像', '容器', 'Pod', 'Service', 'Deployment', 'ConfigMap'
            ],
            'low': [
                '介绍', '概述', '什么是', '基本概念', '入门', '快速开始', '新手指南',
                '产品介绍', '功能介绍', '特性', '优势', '应用场景', '使用场景',
                '计费', '价格', '费用', '套餐', '版本', '规格', '限制', '约束',
                '常见问题', 'FAQ', '帮助', '支持', '联系', '反馈'
            ]
        }
        
        # 操作复杂度指标
        self.operation_indicators = {
            'high': ['命令行', 'CLI', 'API调用', '脚本', '代码', '编程', '开发'],
            'medium': ['控制台', '界面操作', '配置文件', '参数设置'],
            'low': ['点击', '选择', '填写', '提交', '查看']
        }
    
    def assess_difficulty(self, url: str, content: str) -> str:
        """
        评估文档难度
        
        Args:
            url: 文档 URL
            content: 文档内容
            
        Returns:
            难度级别：'初级', '中级', '高级'
        """
        content_lower = content.lower()
        url_lower = url.lower()
        
        # 计算各难度级别的分数
        scores = {'high': 0, 'medium': 0, 'low': 0}
        
        # 基于内容关键词评分
        for level, keywords in self.complexity_keywords.items():
            for keyword in keywords:
                count = content_lower.count(keyword.lower())
                scores[level] += count
        
        # 基于操作复杂度评分
        for level, indicators in self.operation_indicators.items():
            for indicator in indicators:
                count = content_lower.count(indicator.lower())
                scores[level] += count * 2  # 操作指标权重更高
        
        # URL 路径分析
        if any(word in url_lower for word in ['api', 'sdk', 'development', 'advanced']):
            scores['high'] += 10
        elif any(word in url_lower for word in ['tutorial', 'guide', 'howto']):
            scores['medium'] += 5
        elif any(word in url_lower for word in ['overview', 'introduction', 'basic']):
            scores['low'] += 5
        
        # 文档长度分析
        content_length = len(content)
        if content_length > 5000:
            scores['high'] += 3
        elif content_length > 2000:
            scores['medium'] += 2
        else:
            scores['low'] += 1
        
        # 代码块分析
        code_blocks = len(re.findall(r'```|`[^`]+`', content))
        if code_blocks > 10:
            scores['high'] += 5
        elif code_blocks > 3:
            scores['medium'] += 3
        
        # 步骤数量分析
        steps = len(re.findall(r'第[一二三四五六七八九十\d]+步|步骤[\d]+|step \d+', content_lower))
        if steps > 10:
            scores['high'] += 3
        elif steps > 5:
            scores['medium'] += 2
        elif steps > 0:
            scores['low'] += 1
        
        # 确定最终难度
        max_score = max(scores.values())
        if max_score == 0:
            return '初级'  # 默认
        
        if scores['high'] == max_score:
            return '高级'
        elif scores['medium'] == max_score:
            return '中级'
        else:
            return '初级'


class EnhancedMetadataGenerator:
    """增强的元数据生成器"""
    
    def __init__(self):
        self.keyword_extractor = TFIDFKeywordExtractor()
        self.difficulty_assessor = DifficultyAssessor()
        
        # 文档类型关键词
        self.doc_type_keywords = {
            '操作类文档': [
                '教程', '指南', '步骤', '如何', '怎么', '操作指南', '使用指南', '配置', '部署', '创建', '删除', '更新', '修改', '设置',
                '第一步', '第二步', '第三步', '操作步骤', '执行', '运行', '启动', '停止', '重启', '安装', '卸载', '上传', '下载',
                'API', 'SDK', '命令', '参数', '配置项', '字段说明', '接口', '调用', '请求', '响应', '示例代码', '代码示例',
                '故障', '问题', '错误', '异常', '排查', '解决', '修复', '诊断', '调试', '监控', '日志', '告警',
                'tutorial', 'how to', 'step by step', 'guide', 'install', 'configure', 'deploy', 'setup', 'create', 'delete', 'update'
            ],
            '概述类文档': [
                '概述', '介绍', '什么是', '简介', '基本概念', '概念', '原理', '架构', '设计', '理论', '背景',
                '产品介绍', '功能介绍', '特性', '优势', '应用场景', '使用场景', '适用范围', '限制', '约束',
                '总览', '概览', '整体', '全局', '框架', '体系', '结构', '组成', '组件', '模块', '服务',
                'overview', 'introduction', 'what is', 'concept', 'architecture', 'design', 'about'
            ]
        }
    
    def add_document_to_corpus(self, content: str) -> None:
        """将文档添加到 TF-IDF 语料库"""
        self.keyword_extractor.add_document_to_corpus(content)
    
    def generate_metadata(self, url: str, content: str) -> Dict[str, any]:
        """
        生成文档的完整元数据
        
        Args:
            url: 文档 URL
            content: 文档内容
            
        Returns:
            包含所有元数据的字典
        """
        metadata = {}
        
        # 基本信息
        metadata['url'] = url
        metadata['content_hash'] = hashlib.md5(content.encode('utf-8')).hexdigest()
        metadata['content_length'] = len(content)
        
        # URL 解析
        url_info = self._extract_url_info(url)
        metadata.update(url_info)
        
        # 文档分类
        metadata['document_type'] = self._classify_document(url, content)
        
        # 关键词提取
        keywords = self.keyword_extractor.extract_keywords(content, top_k=10)
        metadata['keywords'] = [kw[0] for kw in keywords]
        metadata['keyword_scores'] = {kw[0]: kw[1] for kw in keywords}
        
        # 难度评估
        metadata['difficulty_level'] = self.difficulty_assessor.assess_difficulty(url, content)
        
        # 内容统计
        content_stats = self._analyze_content_structure(content)
        metadata.update(content_stats)
        
        return metadata
    
    def _extract_url_info(self, url: str) -> Dict[str, str]:
        """从 URL 中提取信息"""
        parsed = urlparse(url)
        path_parts = [part for part in parsed.path.split('/') if part]
        
        info = {
            'domain': parsed.netloc,
            'path': parsed.path,
            'path_parts': path_parts
        }
        
        # 提取产品信息
        if len(path_parts) >= 3 and path_parts[0] == 'document' and path_parts[1] == 'product':
            info['product_id'] = path_parts[2]
        
        # 提取文档 ID
        if len(path_parts) >= 4:
            info['document_id'] = path_parts[3]
        
        return info
    
    def _classify_document(self, url: str, content: str) -> str:
        """文档分类"""
        url_lower = url.lower()
        content_lower = content.lower()
        
        # 计算各类型的分数
        scores = {'操作类文档': 0.0, '概述类文档': 0.0}
        
        # 基于内容关键词
        for doc_type, keywords in self.doc_type_keywords.items():
            for keyword in keywords:
                matches = len(re.findall(re.escape(keyword.lower()), content_lower))
                scores[doc_type] += matches * 0.5
        
        # URL 路径分析
        if any(word in url_lower for word in ['api', 'sdk', 'command', 'cli', 'tutorial', 'howto']):
            scores['操作类文档'] += 5.0
        elif any(word in url_lower for word in ['overview', 'introduction', 'concept', 'about']):
            scores['概述类文档'] += 5.0
        
        # 内容结构分析
        if re.search(r'第[一二三四五六七八九十\d]+步|步骤[\d]+|step \d+', content_lower):
            scores['操作类文档'] += 4.0
        
        if any(word in content_lower for word in ['概述', '介绍', '什么是', '产品介绍', '功能介绍']):
            scores['概述类文档'] += 4.0
        
        # 返回得分最高的类型
        if scores['操作类文档'] > scores['概述类文档']:
            return '操作类文档'
        elif scores['概述类文档'] > scores['操作类文档']:
            return '概述类文档'
        else:
            # 默认规则
            if any(word in content_lower for word in ['如何', '怎么', '步骤', 'tutorial', 'how to']):
                return '操作类文档'
            else:
                return '概述类文档'
    
    def _analyze_content_structure(self, content: str) -> Dict[str, any]:
        """分析内容结构"""
        stats = {}
        
        # 段落数量
        paragraphs = [p.strip() for p in content.split('\n') if p.strip()]
        stats['paragraph_count'] = len(paragraphs)
        
        # 代码块数量
        code_blocks = len(re.findall(r'```[\s\S]*?```|`[^`]+`', content))
        stats['code_block_count'] = code_blocks
        
        # 链接数量
        links = len(re.findall(r'https?://[^\s]+', content))
        stats['link_count'] = links
        
        # 步骤数量
        steps = len(re.findall(r'第[一二三四五六七八九十\d]+步|步骤[\d]+|step \d+', content.lower()))
        stats['step_count'] = steps
        
        # 列表项数量
        list_items = len(re.findall(r'^\s*[-*+]|^\s*\d+\.', content, re.MULTILINE))
        stats['list_item_count'] = list_items
        
        # 标题数量
        headers = len(re.findall(r'^#+\s', content, re.MULTILINE))
        stats['header_count'] = headers
        
        return stats


if __name__ == '__main__':
    # 测试代码
    generator = EnhancedMetadataGenerator()
    
    # 测试文档
    test_docs = [
        {
            'url': 'https://cloud.tencent.com/document/product/457/tutorial',
            'content': '''
            # TKE 容器服务部署教程
            
            本教程将指导您如何一步步在 TKE 上部署应用程序。
            
            ## 第一步：创建集群
            
            1. 登录 TKE 控制台
            2. 点击"创建集群"按钮
            3. 填写集群配置信息
            
            ```bash
            kubectl create cluster my-cluster
            ```
            
            ## 第二步：部署应用
            
            使用以下命令部署应用：
            
            ```yaml
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: my-app
            spec:
              replicas: 3
            ```
            
            ## 第三步：验证部署
            
            检查 Pod 状态：
            
            ```bash
            kubectl get pods
            ```
            
            如果遇到问题，请检查日志进行故障排查。
            '''
        },
        {
            'url': 'https://cloud.tencent.com/document/product/457/overview',
            'content': '''
            # TKE 容器服务概述
            
            ## 什么是 TKE？
            
            腾讯云容器服务（Tencent Kubernetes Engine，TKE）是腾讯云基于原生 Kubernetes 提供的容器化应用管理平台。
            
            ## 产品架构
            
            TKE 采用云原生架构设计，包含以下核心组件：
            
            - 控制平面：负责集群管理
            - 数据平面：运行用户工作负载
            - 网络组件：提供容器网络能力
            
            ## 主要特性
            
            - 完全兼容 Kubernetes API
            - 高可用架构设计
            - 弹性伸缩能力
            - 丰富的网络和存储选项
            
            ## 应用场景
            
            TKE 适用于以下场景：
            
            - 微服务架构应用
            - DevOps 持续集成
            - 大数据处理
            - 机器学习训练
            '''
        }
    ]
    
    # 先将文档添加到语料库
    for doc in test_docs:
        generator.add_document_to_corpus(doc['content'])
    
    # 生成元数据
    for i, doc in enumerate(test_docs):
        print(f"\\n=== 文档 {i+1} 元数据 ===")
        metadata = generator.generate_metadata(doc['url'], doc['content'])
        
        print(f"URL: {metadata['url']}")
        print(f"文档类型: {metadata['document_type']}")
        print(f"难度级别: {metadata['difficulty_level']}")
        print(f"产品ID: {metadata.get('product_id', 'N/A')}")
        print(f"内容长度: {metadata['content_length']} 字符")
        print(f"段落数: {metadata['paragraph_count']}")
        print(f"代码块数: {metadata['code_block_count']}")
        print(f"步骤数: {metadata['step_count']}")
        print(f"关键词: {', '.join(metadata['keywords'][:5])}")
    
    print("\\n✅ 增强元数据生成器测试完成！")