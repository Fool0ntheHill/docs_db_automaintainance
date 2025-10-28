#!/bin/bash

# TKE 文档同步系统 - cron 设置验证工具
# 验证 cron 配置是否正确设置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_DIR="/opt/tke-dify-sync"
SERVICE_NAME="tke-dify-sync"

# 日志函数
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

# 验证项目环境
validate_project_environment() {
    echo "🔍 验证项目环境"
    echo "=============="
    
    local errors=0
    
    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        ((errors++))
    else
        log_success "项目目录存在"
    fi
    
    # 检查 Python 虚拟环境
    if [ ! -d "$PROJECT_DIR/venv" ]; then
        log_error "Python 虚拟环境不存在: $PROJECT_DIR/venv"
        ((errors++))
    else
        log_success "Python 虚拟环境存在"
        
        # 检查虚拟环境中的 Python
        if [ -f "$PROJECT_DIR/venv/bin/python" ]; then
            log_success "虚拟环境 Python 可执行文件存在"
        else
            log_error "虚拟环境 Python 可执行文件不存在"
            ((errors++))
        fi
    fi
    
    # 检查主脚本
    if [ ! -f "$PROJECT_DIR/tke_dify_sync.py" ]; then
        log_error "主脚本不存在: $PROJECT_DIR/tke_dify_sync.py"
        ((errors++))
    else
        log_success "主脚本存在"
    fi
    
    # 检查配置文件
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log_error "配置文件不存在: $PROJECT_DIR/.env"
        ((errors++))
    else
        log_success "配置文件存在"
    fi
    
    # 检查日志目录
    if [ ! -d "$PROJECT_DIR/logs" ]; then
        log_warning "日志目录不存在，将创建: $PROJECT_DIR/logs"
        mkdir -p "$PROJECT_DIR/logs"
    else
        log_success "日志目录存在"
    fi
    
    return $errors
}

# 验证 cron 作业配置
validate_cron_jobs() {
    echo
    echo "🕐 验证 cron 作业配置"
    echo "==================="
    
    local errors=0
    local warnings=0
    
    # 获取当前用户的 cron 作业
    local cron_jobs=$(crontab -l 2>/dev/null || echo "")
    
    if [ -z "$cron_jobs" ]; then
        log_warning "当前用户没有配置任何 cron 作业"
        ((warnings++))
        return $warnings
    fi
    
    # 查找相关的 cron 作业
    local tke_cron_jobs=$(echo "$cron_jobs" | grep -E "(tke_dify_sync|tke-dify)" | grep -v "^#" || true)
    
    if [ -z "$tke_cron_jobs" ]; then
        log_warning "未找到 TKE 同步相关的 cron 作业"
        ((warnings++))
    else
        log_success "找到 TKE 同步相关的 cron 作业:"
        
        echo "$tke_cron_jobs" | while IFS= read -r job; do
            if [ -n "$job" ]; then
                echo "  📋 $job"
                
                # 验证 cron 作业格式
                if [[ $job =~ ^[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]].+ ]]; then
                    log_success "    ✅ cron 时间格式正确"
                else
                    log_error "    ❌ cron 时间格式错误"
                    ((errors++))
                fi
                
                # 检查是否包含项目路径
                if [[ $job == *"$PROJECT_DIR"* ]]; then
                    log_success "    ✅ 包含正确的项目路径"
                else
                    log_error "    ❌ 未包含项目路径或路径错误"
                    ((errors++))
                fi
                
                # 检查是否包含 Python 虚拟环境路径
                if [[ $job == *"$PROJECT_DIR/venv/bin/python"* ]]; then
                    log_success "    ✅ 使用虚拟环境 Python"
                else
                    log_warning "    ⚠️ 未使用虚拟环境 Python"
                    ((warnings++))
                fi
                
                # 检查是否包含日志重定向
                if [[ $job == *">>"* ]] && [[ $job == *"2>&1"* ]]; then
                    log_success "    ✅ 包含日志重定向"
                else
                    log_warning "    ⚠️ 缺少日志重定向"
                    ((warnings++))
                fi
                
                echo
            fi
        done
    fi
    
    return $((errors + warnings))
}

# 验证 systemd 服务不存在
validate_no_systemd_service() {
    echo "🚫 验证 systemd 服务不存在"
    echo "========================="
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    
    if [ -f "$service_file" ]; then
        log_error "❌ 发现 systemd 服务文件: $service_file"
        log_error "   这会与 cron 作业冲突，导致无限重启问题！"
        
        # 检查服务状态
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_error "   服务正在运行，必须立即停止！"
        fi
        
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_error "   服务已启用，系统重启后会自动启动！"
        fi
        
        echo
        log_error "🔧 修复步骤："
        echo "   sudo systemctl stop $SERVICE_NAME"
        echo "   sudo systemctl disable $SERVICE_NAME"
        echo "   sudo rm $service_file"
        echo "   sudo systemctl daemon-reload"
        
        return 1
    else
        log_success "✅ 未发现 systemd 服务文件（正确）"
        return 0
    fi
}

# 测试 cron 作业执行
test_cron_execution() {
    echo
    echo "🧪 测试 cron 作业执行"
    echo "==================="
    
    local test_log="$PROJECT_DIR/logs/cron_test_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "执行测试运行..."
    log_info "测试日志: $test_log"
    
    # 切换到项目目录并执行脚本
    cd "$PROJECT_DIR"
    
    if [ -f "$PROJECT_DIR/venv/bin/python" ] && [ -f "$PROJECT_DIR/tke_dify_sync.py" ]; then
        # 使用 timeout 限制执行时间，避免长时间运行
        timeout 60s "$PROJECT_DIR/venv/bin/python" tke_dify_sync.py > "$test_log" 2>&1 &
        local test_pid=$!
        
        log_info "测试进程 PID: $test_pid"
        log_info "等待测试完成（最多60秒）..."
        
        # 等待进程完成或超时
        if wait $test_pid 2>/dev/null; then
            local exit_code=$?
            if [ $exit_code -eq 0 ]; then
                log_success "✅ 测试执行成功"
            else
                log_warning "⚠️ 测试执行完成，但返回非零退出码: $exit_code"
            fi
        else
            log_warning "⚠️ 测试执行超时或被中断"
        fi
        
        # 显示测试日志的最后几行
        if [ -f "$test_log" ]; then
            echo
            echo "📋 测试日志摘要（最后10行）:"
            echo "------------------------"
            tail -10 "$test_log"
        fi
        
        return 0
    else
        log_error "❌ 无法执行测试：缺少必要文件"
        return 1
    fi
}

# 验证日志文件权限和轮转
validate_logging() {
    echo
    echo "📝 验证日志配置"
    echo "=============="
    
    local errors=0
    
    # 检查日志目录权限
    if [ -d "$PROJECT_DIR/logs" ]; then
        local log_dir_perms=$(stat -c "%a" "$PROJECT_DIR/logs" 2>/dev/null || stat -f "%A" "$PROJECT_DIR/logs" 2>/dev/null)
        if [ "$log_dir_perms" = "755" ] || [ "$log_dir_perms" = "750" ]; then
            log_success "日志目录权限正确: $log_dir_perms"
        else
            log_warning "日志目录权限可能需要调整: $log_dir_perms"
        fi
    fi
    
    # 检查现有日志文件
    local log_files=$(find "$PROJECT_DIR/logs" -name "*.log" 2>/dev/null || true)
    if [ -n "$log_files" ]; then
        log_info "发现现有日志文件:"
        echo "$log_files" | while read -r logfile; do
            if [ -n "$logfile" ]; then
                local size=$(du -h "$logfile" 2>/dev/null | cut -f1)
                echo "  📄 $(basename "$logfile"): $size"
            fi
        done
    else
        log_info "暂无日志文件"
    fi
    
    # 检查是否配置了 logrotate
    if [ -f "/etc/logrotate.d/tke-dify-sync" ]; then
        log_success "✅ 已配置 logrotate"
    else
        log_warning "⚠️ 未配置 logrotate，建议配置日志轮转"
    fi
    
    return $errors
}

# 生成验证报告
generate_validation_report() {
    local report_file="$PROJECT_DIR/cron_validation_$(date +%Y%m%d_%H%M%S).md"
    
    echo
    echo "📊 生成验证报告: $report_file"
    
    cat > "$report_file" << EOF
# TKE 文档同步系统 - cron 设置验证报告

生成时间: $(date)
验证用户: $(whoami)

## 验证摘要

### 项目环境
- 项目目录: $PROJECT_DIR
- Python 虚拟环境: $([ -d "$PROJECT_DIR/venv" ] && echo "✅ 存在" || echo "❌ 不存在")
- 主脚本: $([ -f "$PROJECT_DIR/tke_dify_sync.py" ] && echo "✅ 存在" || echo "❌ 不存在")
- 配置文件: $([ -f "$PROJECT_DIR/.env" ] && echo "✅ 存在" || echo "❌ 不存在")

### cron 作业配置
\`\`\`
$(crontab -l 2>/dev/null | grep -E "(tke_dify_sync|tke-dify)" || echo "无相关 cron 作业")
\`\`\`

### systemd 服务状态
- 服务文件: $([ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] && echo "❌ 存在（需要删除）" || echo "✅ 不存在")

### 建议操作
EOF

    # 添加建议操作
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        echo "1. 删除 systemd 服务以避免冲突" >> "$report_file"
    fi
    
    if ! crontab -l 2>/dev/null | grep -q -E "(tke_dify_sync|tke-dify)"; then
        echo "2. 配置 cron 作业进行定时同步" >> "$report_file"
    fi
    
    if [ ! -f "/etc/logrotate.d/tke-dify-sync" ]; then
        echo "3. 配置 logrotate 进行日志轮转" >> "$report_file"
    fi
    
    log_success "验证报告已生成: $report_file"
}

# 主函数
main() {
    echo "🔍 TKE 文档同步系统 - cron 设置验证"
    echo "===================================="
    
    local total_errors=0
    
    validate_project_environment
    total_errors=$((total_errors + $?))
    
    validate_cron_jobs
    total_errors=$((total_errors + $?))
    
    validate_no_systemd_service
    total_errors=$((total_errors + $?))
    
    test_cron_execution
    total_errors=$((total_errors + $?))
    
    validate_logging
    total_errors=$((total_errors + $?))
    
    generate_validation_report
    
    echo
    echo "🎯 验证完成！"
    
    if [ $total_errors -eq 0 ]; then
        log_success "✅ 所有验证通过，cron 设置正确"
        exit 0
    else
        log_warning "⚠️ 发现 $total_errors 个问题，请查看上述输出进行修复"
        exit 1
    fi
}

# 运行主函数
main "$@"