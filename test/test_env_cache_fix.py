#!/usr/bin/env python3

"""
环境变量缓存问题修复测试
验证主程序是否正确处理配置文件切换
"""

import sys
import os
import tempfile
from pathlib import Path

# 添加父目录到路径，以便导入主模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tke_dify_sync import ConfigManager

class EnvCacheFixTest:
    """环境变量缓存修复测试类"""
    
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.original_cwd = os.getcwd()
        
        # 测试配置
        self.config1 = {
            'DIFY_API_KEY': 'test-api-key-1',
            'DIFY_KNOWLEDGE_BASE_ID': '8c6b8e3c-f69c-48ea-b34e-a71798c800ed',
            'DIFY_API_BASE_URL': 'https://api.dify.ai/v1',
            'KB_STRATEGY': 'primary',
            'STATE_FILE': 'crawl_state_config1.json',
            'LOG_FILE': 'tke_sync_config1.log'
        }
        
        self.config2 = {
            'DIFY_API_KEY': 'test-api-key-2',
            'DIFY_KNOWLEDGE_BASE_ID': '2ac0e7aa-9eba-4363-8f9d-e426d0b2451e',
            'DIFY_API_BASE_URL': 'https://api.dify.ai/v1',
            'KB_STRATEGY': 'all',
            'STATE_FILE': 'crawl_state_config2.json',
            'LOG_FILE': 'tke_sync_config2.log'
        }
    
    def create_config_file(self, filename, config):
        """创建配置文件"""
        config_content = ""
        for key, value in config.items():
            config_content += f"{key}={value}\n"
        
        config_path = self.test_dir / filename
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(config_content)
        
        return config_path
    
    def test_sequential_config_loading(self):
        """测试连续加载不同配置文件"""
        print("🧪 测试连续配置文件加载")
        print("=" * 50)
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 创建两个不同的配置文件
            config1_file = self.create_config_file('.env.config1', self.config1)
            config2_file = self.create_config_file('.env.config2', self.config2)
            
            print("📋 创建的配置文件:")
            print(f"   配置1: {config1_file}")
            print(f"   配置2: {config2_file}")
            
            # 第一次加载配置1
            print(f"\n🔧 第一次加载配置1...")
            config_manager1 = ConfigManager(env_file='.env.config1')
            loaded_config1 = config_manager1.load_config()
            
            print(f"   知识库ID: {loaded_config1.dify_knowledge_base_ids[0]}")
            print(f"   API Key: {loaded_config1.dify_api_key}")
            print(f"   策略: {loaded_config1.kb_strategy}")
            print(f"   状态文件: {loaded_config1.state_file}")
            
            # 验证配置1
            expected_kb_id1 = self.config1['DIFY_KNOWLEDGE_BASE_ID']
            if loaded_config1.dify_knowledge_base_ids[0] != expected_kb_id1:
                print(f"❌ 配置1加载失败: 期望 {expected_kb_id1}, 实际 {loaded_config1.dify_knowledge_base_ids[0]}")
                return False
            
            # 第二次加载配置2
            print(f"\n🔧 第二次加载配置2...")
            config_manager2 = ConfigManager(env_file='.env.config2')
            loaded_config2 = config_manager2.load_config()
            
            print(f"   知识库ID: {loaded_config2.dify_knowledge_base_ids[0]}")
            print(f"   API Key: {loaded_config2.dify_api_key}")
            print(f"   策略: {loaded_config2.kb_strategy}")
            print(f"   状态文件: {loaded_config2.state_file}")
            
            # 验证配置2
            expected_kb_id2 = self.config2['DIFY_KNOWLEDGE_BASE_ID']
            if loaded_config2.dify_knowledge_base_ids[0] != expected_kb_id2:
                print(f"❌ 配置2加载失败: 期望 {expected_kb_id2}, 实际 {loaded_config2.dify_knowledge_base_ids[0]}")
                return False
            
            # 验证配置是否真的不同
            if loaded_config1.dify_knowledge_base_ids[0] == loaded_config2.dify_knowledge_base_ids[0]:
                print(f"❌ 环境变量缓存问题: 两次加载的知识库ID相同")
                return False
            
            if loaded_config1.kb_strategy == loaded_config2.kb_strategy:
                print(f"❌ 环境变量缓存问题: 两次加载的策略相同")
                return False
            
            if loaded_config1.state_file == loaded_config2.state_file:
                print(f"❌ 环境变量缓存问题: 两次加载的状态文件相同")
                return False
            
            print(f"\n✅ 配置切换成功!")
            print(f"   配置1知识库: {loaded_config1.dify_knowledge_base_ids[0]}")
            print(f"   配置2知识库: {loaded_config2.dify_knowledge_base_ids[0]}")
            print(f"   配置1策略: {loaded_config1.kb_strategy}")
            print(f"   配置2策略: {loaded_config2.kb_strategy}")
            
            return True
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
            
            # 清理测试文件
            self.cleanup_test_files()
    
    def test_same_process_multiple_configs(self):
        """测试同一进程中多次配置加载"""
        print(f"\n🔄 测试同一进程中多次配置加载")
        print("=" * 50)
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 创建配置文件
            config1_file = self.create_config_file('.env.test1', self.config1)
            config2_file = self.create_config_file('.env.test2', self.config2)
            
            results = []
            
            # 连续加载多次，模拟用户的实际使用场景
            for i in range(3):
                print(f"\n--- 第 {i+1} 轮测试 ---")
                
                # 加载配置1
                print("加载配置1...")
                cm1 = ConfigManager(env_file='.env.test1')
                cfg1 = cm1.load_config()
                kb_id1 = cfg1.dify_knowledge_base_ids[0]
                
                # 加载配置2
                print("加载配置2...")
                cm2 = ConfigManager(env_file='.env.test2')
                cfg2 = cm2.load_config()
                kb_id2 = cfg2.dify_knowledge_base_ids[0]
                
                print(f"配置1知识库: {kb_id1}")
                print(f"配置2知识库: {kb_id2}")
                
                # 验证结果
                if kb_id1 == self.config1['DIFY_KNOWLEDGE_BASE_ID'] and kb_id2 == self.config2['DIFY_KNOWLEDGE_BASE_ID']:
                    results.append(True)
                    print("✅ 本轮测试通过")
                else:
                    results.append(False)
                    print("❌ 本轮测试失败")
            
            success_count = sum(results)
            print(f"\n📊 测试结果: {success_count}/3 轮通过")
            
            return success_count == 3
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
            
            # 清理测试文件
            self.cleanup_test_files()
    
    def cleanup_test_files(self):
        """清理测试文件"""
        test_files = [
            '.env.config1',
            '.env.config2', 
            '.env.test1',
            '.env.test2'
        ]
        
        for file_name in test_files:
            file_path = self.test_dir / file_name
            if file_path.exists():
                try:
                    file_path.unlink()
                except Exception as e:
                    print(f"清理文件失败: {file_name} - {e}")
    
    def run_complete_test(self):
        """运行完整测试"""
        print("🧪 环境变量缓存问题修复测试")
        print("=" * 60)
        print("验证主程序是否正确处理配置文件切换")
        print("=" * 60)
        
        test_results = []
        
        try:
            # 测试1: 连续配置文件加载
            result1 = self.test_sequential_config_loading()
            test_results.append(result1)
            
            # 测试2: 同一进程中多次配置加载
            result2 = self.test_same_process_multiple_configs()
            test_results.append(result2)
            
            # 生成测试报告
            self.generate_test_report(test_results)
            
            return all(test_results)
            
        except Exception as e:
            print(f"❌ 测试过程中出现异常: {e}")
            return False
    
    def generate_test_report(self, test_results):
        """生成测试报告"""
        print("\n" + "=" * 60)
        print("📊 环境变量缓存修复测试报告")
        print("=" * 60)
        
        test_items = [
            "连续配置文件加载",
            "同一进程多次配置加载"
        ]
        
        passed_tests = sum(test_results)
        total_tests = len(test_results)
        
        for i, (test_name, result) in enumerate(zip(test_items, test_results)):
            status = "✅ 通过" if result else "❌ 失败"
            print(f"   {test_name}: {status}")
        
        print(f"\n🎯 测试总结: {passed_tests}/{total_tests} 通过")
        
        if passed_tests == total_tests:
            print("🎉 环境变量缓存问题已修复！")
            print("\n💡 修复内容:")
            print("  ✅ 配置文件中的值现在优先于环境变量")
            print("  ✅ 支持在同一进程中切换不同配置文件")
            print("  ✅ 解决了多知识库配置切换问题")
            
            print("\n🚀 现在可以安全使用以下命令:")
            print("  cp .env.main .env && python tke_dify_sync.py")
            print("  cp .env.test .env && python tke_dify_sync.py")
        else:
            print("⚠️ 环境变量缓存问题仍然存在，需要进一步修复")


def main():
    """主函数"""
    tester = EnvCacheFixTest()
    success = tester.run_complete_test()
    return success


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)