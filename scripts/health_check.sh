#!/bin/bash

# TKE 文档同步系统 - 健康检查脚本
# 专门为计划执行模型设计的健康检查工具

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
HEALTH_LOG="$PROJECT_DIR/logs/health_check.log"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$HEALTH_LOG"
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

# 检查项目环境完整性
check_project_environment() {
    echo "🔍 检查项目环境完整性"
    echo "===================="
    
    local issues=0
    
    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        ((issues++))
        return $issues
    else
        log_success "项目目录存在: $PROJECT_DIR"
    fi
    
    # 检查关键文件
    local critical_files=(
        "tke_dify_sync.py:主同步脚本"
        "dify_sync_manager.py:Dify同步管理器"
        "enhanced_metadata_generator.py:元数据生成器"
        "tke_logger.py:日志管理器"
        ".env:配置文件"
        "requirements.txt:依赖列表"
    )
    
    for file_entry in "${critical_files[@]}"; do
        local file_path="${file_entry%%:*}"
        local file_desc="${file_entry##*:}"
        
        if [ -f "$PROJECT_DIR/$file_path" ]; then
            log_success "✅ $file_desc ($file_path)"
        else
            log_error "❌ $file_desc 缺失 ($file_path)"
            ((issues++))
        fi
    done
    
    # 检查目录结构
    local required_dirs=(
        "logs:日志目录"
        "data:数据目录"
        "scripts:脚本目录"
        "venv:Python虚拟环境"
    )
    
    for dir_entry in "${required_dirs[@]}"; do
        local dir_path="${dir_entry%%:*}"
        local dir_desc="${dir_entry##*:}"
        
        if [ -d "$PROJECT_DIR/$dir_path" ]; then
            log_success "✅ $dir_desc ($dir_path/)"
        else
            log_warning "⚠️ $dir_desc 不存在 ($dir_path/)"
            # 尝试创建缺失的目录
            if mkdir -p "$PROJECT_DIR/$dir_path" 2>/dev/null; then
                log_success "✅ 已创建 $dir_desc"
            else
                log_error "❌ 无法创建 $dir_desc"
                ((issues++))
            fi
        fi
    done
    
    return $issues
}

# 检查 Python 环境
check_python_environment() {
    echo
    echo "🐍 检查 Python 环境"
    echo "=================="
    
    local issues=0
    
    # 检查虚拟环境
    if [ ! -d "$PROJECT_DIR/venv" ]; then
        log_error "Python 虚拟环境不存在"
        ((issues++))
        return $issues
    fi
    
    local python_path="$PROJECT_DIR/venv/bin/python"
    if [ ! -f "$python_path" ]; then
        log_error "虚拟环境中的 Python 不存在"
        ((issues++))
        return $issues
    fi
    
    # 检查 Python 版本
    local python_version=$("$python_path" --version 2>&1)
    log_success "Python 版本: $python_version"
    
    # 检查关键依赖包
    local required_packages=(
        "requests:HTTP请求库"
        "beautifulsoup4:HTML解析库"
        "selenium:浏览器自动化"
        "webdriver-manager:WebDriver管理"
    )
    
    for package_entry in "${required_packages[@]}"; do
        local package_name="${package_entry%%:*}"
        local package_desc="${package_entry##*:}"
        
        if "$python_path" -c "import $package_name" 2>/dev/null; then
            local package_version=$("$python_path" -c "import $package_name; print(getattr($package_name, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
            log_success "✅ $package_desc ($package_name $package_version)"
        else
            log_error "❌ $package_desc 未安装 ($package_name)"
            ((issues++))
        fi
    done
    
    # 检查 Chrome 浏览器
    if command -v google-chrome >/dev/null 2>&1; then
        local chrome_version=$(google-chrome --version 2>/dev/null || echo "unknown")
        log_success "✅ Chrome 浏览器: $chrome_version"
    elif command -v chromium-browser >/dev/null 2>&1; then
        local chromium_version=$(chromium-browser --version 2>/dev/null || echo "unknown")
        log_success "✅ Chromium 浏览器: $chromium_version"
    else
        log_error "❌ 未找到 Chrome 或 Chromium 浏览器"
        ((issues++))
    fi
    
    return $issues
}

# 检查配置文件
check_configuration() {
    echo
    echo "⚙️ 检查配置文件"
    echo "=============="
    
    local issues=0
    
    # 检查主配置文件
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_error "主配置文件不存在: .env"
        ((issues++))
        return $issues
    fi
    
    log_success "主配置文件存在: .env"
    
    # 检查关键配置项
    local required_configs=(
        "DIFY_API_KEY:Dify API密钥"
        "DIFY_KNOWLEDGE_BASE_ID:知识库ID"
        "DIFY_API_BASE_URL:Dify API地址"
    )
    
    for config_entry in "${required_configs[@]}"; do
        local config_key="${config_entry%%:*}"
        local config_desc="${config_entry##*:}"
        
        if grep -q "^$config_key=" "$PROJECT_DIR/.env" 2>/dev/null; then
            local config_value=$(grep "^$config_key=" "$PROJECT_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            if [ -n "$config_value" ] && [ "$config_value" != "your_*_here" ]; then
                log_success "✅ $config_desc 已配置"
            else
                log_warning "⚠️ $config_desc 未设置实际值"
                ((issues++))
            fi
        else
            log_error "❌ $config_desc 未配置 ($config_key)"
            ((issues++))
        fi
    done
    
    # 检查多知识库配置
    local multi_kb_configs=(
        ".env.tke_docs_base:TKE基础文档库配置"
        ".env.tke_knowledge_base:TKE知识库配置"
    )
    
    local multi_kb_count=0
    for config_entry in "${multi_kb_configs[@]}"; do
        local config_file="${config_entry%%:*}"
        local config_desc="${config_entry##*:}"
        
        if [ -f "$PROJECT_DIR/$config_file" ]; then
            log_success "✅ $config_desc ($config_file)"
            ((multi_kb_count++))
        else
            log_info "ℹ️ $config_desc 不存在（可选）"
        fi
    done
    
    if [ $multi_kb_count -gt 0 ]; then
        log_info "检测到 $multi_kb_count 个多知识库配置"
    fi
    
    return $issues
}

# 检查网络连接
check_network_connectivity() {
    echo
    echo "🌐 检查网络连接"
    echo "=============="
    
    local issues=0
    
    # 检查腾讯云文档站点
    if curl -s --max-time 10 https://cloud.tencent.com >/dev/null 2>&1; then
        log_success "✅ 腾讯云文档站点连接正常"
    else
        log_error "❌ 无法连接腾讯云文档站点"
        ((issues++))
    fi
    
    # 检查 Dify API 连接
    if [ -f "$PROJECT_DIR/.env" ]; then
        local dify_url=$(grep "^DIFY_API_BASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$dify_url" ] && [ "$dify_url" != "your_dify_api_base_url_here" ]; then
            if curl -s --max-time 10 "$dify_url" >/dev/null 2>&1; then
                log_success "✅ Dify API 连接正常: $dify_url"
            else
                log_error "❌ 无法连接 Dify API: $dify_url"
                ((issues++))
            fi
        else
            log_warning "⚠️ Dify API URL 未配置"
            ((issues++))
        fi
    fi
    
    return $issues
}

# 检查 cron 作业状态
check_cron_jobs() {
    echo
    echo "🕐 检查 cron 作业状态"
    echo "==================="
    
    local issues=0
    
    # 检查是否有 crontab
    if ! crontab -l >/dev/null 2>&1; then
        log_error "当前用户没有配置 crontab"
        ((issues++))
        return $issues
    fi
    
    # 检查 TKE 相关的 cron 作业
    local tke_cron_jobs=$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|tke-dify)" | grep -v "^#" || true)
    
    if [ -z "$tke_cron_jobs" ]; then
        log_error "❌ 未找到 TKE 同步相关的 cron 作业"
        ((issues++))
    else
        log_success "✅ 找到 TKE 同步相关的 cron 作业"
        
        local job_count=0
        echo "$tke_cron_jobs" | while IFS= read -r job; do
            if [ -n "$job" ]; then
                ((job_count++))
                log_info "  📋 作业 $job_count: $job"
            fi
        done
    fi
    
    # 检查监控 cron 作业
    local monitor_cron=$(crontab -l 2>/dev/null | grep "monitor.sh" || true)
    if [ -n "$monitor_cron" ]; then
        log_success "✅ 找到监控 cron 作业"
    else
        log_warning "⚠️ 未找到监控 cron 作业"
        ((issues++))
    fi
    
    return $issues
}

# 检查最近的执行状态
check_recent_execution() {
    echo
    echo "📋 检查最近的执行状态"
    echo "===================="
    
    local issues=0
    local current_time=$(date +%s)
    
    # 检查各种日志文件
    local log_files=(
        "$PROJECT_DIR/logs/cron.log:单知识库同步"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log:TKE基础文档库"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log:TKE知识库"
        "$PROJECT_DIR/logs/tke_sync.log:应用程序日志"
    )
    
    local found_recent_activity=false
    
    for log_entry in "${log_files[@]}"; do
        local log_file="${log_entry%%:*}"
        local log_desc="${log_entry##*:}"
        
        if [ -f "$log_file" ]; then
            local last_modified=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
            local time_diff=$((current_time - last_modified))
            local hours_ago=$((time_diff / 3600))
            
            if [ $time_diff -lt 86400 ]; then  # 24小时内
                log_success "✅ $log_desc: ${hours_ago}小时前有活动"
                found_recent_activity=true
                
                # 检查是否有错误
                local recent_errors=$(tail -20 "$log_file" | grep -i "error\|exception\|failed\|❌" | wc -l)
                if [ $recent_errors -gt 0 ]; then
                    log_warning "  ⚠️ 发现 $recent_errors 个错误记录"
                    ((issues++))
                fi
                
            elif [ $time_diff -lt 172800 ]; then  # 48小时内
                log_warning "⚠️ $log_desc: ${hours_ago}小时前有活动（超过24小时）"
                ((issues++))
            else
                log_info "ℹ️ $log_desc: 无最近活动记录"
            fi
        else
            log_info "ℹ️ $log_desc: 日志文件不存在"
        fi
    done
    
    if [ "$found_recent_activity" = false ]; then
        log_warning "⚠️ 未发现最近24小时内的同步活动"
        ((issues++))
    fi
    
    return $issues
}

# 检查系统资源
check_system_resources() {
    echo
    echo "💻 检查系统资源"
    echo "=============="
    
    local issues=0
    
    # 检查磁盘空间
    local disk_usage=$(df "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_error "❌ 磁盘使用率过高: ${disk_usage}%"
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
        ((issues++))
    elif [ "$memory_usage" -gt 80 ]; then
        log_warning "⚠️ 内存使用率较高: ${memory_usage}%"
    else
        log_success "✅ 内存使用率正常: ${memory_usage}%"
    fi
    
    # 检查日志文件大小
    local large_logs=$(find "$PROJECT_DIR/logs" -name "*.log" -size +10M 2>/dev/null || true)
    if [ -n "$large_logs" ]; then
        log_warning "⚠️ 发现大型日志文件，建议轮转:"
        echo "$large_logs" | while read -r large_log; do
            if [ -n "$large_log" ]; then
                local size=$(du -h "$large_log" | cut -f1)
                log_warning "  📄 $(basename "$large_log"): $size"
            fi
        done
    else
        log_success "✅ 日志文件大小正常"
    fi
    
    return $issues
}

# 生成健康检查报告
generate_health_report() {
    local total_issues="$1"
    local report_file="$PROJECT_DIR/logs/health_check_report_$(date +%Y%m%d_%H%M%S).md"
    
    log_info "生成健康检查报告: $report_file"
    
    cat > "$report_file" << EOF
# TKE 文档同步系统 - 健康检查报告

生成时间: $(date)
检查用户: $(whoami)
项目目录: $PROJECT_DIR

## 检查摘要

总问题数: $total_issues

## 系统状态

### 项目环境
- 项目目录: $([ -d "$PROJECT_DIR" ] && echo "✅ 存在" || echo "❌ 不存在")
- Python 虚拟环境: $([ -d "$PROJECT_DIR/venv" ] && echo "✅ 存在" || echo "❌ 不存在")
- 主配置文件: $([ -f "$PROJECT_DIR/.env" ] && echo "✅ 存在" || echo "❌ 不存在")

### cron 作业状态
\`\`\`
$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|monitor\.sh)" || echo "无相关 cron 作业")
\`\`\`

### 系统资源
- 磁盘使用率: $(df "$PROJECT_DIR" | awk 'NR==2 {print $5}')
- 内存使用率: $(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')

### 最近活动
EOF

    # 添加日志文件状态
    local log_files=(
        "$PROJECT_DIR/logs/cron.log"
        "$PROJECT_DIR/logs/cron_tke_docs_base.log"
        "$PROJECT_DIR/logs/cron_tke_knowledge_base.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            local last_modified=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local hours_ago=$(( (current_time - last_modified) / 3600 ))
            
            echo "- $(basename "$log_file"): ${hours_ago}小时前" >> "$report_file"
        fi
    done
    
    # 添加建议
    echo "" >> "$report_file"
    echo "## 建议操作" >> "$report_file"
    
    if [ $total_issues -eq 0 ]; then
        echo "- 系统状态良好，无需特别操作" >> "$report_file"
    else
        echo "- 发现 $total_issues 个问题，建议查看详细日志进行修复" >> "$report_file"
        
        if ! crontab -l 2>/dev/null | grep -q "tke_dify_sync"; then
            echo "- 配置 cron 作业进行定时同步" >> "$report_file"
        fi
        
        if [ ! -f "$PROJECT_DIR/.env" ] || ! grep -q "^DIFY_API_KEY=" "$PROJECT_DIR/.env"; then
            echo "- 配置 Dify API 相关参数" >> "$report_file"
        fi
    fi
    
    log_success "健康检查报告已生成: $report_file"
}

# 主函数
main() {
    echo "🏥 TKE 文档同步系统 - 健康检查"
    echo "==============================="
    
    local total_issues=0
    
    # 记录健康检查开始
    log_message "开始健康检查"
    
    # 执行各项检查
    check_project_environment
    total_issues=$((total_issues + $?))
    
    check_python_environment
    total_issues=$((total_issues + $?))
    
    check_configuration
    total_issues=$((total_issues + $?))
    
    check_network_connectivity
    total_issues=$((total_issues + $?))
    
    check_cron_jobs
    total_issues=$((total_issues + $?))
    
    check_recent_execution
    total_issues=$((total_issues + $?))
    
    check_system_resources
    total_issues=$((total_issues + $?))
    
    # 生成报告
    echo
    generate_health_report "$total_issues"
    
    # 记录检查结果
    echo
    echo "🎯 健康检查完成"
    echo "=============="
    
    if [ $total_issues -eq 0 ]; then
        log_success "✅ 系统健康状态良好，未发现问题"
        log_message "健康检查完成，系统状态良好"
    else
        log_warning "⚠️ 发现 $total_issues 个问题，建议进行修复"
        log_message "健康检查完成，发现 $total_issues 个问题"
    fi
    
    echo "健康检查日志: $HEALTH_LOG"
    
    exit $total_issues
}

# 运行主函数
main "$@"