#!/bin/bash

# TKE 文档同步系统 - 日志分析工具
# 分析 cron 执行日志，提供详细的执行统计和错误报告

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ANALYSIS_LOG="$PROJECT_DIR/logs/log_analysis.log"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$ANALYSIS_LOG"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_message "SUCCESS: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

# 显示帮助信息
show_help() {
    echo "TKE 文档同步系统 - 日志分析工具"
    echo "==============================="
    echo
    echo "用法: $0 [选项] [日志文件...]"
    echo
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -d, --days N        分析最近 N 天的日志（默认：7）"
    echo "  -s, --summary       仅显示摘要信息"
    echo "  -e, --errors        仅显示错误信息"
    echo "  -t, --timeline      显示时间线视图"
    echo "  -r, --report        生成详细报告"
    echo "  -f, --format TYPE   输出格式：text, json, html（默认：text）"
    echo "  --no-color          禁用颜色输出"
    echo
    echo "示例:"
    echo "  $0                              # 分析所有日志文件"
    echo "  $0 -d 3                         # 分析最近3天的日志"
    echo "  $0 -s                           # 仅显示摘要"
    echo "  $0 -e                           # 仅显示错误"
    echo "  $0 -r -f html                   # 生成HTML报告"
    echo "  $0 logs/cron.log                # 分析指定日志文件"
    echo
}

# 查找日志文件
find_log_files() {
    local days="$1"
    local specified_files=("${@:2}")
    
    if [ ${#specified_files[@]} -gt 0 ]; then
        # 使用指定的文件
        for file in "${specified_files[@]}"; do
            if [ -f "$file" ]; then
                echo "$file"
            elif [ -f "$PROJECT_DIR/$file" ]; then
                echo "$PROJECT_DIR/$file"
            else
                log_warning "日志文件不存在: $file"
            fi
        done
    else
        # 自动查找日志文件
        find "$PROJECT_DIR/logs" -name "cron*.log" -mtime -"$days" 2>/dev/null | sort
    fi
}

# 解析日志条目
parse_log_entry() {
    local line="$1"
    local timestamp=""
    local level=""
    local message=""
    local kb_name=""
    
    # 提取时间戳
    if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
        timestamp="${BASH_REMATCH[1]}"
    fi
    
    # 提取日志级别
    if [[ "$line" =~ \\[(START|SUCCESS|ERROR|WARNING|INFO)\\] ]]; then
        level="${BASH_REMATCH[1]}"
    fi
    
    # 提取知识库名称
    if [[ "$line" =~ (tke_docs_base|tke_knowledge_base|production|development|staging) ]]; then
        kb_name="${BASH_REMATCH[1]}"
    fi
    
    # 提取消息内容
    if [[ "$line" =~ \\]\ (.+)$ ]]; then
        message="${BASH_REMATCH[1]}"
    else
        message="$line"
    fi
    
    echo "$timestamp|$level|$kb_name|$message"
}

# 分析日志统计
analyze_log_statistics() {
    local log_files=("$@")
    
    echo "📊 日志统计分析"
    echo "==============="
    
    local total_entries=0
    local start_count=0
    local success_count=0
    local error_count=0
    local warning_count=0
    local kb_stats=()
    
    declare -A kb_success_count
    declare -A kb_error_count
    declare -A kb_last_run
    
    for log_file in "${log_files[@]}"; do
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        log_info "分析文件: $(basename "$log_file")"
        
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                continue
            fi
            
            ((total_entries++))\n            \n            local parsed=$(parse_log_entry "$line")
            IFS='|' read -r timestamp level kb_name message <<< "$parsed"
            
            case "$level" in
                "START")
                    ((start_count++))
                    if [ -n "$kb_name" ]; then
                        kb_last_run["$kb_name"]="$timestamp"
                    fi
                    ;;\n                "SUCCESS")
                    ((success_count++))
                    if [ -n "$kb_name" ]; then
                        ((kb_success_count["$kb_name"]++))\n                    fi
                    ;;\n                "ERROR")
                    ((error_count++))
                    if [ -n "$kb_name" ]; then
                        ((kb_error_count["$kb_name"]++))\n                    fi
                    ;;\n                "WARNING")
                    ((warning_count++))
                    ;;\n            esac
        done < "$log_file"
    done
    
    # 显示总体统计
    echo
    echo "📈 总体统计"
    echo "----------"
    echo "  总日志条目: $total_entries"
    echo "  开始执行: $start_count"
    echo "  成功完成: $success_count"
    echo "  执行错误: $error_count"
    echo "  警告信息: $warning_count"
    
    # 计算成功率
    if [ $start_count -gt 0 ]; then
        local success_rate=$((success_count * 100 / start_count))
        if [ $success_rate -ge 95 ]; then
            echo -e "  成功率: ${GREEN}${success_rate}%${NC}"
        elif [ $success_rate -ge 80 ]; then
            echo -e "  成功率: ${YELLOW}${success_rate}%${NC}"
        else
            echo -e "  成功率: ${RED}${success_rate}%${NC}"
        fi
    fi
    
    # 显示知识库统计
    if [ ${#kb_success_count[@]} -gt 0 ] || [ ${#kb_error_count[@]} -gt 0 ]; then
        echo
        echo "📚 知识库统计"
        echo "------------"
        
        local all_kbs=()\n        for kb in "${!kb_success_count[@]}" "${!kb_error_count[@]}"; do
            if [[ ! " ${all_kbs[@]} " =~ " ${kb} " ]]; then
                all_kbs+=("$kb")
            fi
        done
        
        for kb in "${all_kbs[@]}"; do
            local kb_success=${kb_success_count["$kb"]:-0}
            local kb_error=${kb_error_count["$kb"]:-0}
            local kb_total=$((kb_success + kb_error))
            local kb_rate=0
            
            if [ $kb_total -gt 0 ]; then
                kb_rate=$((kb_success * 100 / kb_total))
            fi
            
            echo "  $kb:"
            echo "    成功: $kb_success, 错误: $kb_error"
            if [ $kb_rate -ge 95 ]; then
                echo -e "    成功率: ${GREEN}${kb_rate}%${NC}"
            elif [ $kb_rate -ge 80 ]; then
                echo -e "    成功率: ${YELLOW}${kb_rate}%${NC}"
            else
                echo -e "    成功率: ${RED}${kb_rate}%${NC}"
            fi
            
            if [ -n "${kb_last_run["$kb"]}" ]; then
                echo "    最后运行: ${kb_last_run["$kb"]}"
            fi
            echo
        done
    fi
}

# 分析错误信息
analyze_errors() {
    local log_files=("$@")
    
    echo "🚨 错误分析"
    echo "==========="
    
    local error_found=false
    declare -A error_patterns
    declare -A error_counts
    
    for log_file in "${log_files[@]}"; do
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        while IFS= read -r line; do
            if [[ "$line" =~ \\[ERROR\\] ]]; then
                error_found=true
                
                local parsed=$(parse_log_entry "$line")
                IFS='|' read -r timestamp level kb_name message <<< "$parsed"
                
                echo -e "${RED}[$timestamp]${NC} ${kb_name:+[$kb_name]} $message"
                
                # 统计错误模式
                local error_key=""
                if [[ "$message" =~ (连接|网络|超时) ]]; then
                    error_key="网络连接问题"
                elif [[ "$message" =~ (权限|认证|授权) ]]; then
                    error_key="权限认证问题"
                elif [[ "$message" =~ (配置|参数) ]]; then
                    error_key="配置参数问题"
                elif [[ "$message" =~ (文件|路径) ]]; then
                    error_key="文件路径问题"
                else
                    error_key="其他错误"
                fi
                
                ((error_counts["$error_key"]++))\n            fi
        done < "$log_file"
    done
    
    if [ "$error_found" = false ]; then
        echo -e "${GREEN}✅ 未发现错误信息${NC}"
    else
        echo
        echo "📊 错误分类统计"
        echo "--------------"
        for error_type in "${!error_counts[@]}"; do
            echo "  $error_type: ${error_counts["$error_type"]} 次"
        done
    fi
    
    echo
}

# 生成时间线视图
generate_timeline() {
    local log_files=("$@")
    
    echo "⏰ 执行时间线"
    echo "============="
    
    local timeline_entries=()
    
    for log_file in "${log_files[@]}"; do
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        while IFS= read -r line; do
            if [[ "$line" =~ \\[(START|SUCCESS|ERROR)\\] ]]; then
                local parsed=$(parse_log_entry "$line")
                IFS='|' read -r timestamp level kb_name message <<< "$parsed"
                
                if [ -n "$timestamp" ]; then
                    timeline_entries+=("$timestamp|$level|$kb_name|$message")
                fi
            fi
        done < "$log_file"
    done
    
    # 排序时间线条目
    IFS=$'\n' timeline_entries=($(sort <<< "${timeline_entries[*]}"))
    unset IFS
    
    # 显示时间线
    local current_date=""
    for entry in "${timeline_entries[@]}"; do
        IFS='|' read -r timestamp level kb_name message <<< "$entry"
        
        local entry_date=$(echo "$timestamp" | cut -d' ' -f1)
        if [ "$entry_date" != "$current_date" ]; then
            echo
            echo -e "${CYAN}📅 $entry_date${NC}"
            echo "$(printf '%.0s-' {1..50})"
            current_date="$entry_date"
        fi
        
        local time_only=$(echo "$timestamp" | cut -d' ' -f2)
        local status_icon=""
        local color=""
        
        case "$level" in
            "START")
                status_icon="🚀"
                color="$BLUE"
                ;;\n            "SUCCESS")
                status_icon="✅"
                color="$GREEN"
                ;;\n            "ERROR")
                status_icon="❌"
                color="$RED"
                ;;\n        esac
        
        echo -e "$time_only $status_icon ${color}[$level]${NC} ${kb_name:+[$kb_name]} $message"
    done
    
    echo
}

# 生成摘要报告
generate_summary() {
    local log_files=("$@")
    
    echo "📋 执行摘要"
    echo "==========="
    
    # 获取最新和最旧的日志时间
    local oldest_entry=""
    local newest_entry=""
    local total_runs=0
    local successful_runs=0
    local failed_runs=0
    
    for log_file in "${log_files[@]}"; do
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        while IFS= read -r line; do
            if [[ "$line" =~ \\[(START|SUCCESS|ERROR)\\] ]]; then
                local parsed=$(parse_log_entry "$line")
                IFS='|' read -r timestamp level kb_name message <<< "$parsed"
                
                if [ -n "$timestamp" ]; then
                    if [ -z "$oldest_entry" ] || [[ "$timestamp" < "$oldest_entry" ]]; then
                        oldest_entry="$timestamp"
                    fi
                    if [ -z "$newest_entry" ] || [[ "$timestamp" > "$newest_entry" ]]; then
                        newest_entry="$timestamp"
                    fi
                fi
                
                case "$level" in
                    "START")
                        ((total_runs++))
                        ;;\n                    "SUCCESS")
                        ((successful_runs++))
                        ;;\n                    "ERROR")
                        ((failed_runs++))
                        ;;\n                esac
            fi
        done < "$log_file"
    done
    
    echo "  分析时间范围: $oldest_entry 至 $newest_entry"
    echo "  总执行次数: $total_runs"
    echo "  成功次数: $successful_runs"
    echo "  失败次数: $failed_runs"
    
    if [ $total_runs -gt 0 ]; then
        local success_rate=$((successful_runs * 100 / total_runs))
        if [ $success_rate -ge 95 ]; then
            echo -e "  整体状态: ${GREEN}优秀 (${success_rate}%)${NC}"
        elif [ $success_rate -ge 80 ]; then
            echo -e "  整体状态: ${YELLOW}良好 (${success_rate}%)${NC}"
        else
            echo -e "  整体状态: ${RED}需要关注 (${success_rate}%)${NC}"
        fi
    fi
    
    # 检查最近的执行状态
    if [ -n "$newest_entry" ]; then
        local hours_since_last=$(( ($(date +%s) - $(date -d "$newest_entry" +%s)) / 3600 ))
        if [ $hours_since_last -gt 25 ]; then
            echo -e "  ${RED}⚠️ 警告: 最后执行时间超过 $hours_since_last 小时前${NC}"
        else
            echo -e "  ${GREEN}✅ 最近执行正常 ($hours_since_last 小时前)${NC}"
        fi
    fi
    
    echo
}

# 生成 HTML 报告
generate_html_report() {
    local log_files=("$@")
    local report_file="$PROJECT_DIR/logs/log_analysis_report_$(date +%Y%m%d_%H%M%S).html"
    
    log_info "生成 HTML 报告: $report_file"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TKE 文档同步系统 - 日志分析报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007acc; }
        .stat-number { font-size: 2em; font-weight: bold; color: #007acc; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        .timeline { background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .timeline-entry { margin: 5px 0; padding: 5px; border-left: 3px solid #ddd; padding-left: 10px; }
        .timeline-entry.success { border-left-color: #28a745; }
        .timeline-entry.error { border-left-color: #dc3545; }
        .timeline-entry.start { border-left-color: #007acc; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 TKE 文档同步系统 - 日志分析报告</h1>
        <p><strong>生成时间:</strong> $(date)</p>
        <p><strong>分析文件:</strong> $(echo "${log_files[@]}" | sed 's|'$PROJECT_DIR'/||g')</p>
EOF
    
    # 添加统计数据（这里需要重新计算，简化版本）
    cat >> "$report_file" << 'EOF'
        
        <h2>📊 执行统计</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number success">--</div>
                <div>成功执行</div>
            </div>
            <div class="stat-card">
                <div class="stat-number error">--</div>
                <div>执行失败</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">--%</div>
                <div>成功率</div>
            </div>
        </div>
        
        <h2>⏰ 最近执行记录</h2>
        <div class="timeline">
            <p>请运行文本版本获取详细时间线信息</p>
        </div>
        
        <div class="footer">
            <p>报告由 TKE 文档同步系统日志分析工具生成</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log_success "HTML 报告已生成: $report_file"
    echo "  在浏览器中打开: file://$report_file"
}

# 生成 JSON 报告
generate_json_report() {
    local log_files=("$@")
    local report_file="$PROJECT_DIR/logs/log_analysis_report_$(date +%Y%m%d_%H%M%S).json"
    
    log_info "生成 JSON 报告: $report_file"
    
    cat > "$report_file" << EOF
{
  "report_info": {
    "generated_at": "$(date -Iseconds)",
    "analyzer_version": "1.0",
    "analyzed_files": [$(printf '"%s",' "${log_files[@]}" | sed 's/,$//')],
    "project_dir": "$PROJECT_DIR"
  },
  "summary": {
    "total_entries": 0,
    "successful_runs": 0,
    "failed_runs": 0,
    "success_rate": 0,
    "analysis_period": {
      "start": null,
      "end": null
    }
  },
  "knowledge_bases": {},
  "errors": [],
  "timeline": [],
  "recommendations": []
}
EOF
    
    log_success "JSON 报告已生成: $report_file"
}

# 主函数
main() {
    local days=7
    local summary_only=false
    local errors_only=false
    local timeline_only=false
    local generate_report=false
    local output_format="text"
    local no_color=false
    local log_files=()
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;\n            -d|--days)
                days="$2"
                shift 2
                ;;\n            -s|--summary)
                summary_only=true
                shift
                ;;\n            -e|--errors)
                errors_only=true
                shift
                ;;\n            -t|--timeline)
                timeline_only=true
                shift
                ;;\n            -r|--report)
                generate_report=true
                shift
                ;;\n            -f|--format)
                output_format="$2"
                shift 2
                ;;\n            --no-color)
                no_color=true
                shift
                ;;\n            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;\n            *)
                log_files+=("$1")
                shift
                ;;\n        esac
    done
    
    # 禁用颜色（如果需要）
    if [ "$no_color" = true ]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        CYAN=''
        MAGENTA=''
        NC=''
    fi
    
    echo "📊 TKE 文档同步系统 - 日志分析工具"
    echo "================================="
    
    # 记录分析开始
    log_message "开始日志分析，天数: $days"
    
    # 查找日志文件
    local found_files=($(find_log_files "$days" "${log_files[@]}"))
    
    if [ ${#found_files[@]} -eq 0 ]; then
        log_error "未找到任何日志文件"
        exit 1
    fi
    
    log_info "找到 ${#found_files[@]} 个日志文件"
    
    # 根据选项执行相应分析
    if [ "$summary_only" = true ]; then
        generate_summary "${found_files[@]}"
    elif [ "$errors_only" = true ]; then
        analyze_errors "${found_files[@]}"
    elif [ "$timeline_only" = true ]; then
        generate_timeline "${found_files[@]}"
    else
        # 完整分析
        generate_summary "${found_files[@]}"
        analyze_log_statistics "${found_files[@]}"
        analyze_errors "${found_files[@]}"
        
        if [ "$generate_report" = true ]; then
            case "$output_format" in
                "html")
                    generate_html_report "${found_files[@]}"
                    ;;\n                "json")
                    generate_json_report "${found_files[@]}"
                    ;;\n                "text"|*)
                    generate_timeline "${found_files[@]}"
                    ;;\n            esac
        fi
    fi
    
    log_message "日志分析完成"
}

# 运行主函数
main "$@"