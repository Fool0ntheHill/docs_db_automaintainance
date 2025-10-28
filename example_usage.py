#!/usr/bin/env python3

"""
使用示例 - 演示如何使用 TKE 文档同步系统
"""
from tke_dify_sync import ConfigManager, sync_to_dify
from dify_sync_manager import DifySyncManager

def example_single_document():
    """示例：同步单个文档"""
    print("📄 示例：同步单个文档")
    print("=" * 40)
    
    # 1. 加载配置
    config_manager = ConfigManager()
    config = config_manager.load_config()
    
    # 2. 准备文档数据
    url = "https://cloud.tencent.com/document/product/457/example"
    content = "TITLE:TKE 使用示例\nCONTENT:这是一个 TKE 容器服务的使用示例文档。"
    metadata = {
        "document_type": "操作类文档",
        "url": url
    }
    
    # 3. 同步文档
    print(f"同步文档: {url}")
    success = sync_to_dify(url, content, config, metadata)
    
    if success:
        print("✅ 文档同步成功")
    else:
        print("❌ 文档同步失败")
    
    return success

def example_batch_sync():
    """示例：批量同步文档"""
    print("\n📚 示例：批量同步文档")
    print("=" * 40)
    
    # 1. 加载配置
    config_manager = ConfigManager()
    config = config_manager.load_config()
    
    # 2. 创建同步管理器
    dify_manager = DifySyncManager(config)
    
    # 3. 准备多个文档
    documents = [
        {
            "url": "https://cloud.tencent.com/document/product/457/batch-1",
            "content": "TITLE:TKE 集群管理\nCONTENT:介绍如何创建和管理 TKE 集群。",
            "metadata": {"document_type": "操作类文档"}
        },
        {
            "url": "https://cloud.tencent.com/document/product/457/batch-2",
            "content": "TITLE:TKE 产品概述\nCONTENT:TKE 是腾讯云提供的容器服务平台。",
            "metadata": {"document_type": "概述类文档"}
        }
    ]
    
    # 4. 批量同步
    success_count = 0
    for i, doc in enumerate(documents, 1):
        print(f"\n同步文档 {i}: {doc['url']}")
        success = dify_manager.sync_document(
            doc["url"], 
            doc["content"], 
            doc["metadata"]
        )
        
        if success:
            print(f"✅ 文档 {i} 同步成功")
            success_count += 1
        else:
            print(f"❌ 文档 {i} 同步失败")
    
    print(f"\n📊 批量同步结果: {success_count}/{len(documents)} 成功")
    
    # 5. 显示统计信息
    print("\n📈 同步统计:")
    dify_manager.print_stats()
    
    return success_count == len(documents)

def example_smart_hash():
    """示例：智能哈希对比"""
    print("\n🔍 示例：智能哈希对比")
    print("=" * 40)
    
    # 1. 加载配置
    config_manager = ConfigManager()
    config = config_manager.load_config()
    
    # 2. 准备测试文档
    url = "https://cloud.tencent.com/document/product/457/hash-test"
    content = "TITLE:哈希测试文档\nCONTENT:这是一个用于测试智能哈希对比的文档。"
    metadata = {"document_type": "操作类文档"}
    
    # 3. 第一次同步（创建）
    print("第一次同步（创建文档）:")
    success1 = sync_to_dify(url, content, config, metadata)
    print(f"结果: {'✅ 成功' if success1 else '❌ 失败'}")
    
    # 4. 第二次同步（相同内容，应该跳过）
    print("\n第二次同步（相同内容，应该跳过）:")
    success2 = sync_to_dify(url, content, config, metadata)
    print(f"结果: {'✅ 成功' if success2 else '❌ 失败'}")
    
    # 5. 第三次同步（修改内容，应该更新）
    print("\n第三次同步（修改内容，应该更新）:")
    modified_content = "TITLE:哈希测试文档（更新版）\nCONTENT:这是一个用于测试智能哈希对比的文档的更新版本。"
    success3 = sync_to_dify(url, modified_content, config, metadata)
    print(f"结果: {'✅ 成功' if success3 else '❌ 失败'}")
    
    return success1 and success2 and success3

def main():
    """主函数"""
    print("🚀 TKE 文档同步系统 - 使用示例")
    print("=" * 60)
    
    try:
        # 1. 测试配置
        print("🔧 测试配置...")
        config_manager = ConfigManager()
        if not config_manager.validate_config():
            print("❌ 配置验证失败，请检查 .env 文件")
            return False
        print("✅ 配置验证通过")
        
        # 2. 运行示例
        results = []
        
        # 示例1：单个文档同步
        results.append(example_single_document())
        
        # 示例2：批量同步
        results.append(example_batch_sync())
        
        # 示例3：智能哈希对比
        results.append(example_smart_hash())
        
        # 3. 总结
        print("\n" + "=" * 60)
        print("🎯 示例运行总结")
        print("=" * 60)
        
        success_count = sum(results)
        total_count = len(results)
        
        print(f"成功示例: {success_count}/{total_count}")
        
        if success_count == total_count:
            print("🎉 所有示例运行成功！")
            print("\n💡 您已经掌握了系统的基本用法：")
            print("  • 单个文档同步")
            print("  • 批量文档同步")
            print("  • 智能哈希对比")
            print("\n🚀 现在可以运行完整同步: python tke_dify_sync.py")
        else:
            print("⚠️ 部分示例运行失败，请检查配置和网络连接")
        
        return success_count == total_count
        
    except Exception as e:
        print(f"❌ 示例运行失败: {e}")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)