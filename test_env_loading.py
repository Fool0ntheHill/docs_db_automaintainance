#!/usr/bin/env python3

"""
测试环境文件加载
"""

import sys
import os
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from tke_dify_sync import ConfigManager

def test_env_loading():
    """测试环境文件加载"""
    
    # 支持命令行参数指定环境文件
    env_file = sys.argv[1] if len(sys.argv) > 1 else ".env"
    print(f"🔧 测试环境文件: {env_file}")
    
    try:
        # 初始化配置管理器
        config_manager = ConfigManager(env_file)
        
        # 验证配置
        if not config_manager.validate_config():
            print("❌ 配置验证失败")
            return
        
        config = config_manager.get_config()
        
        print(f"✅ 配置加载成功")
        print(f"📋 API Key: {config.dify_api_key[:20]}...")
        print(f"📋 Base URL: {config.dify_api_base_url}")
        print(f"📋 知识库 ID: {config.dify_knowledge_base_ids}")
        print(f"📋 状态文件: {config.state_file}")
        print(f"📋 日志文件: {config.log_file}")
        
    except Exception as e:
        print(f"❌ 配置加载失败: {e}")

if __name__ == "__main__":
    test_env_loading()