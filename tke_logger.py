#!/usr/bin/env python3

"""
TKE 统一日志系统
支持文件和控制台输出，带时间戳和日志级别的格式化输出
"""
import logging
import sys
import os
from datetime import datetime
from typing import Dict, Any, Optional, List
from dataclasses import dataclass, field
from enum import Enum
import json
import threading
from pathlib import Path


class LogLevel(Enum):
    """日志级别"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


@dataclass
class LogStats:
    """日志统计信息"""
    total_logs: int = 0
    debug_count: int = 0
    info_count: int = 0
    warning_count: int = 0
    error_count: int = 0
    critical_count: int = 0
    start_time: datetime = field(default_factory=datetime.now)
    
    def increment(self, level: LogLevel):
        """增加日志计数"""
        self.total_logs += 1
        if level == LogLevel.DEBUG:
            self.debug_count += 1
        elif level == LogLevel.INFO:
            self.info_count += 1
        elif level == LogLevel.WARNING:
            self.warning_count += 1
        elif level == LogLevel.ERROR:
            self.error_count += 1
        elif level == LogLevel.CRITICAL:
            self.critical_count += 1
    
    def get_summary(self) -> Dict[str, Any]:
        """获取统计摘要"""
        runtime = datetime.now() - self.start_time
        return {
            'total_logs': self.total_logs,
            'debug_count': self.debug_count,
            'info_count': self.info_count,
            'warning_count': self.warning_count,
            'error_count': self.error_count,
            'critical_count': self.critical_count,
            'runtime_seconds': runtime.total_seconds(),
            'start_time': self.start_time.isoformat(),
            'error_rate': (self.error_count + self.critical_count) / max(1, self.total_logs)
        }


class SensitiveDataFilter:
    """敏感数据过滤器"""
    
    def __init__(self):
        # 敏感数据模式
        self.sensitive_patterns = [
            # API Keys
            r'sk-[a-zA-Z0-9]{48}',
            r'Bearer\s+[a-zA-Z0-9\-_\.]+',
            
            # 密码和令牌
            r'password["\']?\s*[:=]\s*["\']?[^"\'\s]+',
            r'token["\']?\s*[:=]\s*["\']?[^"\'\s]+',
            r'secret["\']?\s*[:=]\s*["\']?[^"\'\s]+',
            
            # 数据库连接字符串
            r'mongodb://[^\s]+',
            r'mysql://[^\s]+',
            r'postgresql://[^\s]+',
            
            # 邮箱地址
            r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
            
            # IP 地址（内网）
            r'\b(?:10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.|192\.168\.)\d{1,3}\.\d{1,3}\b',
            
            # 手机号码
            r'\b1[3-9]\d{9}\b',
            
            # 身份证号
            r'\b\d{17}[0-9Xx]\b'
        ]
        
        # 替换文本
        self.replacement_map = {
            'sk-': '[API_KEY]',
            'Bearer': '[BEARER_TOKEN]',
            'password': '[PASSWORD]',
            'token': '[TOKEN]',
            'secret': '[SECRET]',
            'mongodb://': '[MONGODB_URL]',
            'mysql://': '[MYSQL_URL]',
            'postgresql://': '[POSTGRESQL_URL]',
            '@': '[EMAIL]',
            '10.': '[INTERNAL_IP]',
            '172.': '[INTERNAL_IP]',
            '192.168.': '[INTERNAL_IP]',
            '1': '[PHONE_NUMBER]',  # 手机号
            'ID': '[ID_NUMBER]'     # 身份证
        }
    
    def filter_message(self, message: str) -> str:
        """过滤敏感信息"""
        import re
        
        filtered_message = message
        
        # 定义模式和对应的替换文本
        pattern_replacements = [
            (r'sk-[a-zA-Z0-9]{8,}', '[API_KEY]'),  # API Key 通常以 sk- 开头，后面跟随 8+ 个字符
            (r'Bearer\s+[a-zA-Z0-9\-_\.]+', '[BEARER_TOKEN]'),
            (r'password["\']?\s*[:=]\s*["\']?[^"\'\s]+', 'password: [PASSWORD]'),
            (r'token["\']?\s*[:=]\s*["\']?[^"\'\s]+', 'token: [TOKEN]'),
            (r'secret["\']?\s*[:=]\s*["\']?[^"\'\s]+', 'secret: [SECRET]'),
            (r'mongodb://[^\s]+', '[MONGODB_URL]'),
            (r'mysql://[^\s]+', '[MYSQL_URL]'),
            (r'postgresql://[^\s]+', '[POSTGRESQL_URL]'),
            (r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]'),
            (r'\b(?:10\.|172\.(?:1[6-9]|2[0-9]|3[01])\.|192\.168\.)\d{1,3}\.\d{1,3}\b', '[INTERNAL_IP]'),
            (r'\b1[3-9]\d{9}\b', '[PHONE_NUMBER]'),
            (r'\b\d{17}[0-9Xx]\b', '[ID_NUMBER]'),
            # 特殊处理：JSON 中的 API Key
            (r'"api_key":\s*"sk-[^"]*"', '"api_key": "[API_KEY]"'),
            (r"'api_key':\s*'sk-[^']*'", "'api_key': '[API_KEY]'"),
        ]
        
        for pattern, replacement in pattern_replacements:
            filtered_message = re.sub(pattern, replacement, filtered_message, flags=re.IGNORECASE)
        
        return filtered_message


class TKELogger:
    """TKE 统一日志系统"""
    
    def __init__(self, 
                 name: str = "TKE",
                 log_file: Optional[str] = None,
                 console_output: bool = True,
                 file_output: bool = True,
                 log_level: LogLevel = LogLevel.INFO,
                 max_file_size: int = 10 * 1024 * 1024,  # 10MB
                 backup_count: int = 5):
        """
        初始化日志系统
        
        Args:
            name: 日志器名称
            log_file: 日志文件路径
            console_output: 是否输出到控制台
            file_output: 是否输出到文件
            log_level: 日志级别
            max_file_size: 最大文件大小（字节）
            backup_count: 备份文件数量
        """
        self.name = name
        self.console_output = console_output
        self.file_output = file_output
        self.log_level = log_level
        
        # 统计信息
        self.stats = LogStats()
        self.lock = threading.Lock()
        
        # 敏感数据过滤器
        self.sensitive_filter = SensitiveDataFilter()
        
        # 错误汇总
        self.error_summary: List[Dict[str, Any]] = []
        
        # 设置日志文件路径
        if log_file is None:
            log_dir = Path("logs")
            log_dir.mkdir(exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            log_file = log_dir / f"tke_sync_{timestamp}.log"
        
        self.log_file = Path(log_file)
        
        # 创建 Python 日志器
        self.logger = logging.getLogger(name)
        self.logger.setLevel(getattr(logging, log_level.value))
        
        # 清除现有处理器
        self.logger.handlers.clear()
        
        # 创建格式化器
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # 添加控制台处理器
        if console_output:
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setFormatter(formatter)
            self.logger.addHandler(console_handler)
        
        # 添加文件处理器
        if file_output:
            from logging.handlers import RotatingFileHandler
            
            # 确保日志目录存在
            self.log_file.parent.mkdir(parents=True, exist_ok=True)
            
            file_handler = RotatingFileHandler(
                self.log_file,
                maxBytes=max_file_size,
                backupCount=backup_count,
                encoding='utf-8'
            )
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)
        
        # 记录初始化信息
        self.info(f"TKE 日志系统初始化完成 - 文件: {self.log_file}")
    
    def _log(self, level: LogLevel, message: str, extra_data: Dict = None):
        """内部日志方法"""
        with self.lock:
            # 过滤敏感信息
            filtered_message = self.sensitive_filter.filter_message(message)
            
            # 更新统计
            self.stats.increment(level)
            
            # 记录错误到汇总
            if level in [LogLevel.ERROR, LogLevel.CRITICAL]:
                error_entry = {
                    'timestamp': datetime.now().isoformat(),
                    'level': level.value,
                    'message': filtered_message,
                    'extra_data': extra_data or {}
                }
                self.error_summary.append(error_entry)
                
                # 限制错误汇总大小
                if len(self.error_summary) > 100:
                    self.error_summary = self.error_summary[-50:]
            
            # 记录到 Python 日志器
            log_method = getattr(self.logger, level.value.lower())
            
            if extra_data:
                # 添加额外数据到消息
                extra_str = json.dumps(extra_data, ensure_ascii=False, indent=2)
                full_message = f"{filtered_message}\\n额外数据: {extra_str}"
            else:
                full_message = filtered_message
            
            log_method(full_message)
    
    def debug(self, message: str, **kwargs):
        """调试日志"""
        self._log(LogLevel.DEBUG, message, kwargs)
    
    def info(self, message: str, **kwargs):
        """信息日志"""
        self._log(LogLevel.INFO, message, kwargs)
    
    def warning(self, message: str, **kwargs):
        """警告日志"""
        self._log(LogLevel.WARNING, message, kwargs)
    
    def error(self, message: str, **kwargs):
        """错误日志"""
        self._log(LogLevel.ERROR, message, kwargs)
    
    def critical(self, message: str, **kwargs):
        """严重错误日志"""
        self._log(LogLevel.CRITICAL, message, kwargs)
    
    def log_exception(self, message: str, exception: Exception, **kwargs):
        """记录异常"""
        import traceback
        
        error_details = {
            'exception_type': type(exception).__name__,
            'exception_message': str(exception),
            'traceback': traceback.format_exc(),
            **kwargs
        }
        
        self.error(f"{message}: {exception}", **error_details)
    
    def log_api_call(self, method: str, url: str, status_code: int, 
                     response_time: float, **kwargs):
        """记录 API 调用"""
        # 过滤 URL 中的敏感信息
        filtered_url = self.sensitive_filter.filter_message(url)
        
        api_data = {
            'method': method,
            'url': filtered_url,
            'status_code': status_code,
            'response_time_ms': round(response_time * 1000, 2),
            **kwargs
        }
        
        if status_code >= 400:
            self.error(f"API 调用失败: {method} {filtered_url}", **api_data)
        elif status_code >= 300:
            self.warning(f"API 调用重定向: {method} {filtered_url}", **api_data)
        else:
            self.info(f"API 调用成功: {method} {filtered_url}", **api_data)
    
    def log_task_start(self, task_name: str, **kwargs):
        """记录任务开始"""
        self.info(f"[任务开始] {task_name}", task_name=task_name, **kwargs)
    
    def log_task_complete(self, task_name: str, duration: float, **kwargs):
        """记录任务完成"""
        self.info(f"[任务完成] {task_name} - 耗时: {duration:.2f}秒", 
                 task_name=task_name, duration=duration, **kwargs)
    
    def log_task_error(self, task_name: str, error: Exception, **kwargs):
        """记录任务错误"""
        self.log_exception(f"[任务错误] {task_name}", error, 
                          task_name=task_name, **kwargs)
    
    def log_sync_stats(self, stats: Dict[str, Any]):
        """记录同步统计信息"""
        # 过滤统计信息中的敏感数据
        filtered_stats = {}
        for key, value in stats.items():
            if isinstance(value, str):
                filtered_stats[key] = self.sensitive_filter.filter_message(value)
            else:
                filtered_stats[key] = value
        
        self.info("同步统计信息", **filtered_stats)
    
    def get_stats(self) -> Dict[str, Any]:
        """获取日志统计信息"""
        with self.lock:
            return self.stats.get_summary()
    
    def get_error_summary(self) -> List[Dict[str, Any]]:
        """获取错误汇总"""
        with self.lock:
            return self.error_summary.copy()
    
    def print_execution_summary(self):
        """打印执行摘要"""
        stats = self.get_stats()
        errors = self.get_error_summary()
        
        print("\\n" + "="*60)
        print("TKE 同步执行摘要")
        print("="*60)
        
        # 基本统计
        print(f"执行时间: {stats['runtime_seconds']:.2f} 秒")
        print(f"开始时间: {stats['start_time']}")
        print(f"总日志数: {stats['total_logs']}")
        print(f"错误率: {stats['error_rate']:.1%}")
        
        # 日志级别统计
        print(f"\\n日志级别分布:")
        print(f"  DEBUG: {stats['debug_count']}")
        print(f"  INFO: {stats['info_count']}")
        print(f"  WARNING: {stats['warning_count']}")
        print(f"  ERROR: {stats['error_count']}")
        print(f"  CRITICAL: {stats['critical_count']}")
        
        # 错误汇总
        if errors:
            print(f"\\n错误汇总 (最近 {len(errors)} 个):")
            for i, error in enumerate(errors[-10:], 1):  # 只显示最近 10 个
                timestamp = error['timestamp'][:19]  # 去掉毫秒
                level = error['level']
                message = error['message'][:100]  # 限制长度
                if len(error['message']) > 100:
                    message += "..."
                print(f"  {i}. [{timestamp}] {level}: {message}")
        else:
            print("\\n✅ 执行过程中没有错误")
        
        # 日志文件位置
        if self.file_output:
            print(f"\\n📄 详细日志文件: {self.log_file}")
        
        print("="*60)
    
    def close(self):
        """关闭日志系统"""
        self.info("TKE 日志系统关闭")
        
        # 关闭所有处理器
        for handler in self.logger.handlers:
            handler.close()
        
        # 清除处理器
        self.logger.handlers.clear()


# 全局日志实例
_global_logger: Optional[TKELogger] = None


def get_logger(name: str = "TKE", **kwargs) -> TKELogger:
    """获取全局日志实例"""
    global _global_logger
    
    if _global_logger is None:
        _global_logger = TKELogger(name, **kwargs)
    
    return _global_logger


def setup_logger(name: str = "TKE", **kwargs) -> TKELogger:
    """设置全局日志实例"""
    global _global_logger
    
    if _global_logger is not None:
        _global_logger.close()
    
    _global_logger = TKELogger(name, **kwargs)
    return _global_logger


if __name__ == '__main__':
    # 测试代码
    import time
    
    # 创建日志器
    logger = TKELogger("TEST", log_file="test.log")
    
    # 测试各种日志级别
    logger.debug("这是调试信息")
    logger.info("这是普通信息")
    logger.warning("这是警告信息")
    logger.error("这是错误信息")
    logger.critical("这是严重错误")
    
    # 测试敏感数据过滤
    logger.info("API Key: sk-1234567890abcdef1234567890abcdef12345678")
    logger.info("Bearer Token: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
    logger.info("Password: password=secret123")
    logger.info("Email: user@example.com")
    logger.info("Phone: 13812345678")
    
    # 测试异常记录
    try:
        raise ValueError("测试异常")
    except Exception as e:
        logger.log_exception("测试异常记录", e, context="测试环境")
    
    # 测试 API 调用记录
    logger.log_api_call("POST", "https://api.example.com/test", 200, 0.5, 
                       request_size=1024, response_size=2048)
    
    # 测试任务记录
    logger.log_task_start("测试任务", task_id="task-123")
    time.sleep(0.1)
    logger.log_task_complete("测试任务", 0.1, task_id="task-123", result="success")
    
    # 测试统计信息
    stats = {
        'documents_processed': 10,
        'documents_failed': 2,
        'total_time': 30.5,
        'api_key': 'sk-secret123'  # 这个会被过滤
    }
    logger.log_sync_stats(stats)
    
    # 打印执行摘要
    logger.print_execution_summary()
    
    # 关闭日志器
    logger.close()
    
    print("\\n✅ TKE 日志系统测试完成！")