#!/bin/bash

# TKE 文档同步系统 - cron 执行状态监控脚本
# 专门监控 cron 作业的执行状态和结果

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MONITOR_LOG="$PROJECT_DIR/logs/cron_monitor.log"
ALERT_LOG="$PROJECT_DIR/logs/cron_alerts.log"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$MONITOR_LOG"
}

log_alert() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$ALERT_LOG"
    log_message "ALERT: $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 cron 作业执行状态
check_cron_execution_status() {
    echo "🕐 检查 cron 作业执行状态"
    echo "========================="
    
    local issues=0
    local current_time=$(date +%s)
    
    # 定义需要检查的日志文件
    local log_files=(
        "$PROJECT_DIR/logs/cron.log:单知识库同步"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log:TKE基础文档库"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log:TKE知识库"
    )
    
    for log_entry in "${log_files[@]}"; do
        local log_file="${log_entry%%:*}"
        local log_desc="${log_entry##*:}"
        
        if [ -f "$log_file" ]; then
            log_info "检查 $log_desc 日志: $(basename "$log_file")"
            
            # 检查文件最后修改时间
            local last_modified=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
            local time_diff=$((current_time - last_modified))
            local hours_ago=$((time_diff / 3600))
            
            if [ $time_diff -lt 86400 ]; then  # 24小时内
                log_success "  ✅ 最近24小时内有执行记录（${hours_ago}小时前）"
                
                # 检查最后几行是否有错误
                local recent_errors=$(tail -20 "$log_file" | grep -i "error\|exception\|failed\|❌" | wc -l)
                if [ $recent_errors -gt 0 ]; then
                    log_warning "  ⚠️ 发现 $recent_errors 个错误记录"
                    log_alert "$log_desc 日志中发现 $recent_errors 个错误"
                    ((issues++))
                else
                    log_success "  ✅ 未发现错误记录"
                fi
                
                # 检查成功执行标记
                local success_count=$(tail -50 "$log_file" | grep -i "success\|完成\|✅" | wc -l)
                if [ $success_count -gt 0 ]; then
                    log_success "  ✅ 发现 $success_count 个成功执行标记"
                else
                    log_warning "  ⚠️ 未发现明确的成功执行标记"
                    ((issues++))
                fi
                
            elif [ $time_diff -lt 172800 ]; then  # 48小时内
                log_warning "  ⚠️ 超过24小时未执行（${hours_ago}小时前）"
                log_alert "$log_desc 超过24小时未执行"
                ((issues++))
            else
                log_error "  ❌ 超过48小时未执行（${hours_ago}小时前）"
                log_alert "$log_desc 超过48小时未执行，可能存在严重问题"
                ((issues++))
            fi
            
        else
            log_warning "日志文件不存在: $log_file"
        fi
        
        echo
    done
    
    return $issues
}

# 分析 cron 作业执行模式
analyze_execution_patterns() {
    echo "📊 分析 cron 作业执行模式"
    echo "========================"
    
    local log_files=(
        "$PROJECT_DIR/logs/cron.log"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            local log_name=$(basename "$log_file")
            log_info "分析 $log_name 执行模式"
            
            # 统计最近7天的执行次数
            local recent_executions=$(find "$log_file" -mtime -7 -exec grep -l "python.*tke_dify_sync.py" {} \; 2>/dev/null | wc -l)
            if [ $recent_executions -gt 0 ]; then
                log_success "  ✅ 最近7天有执行记录"
            else
                log_warning "  ⚠️ 最近7天无执行记录"
            fi
            
            # 检查文件大小
            local file_size=$(du -h "$log_file" 2>/dev/null | cut -f1)
            log_info "  📄 日志文件大小: $file_size"
            
            # 检查是否需要轮转
            local file_size_bytes=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            if [ $file_size_bytes -gt 10485760 ]; then  # 10MB
                log_warning "  ⚠️ 日志文件过大，建议轮转"
                log_alert "$log_name 文件过大（$file_size），建议配置日志轮转"
            fi
            
        fi
    done
}

# 检查 cron 作业配置
check_cron_configuration() {
    echo "⚙️ 检查 cron 作业配置"
    echo "===================="
    
    local issues=0
    
    # 检查是否有 TKE 相关的 cron 作业
    local tke_cron_jobs=$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|tke-dify)" | grep -v "^#" || true)
    
    if [ -z "$tke_cron_jobs" ]; then
        log_error "❌ 未找到 TKE 相关的 cron 作业"
        log_alert "未配置 TKE 同步的 cron 作业"
        ((issues++))
    else
        log_success "✅ 找到 TKE 相关的 cron 作业"
        
        local job_count=0
        echo "$tke_cron_jobs" | while IFS= read -r job; do
            if [ -n "$job" ]; then
                ((job_count++))
                log_info "  📋 作业 $job_count: $job"
                
                # 检查作业格式
                if [[ $job =~ ^[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]].+ ]]; then
                    log_success "    ✅ 时间格式正确"
                else
                    log_error "    ❌ 时间格式错误"
                    log_alert "cron 作业时间格式错误: $job"
                fi
                
                # 检查路径
                if [[ $job == *"$PROJECT_DIR"* ]]; then
                    log_success "    ✅ 路径正确"
                else
                    log_warning "    ⚠️ 路径可能不正确"
                fi
                
                # 检查日志重定向
                if [[ $job == *">>"* ]]; then
                    log_success "    ✅ 包含日志重定向"
                else
                    log_warning "    ⚠️ 缺少日志重定向"
                fi
            fi
        done
    fi
    
    # 检查监控任务
    local monitor_cron=$(crontab -l 2>/dev/null | grep "monitor.sh" || true)
    if [ -n "$monitor_cron" ]; then
        log_success "✅ 找到监控 cron 作业"
    else
        log_warning "⚠️ 未找到监控 cron 作业"
        ((issues++))
    fi
    
    return $issues
}

# 检查系统资源和健康状态
check_system_health() {
    echo "🏥 检查系统健康状态"
    echo "=================="
    
    local issues=0
    
    # 检查磁盘空间
    local disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_error "❌ 磁盘使用率过高: ${disk_usage}%"
        log_alert "磁盘使用率过高: ${disk_usage}%"
        ((issues++))
    elif [ "$disk_usage" -gt 80 ]; then
        log_warning "⚠️ 磁盘使用率较高: ${disk_usage}%"
    else
        log_success "✅ 磁盘使用率正常: ${disk_usage}%"
    fi
    
    # 检查内存使用
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -gt 90 ]; then
        log_error "❌ 内存使用率过高: ${memory_usage}%"
        log_alert "内存使用率过高: ${memory_usage}%"
        ((issues++))
    elif [ "$memory_usage" -gt 80 ]; then
        log_warning "⚠️ 内存使用率较高: ${memory_usage}%"
    else
        log_success "✅ 内存使用率正常: ${memory_usage}%"
    fi
    
    # 检查负载平均值
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_ratio=$(echo "$load_avg $cpu_cores" | awk '{printf "%.2f", $1/$2}')
    
    if (( $(echo "$load_ratio > 2.0" | bc -l) )); then
        log_error "❌ 系统负载过高: $load_avg (${load_ratio}x CPU核心数)"
        log_alert "系统负载过高: $load_avg"
        ((issues++))
    elif (( $(echo "$load_ratio > 1.0" | bc -l) )); then
        log_warning "⚠️ 系统负载较高: $load_avg (${load_ratio}x CPU核心数)"
    else
        log_success "✅ 系统负载正常: $load_avg"
    fi
    
    return $issues
}

# 生成监控报告
generate_monitoring_report() {
    local report_file="$PROJECT_DIR/logs/cron_monitoring_report_$(date +%Y%m%d_%H%M%S).md"
    
    log_info "生成监控报告: $report_file"
    
    cat > "$report_file" << EOF
# TKE 文档同步系统 - cron 监控报告

生成时间: $(date)
监控用户: $(whoami)
项目目录: $PROJECT_DIR

## 监控摘要

### cron 作业配置状态
\`\`\`
$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|monitor\.sh)" || echo "无相关 cron 作业")
\`\`\`

### 最近执行状态
EOF

    # 添加日志文件状态
    local log_files=(
        "$PROJECT_DIR/logs/cron.log:单知识库同步"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log:TKE基础文档库"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log:TKE知识库"
    )
    
    for log_entry in "${log_files[@]}"; do
        local log_file="${log_entry%%:*}"
        local log_desc="${log_entry##*:}"
        
        echo "#### $log_desc" >> "$report_file"
        if [ -f "$log_file" ]; then
            local last_modified=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local hours_ago=$(( (current_time - last_modified) / 3600 ))
            
            echo "- 日志文件: $(basename "$log_file")" >> "$report_file"
            echo "- 最后更新: ${hours_ago}小时前" >> "$report_file"
            echo "- 文件大小: $(du -h "$log_file" 2>/dev/null | cut -f1)" >> "$report_file"
            
            # 添加最后几行日志
            echo "- 最近日志:" >> "$report_file"
            echo "\`\`\`" >> "$report_file"
            tail -5 "$log_file" >> "$report_file" 2>/dev/null || echo "无法读取日志内容" >> "$report_file"
            echo "\`\`\`" >> "$report_file"
        else
            echo "- 状态: 日志文件不存在" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # 添加系统状态
    echo "### 系统状态" >> "$report_file"
    echo "- 磁盘使用率: $(df "$PROJECT_DIR" | awk 'NR==2 {print $5}')" >> "$report_file"
    echo "- 内存使用率: $(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')" >> "$report_file"
    echo "- 系统负载: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')" >> "$report_file"
    
    # 添加告警信息
    if [ -f "$ALERT_LOG" ] && [ -s "$ALERT_LOG" ]; then
        echo "" >> "$report_file"
        echo "### 最近告警" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
        tail -10 "$ALERT_LOG" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
    fi
    
    log_success "监控报告已生成: $report_file"
}

# 自动日志轮转
rotate_logs() {
    echo "🔄 检查日志轮转"
    echo "=============="
    
    local rotated_count=0
    
    # 检查需要轮转的日志文件
    local log_files=(
        "$PROJECT_DIR/logs/cron.log"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log"
        "$MONITOR_LOG"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            local file_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
            
            # 如果文件大于10MB，进行轮转
            if [ $file_size -gt 10485760 ]; then
                local rotated_name="${log_file}.$(date +%Y%m%d_%H%M%S)"
                mv "$log_file" "$rotated_name"
                touch "$log_file"
                
                # 压缩旧日志
                gzip "$rotated_name" 2>/dev/null || true
                
                log_success "轮转日志文件: $(basename "$log_file") -> $(basename "$rotated_name").gz"
                log_message "轮转日志文件: $log_file"
                ((rotated_count++))
            fi
        fi
    done
    
    if [ $rotated_count -eq 0 ]; then
        log_info "无需轮转日志文件"
    else
        log_success "轮转了 $rotated_count 个日志文件"
    fi
    
    # 清理超过30天的压缩日志
    find "$PROJECT_DIR/logs" -name "*.gz" -mtime +30 -delete 2>/dev/null || true
}

# 主函数
main() {
    echo "🔍 TKE 文档同步系统 - cron 监控"
    echo "================================"
    
    local total_issues=0
    
    # 记录监控开始
    log_message "开始 cron 监控检查"
    
    # 执行各项检查
    check_cron_execution_status
    total_issues=$((total_issues + $?))
    
    echo
    analyze_execution_patterns
    
    echo
    check_cron_configuration
    total_issues=$((total_issues + $?))
    
    echo
    check_system_health
    total_issues=$((total_issues + $?))
    
    echo
    rotate_logs
    
    echo
    generate_monitoring_report
    
    # 记录监控结果
    if [ $total_issues -eq 0 ]; then
        log_message "监控检查完成，系统状态正常"
        log_success "✅ 监控检查完成，系统状态正常"
    else
        log_message "监控检查完成，发现 $total_issues 个问题"
        log_warning "⚠️ 监控检查完成，发现 $total_issues 个问题"
        log_alert "监控检查发现 $total_issues 个问题，请查看详细报告"
    fi
    
    # 如果是交互式运行，显示摘要
    if [ -t 1 ]; then
        echo
        echo "📊 监控摘要"
        echo "=========="
        echo "发现问题: $total_issues 个"
        echo "监控日志: $MONITOR_LOG"
        echo "告警日志: $ALERT_LOG"
        
        if [ $total_issues -gt 0 ]; then
            echo "建议查看详细的监控报告和日志文件"
        fi
    fi
    
    exit $total_issues
}

# 运行主函数
main "$@"