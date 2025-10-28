#!/bin/bash

# TKE 文档同步系统状态检查脚本
# 基于 cron 调度的状态检查，不依赖 systemd

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 显示帮助信息
show_help() {
    echo "TKE 文档同步系统状态检查脚本"
    echo "============================"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -v, --verbose       详细输出模式"
    echo "  -q, --quiet         静默模式，仅显示关键信息"
    echo "  -j, --json          JSON 格式输出"
    echo "  --no-color          禁用颜色输出"
    echo
    echo "示例:"
    echo "  $0                  # 标准状态检查"
    echo "  $0 -v               # 详细状态检查"
    echo "  $0 -j               # JSON 格式输出"
    echo
}

# 日志函数
log_info() {
    if [ "$QUIET" != "true" ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
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

# 检查当前运行的进程
check_running_processes() {
    log_info "检查运行中的进程"
    
    local pids=$(pgrep -f "python.*tke_dify_sync.py" 2>/dev/null || true)
    local process_count=0
    
    if [ -n "$pids" ]; then
        process_count=$(echo "$pids" | wc -l)
        log_success "发现 $process_count 个 TKE 同步进程正在运行"
        
        if [ "$VERBOSE" = "true" ]; then
            echo "📋 进程详情："
            ps -p $pids -o pid,ppid,etime,pcpu,pmem,cmd --no-headers | while read line; do
                echo "  $line"
            done
        fi
        
        # 检查进程运行时间
        local oldest_pid=$(echo "$pids" | head -n1)
        local runtime=$(ps -p $oldest_pid -o etime --no-headers 2>/dev/null | tr -d ' ')
        if [ -n "$runtime" ]; then
            log_info "最长运行时间: $runtime"
        fi
    else
        log_info "当前没有 TKE 同步进程运行（这是正常的，因为使用 cron 调度）"
    fi
    
    return $process_count
}

# 检查 cron 作业配置
check_cron_configuration() {
    log_info "检查 cron 作业配置"
    
    local cron_jobs=$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|tke-dify)" || true)
    
    if [ -n "$cron_jobs" ]; then
        local job_count=$(echo "$cron_jobs" | wc -l)
        log_success "发现 $job_count 个 TKE 相关的 cron 作业"
        
        if [ "$VERBOSE" = "true" ]; then
            echo "📋 cron 作业详情："
            echo "$cron_jobs" | while read job; do
                echo "  📅 $job"
            done
        fi
        
        # 检查 cron 服务状态
        if systemctl is-active --quiet cron 2>/dev/null; then
            log_success "cron 服务正在运行"
        else
            log_error "cron 服务未运行"
        fi
    else
        log_error "未发现 TKE 相关的 cron 作业"
        log_info "请运行部署脚本或迁移工具配置 cron 作业"
    fi
}

# 检查配置文件
check_configuration_files() {
    log_info "检查配置文件"
    
    local config_files=0
    local main_config="$PROJECT_DIR/.env"
    
    # 检查主配置文件
    if [ -f "$main_config" ]; then
        log_success "主配置文件存在: .env"
        ((config_files++))
        
        if [ "$VERBOSE" = "true" ]; then
            # 检查关键配置项（不显示敏感信息）
            local api_key_set=$(grep -q "^DIFY_API_KEY=" "$main_config" && echo "✅" || echo "❌")
            local kb_id_set=$(grep -q "^DIFY_KNOWLEDGE_BASE_ID=" "$main_config" && echo "✅" || echo "❌")
            local api_url_set=$(grep -q "^DIFY_API_BASE_URL=" "$main_config" && echo "✅" || echo "❌")
            
            echo "  配置项检查："
            echo "    API Key: $api_key_set"
            echo "    知识库 ID: $kb_id_set"
            echo "    API URL: $api_url_set"
        fi
    else
        log_error "主配置文件不存在: .env"
    fi
    
    # 检查多知识库配置
    local multi_configs=($(find "$PROJECT_DIR" -maxdepth 1 -name ".env.*" 2>/dev/null || true))
    if [ ${#multi_configs[@]} -gt 0 ]; then
        log_success "发现 ${#multi_configs[@]} 个多知识库配置文件"
        config_files=$((config_files + ${#multi_configs[@]}))
        
        if [ "$VERBOSE" = "true" ]; then
            for config in "${multi_configs[@]}"; do
                echo "  📄 $(basename "$config")"
            done
        fi
    fi
    
    return $config_files
}

# 检查日志文件和最近执行状态
check_logs_and_execution() {
    log_info "检查日志文件和执行状态"
    
    local log_dir="$PROJECT_DIR/logs"
    local log_files=0
    local recent_activity=false
    
    if [ ! -d "$log_dir" ]; then
        log_error "日志目录不存在: $log_dir"
        return 0
    fi
    
    # 统计日志文件
    log_files=$(find "$log_dir" -name "*.log" 2>/dev/null | wc -l)
    log_success "发现 $log_files 个日志文件"
    
    # 检查最近的执行活动
    local recent_logs=$(find "$log_dir" -name "cron*.log" -mtime -1 2>/dev/null)
    if [ -n "$recent_logs" ]; then
        recent_activity=true
        log_success "发现最近24小时内的执行日志"
        
        if [ "$VERBOSE" = "true" ]; then
            echo "📊 最近执行的日志文件："
            for log_file in $recent_logs; do
                local size=$(du -h "$log_file" 2>/dev/null | cut -f1)
                local mtime=$(stat -c %y "$log_file" 2>/dev/null | cut -d'.' -f1)
                echo "  📄 $(basename "$log_file") ($size, 修改时间: $mtime)"
            done
        fi
    else
        log_warning "未发现最近24小时内的执行日志"
    fi
    
    # 分析最新的日志内容
    local latest_log=$(find "$log_dir" -name "cron*.log" -type f -exec ls -t {} + 2>/dev/null | head -n1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        log_info "分析最新日志: $(basename "$latest_log")"
        
        # 检查最后的执行状态
        local last_success=$(grep "\[SUCCESS\]" "$latest_log" 2>/dev/null | tail -n1)
        local last_error=$(grep "\[ERROR\]" "$latest_log" 2>/dev/null | tail -n1)
        local last_start=$(grep "\[START\]" "$latest_log" 2>/dev/null | tail -n1)
        
        if [ -n "$last_success" ]; then
            log_success "最后执行状态: 成功"
            if [ "$VERBOSE" = "true" ]; then
                echo "  📝 $last_success"
            fi
        elif [ -n "$last_error" ]; then
            log_error "最后执行状态: 失败"
            if [ "$VERBOSE" = "true" ]; then
                echo "  📝 $last_error"
            fi
        elif [ -n "$last_start" ]; then
            log_warning "最后执行状态: 可能正在运行或异常终止"
            if [ "$VERBOSE" = "true" ]; then
                echo "  📝 $last_start"
            fi
        else
            log_info "无法确定最后执行状态"
        fi
        
        # 显示最近几行日志
        if [ "$VERBOSE" = "true" ]; then
            echo "📝 最近的日志内容（最后5行）："
            tail -n5 "$latest_log" 2>/dev/null | while read line; do
                echo "  $line"
            done
        fi
    fi
    
    return $([ "$recent_activity" = true ] && echo 1 || echo 0)
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源"
    
    # 检查磁盘空间
    local disk_usage=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        log_success "磁盘空间充足 (已使用 ${disk_usage}%)"
    elif [ "$disk_usage" -lt 90 ]; then
        log_warning "磁盘空间紧张 (已使用 ${disk_usage}%)"
    else
        log_error "磁盘空间不足 (已使用 ${disk_usage}%)"
    fi
    
    # 检查内存使用
    local mem_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    log_info "内存使用率: ${mem_info}%"
    
    # 检查网络连接
    if curl -s --connect-timeout 5 https://cloud.tencent.com >/dev/null 2>&1; then
        log_success "网络连接正常"
    else
        log_warning "网络连接可能有问题"
    fi
    
    if [ "$VERBOSE" = "true" ]; then
        echo "💾 磁盘使用详情："
        df -h "$PROJECT_DIR" | while read line; do
            echo "  $line"
        done
        
        echo "🧠 内存使用详情："
        free -h | while read line; do
            echo "  $line"
        done
    fi
}

# 检查项目文件完整性
check_project_integrity() {
    log_info "检查项目文件完整性"
    
    local required_files=(
        "$PROJECT_DIR/tke_dify_sync.py"
        "$PROJECT_DIR/requirements.txt"
        "$PROJECT_DIR/venv/bin/python"
    )
    
    local missing_files=0
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            if [ "$VERBOSE" = "true" ]; then
                log_success "文件存在: $(basename "$file")"
            fi
        else
            log_error "文件缺失: $(basename "$file")"
            ((missing_files++))
        fi
    done
    
    if [ $missing_files -eq 0 ]; then
        log_success "所有关键文件都存在"
    else
        log_error "发现 $missing_files 个缺失文件"
    fi
    
    # 检查 Python 环境
    if [ -f "$PROJECT_DIR/venv/bin/python" ]; then
        local python_version=$("$PROJECT_DIR/venv/bin/python" --version 2>&1)
        log_success "Python 环境: $python_version"
    else
        log_error "Python 虚拟环境不存在"
    fi
    
    return $missing_files
}

# 生成状态摘要
generate_status_summary() {
    local process_count="$1"
    local config_count="$2"
    local recent_activity="$3"
    local missing_files="$4"
    
    echo
    echo "📋 状态摘要"
    echo "==========="
    
    # 总体健康状态
    local health_score=0
    local max_score=5
    
    # cron 配置检查
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync"; then
        log_success "✅ cron 作业已配置"
        ((health_score++))
    else
        log_error "❌ cron 作业未配置"
    fi
    
    # 配置文件检查
    if [ $config_count -gt 0 ]; then
        log_success "✅ 配置文件完整 ($config_count 个)"
        ((health_score++))
    else
        log_error "❌ 配置文件缺失"
    fi
    
    # 最近活动检查
    if [ $recent_activity -eq 1 ]; then
        log_success "✅ 最近有执行活动"
        ((health_score++))
    else
        log_warning "⚠️ 最近无执行活动"
    fi
    
    # 文件完整性检查
    if [ $missing_files -eq 0 ]; then
        log_success "✅ 项目文件完整"
        ((health_score++))
    else
        log_error "❌ 项目文件不完整"
    fi
    
    # 系统资源检查
    local disk_usage=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        log_success "✅ 系统资源充足"
        ((health_score++))
    else
        log_error "❌ 系统资源不足"
    fi
    
    # 计算健康度
    local health_percentage=$((health_score * 100 / max_score))
    
    echo
    if [ $health_percentage -ge 80 ]; then
        echo -e "🎉 系统状态: ${GREEN}健康 (${health_percentage}%)${NC}"
    elif [ $health_percentage -ge 60 ]; then
        echo -e "⚠️ 系统状态: ${YELLOW}需要关注 (${health_percentage}%)${NC}"
    else
        echo -e "🚨 系统状态: ${RED}需要修复 (${health_percentage}%)${NC}"
    fi
    
    echo
    echo "🔧 管理命令："
    echo "  手动执行: cd $PROJECT_DIR && ./scripts/start.sh"
    echo "  查看日志: tail -f $PROJECT_DIR/logs/cron.log"
    echo "  健康检查: ./scripts/health_check.sh"
    echo "  日志分析: ./scripts/log_analyzer.sh"
    echo "  迁移工具: ./scripts/migrate_to_cron.sh --check-only"
}

# 生成 JSON 输出
generate_json_output() {
    local process_count="$1"
    local config_count="$2"
    local recent_activity="$3"
    local missing_files="$4"
    
    local cron_configured=$(crontab -l 2>/dev/null | grep -q "tke_dify_sync" && echo "true" || echo "false")
    local disk_usage=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    local health_score=0
    
    # 计算健康分数
    [ "$cron_configured" = "true" ] && ((health_score++))
    [ $config_count -gt 0 ] && ((health_score++))
    [ $recent_activity -eq 1 ] && ((health_score++))
    [ $missing_files -eq 0 ] && ((health_score++))
    [ $disk_usage -lt 90 ] && ((health_score++))
    
    local health_percentage=$((health_score * 100 / 5))
    
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "system_status": {
    "health_percentage": $health_percentage,
    "health_score": "$health_score/5",
    "overall_status": "$([ $health_percentage -ge 80 ] && echo "healthy" || ([ $health_percentage -ge 60 ] && echo "warning" || echo "critical"))"
  },
  "processes": {
    "running_count": $process_count,
    "expected_running": false,
    "note": "Processes run via cron scheduling"
  },
  "cron_configuration": {
    "configured": $cron_configured,
    "service_active": $(systemctl is-active --quiet cron 2>/dev/null && echo "true" || echo "false")
  },
  "configuration": {
    "files_count": $config_count,
    "main_config_exists": $([ -f "$PROJECT_DIR/.env" ] && echo "true" || echo "false"),
    "multi_kb_configs": $(find "$PROJECT_DIR" -maxdepth 1 -name ".env.*" 2>/dev/null | wc -l)
  },
  "logs": {
    "recent_activity": $([ $recent_activity -eq 1 ] && echo "true" || echo "false"),
    "log_files_count": $(find "$PROJECT_DIR/logs" -name "*.log" 2>/dev/null | wc -l)
  },
  "system_resources": {
    "disk_usage_percent": $disk_usage,
    "disk_status": "$([ $disk_usage -lt 80 ] && echo "good" || ([ $disk_usage -lt 90 ] && echo "warning" || echo "critical"))"
  },
  "project_integrity": {
    "missing_files": $missing_files,
    "python_env_exists": $([ -f "$PROJECT_DIR/venv/bin/python" ] && echo "true" || echo "false")
  }
}
EOF
}

# 主函数
main() {
    local verbose=false
    local quiet=false
    local json_output=false
    local no_color=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -j|--json)
                json_output=true
                shift
                ;;
            --no-color)
                no_color=true
                shift
                ;;
            -*)
                echo "未知选项: $1" >&2
                show_help
                exit 1
                ;;
            *)
                echo "未知参数: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置全局变量
    VERBOSE=$verbose
    QUIET=$quiet
    
    # 禁用颜色（如果需要）
    if [ "$no_color" = true ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        CYAN=''
        NC=''
    fi
    
    if [ "$json_output" != "true" ]; then
        echo "📊 TKE 文档同步系统状态检查"
        echo "============================"
        echo "基于 cron 调度的状态检查（不依赖 systemd）"
        echo
    fi
    
    # 执行各项检查
    check_running_processes
    local process_count=$?
    
    check_cron_configuration
    
    check_configuration_files
    local config_count=$?
    
    check_logs_and_execution
    local recent_activity=$?
    
    check_system_resources
    
    check_project_integrity
    local missing_files=$?
    
    # 生成输出
    if [ "$json_output" = "true" ]; then
        generate_json_output "$process_count" "$config_count" "$recent_activity" "$missing_files"
    else
        generate_status_summary "$process_count" "$config_count" "$recent_activity" "$missing_files"
    fi
}

# 运行主函数
main "$@"