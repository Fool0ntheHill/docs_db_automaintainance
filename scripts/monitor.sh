#!/bin/bash

# TKE 文档同步系统监控脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/monitor.log"
PID_FILE="$PROJECT_DIR/data/tke_sync.pid"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

# 记录日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# 检查服务状态
check_service() {
    # 检查系统服务
    if systemctl is-active --quiet tke-dify-sync 2>/dev/null; then
        log_message "✅ 系统服务运行正常"
        return 0
    fi
    
    # 检查进程
    if pgrep -f "python.*tke_dify_sync.py" > /dev/null; then
        log_message "✅ 进程运行正常"
        return 0
    fi
    
    log_message "❌ 服务已停止"
    return 1
}

# 检查磁盘空间
check_disk_space() {
    USAGE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$USAGE" -gt 80 ]; then
        log_message "⚠️ 磁盘使用率过高: ${USAGE}%"
        return 1
    fi
    return 0
}

# 检查内存使用
check_memory() {
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$MEMORY_USAGE" -gt 90 ]; then
        log_message "⚠️ 内存使用率过高: ${MEMORY_USAGE}%"
        return 1
    fi
    return 0
}

# 检查日志文件大小
check_log_size() {
    if [ -f "$PROJECT_DIR/logs/tke_sync.log" ]; then
        LOG_SIZE=$(stat -f%z "$PROJECT_DIR/logs/tke_sync.log" 2>/dev/null || stat -c%s "$PROJECT_DIR/logs/tke_sync.log" 2>/dev/null)
        if [ "$LOG_SIZE" -gt 104857600 ]; then  # 100MB
            log_message "⚠️ 日志文件过大: $(($LOG_SIZE / 1024 / 1024))MB"
            # 轮转日志文件
            mv "$PROJECT_DIR/logs/tke_sync.log" "$PROJECT_DIR/logs/tke_sync.log.$(date +%Y%m%d_%H%M%S)"
            log_message "📄 日志文件已轮转"
        fi
    fi
}

# 清理旧日志
cleanup_logs() {
    # 删除7天前的日志文件
    find "$PROJECT_DIR/logs" -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    
    # 删除30天前的监控日志
    if [ -f "$LOG_FILE" ]; then
        # 保留最后1000行
        tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# 检查网络连接
check_network() {
    if ! curl -s --max-time 10 https://cloud.tencent.com > /dev/null; then
        log_message "⚠️ 无法访问腾讯云文档站点"
        return 1
    fi
    
    # 检查 Dify API（如果配置文件存在）
    if [ -f "$PROJECT_DIR/.env" ]; then
        DIFY_URL=$(grep "^DIFY_API_BASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
        if [ -n "$DIFY_URL" ] && ! curl -s --max-time 10 "$DIFY_URL" > /dev/null; then
            log_message "⚠️ 无法访问 Dify API: $DIFY_URL"
            return 1
        fi
    fi
    
    return 0
}

# 主监控逻辑
main() {
    local issues=0
    
    # 执行各项检查
    check_service || ((issues++))
    check_disk_space || ((issues++))
    check_memory || ((issues++))
    check_log_size
    check_network || ((issues++))
    cleanup_logs
    
    # 记录监控摘要
    if [ $issues -eq 0 ]; then
        log_message "📊 监控检查完成，系统状态正常"
    else
        log_message "📊 监控检查完成，发现 $issues 个问题"
    fi
    
    # 如果是交互式运行，显示状态
    if [ -t 1 ]; then
        echo "📊 监控检查完成"
        if [ $issues -eq 0 ]; then
            echo "✅ 系统状态正常"
        else
            echo "⚠️ 发现 $issues 个问题，请查看日志：$LOG_FILE"
        fi
    fi
}

# 运行监控
main "$@"