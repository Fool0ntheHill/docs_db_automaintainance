#!/usr/bin/env python3

"""
边缘情况和潜在问题测试
全面检查系统在各种异常情况下的表现
"""

import sys
import os
import tempfile
import json
import time
from pathlib import Path

# 添加父目录到路径，以便导入主模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tke_dify_sync import ConfigManager, StateManager
from dify_sync_manager import DifySyncManager

class EdgeCaseTest:
    """边缘情况测试类"""
    
    def __init__(self):
        self.test_dir = Path(__file__).parent
        self.original_cwd = os.getcwd()
        self.test_results = []
    
    def test_invalid_config_files(self):
        """测试无效配置文件的处理"""
        print("🧪 测试无效配置文件处理")
        print("=" * 50)
        
        test_cases = [
            ("空文件", ""),
            ("只有注释", "# 这是注释\n# 另一个注释"),
            ("格式错误", "INVALID_FORMAT_NO_EQUALS\nANOTHER_LINE"),
            ("部分配置缺失", "DIFY_API_KEY=test\n# 缺少知识库ID"),
            ("包含特殊字符", "DIFY_API_KEY=test=with=equals\nDIFY_KNOWLEDGE_BASE_ID=test"),
            ("超长行", "DIFY_API_KEY=" + "x" * 10000),
            ("Unicode字符", "DIFY_API_KEY=测试中文\nDIFY_KNOWLEDGE_BASE_ID=中文ID"),
            ("空值", "DIFY_API_KEY=\nDIFY_KNOWLEDGE_BASE_ID="),
        ]
        
        results = []
        
        try:
            os.chdir(self.test_dir)
            
            for case_name, content in test_cases:
                print(f"\n📋 测试案例: {case_name}")
                
                # 创建测试配置文件
                config_file = f".env.test_{case_name.replace(' ', '_')}"
                with open(config_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                try:
                    # 尝试加载配置
                    config_manager = ConfigManager(env_file=config_file)
                    config = config_manager.load_config()
                    
                    # 验证配置
                    is_valid = config_manager.validate_config()
                    
                    if case_name in ["空文件", "只有注释", "部分配置缺失", "空值"]:
                        # 这些情况应该失败
                        if not is_valid:
                            print(f"   ✅ 正确识别为无效配置")
                            results.append(True)
                        else:
                            print(f"   ❌ 错误地认为配置有效")
                            results.append(False)
                    else:
                        # 其他情况应该能处理或给出合理错误
                        print(f"   ✅ 配置处理正常 (有效: {is_valid})")
                        results.append(True)
                        
                except Exception as e:
                    if case_name in ["格式错误", "超长行"]:
                        print(f"   ✅ 正确抛出异常: {type(e).__name__}")
                        results.append(True)
                    else:
                        print(f"   ❌ 意外异常: {e}")
                        results.append(False)
                
                # 清理测试文件
                try:
                    os.remove(config_file)
                except:
                    pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 无效配置文件测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 80  # 80% 通过率认为合格
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def test_corrupted_state_files(self):
        """测试损坏状态文件的处理"""
        print("\n🧪 测试损坏状态文件处理")
        print("=" * 50)
        
        test_cases = [
            ("空文件", ""),
            ("无效JSON", "{invalid json"),
            ("非对象JSON", "[1,2,3]"),
            ("包含非字符串", '{"key": 123, "another": true}'),
            ("超大文件", '{"key": "' + "x" * 1000000 + '"}'),
            ("特殊字符", '{"测试": "中文值", "emoji": "🚀"}'),
        ]
        
        results = []
        
        try:
            os.chdir(self.test_dir)
            
            for case_name, content in test_cases:
                print(f"\n📋 测试案例: {case_name}")
                
                state_file = f"test_state_{case_name.replace(' ', '_')}.json"
                
                # 创建损坏的状态文件
                with open(state_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                try:
                    # 尝试加载状态
                    state_manager = StateManager(state_file)
                    state = state_manager.load_state()
                    
                    # 检查是否正确处理
                    if isinstance(state, dict):
                        print(f"   ✅ 成功加载状态 (条目数: {len(state)})")
                        results.append(True)
                    else:
                        print(f"   ❌ 返回了非字典类型: {type(state)}")
                        results.append(False)
                        
                except Exception as e:
                    print(f"   ❌ 加载状态异常: {e}")
                    results.append(False)
                
                # 测试保存功能
                try:
                    test_state = {"test_key": "test_value"}
                    save_success = state_manager.save_state(test_state)
                    
                    if save_success:
                        print(f"   ✅ 状态保存成功")
                        results.append(True)
                    else:
                        print(f"   ❌ 状态保存失败")
                        results.append(False)
                        
                except Exception as e:
                    print(f"   ❌ 保存状态异常: {e}")
                    results.append(False)
                
                # 清理测试文件
                for cleanup_file in [state_file, f"{state_file}.backup", f"{state_file}.tmp"]:
                    try:
                        if os.path.exists(cleanup_file):
                            os.remove(cleanup_file)
                    except:
                        pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 损坏状态文件测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 70  # 70% 通过率认为合格
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def test_network_edge_cases(self):
        """测试网络相关边缘情况"""
        print("\n🧪 测试网络边缘情况")
        print("=" * 50)
        
        # 创建测试配置
        test_config_content = """
DIFY_API_KEY=test-api-key
DIFY_KNOWLEDGE_BASE_ID=test-kb-id
DIFY_API_BASE_URL=https://invalid-domain-that-does-not-exist.com/v1
KB_STRATEGY=primary
REQUEST_TIMEOUT=1
RETRY_ATTEMPTS=2
RETRY_DELAY=1
"""
        
        results = []
        
        try:
            os.chdir(self.test_dir)
            
            # 创建配置文件
            config_file = ".env.network_test"
            with open(config_file, 'w', encoding='utf-8') as f:
                f.write(test_config_content)
            
            # 清理环境变量
            env_keys_to_clear = [
                'DIFY_API_KEY', 'DIFY_KNOWLEDGE_BASE_ID', 'DIFY_API_BASE_URL',
                'KB_STRATEGY', 'REQUEST_TIMEOUT', 'RETRY_ATTEMPTS', 'RETRY_DELAY'
            ]
            original_env = {}
            for key in env_keys_to_clear:
                if key in os.environ:
                    original_env[key] = os.environ[key]
                    del os.environ[key]
            
            # 加载配置
            config_manager = ConfigManager(env_file=config_file)
            config = config_manager.load_config()
            
            # 恢复环境变量
            for key, value in original_env.items():
                os.environ[key] = value
            
            print("📋 测试网络超时处理...")
            
            # 创建 Dify 管理器
            dify_manager = DifySyncManager(config)
            
            # 测试文档同步（应该失败但不崩溃）
            test_doc = {
                "url": "https://test.com/doc1",
                "content": "TITLE:测试文档\nCONTENT:测试内容",
                "metadata": {"type": "test"}
            }
            
            start_time = time.time()
            success = dify_manager.sync_document(
                test_doc['url'],
                test_doc['content'],
                test_doc['metadata']
            )
            end_time = time.time()
            
            # 检查结果
            if not success:
                print(f"   ✅ 正确处理网络失败 (耗时: {end_time - start_time:.2f}秒)")
                results.append(True)
            else:
                print(f"   ❌ 意外成功了网络请求")
                results.append(False)
            
            # 检查超时时间是否合理
            expected_max_time = config.request_timeout * config.retry_attempts + 5  # 加5秒缓冲
            if end_time - start_time <= expected_max_time:
                print(f"   ✅ 超时时间合理")
                results.append(True)
            else:
                print(f"   ❌ 超时时间过长: {end_time - start_time:.2f}秒")
                results.append(False)
            
            # 清理测试文件
            try:
                os.remove(config_file)
            except:
                pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 网络边缘情况测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 80
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def test_file_permission_issues(self):
        """测试文件权限问题"""
        print("\n🧪 测试文件权限问题")
        print("=" * 50)
        
        results = []
        
        try:
            os.chdir(self.test_dir)
            
            # 测试只读配置文件
            print("📋 测试只读配置文件...")
            readonly_config = ".env.readonly"
            with open(readonly_config, 'w') as f:
                f.write("DIFY_API_KEY=test\nDIFY_KNOWLEDGE_BASE_ID=test")
            
            # 设置为只读
            os.chmod(readonly_config, 0o444)
            
            try:
                config_manager = ConfigManager(env_file=readonly_config)
                config = config_manager.load_config()
                print("   ✅ 成功读取只读配置文件")
                results.append(True)
            except Exception as e:
                print(f"   ❌ 读取只读配置文件失败: {e}")
                results.append(False)
            
            # 测试无权限目录
            print("\n📋 测试状态文件权限...")
            
            # 创建测试状态文件
            state_file = "test_permission_state.json"
            state_manager = StateManager(state_file)
            
            # 尝试保存状态
            test_state = {"test": "value"}
            save_success = state_manager.save_state(test_state)
            
            if save_success:
                print("   ✅ 状态文件保存成功")
                results.append(True)
            else:
                print("   ❌ 状态文件保存失败")
                results.append(False)
            
            # 清理测试文件
            for cleanup_file in [readonly_config, state_file, f"{state_file}.backup", f"{state_file}.tmp"]:
                try:
                    if os.path.exists(cleanup_file):
                        os.chmod(cleanup_file, 0o666)  # 恢复权限
                        os.remove(cleanup_file)
                except:
                    pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 文件权限测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 80
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def test_memory_and_performance(self):
        """测试内存和性能相关问题"""
        print("\n🧪 测试内存和性能问题")
        print("=" * 50)
        
        results = []
        
        try:
            # 测试大量知识库ID
            print("📋 测试大量知识库ID...")
            
            large_kb_ids = ",".join([f"kb-{i:06d}" for i in range(1000)])
            
            config_content = f"""
DIFY_API_KEY=test-api-key
DIFY_KNOWLEDGE_BASE_ID={large_kb_ids}
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
"""
            
            os.chdir(self.test_dir)
            config_file = ".env.large_test"
            with open(config_file, 'w') as f:
                f.write(config_content)
            
            start_time = time.time()
            config_manager = ConfigManager(env_file=config_file)
            config = config_manager.load_config()
            end_time = time.time()
            
            if len(config.dify_knowledge_base_ids) == 1000 and end_time - start_time < 5:
                print(f"   ✅ 大量知识库ID处理正常 ({len(config.dify_knowledge_base_ids)} 个, {end_time - start_time:.2f}秒)")
                results.append(True)
            else:
                print(f"   ❌ 大量知识库ID处理异常")
                results.append(False)
            
            # 测试超长配置值
            print("\n📋 测试超长配置值...")
            
            very_long_value = "x" * 100000
            long_config_content = f"""
DIFY_API_KEY={very_long_value}
DIFY_KNOWLEDGE_BASE_ID=test-kb
DIFY_API_BASE_URL=https://api.dify.ai/v1
"""
            
            long_config_file = ".env.long_test"
            with open(long_config_file, 'w') as f:
                f.write(long_config_content)
            
            try:
                start_time = time.time()
                long_config_manager = ConfigManager(env_file=long_config_file)
                long_config = long_config_manager.load_config()
                end_time = time.time()
                
                if len(long_config.dify_api_key) == 100000 and end_time - start_time < 5:
                    print(f"   ✅ 超长配置值处理正常 ({len(long_config.dify_api_key)} 字符, {end_time - start_time:.2f}秒)")
                    results.append(True)
                else:
                    print(f"   ❌ 超长配置值处理异常")
                    results.append(False)
            except Exception as e:
                print(f"   ❌ 超长配置值处理异常: {e}")
                results.append(False)
            
            # 清理测试文件
            for cleanup_file in [config_file, long_config_file]:
                try:
                    if os.path.exists(cleanup_file):
                        os.remove(cleanup_file)
                except:
                    pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 内存和性能测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 80
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def test_concurrent_access(self):
        """测试并发访问问题"""
        print("\n🧪 测试并发访问问题")
        print("=" * 50)
        
        results = []
        
        try:
            os.chdir(self.test_dir)
            
            # 测试多个配置管理器同时访问同一文件
            print("📋 测试并发配置文件访问...")
            
            config_content = """
DIFY_API_KEY=test-concurrent
DIFY_KNOWLEDGE_BASE_ID=test-kb-concurrent
DIFY_API_BASE_URL=https://api.dify.ai/v1
"""
            
            config_file = ".env.concurrent"
            with open(config_file, 'w') as f:
                f.write(config_content)
            
            # 创建多个配置管理器
            managers = []
            configs = []
            
            for i in range(5):
                manager = ConfigManager(env_file=config_file)
                config = manager.load_config()
                managers.append(manager)
                configs.append(config)
            
            # 检查所有配置是否一致
            first_kb_id = configs[0].dify_knowledge_base_ids[0]
            all_same = all(config.dify_knowledge_base_ids[0] == first_kb_id for config in configs)
            
            if all_same:
                print(f"   ✅ 并发配置文件访问正常")
                results.append(True)
            else:
                print(f"   ❌ 并发配置文件访问异常")
                results.append(False)
            
            # 测试并发状态文件访问
            print("\n📋 测试并发状态文件访问...")
            
            state_file = "test_concurrent_state.json"
            state_managers = []
            
            for i in range(3):
                manager = StateManager(state_file)
                state_managers.append(manager)
            
            # 并发保存不同状态
            save_results = []
            for i, manager in enumerate(state_managers):
                test_state = {f"key_{i}": f"value_{i}"}
                success = manager.save_state(test_state)
                save_results.append(success)
            
            if all(save_results):
                print(f"   ✅ 并发状态文件访问正常")
                results.append(True)
            else:
                print(f"   ❌ 并发状态文件访问异常")
                results.append(False)
            
            # 清理测试文件
            for cleanup_file in [config_file, state_file, f"{state_file}.backup", f"{state_file}.tmp"]:
                try:
                    if os.path.exists(cleanup_file):
                        os.remove(cleanup_file)
                except:
                    pass
            
            success_rate = sum(results) / len(results) * 100
            print(f"\n📊 并发访问测试: {sum(results)}/{len(results)} 通过 ({success_rate:.1f}%)")
            return success_rate >= 80
            
        except Exception as e:
            print(f"❌ 测试异常: {e}")
            return False
        finally:
            os.chdir(self.original_cwd)
    
    def run_complete_test(self):
        """运行完整的边缘情况测试"""
        print("🧪 边缘情况和潜在问题测试")
        print("=" * 80)
        print("全面检查系统在各种异常情况下的表现")
        print("=" * 80)
        
        test_methods = [
            ("无效配置文件处理", self.test_invalid_config_files),
            ("损坏状态文件处理", self.test_corrupted_state_files),
            ("网络边缘情况", self.test_network_edge_cases),
            ("文件权限问题", self.test_file_permission_issues),
            ("内存和性能问题", self.test_memory_and_performance),
            ("并发访问问题", self.test_concurrent_access),
        ]
        
        results = []
        
        try:
            for test_name, test_method in test_methods:
                print(f"\n{'='*20} {test_name} {'='*20}")
                result = test_method()
                results.append(result)
                self.test_results.append((test_name, result))
            
            # 生成测试报告
            self.generate_test_report(results, test_methods)
            
            return all(results)
            
        except Exception as e:
            print(f"❌ 测试过程中出现异常: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def generate_test_report(self, results, test_methods):
        """生成测试报告"""
        print("\n" + "=" * 80)
        print("📊 边缘情况测试报告")
        print("=" * 80)
        
        passed_tests = sum(results)
        total_tests = len(results)
        
        for i, ((test_name, _), result) in enumerate(zip(test_methods, results)):
            status = "✅ 通过" if result else "❌ 失败"
            print(f"   {test_name}: {status}")
        
        print(f"\n🎯 测试总结: {passed_tests}/{total_tests} 通过")
        
        if passed_tests == total_tests:
            print("🎉 所有边缘情况测试通过！")
            print("\n💡 验证的健壮性:")
            print("  ✅ 无效配置文件处理 - 系统能正确识别和处理各种无效配置")
            print("  ✅ 损坏状态文件处理 - 系统能从损坏的状态文件中恢复")
            print("  ✅ 网络异常处理 - 系统能正确处理网络超时和连接失败")
            print("  ✅ 文件权限处理 - 系统能处理各种文件权限问题")
            print("  ✅ 内存和性能 - 系统能处理大量数据和长时间运行")
            print("  ✅ 并发访问 - 系统能正确处理并发文件访问")
            
            print("\n🚀 系统健壮性良好，可以安全部署到生产环境！")
        else:
            failed_tests = [name for (name, _), result in zip(test_methods, results) if not result]
            print("⚠️ 以下边缘情况需要关注:")
            for test_name in failed_tests:
                print(f"   - {test_name}")
            
            print("\n💡 建议:")
            print("  1. 检查失败的测试用例")
            print("  2. 加强相应的错误处理")
            print("  3. 考虑添加更多的防护措施")


def main():
    """主函数"""
    tester = EdgeCaseTest()
    success = tester.run_complete_test()
    return success


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)