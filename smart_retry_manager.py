#!/usr/bin/env python3

"""
智能重试机制管理器
实现指数退避、熔断器模式和自适应重试策略
"""
import time
import random
import threading
from typing import Callable, Any, Optional, Dict, List
from dataclasses import dataclass
from enum import Enum
from collections import defaultdict, deque
import requests


class RetryReason(Enum):
    """重试原因枚举"""
    TIMEOUT = "timeout"
    CONNECTION_ERROR = "connection_error"
    SERVER_ERROR = "server_error"
    RATE_LIMIT = "rate_limit"
    TEMPORARY_FAILURE = "temporary_failure"
    UNKNOWN_ERROR = "unknown_error"


class CircuitState(Enum):
    """熔断器状态"""
    CLOSED = "closed"      # 正常状态
    OPEN = "open"          # 熔断状态
    HALF_OPEN = "half_open" # 半开状态


@dataclass
class RetryConfig:
    """重试配置"""
    max_attempts: int = 3
    base_delay: float = 1.0
    max_delay: float = 60.0
    exponential_base: float = 2.0
    jitter: bool = True
    
    # 熔断器配置
    failure_threshold: int = 5
    recovery_timeout: float = 30.0
    half_open_max_calls: int = 3
    
    # 自适应配置
    success_rate_threshold: float = 0.8
    adaptive_window_size: int = 100


class CircuitBreaker:
    """熔断器实现"""
    
    def __init__(self, config: RetryConfig):
        self.config = config
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.last_failure_time = 0
        self.half_open_calls = 0
        self.lock = threading.Lock()
    
    def can_execute(self) -> bool:
        """检查是否可以执行请求"""
        with self.lock:
            if self.state == CircuitState.CLOSED:
                return True
            elif self.state == CircuitState.OPEN:
                if time.time() - self.last_failure_time >= self.config.recovery_timeout:
                    self.state = CircuitState.HALF_OPEN
                    self.half_open_calls = 0
                    return True
                return False
            elif self.state == CircuitState.HALF_OPEN:
                return self.half_open_calls < self.config.half_open_max_calls
        return False
    
    def record_success(self):
        """记录成功"""
        with self.lock:
            if self.state == CircuitState.HALF_OPEN:
                self.half_open_calls += 1
                if self.half_open_calls >= self.config.half_open_max_calls:
                    self.state = CircuitState.CLOSED
                    self.failure_count = 0
            elif self.state == CircuitState.CLOSED:
                self.failure_count = max(0, self.failure_count - 1)
    
    def record_failure(self):
        """记录失败"""
        with self.lock:
            self.failure_count += 1
            self.last_failure_time = time.time()
            
            if self.state == CircuitState.HALF_OPEN:
                self.state = CircuitState.OPEN
            elif self.state == CircuitState.CLOSED:
                if self.failure_count >= self.config.failure_threshold:
                    self.state = CircuitState.OPEN
    
    def get_state(self) -> CircuitState:
        """获取当前状态"""
        return self.state


class AdaptiveRetryStrategy:
    """自适应重试策略"""
    
    def __init__(self, config: RetryConfig):
        self.config = config
        self.success_history = deque(maxlen=config.adaptive_window_size)
        self.lock = threading.Lock()
    
    def record_attempt(self, success: bool):
        """记录尝试结果"""
        with self.lock:
            self.success_history.append(success)
    
    def get_success_rate(self) -> float:
        """获取成功率"""
        with self.lock:
            if not self.success_history:
                return 1.0
            return sum(self.success_history) / len(self.success_history)
    
    def should_retry(self, attempt: int, reason: RetryReason) -> bool:
        """判断是否应该重试"""
        if attempt >= self.config.max_attempts:
            return False
        
        success_rate = self.get_success_rate()
        
        # 根据成功率调整重试策略
        if success_rate < self.config.success_rate_threshold:
            # 成功率低时，减少重试次数
            max_attempts = max(1, self.config.max_attempts - 1)
        else:
            # 成功率高时，使用正常重试次数
            max_attempts = self.config.max_attempts
        
        # 根据错误类型调整重试策略
        if reason in [RetryReason.TIMEOUT, RetryReason.CONNECTION_ERROR]:
            # 网络问题，积极重试
            return attempt < max_attempts
        elif reason == RetryReason.SERVER_ERROR:
            # 服务器错误，适度重试
            return attempt < max(1, max_attempts - 1)
        elif reason == RetryReason.RATE_LIMIT:
            # 限流，延长等待时间后重试
            return attempt < max_attempts
        else:
            # 其他错误，保守重试
            return attempt < max(1, max_attempts - 2)
    
    def calculate_delay(self, attempt: int, reason: RetryReason) -> float:
        """计算延迟时间"""
        base_delay = self.config.base_delay
        
        # 根据错误类型调整基础延迟
        if reason == RetryReason.RATE_LIMIT:
            base_delay *= 2  # 限流时延长等待
        elif reason == RetryReason.SERVER_ERROR:
            base_delay *= 1.5  # 服务器错误时适度延长
        
        # 指数退避
        delay = base_delay * (self.config.exponential_base ** attempt)
        
        # 限制最大延迟
        delay = min(delay, self.config.max_delay)
        
        # 添加抖动
        if self.config.jitter:
            jitter = random.uniform(0.1, 0.3) * delay
            delay += jitter
        
        return delay


class SmartRetryManager:
    """智能重试管理器"""
    
    def __init__(self, config: RetryConfig = None):
        self.config = config or RetryConfig()
        self.circuit_breakers = defaultdict(lambda: CircuitBreaker(self.config))
        self.retry_strategies = defaultdict(lambda: AdaptiveRetryStrategy(self.config))
        
        # 统计信息
        self.stats = {
            'total_attempts': 0,
            'successful_attempts': 0,
            'failed_attempts': 0,
            'retries_performed': 0,
            'circuit_breaker_trips': 0,
            'adaptive_adjustments': 0
        }
        
        self.lock = threading.Lock()
    
    def execute_with_retry(self, 
                          func: Callable, 
                          *args, 
                          endpoint_key: str = "default",
                          **kwargs) -> Any:
        """
        执行带重试的函数调用
        
        Args:
            func: 要执行的函数
            *args: 函数参数
            endpoint_key: 端点标识符（用于独立的熔断器和策略）
            **kwargs: 函数关键字参数
            
        Returns:
            函数执行结果
            
        Raises:
            Exception: 所有重试都失败后抛出最后一个异常
        """
        circuit_breaker = self.circuit_breakers[endpoint_key]
        retry_strategy = self.retry_strategies[endpoint_key]
        
        last_exception = None
        attempt = 0
        
        while attempt < self.config.max_attempts:
            # 检查熔断器状态
            if not circuit_breaker.can_execute():
                with self.lock:
                    self.stats['circuit_breaker_trips'] += 1
                raise Exception(f"Circuit breaker is OPEN for endpoint: {endpoint_key}")
            
            try:
                with self.lock:
                    self.stats['total_attempts'] += 1
                
                # 执行函数
                result = func(*args, **kwargs)
                
                # 记录成功
                circuit_breaker.record_success()
                retry_strategy.record_attempt(True)
                
                with self.lock:
                    self.stats['successful_attempts'] += 1
                
                return result
                
            except Exception as e:
                last_exception = e
                attempt += 1
                
                # 分析错误原因
                reason = self._analyze_error(e)
                
                # 记录失败
                circuit_breaker.record_failure()
                retry_strategy.record_attempt(False)
                
                with self.lock:
                    self.stats['failed_attempts'] += 1
                
                # 判断是否应该重试
                if not retry_strategy.should_retry(attempt, reason):
                    break
                
                # 计算延迟时间
                delay = retry_strategy.calculate_delay(attempt - 1, reason)
                
                print(f"[重试] 第 {attempt} 次尝试失败 ({reason.value})，{delay:.2f}秒后重试...")
                
                with self.lock:
                    self.stats['retries_performed'] += 1
                
                time.sleep(delay)
        
        # 所有重试都失败
        if last_exception:
            raise last_exception
        else:
            raise Exception("All retry attempts failed")
    
    def _analyze_error(self, error: Exception) -> RetryReason:
        """分析错误类型"""
        if isinstance(error, requests.exceptions.Timeout):
            return RetryReason.TIMEOUT
        elif isinstance(error, requests.exceptions.ConnectionError):
            return RetryReason.CONNECTION_ERROR
        elif isinstance(error, requests.exceptions.HTTPError):
            if hasattr(error, 'response') and error.response is not None:
                status_code = error.response.status_code
                if status_code == 429:  # Too Many Requests
                    return RetryReason.RATE_LIMIT
                elif 500 <= status_code < 600:
                    return RetryReason.SERVER_ERROR
                elif status_code in [502, 503, 504]:  # Bad Gateway, Service Unavailable, Gateway Timeout
                    return RetryReason.TEMPORARY_FAILURE
        elif isinstance(error, requests.exceptions.RequestException):
            return RetryReason.CONNECTION_ERROR
        
        return RetryReason.UNKNOWN_ERROR
    
    def get_endpoint_stats(self, endpoint_key: str) -> Dict:
        """获取特定端点的统计信息"""
        circuit_breaker = self.circuit_breakers[endpoint_key]
        retry_strategy = self.retry_strategies[endpoint_key]
        
        return {
            'circuit_breaker_state': circuit_breaker.get_state().value,
            'failure_count': circuit_breaker.failure_count,
            'success_rate': retry_strategy.get_success_rate(),
            'history_size': len(retry_strategy.success_history)
        }
    
    def get_global_stats(self) -> Dict:
        """获取全局统计信息"""
        with self.lock:
            stats = self.stats.copy()
        
        if stats['total_attempts'] > 0:
            stats['success_rate'] = stats['successful_attempts'] / stats['total_attempts']
        else:
            stats['success_rate'] = 0.0
        
        return stats
    
    def reset_circuit_breaker(self, endpoint_key: str):
        """重置熔断器"""
        if endpoint_key in self.circuit_breakers:
            circuit_breaker = self.circuit_breakers[endpoint_key]
            with circuit_breaker.lock:
                circuit_breaker.state = CircuitState.CLOSED
                circuit_breaker.failure_count = 0
                circuit_breaker.half_open_calls = 0
    
    def print_stats(self):
        """打印统计信息"""
        global_stats = self.get_global_stats()
        
        print("\\n=== 智能重试统计 ===")
        print(f"总尝试次数: {global_stats['total_attempts']}")
        print(f"成功次数: {global_stats['successful_attempts']}")
        print(f"失败次数: {global_stats['failed_attempts']}")
        print(f"重试次数: {global_stats['retries_performed']}")
        print(f"熔断器触发: {global_stats['circuit_breaker_trips']}")
        print(f"成功率: {global_stats['success_rate']:.1%}")
        
        # 打印各端点状态
        if self.circuit_breakers:
            print("\\n端点状态:")
            for endpoint_key in self.circuit_breakers.keys():
                endpoint_stats = self.get_endpoint_stats(endpoint_key)
                print(f"  {endpoint_key}:")
                print(f"    熔断器状态: {endpoint_stats['circuit_breaker_state']}")
                print(f"    失败计数: {endpoint_stats['failure_count']}")
                print(f"    成功率: {endpoint_stats['success_rate']:.1%}")
        
        print("==================\\n")


if __name__ == '__main__':
    # 测试代码
    import requests
    
    # 创建重试管理器
    retry_config = RetryConfig(
        max_attempts=3,
        base_delay=1.0,
        max_delay=10.0,
        failure_threshold=3
    )
    
    retry_manager = SmartRetryManager(retry_config)
    
    # 测试函数
    def test_request(url: str, should_fail: bool = False):
        if should_fail:
            raise requests.exceptions.ConnectionError("Simulated connection error")
        return f"Success: {url}"
    
    # 测试成功情况
    try:
        result = retry_manager.execute_with_retry(
            test_request, 
            "https://example.com", 
            should_fail=False,
            endpoint_key="test_endpoint"
        )
        print(f"Result: {result}")
    except Exception as e:
        print(f"Failed: {e}")
    
    # 测试失败情况
    try:
        result = retry_manager.execute_with_retry(
            test_request, 
            "https://failing.com", 
            should_fail=True,
            endpoint_key="failing_endpoint"
        )
        print(f"Result: {result}")
    except Exception as e:
        print(f"Failed after retries: {e}")
    
    # 打印统计信息
    retry_manager.print_stats()
    
    print("✅ 智能重试管理器测试完成！")