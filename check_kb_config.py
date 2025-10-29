#!/usr/bin/env python3

"""
检查知识库配置脚本
用于诊断 doc_form 不匹配问题
"""

import requests
import json
import os
import sys
from dotenv import load_dotenv

def check_kb_config(env_file=None):
    """检查知识库配置"""
    
    # 加载指定的环境文件
    if env_file:
        print(f"🔧 使用环境文件: {env_file}")
        load_dotenv(env_file)
    else:
        print("🔧 使用默认环境变量")
    
    # 从环境变量获取配置
    api_key = os.getenv('DIFY_API_KEY')
    base_url = os.getenv('DIFY_API_BASE_URL')
    
    # 支持两种配置方式
    kb_ids_str = os.getenv('DIFY_KNOWLEDGE_BASE_IDS') or os.getenv('DIFY_KNOWLEDGE_BASE_ID')
    if kb_ids_str:
        kb_ids = [kb_id.strip() for kb_id in kb_ids_str.split(',') if kb_id.strip()]
    else:
        kb_ids = []
    
    if not api_key or not base_url or not kb_ids:
        print("❌ 缺少必要的环境变量配置")
        print(f"   API_KEY: {'✓' if api_key else '✗'}")
        print(f"   BASE_URL: {'✓' if base_url else '✗'}")
        print(f"   KB_IDS: {'✓' if kb_ids else '✗'}")
        return
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    for kb_id in kb_ids:
        kb_id = kb_id.strip()
        if not kb_id:
            continue
            
        print(f"\n🔍 检查知识库: {kb_id}")
        print("=" * 50)
        
        # 1. 获取知识库基本信息
        try:
            url = f"{base_url}/datasets/{kb_id}"
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                kb_info = response.json()
                print(f"📋 知识库名称: {kb_info.get('name', 'N/A')}")
                print(f"📋 索引技术: {kb_info.get('indexing_technique', 'N/A')}")
                print(f"📋 数据源类型: {kb_info.get('data_source_type', 'N/A')}")
                print(f"📋 文档数量: {kb_info.get('document_count', 0)}")
                
                # 检查是否有 doc_form 信息
                if 'doc_form' in kb_info:
                    print(f"📋 文档格式: {kb_info['doc_form']}")
                else:
                    print("⚠️  基本信息中未找到 doc_form")
                    
            else:
                print(f"❌ 获取知识库信息失败: {response.status_code}")
                print(f"   响应: {response.text}")
                continue
                
        except Exception as e:
            print(f"❌ 请求知识库信息时出错: {e}")
            continue
        
        # 2. 获取处理规则配置
        try:
            url = f"{base_url}/datasets/{kb_id}/process-rule"
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                process_rule = response.json()
                print(f"🔧 处理模式: {process_rule.get('mode', 'N/A')}")
                
                # 检查规则详情
                rules = process_rule.get('rules', {})
                if rules:
                    print("🔧 处理规则:")
                    if 'pre_processing_rules' in rules:
                        print(f"   - 预处理规则: {len(rules['pre_processing_rules'])} 个")
                    if 'segmentation' in rules:
                        seg = rules['segmentation']
                        print(f"   - 分割规则: max_tokens={seg.get('max_tokens', 'N/A')}")
                        
            else:
                print(f"⚠️  获取处理规则失败: {response.status_code}")
                
        except Exception as e:
            print(f"⚠️  获取处理规则时出错: {e}")
        
        # 3. 获取现有文档示例来推断 doc_form
        try:
            url = f"{base_url}/datasets/{kb_id}/documents"
            response = requests.get(url, headers=headers, params={'limit': 1}, timeout=30)
            
            if response.status_code == 200:
                docs_data = response.json()
                documents = docs_data.get('data', [])
                
                if documents:
                    doc = documents[0]
                    doc_form = doc.get('doc_form')
                    if doc_form:
                        print(f"📄 现有文档格式: {doc_form}")
                    else:
                        print("⚠️  现有文档中未找到 doc_form")
                        
                    # 显示文档详细信息
                    print(f"📄 示例文档: {doc.get('name', 'N/A')}")
                    print(f"📄 索引状态: {doc.get('indexing_status', 'N/A')}")
                    
                else:
                    print("📄 知识库中暂无文档")
                    
            else:
                print(f"⚠️  获取文档列表失败: {response.status_code}")
                
        except Exception as e:
            print(f"⚠️  获取文档列表时出错: {e}")
        
        print("\n" + "=" * 50)

if __name__ == "__main__":
    # 支持命令行参数指定环境文件
    env_file = sys.argv[1] if len(sys.argv) > 1 else None
    check_kb_config(env_file)