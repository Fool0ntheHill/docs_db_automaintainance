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

# 检查 cron 作业和进程状态（不依赖 systemd）
check_service() {
    local issues=0
    
    # 检查 cron 作业是否配置
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync"; then
        log_message "✅ cron 作业已配置"
    else
        log_message "⚠️ cron 作业未配置"
        ((issues++))
    fi
    
    # 检查是否有进程正在运行（可能是手动执行或 cron 触发）
    if pgrep -f "python.*tke_dify_sync.py" > /dev/null; then
        log_message "ℹ️ 同步进程正在运行"
    else
        log_message "ℹ️ 当前无同步进程运行（正常，等待下次 cron 调度）"
    fi
    
    # 检查最近的执行日志
    if [ -f "$PROJECT_DIR/logs/tke_sync.log" ]; then
        local last_log_time=$(stat -c %Y "$PROJECT_DIR/logs/tke_sync.log" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_log_time))
        
        if [ $time_diff -lt 86400 ]; then  # 24小时内有日志更新
            log_message "✅ 最近24小时内有同步活动"
        else
            log_message "⚠️ 超过24小时未检测到同步活动"
            ((issues++))
        fi
    else
        log_message "⚠️ 未找到同步日志文件"
        ((issues++))
    fi
    
    return $issues
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

# 检查网络连接（独立于 systemd 服务）
check_network() {
    local issues=0
    
    # 检查腾讯云文档站点连接
    if curl -s --max-time 10 https://cloud.tencent.com > /dev/null; then
        log_message "✅ 腾讯云文档站点连接正常"
    else
        log_message "⚠️ 无法访问腾讯云文档站点"
        ((issues++))
    fi
    
    # 检查 Dify API 连接（如果配置文件存在）
    if [ -f "$PROJECT_DIR/.env" ]; then
        local dify_url=$(grep "^DIFY_API_BASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$dify_url" ]; then
            if curl -s --max-time 10 "$dify_url" > /dev/null; then
                log_message "✅ Dify API 连接正常: $dify_url"
            else
                log_message "⚠️ 无法访问 Dify API: $dify_url"
                ((issues++))
            fi
        else
            log_message "⚠️ 未配置 Dify API URL"
            ((issues++))
        fi
    else
        log_message "⚠️ 配置文件不存在: $PROJECT_DIR/.env"
        ((issues++))
    fi
    
    return $issues
}

# 检查 cron 作业执行历史
check_cron_execution() {
    local issues=0
    
    # 检查 cron 日志文件
    local cron_logs=(
        "$PROJECT_DIR/logs/cron.log"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log"
    )
    
    local found_recent_execution=false
    
    for cron_log in "${cron_logs[@]}"; do
        if [ -f "$cron_log" ]; then
            # 检查最近24小时内是否有执行记录
            local recent_entries=$(find "$cron_log" -mtime -1 2>/dev/null || true)
            if [ -n "$recent_entries" ]; then
                log_message "✅ 发现最近的 cron 执行记录: $(basename "$cron_log")"
                found_recent_execution=true
            fi
        fi
    done
    
    if [ "$found_recent_execution" = false ]; then
        log_message "⚠️ 未发现最近24小时内的 cron 执行记录"
        ((issues++))
    fi
    
    return $issues
}

# 主监控逻辑
main() {
    local issues=0
    
    # 执行各项检查
    check_service
    issues=$((issues + $?))
    
    check_disk_space
    issues=$((issues + $?))
    
    check_memory
    issues=$((issues + $?))
    
    check_log_size
    
    check_network
    issues=$((issues + $?))
    
    check_cron_execution
    issues=$((issues + $?))
    
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