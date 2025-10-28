#!/usr/bin/env python3

"""
安全的临时文件管理系统
使用 Python tempfile 模块创建安全临时文件，实现自动清理机制
"""
import os
import tempfile
import shutil
import atexit
import threading
from pathlib import Path
from typing import List, Optional, Dict, Any, Union
from dataclasses import dataclass, field
from contextlib import contextmanager
import json
import time
from datetime import datetime, timedelta


@dataclass
class TempFileInfo:
    """临时文件信息"""
    path: Path
    created_at: datetime
    purpose: str
    size_bytes: int = 0
    is_directory: bool = False
    auto_cleanup: bool = True
    
    def get_age_seconds(self) -> float:
        """获取文件年龄（秒）"""
        return (datetime.now() - self.created_at).total_seconds()
    
    def get_size_mb(self) -> float:
        """获取文件大小（MB）"""
        return self.size_bytes / (1024 * 1024)


class SecureTempManager:
    """安全临时文件管理器"""
    
    def __init__(self, 
                 base_prefix: str = "tke_temp_",
                 max_age_hours: int = 24,
                 max_total_size_mb: int = 1024,
                 cleanup_interval_minutes: int = 30):
        """
        初始化临时文件管理器
        
        Args:
            base_prefix: 临时文件前缀
            max_age_hours: 最大文件年龄（小时）
            max_total_size_mb: 最大总大小（MB）
            cleanup_interval_minutes: 清理间隔（分钟）
        """
        self.base_prefix = base_prefix
        self.max_age_hours = max_age_hours
        self.max_total_size_mb = max_total_size_mb
        self.cleanup_interval_minutes = cleanup_interval_minutes
        
        # 临时文件跟踪
        self.temp_files: Dict[str, TempFileInfo] = {}
        self.lock = threading.Lock()
        
        # 统计信息
        self.stats = {
            'files_created': 0,
            'files_cleaned': 0,
            'directories_created': 0,
            'directories_cleaned': 0,
            'total_size_cleaned_mb': 0.0,
            'cleanup_runs': 0,
            'last_cleanup': None
        }
        
        # 启动清理线程
        self.cleanup_thread = None
        self.stop_cleanup = threading.Event()
        self._start_cleanup_thread()
        
        # 注册程序退出时的清理
        atexit.register(self.cleanup_all)
    
    def _start_cleanup_thread(self):
        """启动清理线程"""
        def cleanup_worker():
            while not self.stop_cleanup.wait(self.cleanup_interval_minutes * 60):
                try:
                    self.cleanup_expired()
                except Exception as e:
                    print(f"[临时文件] 清理线程错误: {e}")
        
        self.cleanup_thread = threading.Thread(target=cleanup_worker, daemon=True)
        self.cleanup_thread.start()
    
    def create_temp_file(self, 
                        suffix: str = "",
                        prefix: Optional[str] = None,
                        purpose: str = "general",
                        auto_cleanup: bool = True,
                        mode: int = 0o600) -> Path:
        """
        创建安全的临时文件
        
        Args:
            suffix: 文件后缀
            prefix: 文件前缀（如果为 None，使用默认前缀）
            purpose: 文件用途描述
            auto_cleanup: 是否自动清理
            mode: 文件权限（默认只有所有者可读写）
            
        Returns:
            临时文件路径
        """
        if prefix is None:
            prefix = self.base_prefix
        
        # 创建临时文件
        fd, temp_path = tempfile.mkstemp(suffix=suffix, prefix=prefix)
        
        try:
            # 设置文件权限
            os.chmod(temp_path, mode)
            
            # 关闭文件描述符
            os.close(fd)
            
            # 记录文件信息
            path_obj = Path(temp_path)
            file_info = TempFileInfo(
                path=path_obj,
                created_at=datetime.now(),
                purpose=purpose,
                size_bytes=0,
                is_directory=False,
                auto_cleanup=auto_cleanup
            )
            
            with self.lock:
                self.temp_files[str(path_obj)] = file_info
                self.stats['files_created'] += 1
            
            print(f"[临时文件] 创建文件: {temp_path} (用途: {purpose})")
            return path_obj
            
        except Exception as e:
            # 清理失败的文件
            try:
                os.unlink(temp_path)
            except:
                pass
            raise e
    
    def create_temp_directory(self, 
                            suffix: str = "",
                            prefix: Optional[str] = None,
                            purpose: str = "general",
                            auto_cleanup: bool = True,
                            mode: int = 0o700) -> Path:
        """
        创建安全的临时目录
        
        Args:
            suffix: 目录后缀
            prefix: 目录前缀（如果为 None，使用默认前缀）
            purpose: 目录用途描述
            auto_cleanup: 是否自动清理
            mode: 目录权限（默认只有所有者可访问）
            
        Returns:
            临时目录路径
        """
        if prefix is None:
            prefix = self.base_prefix
        
        # 创建临时目录
        temp_dir = tempfile.mkdtemp(suffix=suffix, prefix=prefix)
        
        try:
            # 设置目录权限
            os.chmod(temp_dir, mode)
            
            # 记录目录信息
            path_obj = Path(temp_dir)
            dir_info = TempFileInfo(
                path=path_obj,
                created_at=datetime.now(),
                purpose=purpose,
                size_bytes=0,
                is_directory=True,
                auto_cleanup=auto_cleanup
            )
            
            with self.lock:
                self.temp_files[str(path_obj)] = dir_info
                self.stats['directories_created'] += 1
            
            print(f"[临时文件] 创建目录: {temp_dir} (用途: {purpose})")
            return path_obj
            
        except Exception as e:
            # 清理失败的目录
            try:
                shutil.rmtree(temp_dir, ignore_errors=True)
            except:
                pass
            raise e
    
    @contextmanager
    def temp_file(self, **kwargs):
        """
        临时文件上下文管理器
        
        Args:
            **kwargs: create_temp_file 的参数
            
        Yields:
            临时文件路径
        """
        temp_path = None
        try:
            temp_path = self.create_temp_file(**kwargs)
            yield temp_path
        finally:
            if temp_path and temp_path.exists():
                self.remove_temp_file(temp_path)
    
    @contextmanager
    def temp_directory(self, **kwargs):
        """
        临时目录上下文管理器
        
        Args:
            **kwargs: create_temp_directory 的参数
            
        Yields:
            临时目录路径
        """
        temp_dir = None
        try:
            temp_dir = self.create_temp_directory(**kwargs)
            yield temp_dir
        finally:
            if temp_dir and temp_dir.exists():
                self.remove_temp_file(temp_dir)
    
    def write_temp_file(self, 
                       content: Union[str, bytes],
                       suffix: str = "",
                       purpose: str = "data_storage",
                       encoding: str = "utf-8") -> Path:
        """
        创建临时文件并写入内容
        
        Args:
            content: 要写入的内容
            suffix: 文件后缀
            purpose: 文件用途
            encoding: 文本编码（仅用于字符串内容）
            
        Returns:
            临时文件路径
        """
        temp_path = self.create_temp_file(suffix=suffix, purpose=purpose)
        
        try:
            if isinstance(content, str):
                temp_path.write_text(content, encoding=encoding)
            else:
                temp_path.write_bytes(content)
            
            # 更新文件大小
            self._update_file_size(temp_path)
            
            return temp_path
            
        except Exception as e:
            # 写入失败，清理文件
            self.remove_temp_file(temp_path)
            raise e
    
    def write_temp_json(self, 
                       data: Any,
                       suffix: str = ".json",
                       purpose: str = "json_storage",
                       indent: int = 2) -> Path:
        """
        创建临时 JSON 文件
        
        Args:
            data: 要序列化的数据
            suffix: 文件后缀
            purpose: 文件用途
            indent: JSON 缩进
            
        Returns:
            临时文件路径
        """
        json_content = json.dumps(data, ensure_ascii=False, indent=indent)
        return self.write_temp_file(json_content, suffix=suffix, purpose=purpose)
    
    def _update_file_size(self, path: Path):
        """更新文件大小信息"""
        try:
            if path.exists():
                if path.is_file():
                    size = path.stat().st_size
                else:
                    # 计算目录大小
                    size = sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
                
                with self.lock:
                    path_str = str(path)
                    if path_str in self.temp_files:
                        self.temp_files[path_str].size_bytes = size
        except Exception:
            pass  # 忽略大小计算错误
    
    def remove_temp_file(self, path: Union[str, Path]) -> bool:
        """
        移除临时文件或目录
        
        Args:
            path: 文件或目录路径
            
        Returns:
            是否成功移除
        """
        path_obj = Path(path)
        path_str = str(path_obj)
        
        try:
            if path_obj.exists():
                if path_obj.is_file():
                    path_obj.unlink()
                    print(f"[临时文件] 删除文件: {path_obj}")
                elif path_obj.is_dir():
                    shutil.rmtree(path_obj)
                    print(f"[临时文件] 删除目录: {path_obj}")
            
            # 从跟踪中移除
            with self.lock:
                if path_str in self.temp_files:
                    file_info = self.temp_files.pop(path_str)
                    if file_info.is_directory:
                        self.stats['directories_cleaned'] += 1
                    else:
                        self.stats['files_cleaned'] += 1
                    self.stats['total_size_cleaned_mb'] += file_info.get_size_mb()
            
            return True
            
        except Exception as e:
            print(f"[临时文件] 删除失败 {path_obj}: {e}")
            return False
    
    def cleanup_expired(self) -> int:
        """
        清理过期的临时文件
        
        Returns:
            清理的文件数量
        """
        cleaned_count = 0
        max_age = timedelta(hours=self.max_age_hours)
        current_time = datetime.now()
        
        # 获取需要清理的文件列表
        files_to_clean = []
        
        with self.lock:
            for path_str, file_info in list(self.temp_files.items()):
                if not file_info.auto_cleanup:
                    continue
                
                # 检查年龄
                if current_time - file_info.created_at > max_age:
                    files_to_clean.append(path_str)
                    continue
                
                # 检查文件是否仍然存在
                if not file_info.path.exists():
                    files_to_clean.append(path_str)
        
        # 清理文件
        for path_str in files_to_clean:
            if self.remove_temp_file(path_str):
                cleaned_count += 1
        
        # 检查总大小限制
        cleaned_count += self._cleanup_by_size()
        
        with self.lock:
            self.stats['cleanup_runs'] += 1
            self.stats['last_cleanup'] = current_time.isoformat()
        
        if cleaned_count > 0:
            print(f"[临时文件] 清理完成，删除了 {cleaned_count} 个项目")
        
        return cleaned_count
    
    def _cleanup_by_size(self) -> int:
        """根据大小限制清理文件"""
        cleaned_count = 0
        max_size_bytes = self.max_total_size_mb * 1024 * 1024
        
        # 计算当前总大小
        total_size = 0
        file_list = []
        
        with self.lock:
            for path_str, file_info in self.temp_files.items():
                if not file_info.auto_cleanup:
                    continue
                
                # 更新文件大小
                self._update_file_size(file_info.path)
                total_size += file_info.size_bytes
                file_list.append((path_str, file_info))
        
        # 如果超过限制，按创建时间排序，删除最旧的文件
        if total_size > max_size_bytes:
            # 按创建时间排序（最旧的在前）
            file_list.sort(key=lambda x: x[1].created_at)
            
            for path_str, file_info in file_list:
                if total_size <= max_size_bytes:
                    break
                
                if self.remove_temp_file(path_str):
                    total_size -= file_info.size_bytes
                    cleaned_count += 1
        
        return cleaned_count
    
    def cleanup_all(self):
        """清理所有临时文件"""
        print("[临时文件] 开始清理所有临时文件...")
        
        # 停止清理线程
        if self.cleanup_thread and self.cleanup_thread.is_alive():
            self.stop_cleanup.set()
            self.cleanup_thread.join(timeout=5)
        
        # 清理所有文件
        files_to_clean = []
        with self.lock:
            files_to_clean = list(self.temp_files.keys())
        
        cleaned_count = 0
        for path_str in files_to_clean:
            if self.remove_temp_file(path_str):
                cleaned_count += 1
        
        print(f"[临时文件] 清理完成，删除了 {cleaned_count} 个项目")
    
    def get_temp_files_info(self) -> List[TempFileInfo]:
        """获取所有临时文件信息"""
        with self.lock:
            return list(self.temp_files.values())
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.lock:
            stats = self.stats.copy()
            
            # 添加当前状态
            stats['current_files'] = len([f for f in self.temp_files.values() if not f.is_directory])
            stats['current_directories'] = len([f for f in self.temp_files.values() if f.is_directory])
            stats['current_total_size_mb'] = sum(f.get_size_mb() for f in self.temp_files.values())
            
            return stats
    
    def print_stats(self):
        """打印统计信息"""
        stats = self.get_stats()
        
        print("\\n=== 临时文件管理统计 ===")
        print(f"创建文件: {stats['files_created']}")
        print(f"创建目录: {stats['directories_created']}")
        print(f"清理文件: {stats['files_cleaned']}")
        print(f"清理目录: {stats['directories_cleaned']}")
        print(f"清理大小: {stats['total_size_cleaned_mb']:.2f} MB")
        print(f"清理次数: {stats['cleanup_runs']}")
        print(f"最后清理: {stats['last_cleanup'] or '未执行'}")
        
        print(f"\\n当前状态:")
        print(f"文件数: {stats['current_files']}")
        print(f"目录数: {stats['current_directories']}")
        print(f"总大小: {stats['current_total_size_mb']:.2f} MB")
        print("========================\\n")
    
    def list_temp_files(self):
        """列出所有临时文件"""
        files_info = self.get_temp_files_info()
        
        if not files_info:
            print("[临时文件] 当前没有临时文件")
            return
        
        print(f"\\n=== 临时文件列表 ({len(files_info)} 个) ===")
        for file_info in sorted(files_info, key=lambda x: x.created_at):
            file_type = "目录" if file_info.is_directory else "文件"
            age = file_info.get_age_seconds()
            size = file_info.get_size_mb()
            
            print(f"{file_type}: {file_info.path}")
            print(f"  用途: {file_info.purpose}")
            print(f"  创建: {file_info.created_at.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"  年龄: {age:.1f} 秒")
            print(f"  大小: {size:.2f} MB")
            print(f"  自动清理: {'是' if file_info.auto_cleanup else '否'}")
            print()
        print("========================\\n")


# 全局临时文件管理器实例
_global_temp_manager: Optional[SecureTempManager] = None


def get_temp_manager(**kwargs) -> SecureTempManager:
    """获取全局临时文件管理器"""
    global _global_temp_manager
    
    if _global_temp_manager is None:
        _global_temp_manager = SecureTempManager(**kwargs)
    
    return _global_temp_manager


def setup_temp_manager(**kwargs) -> SecureTempManager:
    """设置全局临时文件管理器"""
    global _global_temp_manager
    
    if _global_temp_manager is not None:
        _global_temp_manager.cleanup_all()
    
    _global_temp_manager = SecureTempManager(**kwargs)
    return _global_temp_manager


if __name__ == '__main__':
    # 测试代码
    import time
    
    print("测试安全临时文件管理器...")
    
    # 创建管理器
    temp_manager = SecureTempManager(
        base_prefix="test_temp_",
        max_age_hours=1,
        max_total_size_mb=10,
        cleanup_interval_minutes=1  # 1分钟清理间隔用于测试
    )
    
    try:
        # 测试创建临时文件
        temp_file = temp_manager.create_temp_file(suffix=".txt", purpose="测试文件")
        print(f"创建临时文件: {temp_file}")
        
        # 写入内容
        temp_file.write_text("这是测试内容")
        temp_manager._update_file_size(temp_file)
        
        # 测试创建临时目录
        temp_dir = temp_manager.create_temp_directory(suffix="_test", purpose="测试目录")
        print(f"创建临时目录: {temp_dir}")
        
        # 在临时目录中创建文件
        test_file = temp_dir / "test.txt"
        test_file.write_text("目录中的测试文件")
        temp_manager._update_file_size(temp_dir)
        
        # 测试写入临时文件
        json_file = temp_manager.write_temp_json(
            {"test": "data", "number": 123},
            purpose="JSON测试"
        )
        print(f"创建JSON文件: {json_file}")
        
        # 测试上下文管理器
        with temp_manager.temp_file(suffix=".log", purpose="上下文测试") as ctx_file:
            ctx_file.write_text("上下文管理器测试")
            print(f"上下文文件: {ctx_file}")
        
        # 列出所有临时文件
        temp_manager.list_temp_files()
        
        # 打印统计信息
        temp_manager.print_stats()
        
        # 测试手动清理
        print("\\n测试手动清理...")
        temp_manager.remove_temp_file(temp_file)
        
        # 等待一段时间测试自动清理
        print("\\n等待自动清理...")
        time.sleep(2)
        
        # 最终统计
        temp_manager.print_stats()
        
    finally:
        # 清理所有临时文件
        temp_manager.cleanup_all()
    
    print("\\n✅ 安全临时文件管理器测试完成！")