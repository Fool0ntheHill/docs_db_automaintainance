#!/usr/bin/env python3

"""
测试文档格式检测功能
"""

import os
import sys
from dotenv import load_dotenv

# 添加项目根目录到路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dify_sync_manager import DifySyncManager
from config import Config

def test_doc_form_detection():
    """测试文档格式检测"""
    
    # 加载环境变量
    load_dotenv('.env.testing.example')
    
    # 创建配置
    config = Config()
    
    # 创建同步管理器
    sync_manager = DifySyncManager(config)
    
    print("🔍 测试文档格式检测功能")
    print("=" * 50)
    
    # 获取知识库ID
    kb_id = config.dify_knowledge_base_ids[0] if config.dify_knowledge_base_ids else None
    
    if not kb_id:
        print("❌ 没有配置知识库ID")
        return
    
    print(f"📋 测试知识库: {kb_id}")
    
    # 测试检测功能
    try:
        detected_form = sync_manager._detect_kb_doc_form(kb_id)
        print(f"🔍 检测到的文档格式: {detected_form or '未检测到'}")
        
        # 获取完整配置
        full_config = sync_manager._get_kb_full_config(kb_id)
        print(f"📋 完整配置:")
        for key, value in full_config.items():
            print(f"   {key}: {value}")
        
        # 测试内容格式化
        test_content = "这是一个测试文档的内容。\n\n包含多个段落和格式。"
        test_title = "测试文档标题"
        
        for doc_form in ['text_model', 'qa_model', 'hierarchical_model']:
            formatted = sync_manager._format_content_for_doc_form(test_content, doc_form, test_title)
            print(f"\n📄 {doc_form} 格式化结果:")
            print(f"   长度: {len(formatted)} 字符")
            if doc_form == 'qa_model':
                print(f"   预览: {formatted[:100]}...")
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_doc_form_detection()