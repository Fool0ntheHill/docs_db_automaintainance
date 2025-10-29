#!/usr/bin/env python3

"""
元数据生成器
专门用于从 URL 路径和内容中提取和生成文档元数据
"""
import re
import hashlib
from typing import Dict


class MetadataGenerator:
    """元数据生成器，从 URL 和内容中提取文档元数据"""
    
    def __init__(self):
        # 文档类型关键词（只有两种类型）
        self.doc_type_keywords = {
            '操作类文档': [
                '教程', '指南', '步骤', '如何', '怎么', '操作指南', '使用指南', '配置', '部署', '创建', '删除', '更新', '修改', '设置',
                '第一步', '第二步', '第三步', '操作步骤', '执行', '运行', '启动', '停止', '重启', '安装', '卸载', '上传', '下载',
                'API', 'SDK', '命令', '参数', '配置项', '字段说明', '接口', '调用', '请求', '响应', '示例代码', '代码示例',
                '故障', '问题', '错误', '异常', '排查', '解决', '修复', '诊断', '调试', '监控', '日志', '告警'
            ],
            '概述类文档': [
                '概述', '介绍', '什么是', '简介', '基本概念', '概念', '原理', '架构', '设计', '理论', '背景',
                '产品介绍', '功能介绍', '特性', '优势', '应用场景', '使用场景', '适用范围', '限制', '约束',
                '总览', '概览', '整体', '全局', '框架', '体系', '结构', '组成', '组件', '模块', '服务'
            ]
        }
    
    def generate_metadata(self, url: str, content: str) -> Dict[str, any]:
        """
        生成文档的元数据（只包含 Dify 需要的三个字段）
        
        Args:
            url: 文档 URL
            content: 文档内容
            
        Returns:
            包含三个元数据字段的字典：url, content_hash, document_type
        """
        metadata = {}
        
        # 必需的三个元数据字段
        metadata['url'] = url
        metadata['content_hash'] = hashlib.md5(content.encode('utf-8')).hexdigest()
        metadata['document_type'] = self._determine_document_type(url, content)
        
        return metadata
    

    
    def _determine_document_type(self, url: str, content: str) -> str:
        """确定文档类型：操作类文档 或 概述类文档"""
        url_lower = url.lower()
        content_lower = content.lower()
        
        # 计算各类型的分数
        scores = {'操作类文档': 0.0, '概述类文档': 0.0}
        
        # 基于内容判断中文关键词
        for doc_type, keywords in self.doc_type_keywords.items():
            for keyword in keywords:
                matches = len(re.findall(keyword, content_lower))
                scores[doc_type] += matches * 0.5
        
        # 英文关键词判断
        english_operation_keywords = ['tutorial', 'how to', 'step by step', 'guide', 'install', 'configure', 'deploy', 'setup', 'create', 'delete', 'update']
        english_overview_keywords = ['overview', 'introduction', 'what is', 'concept', 'architecture', 'design', 'about']
        
        for keyword in english_operation_keywords:
            if keyword in content_lower:
                scores['操作类文档'] += 2.0
        
        for keyword in english_overview_keywords:
            if keyword in content_lower:
                scores['概述类文档'] += 2.0
        
        # 特殊规则加权
        # API、SDK、命令相关 -> 操作类
        if any(word in url_lower for word in ['api', 'sdk', 'command', 'cli']):
            scores['操作类文档'] += 5.0
        
        # 操作步骤相关 -> 操作类
        if any(word in content_lower for word in ['步骤', '第一步', '第二步', '操作步骤', '执行以下', '按照以下']):
            scores['操作类文档'] += 4.0
        
        # 概述、介绍相关 -> 概述类
        if any(word in content_lower for word in ['概述', '介绍', '什么是', '产品介绍', '功能介绍']):
            scores['概述类文档'] += 4.0
        
        # 返回得分最高的类型
        if scores['操作类文档'] > scores['概述类文档']:
            return '操作类文档'
        elif scores['概述类文档'] > scores['操作类文档']:
            return '概述类文档'
        else:
            # 如果分数相等，根据默认规则判断
            if any(word in content_lower for word in ['如何', '怎么', '步骤', 'tutorial', 'how to']):
                return '操作类文档'
            else:
                return '概述类文档'  # 默认为概述类


if __name__ == '__main__':
    # 测试代码
    generator = MetadataGenerator()
    
    # 测试操作类文档
    operation_url = "https://cloud.tencent.com/document/product/457/tutorial"
    operation_content = "本教程将指导您如何一步步部署应用程序。第一步：创建集群。第二步：部署应用。"
    
    # 测试概述类文档
    overview_url = "https://cloud.tencent.com/document/product/457/overview"
    overview_content = "TKE 容器服务是什么？本文档介绍 TKE 的基本概念、产品架构和主要功能。"
    
    # 测试英文操作类文档
    english_operation_content = "This is a tutorial on how to deploy applications step by step."
    
    operation_metadata = generator.generate_metadata(operation_url, operation_content)
    overview_metadata = generator.generate_metadata(overview_url, overview_content)
    english_metadata = generator.generate_metadata("http://test.com", english_operation_content)
    
    print("操作类文档元数据:")
    print(f"  URL: {operation_metadata['url']}")
    print(f"  文档类型: {operation_metadata['document_type']}")
    print(f"  内容哈希: {operation_metadata['content_hash'][:8]}...")
    
    print("\n概述类文档元数据:")
    print(f"  URL: {overview_metadata['url']}")
    print(f"  文档类型: {overview_metadata['document_type']}")
    print(f"  内容哈希: {overview_metadata['content_hash'][:8]}...")
    
    print("\n英文操作类文档元数据:")
    print(f"  URL: {english_metadata['url']}")
    print(f"  文档类型: {english_metadata['document_type']}")
    print(f"  内容哈希: {english_metadata['content_hash'][:8]}...")
    
    print("\n✅ 元数据生成器测试完成！")