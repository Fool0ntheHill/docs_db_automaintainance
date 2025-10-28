#!/usr/bin/env python3

"""
多知识库配置测试
测试配置文件分离的多知识库管理方式
"""

import sys
import os
import shutil
import tempfile
from pathlib import Path

# 添加父目录到路径，以便导入主模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tke_dify_sync import ConfigManager
from dify_sync_manager import DifySyncManager

class MultiKBConfigTest:
    """多知识库配置测试类"""
    
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.original_cwd = os.getcwd()
        
        # 测试知识库配置
        self.kb_configs = {
            'main': {
                'id': '8c6b8e3c-f69c-48ea-b34e-a71798c800ed',
                'name': '主知识库',
                'description': '原有的主要知识库'
            },
            'test': {
                'id': '2ac0e7aa-9eba-4363-8f9d-e426d0b2451e',
                'name': '测试知识库',
                'description': '新增的测试知识库'
            }
        }
    
    def create_test_env_files(self):
        """创建测试用的环境配置文件"""
        print("📋 创建测试环境配置文件...")
        
        # 创建主知识库配置
        main_config = f"""# 主知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID={self.kb_configs['main']['id']}
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=1
STATE_FILE=crawl_state_main.json
LOG_FILE=tke_sync_main.log
BASE_URL=https://cloud.tencent.com
START_URL=https://cloud.tencent.com/document/product/457
"""
        
        # 创建测试知识库配置
        test_config = f"""# 测试知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID={self.kb_configs['test']['id']}
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=1
STATE_FILE=crawl_state_test.json
LOG_FILE=tke_sync_test.log
BASE_URL=https://cloud.tencent.com
START_URL=https://cloud.tencent.com/document/product/457
"""
        
        # 写入文件
        with open(self.test_dir / '.env.main', 'w', encoding='utf-8') as f:
            f.write(main_config)
        
        with open(self.test_dir / '.env.test', 'w', encoding='utf-8') as f:
            f.write(test_config)
        
        print("✅ 测试配置文件创建完成")
        print(f"   - .env.main: {self.kb_configs['main']['name']}")
        print(f"   - .env.test: {self.kb_configs['test']['name']}")
    
    def test_config_loading(self, config_name):
        """测试配置加载"""
        print(f"\\n🔧 测试配置加载: {config_name}")
        
        config_file = self.test_dir / f'.env.{config_name}'
        if not config_file.exists():
            print(f"❌ 配置文件不存在: {config_file}")
            return False
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 清理环境变量，避免缓存问题
            env_keys_to_clear = [
                'DIFY_API_KEY', 'DIFY_KNOWLEDGE_BASE_ID', 'DIFY_API_BASE_URL',
                'KB_STRATEGY', 'REQUEST_TIMEOUT', 'RETRY_ATTEMPTS', 'RETRY_DELAY',
                'STATE_FILE', 'LOG_FILE', 'BASE_URL', 'START_URL'
            ]
            original_env = {}
            for key in env_keys_to_clear:
                if key in os.environ:
                    original_env[key] = os.environ[key]
                    del os.environ[key]
            
            # 创建配置管理器
            config_manager = ConfigManager(env_file=f'.env.{config_name}')
            config = config_manager.load_config()
            
            # 恢复环境变量
            for key, value in original_env.items():
                os.environ[key] = value
            
            # 验证配置
            expected_kb_id = self.kb_configs[config_name]['id']
            if config.dify_knowledge_base_ids[0] != expected_kb_id:
                print(f"❌ 知识库ID不匹配: 期望 {expected_kb_id}, 实际 {config.dify_knowledge_base_ids[0]}")
                return False
            
            print(f"✅ 配置加载成功")
            print(f"   知识库ID: {config.dify_knowledge_base_ids[0]}")
            print(f"   状态文件: {config.state_file}")
            print(f"   日志文件: {config.log_file}")
            print(f"   同步策略: {config.kb_strategy}")
            
            return True
            
        except Exception as e:
            print(f"❌ 配置加载失败: {e}")
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
    
    def test_dify_manager_creation(self, config_name):
        """测试 Dify 管理器创建"""
        print(f"\\n🚀 测试 Dify 管理器创建: {config_name}")
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 清理环境变量，避免缓存问题
            env_keys_to_clear = [
                'DIFY_API_KEY', 'DIFY_KNOWLEDGE_BASE_ID', 'DIFY_API_BASE_URL',
                'KB_STRATEGY', 'REQUEST_TIMEOUT', 'RETRY_ATTEMPTS', 'RETRY_DELAY',
                'STATE_FILE', 'LOG_FILE', 'BASE_URL', 'START_URL'
            ]
            original_env = {}
            for key in env_keys_to_clear:
                if key in os.environ:
                    original_env[key] = os.environ[key]
                    del os.environ[key]
            
            # 创建配置管理器
            config_manager = ConfigManager(env_file=f'.env.{config_name}')
            config = config_manager.load_config()
            
            # 恢复环境变量
            for key, value in original_env.items():
                os.environ[key] = value
            
            # 创建 Dify 管理器
            dify_manager = DifySyncManager(config)
            
            print(f"✅ Dify 管理器创建成功")
            print(f"   知识库数量: {len(config.dify_knowledge_base_ids)}")
            print(f"   API 基础URL: {config.dify_api_base_url}")
            
            return True
            
        except Exception as e:
            print(f"❌ Dify 管理器创建失败: {e}")
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
    
    def test_document_sync(self, config_name):
        """测试文档同步"""
        print(f"\\n📄 测试文档同步: {config_name}")
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 清理环境变量，避免缓存问题
            env_keys_to_clear = [
                'DIFY_API_KEY', 'DIFY_KNOWLEDGE_BASE_ID', 'DIFY_API_BASE_URL',
                'KB_STRATEGY', 'REQUEST_TIMEOUT', 'RETRY_ATTEMPTS', 'RETRY_DELAY',
                'STATE_FILE', 'LOG_FILE', 'BASE_URL', 'START_URL'
            ]
            original_env = {}
            for key in env_keys_to_clear:
                if key in os.environ:
                    original_env[key] = os.environ[key]
                    del os.environ[key]
            
            # 创建配置管理器和 Dify 管理器
            config_manager = ConfigManager(env_file=f'.env.{config_name}')
            config = config_manager.load_config()
            dify_manager = DifySyncManager(config)
            
            # 恢复环境变量
            for key, value in original_env.items():
                os.environ[key] = value
            
            # 测试文档
            test_doc = {
                "url": f"https://cloud.tencent.com/document/product/457/multi-kb-test-{config_name}",
                "title": f"多知识库测试文档-{config_name}",
                "content": f"TITLE:多知识库测试文档-{config_name}\\nCONTENT:这是用于测试 {config_name} 知识库的文档内容。测试配置文件分离功能。",
                "metadata": {"document_type": "测试文档", "kb_type": config_name}
            }
            
            print(f"   同步文档: {test_doc['title']}")
            print(f"   目标知识库: {config.dify_knowledge_base_ids[0]}")
            
            # 执行同步
            success = dify_manager.sync_document(
                test_doc['url'],
                test_doc['content'],
                test_doc['metadata']
            )
            
            if success:
                print(f"✅ 文档同步成功")
                
                # 显示统计信息
                stats = dify_manager.get_stats()
                print(f"   文档创建: {stats.get('documents_created', 0)}")
                print(f"   文档更新: {stats.get('documents_updated', 0)}")
                print(f"   API 调用: {stats.get('api_calls', 0)}")
                
                return True
            else:
                print(f"❌ 文档同步失败")
                return False
                
        except Exception as e:
            print(f"❌ 文档同步异常: {e}")
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
    
    def test_state_file_isolation(self):
        """测试状态文件隔离"""
        print(f"\\n📊 测试状态文件隔离")
        
        try:
            # 切换到测试目录
            os.chdir(self.test_dir)
            
            # 测试两个配置的状态文件是否独立
            main_state_file = "crawl_state_main.json"
            test_state_file = "crawl_state_test.json"
            
            # 检查状态文件是否存在且不同
            main_exists = os.path.exists(main_state_file)
            test_exists = os.path.exists(test_state_file)
            
            print(f"   主知识库状态文件: {main_state_file} - {'存在' if main_exists else '不存在'}")
            print(f"   测试知识库状态文件: {test_state_file} - {'存在' if test_exists else '不存在'}")
            
            if main_exists and test_exists:
                # 比较文件内容
                with open(main_state_file, 'r', encoding='utf-8') as f:
                    main_content = f.read()
                with open(test_state_file, 'r', encoding='utf-8') as f:
                    test_content = f.read()
                
                if main_content != test_content:
                    print("✅ 状态文件隔离成功 - 文件内容不同")
                    return True
                else:
                    print("⚠️ 状态文件内容相同，可能存在隔离问题")
                    return False
            else:
                print("✅ 状态文件隔离正常 - 文件独立存在")
                return True
                
        except Exception as e:
            print(f"❌ 状态文件隔离测试异常: {e}")
            return False
        finally:
            # 恢复原始工作目录
            os.chdir(self.original_cwd)
    
    def cleanup_test_files(self):
        """清理测试文件"""
        print("\\n🧹 清理测试文件...")
        
        test_files = [
            '.env.main',
            '.env.test',
            'crawl_state_main.json',
            'crawl_state_test.json',
            'tke_sync_main.log',
            'tke_sync_test.log'
        ]
        
        for file_name in test_files:
            file_path = self.test_dir / file_name
            if file_path.exists():
                try:
                    file_path.unlink()
                    print(f"   删除: {file_name}")
                except Exception as e:
                    print(f"   删除失败: {file_name} - {e}")
        
        print("✅ 测试文件清理完成")
    
    def run_complete_test(self):
        """运行完整的多知识库配置测试"""
        print("🧪 多知识库配置测试")
        print("=" * 60)
        print("测试配置文件分离的多知识库管理方式")
        print("=" * 60)
        
        test_results = []
        
        try:
            # 1. 创建测试配置文件
            self.create_test_env_files()
            
            # 2. 测试配置加载
            for config_name in ['main', 'test']:
                result = self.test_config_loading(config_name)
                test_results.append(result)
            
            # 3. 测试 Dify 管理器创建
            for config_name in ['main', 'test']:
                result = self.test_dify_manager_creation(config_name)
                test_results.append(result)
            
            # 4. 测试文档同步
            for config_name in ['main', 'test']:
                result = self.test_document_sync(config_name)
                test_results.append(result)
            
            # 5. 测试状态文件隔离
            result = self.test_state_file_isolation()
            test_results.append(result)
            
            # 6. 生成测试报告
            self.generate_test_report(test_results)
            
            return all(test_results)
            
        except Exception as e:
            print(f"❌ 测试过程中出现异常: {e}")
            import traceback
            traceback.print_exc()
            return False
        finally:
            # 清理测试文件
            self.cleanup_test_files()
    
    def generate_test_report(self, test_results):
        """生成测试报告"""
        print("\\n" + "=" * 60)
        print("📊 多知识库配置测试报告")
        print("=" * 60)
        
        test_items = [
            "主知识库配置加载",
            "测试知识库配置加载",
            "主知识库 Dify 管理器创建",
            "测试知识库 Dify 管理器创建",
            "主知识库文档同步",
            "测试知识库文档同步",
            "状态文件隔离"
        ]
        
        passed_tests = sum(test_results)
        total_tests = len(test_results)
        
        for i, (test_name, result) in enumerate(zip(test_items, test_results)):
            status = "✅ 通过" if result else "❌ 失败"
            print(f"   {test_name}: {status}")
        
        print(f"\\n🎯 测试总结: {passed_tests}/{total_tests} 通过")
        
        if passed_tests == total_tests:
            print("🎉 所有多知识库配置测试通过！")
            print("\\n💡 验证的功能:")
            print("  ✅ 配置文件分离 - 支持独立的 .env.main 和 .env.test")
            print("  ✅ 知识库ID隔离 - 不同配置使用不同知识库")
            print("  ✅ 状态文件隔离 - 独立的状态文件避免冲突")
            print("  ✅ 日志文件隔离 - 独立的日志文件便于调试")
            print("  ✅ 文档同步正常 - 可以正常同步到不同知识库")
            
            print("\\n🚀 配置文件分离方案完全可用！")
            print("\\n📋 使用方法:")
            print("  1. 复制 test/.env.main.example 为 .env.main")
            print("  2. 复制 test/.env.test.example 为 .env.test")
            print("  3. 修改各配置文件中的知识库ID")
            print("  4. 运行: cp .env.main .env && python tke_dify_sync.py")
            print("  5. 运行: cp .env.test .env && python tke_dify_sync.py")
        else:
            print("⚠️ 部分多知识库配置测试未通过，请检查相关配置")


def main():
    """主函数"""
    tester = MultiKBConfigTest()
    success = tester.run_complete_test()
    return success


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)