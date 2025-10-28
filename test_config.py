#!/usr/bin/env python3

"""
配置测试脚本 - 验证用户配置是否正确
"""
from tke_dify_sync import ConfigManager

def test_config():
    """测试配置是否正确"""
    print("🔧 测试配置文件...")
    print("=" * 50)
    
    try:
        # 1. 加载配置
        config_manager = ConfigManager()
        
        # 2. 验证配置
        if not config_manager.validate_config():
            print("❌ 配置验证失败")
            print("\n📋 请检查 .env 文件中的以下配置：")
            print("  • DIFY_API_KEY=your_dify_api_key")
            print("  • DIFY_KNOWLEDGE_BASE_ID=your_kb_id")
            print("  • DIFY_API_BASE_URL=https://api.dify.ai/v1")
            return False
        
        # 3. 加载配置
        config = config_manager.load_config()
        
        print("✅ 配置验证成功！")
        print(f"\n📊 配置信息：")
        print(f"  • API 地址: {config.dify_api_base_url}")
        print(f"  • 知识库数量: {len(config.dify_knowledge_base_ids)}")
        print(f"  • 知识库 ID: {', '.join(config.dify_knowledge_base_ids)}")
        print(f"  • 同步策略: {config.kb_strategy}")
        print(f"  • 请求超时: {config.request_timeout}秒")
        print(f"  • 重试次数: {config.retry_attempts}")
        
        print("\n🎯 配置正确，可以开始使用！")
        print("运行命令: python tke_dify_sync.py")
        
        return True
        
    except Exception as e:
        print(f"❌ 配置测试失败: {e}")
        print("\n📋 请确保：")
        print("  1. .env 文件存在于当前目录")
        print("  2. .env 文件包含必要的配置项")
        print("  3. 配置值正确填写")
        return False

if __name__ == "__main__":
    test_config()