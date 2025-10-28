#!/bin/bash

# TKE 文档同步系统 - 迁移验证工具
# 验证从 systemd 到 cron 的迁移是否成功

set -e

# 颜色定义
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
NC='\\033[0m' # No Color

# 配置
SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"
PROJECT_DIR=\"$(dirname \"$SCRIPT_DIR\")\"
SERVICE_NAME=\"tke-dify-sync\"
SERVICE_FILE=\"/etc/systemd/system/${SERVICE_NAME}.service\"

# 日志函数
log_info() {
    echo -e \"${BLUE}[INFO]${NC} $1\"
}

log_success() {
    echo -e \"${GREEN}[SUCCESS]${NC} $1\"
}

log_warning() {
    echo -e \"${YELLOW}[WARNING]${NC} $1\"
}

log_error() {
    echo -e \"${RED}[ERROR]${NC} $1\"
}

# 显示帮助信息
show_help() {
    echo \"TKE 文档同步系统 - 迁移验证工具\"
    echo \"==============================\"
    echo
    echo \"用法: $0 [选项]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help          显示此帮助信息\"
    echo \"  -v, --verbose       详细输出\"
    echo \"  -q, --quiet         静默模式\"
    echo \"  --fix-issues        自动修复发现的问题\"
    echo
    echo \"示例:\"
    echo \"  $0                  # 标准验证\"
    echo \"  $0 -v               # 详细验证\"
    echo \"  $0 --fix-issues     # 验证并修复问题\"
    echo
}

# 检查 systemd 服务状态
check_systemd_status() {
    echo \"🔍 检查 systemd 服务状态\"
    echo \"=======================\"
    
    local issues=0
    
    # 检查服务文件是否存在
    if [ -f \"$SERVICE_FILE\" ]; then
        log_error \"❌ systemd 服务文件仍然存在: $SERVICE_FILE\"
        ((issues++))
        
        if [ \"$FIX_ISSUES\" = true ]; then
            log_info \"尝试删除 systemd 服务文件...\"
            if sudo rm \"$SERVICE_FILE\" 2>/dev/null; then
                log_success \"✅ systemd 服务文件已删除\"
                sudo systemctl daemon-reload
                ((issues--))
            else
                log_error \"❌ 无法删除 systemd 服务文件\"
            fi
        fi
    else
        log_success \"✅ systemd 服务文件已正确删除\"
    fi
    
    # 检查服务是否仍在运行
    if systemctl is-active --quiet \"$SERVICE_NAME\" 2>/dev/null; then
        log_error \"❌ systemd 服务仍在运行\"
        ((issues++))
        
        if [ \"$FIX_ISSUES\" = true ]; then
            log_info \"尝试停止 systemd 服务...\"
            if sudo systemctl stop \"$SERVICE_NAME\" 2>/dev/null; then
                log_success \"✅ systemd 服务已停止\"
                ((issues--))
            else
                log_error \"❌ 无法停止 systemd 服务\"
            fi
        fi
    else
        log_success \"✅ systemd 服务未运行\"
    fi
    
    # 检查服务是否仍被启用
    if systemctl is-enabled --quiet \"$SERVICE_NAME\" 2>/dev/null; then
        log_error \"❌ systemd 服务仍被启用\"
        ((issues++))
        
        if [ \"$FIX_ISSUES\" = true ]; then
            log_info \"尝试禁用 systemd 服务...\"
            if sudo systemctl disable \"$SERVICE_NAME\" 2>/dev/null; then
                log_success \"✅ systemd 服务已禁用\"
                ((issues--))
            else
                log_error \"❌ 无法禁用 systemd 服务\"
            fi
        fi
    else
        log_success \"✅ systemd 服务未启用\"
    fi
    
    return $issues
}

# 检查 cron 作业配置
check_cron_configuration() {
    echo
    echo \"🕐 检查 cron 作业配置\"
    echo \"===================\"
    
    local issues=0
    
    # 检查是否有 TKE 相关的 cron 作业
    if crontab -l 2>/dev/null | grep -q \"tke_dify_sync\\|tke-dify\"; then
        log_success \"✅ 发现 TKE 相关的 cron 作业\"
        
        local job_count=$(crontab -l 2>/dev/null | grep -c \"tke_dify_sync\\|tke-dify\" || echo 0)
        log_info \"📋 配置了 $job_count 个相关 cron 作业\"
        
        if [ \"$VERBOSE\" = true ]; then
            echo \"   配置的 cron 作业:\"
            crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" | while read -r job; do
                echo \"     📋 $job\"
            done
        fi
    else
        log_error \"❌ 未发现 TKE 相关的 cron 作业\"
        ((issues++))
        
        if [ \"$FIX_ISSUES\" = true ]; then
            log_info \"尝试设置基本的 cron 作业...\"
            # 创建基本的 cron 作业
            (crontab -l 2>/dev/null; echo \"0 2 * * * cd $PROJECT_DIR && $PROJECT_DIR/venv/bin/python tke_dify_sync.py >> $PROJECT_DIR/logs/cron.log 2>&1\") | crontab -
            if [ $? -eq 0 ]; then
                log_success \"✅ 基本 cron 作业已设置\"
                ((issues--))
            else
                log_error \"❌ 无法设置 cron 作业\"
            fi
        fi
    fi
    
    # 检查 cron 服务状态
    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
        log_success \"✅ cron 服务正在运行\"
    else
        log_error \"❌ cron 服务未运行\"
        ((issues++))
        
        if [ \"$FIX_ISSUES\" = true ]; then
            log_info \"尝试启动 cron 服务...\"
            if sudo systemctl start cron 2>/dev/null || sudo systemctl start crond 2>/dev/null; then
                log_success \"✅ cron 服务已启动\"
                ((issues--))
            else
                log_error \"❌ 无法启动 cron 服务\"
            fi
        fi
    fi
    
    return $issues
}

# 检查项目文件完整性
check_project_integrity() {
    echo
    echo \"📁 检查项目文件完整性\"
    echo \"===================\"
    
    local issues=0
    
    # 检查关键文件
    local required_files=(
        \"$PROJECT_DIR/tke_dify_sync.py\"
        \"$PROJECT_DIR/.env\"
        \"$PROJECT_DIR/venv/bin/python\"
    )
    
    for file in \"${required_files[@]}\"; do
        if [ -f \"$file\" ]; then
            log_success \"✅ 关键文件存在: $(basename \"$file\")\"
        else
            log_error \"❌ 关键文件缺失: $file\"
            ((issues++))
        fi
    done
    
    # 检查日志目录
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        log_success \"✅ 日志目录存在\"
    else
        log_warning \"⚠️ 日志目录不存在\"
        if [ \"$FIX_ISSUES\" = true ]; then
            mkdir -p \"$PROJECT_DIR/logs\"
            log_success \"✅ 日志目录已创建\"
        else
            ((issues++))
        fi
    fi
    
    # 检查数据目录
    if [ -d \"$PROJECT_DIR/data\" ]; then
        log_success \"✅ 数据目录存在\"
    else
        log_warning \"⚠️ 数据目录不存在\"
        if [ \"$FIX_ISSUES\" = true ]; then
            mkdir -p \"$PROJECT_DIR/data\"
            log_success \"✅ 数据目录已创建\"
        else
            ((issues++))
        fi
    fi
    
    # 检查脚本目录
    if [ -d \"$PROJECT_DIR/scripts\" ]; then
        log_success \"✅ 脚本目录存在\"
        
        # 检查关键脚本
        local scripts=(\"monitor.sh\" \"health_check.sh\" \"start.sh\")
        for script in \"${scripts[@]}\"; do
            if [ -f \"$PROJECT_DIR/scripts/$script\" ]; then
                log_success \"✅ 脚本存在: $script\"
            else
                log_warning \"⚠️ 脚本缺失: $script\"
            fi
        done
    else
        log_error \"❌ 脚本目录不存在\"
        ((issues++))
    fi
    
    return $issues
}

# 测试脚本执行
test_script_execution() {
    echo
    echo \"🧪 测试脚本执行\"
    echo \"===============\"
    
    local issues=0
    
    # 测试 Python 环境
    log_info \"测试 Python 虚拟环境...\"
    if cd \"$PROJECT_DIR\" && \"$PROJECT_DIR/venv/bin/python\" --version >/dev/null 2>&1; then
        log_success \"✅ Python 虚拟环境正常\"
        if [ \"$VERBOSE\" = true ]; then
            local python_version=$(\"$PROJECT_DIR/venv/bin/python\" --version 2>&1)
            echo \"   Python 版本: $python_version\"
        fi
    else
        log_error \"❌ Python 虚拟环境异常\"
        ((issues++))
    fi
    
    # 测试主脚本语法
    log_info \"测试主脚本语法...\"
    if cd \"$PROJECT_DIR\" && \"$PROJECT_DIR/venv/bin/python\" -m py_compile tke_dify_sync.py 2>/dev/null; then
        log_success \"✅ 主脚本语法正确\"
    else
        log_error \"❌ 主脚本语法错误\"
        ((issues++))
    fi
    
    # 测试配置文件
    log_info \"测试配置文件...\"
    if [ -f \"$PROJECT_DIR/.env\" ]; then
        # 检查必需的配置项
        local required_vars=(\"DIFY_API_KEY\" \"DIFY_KNOWLEDGE_BASE_ID\" \"DIFY_API_BASE_URL\")
        local missing_vars=0
        
        for var in \"${required_vars[@]}\"; do
            if grep -q \"^$var=\" \"$PROJECT_DIR/.env\"; then
                if [ \"$VERBOSE\" = true ]; then
                    log_success \"✅ 配置项存在: $var\"
                fi
            else
                log_error \"❌ 配置项缺失: $var\"
                ((missing_vars++))
            fi
        done
        
        if [ $missing_vars -eq 0 ]; then
            log_success \"✅ 配置文件完整\"
        else
            log_error \"❌ 配置文件缺少 $missing_vars 个必需项\"
            ((issues++))
        fi
    else
        log_error \"❌ 配置文件不存在\"
        ((issues++))
    fi
    
    # 测试脚本快速执行（如果可能）
    if [ $issues -eq 0 ]; then
        log_info \"测试脚本快速执行...\"
        if timeout 10s \"$PROJECT_DIR/venv/bin/python\" \"$PROJECT_DIR/tke_dify_sync.py\" --help >/dev/null 2>&1; then
            log_success \"✅ 脚本可以正常启动\"
        else
            log_warning \"⚠️ 脚本启动测试超时或失败（这可能是正常的）\"
        fi
    fi
    
    return $issues
}

# 检查日志文件
check_log_files() {
    echo
    echo \"📄 检查日志文件\"
    echo \"===============\"
    
    local issues=0
    
    # 检查是否有最近的日志
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        local recent_logs=$(find \"$PROJECT_DIR/logs\" -name \"*.log\" -mtime -7 2>/dev/null | wc -l)
        
        if [ $recent_logs -gt 0 ]; then
            log_success \"✅ 发现 $recent_logs 个最近的日志文件\"
            
            if [ \"$VERBOSE\" = true ]; then
                echo \"   最近的日志文件:\"
                find \"$PROJECT_DIR/logs\" -name \"*.log\" -mtime -7 -exec ls -la {} \\; 2>/dev/null | while read -r line; do
                    echo \"     $line\"
                done
            fi
        else
            log_warning \"⚠️ 未发现最近的日志文件\"
            log_info \"   这可能表示 cron 作业尚未执行或日志配置有问题\"
        fi
        
        # 检查日志文件权限
        local log_files=$(find \"$PROJECT_DIR/logs\" -name \"*.log\" 2>/dev/null)
        if [ -n \"$log_files\" ]; then
            local permission_issues=0
            while IFS= read -r log_file; do
                if [ -w \"$log_file\" ]; then
                    if [ \"$VERBOSE\" = true ]; then
                        log_success \"✅ 日志文件可写: $(basename \"$log_file\")\"
                    fi
                else
                    log_error \"❌ 日志文件不可写: $(basename \"$log_file\")\"
                    ((permission_issues++))
                fi
            done <<< \"$log_files\"
            
            if [ $permission_issues -eq 0 ]; then
                log_success \"✅ 所有日志文件权限正常\"
            else
                log_error \"❌ $permission_issues 个日志文件权限异常\"
                ((issues++))
            fi
        fi
    else
        log_error \"❌ 日志目录不存在\"
        ((issues++))
    fi
    
    return $issues
}

# 生成验证报告
generate_validation_report() {
    local total_issues=\"$1\"
    local report_file=\"$PROJECT_DIR/logs/migration_validation_$(date +%Y%m%d_%H%M%S).md\"
    
    log_info \"生成验证报告: $report_file\"
    
    cat > \"$report_file\" << EOF
# TKE 文档同步系统 - 迁移验证报告

生成时间: $(date)
验证用户: $(whoami)
项目目录: $PROJECT_DIR

## 验证摘要

- 发现问题: $total_issues 个
- systemd 服务: $([ -f \"$SERVICE_FILE\" ] && echo \"❌ 仍存在\" || echo \"✅ 已删除\")
- cron 作业: $(crontab -l 2>/dev/null | grep -q \"tke_dify_sync\" && echo \"✅ 已配置\" || echo \"❌ 未配置\")
- 项目文件: $([ -f \"$PROJECT_DIR/tke_dify_sync.py\" ] && echo \"✅ 完整\" || echo \"❌ 缺失\")

## 详细检查结果

### systemd 服务状态
- 服务文件: $([ -f \"$SERVICE_FILE\" ] && echo \"存在（需要删除）\" || echo \"已删除\")
- 服务运行状态: $(systemctl is-active \"$SERVICE_NAME\" 2>/dev/null || echo \"未运行\")
- 服务启用状态: $(systemctl is-enabled \"$SERVICE_NAME\" 2>/dev/null || echo \"未启用\")

### cron 配置状态
- cron 服务: $(systemctl is-active cron 2>/dev/null || systemctl is-active crond 2>/dev/null || echo \"未运行\")
- TKE cron 作业数量: $(crontab -l 2>/dev/null | grep -c \"tke_dify_sync\\|tke-dify\" || echo 0)

### 当前 cron 作业
\\`\\`\\`
$(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" || echo \"无相关 cron 作业\")
\\`\\`\\`

### 项目文件状态
- 主脚本: $([ -f \"$PROJECT_DIR/tke_dify_sync.py\" ] && echo \"存在\" || echo \"缺失\")
- 配置文件: $([ -f \"$PROJECT_DIR/.env\" ] && echo \"存在\" || echo \"缺失\")
- Python 环境: $([ -f \"$PROJECT_DIR/venv/bin/python\" ] && echo \"存在\" || echo \"缺失\")
- 日志目录: $([ -d \"$PROJECT_DIR/logs\" ] && echo \"存在\" || echo \"缺失\")
- 数据目录: $([ -d \"$PROJECT_DIR/data\" ] && echo \"存在\" || echo \"缺失\")

## 建议操作

EOF

    if [ $total_issues -eq 0 ]; then
        echo \"✅ 迁移验证通过，系统配置正确\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"建议的下一步操作：\" >> \"$report_file\"
        echo \"1. 手动测试执行: cd $PROJECT_DIR && ./scripts/start.sh\" >> \"$report_file\"
        echo \"2. 监控 cron 执行: tail -f $PROJECT_DIR/logs/cron*.log\" >> \"$report_file\"
        echo \"3. 定期健康检查: ./scripts/health_check.sh\" >> \"$report_file\"
    else
        echo \"⚠️ 发现 $total_issues 个问题，需要处理\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"问题修复建议：\" >> \"$report_file\"
        
        if [ -f \"$SERVICE_FILE\" ]; then
            echo \"1. 删除 systemd 服务: sudo rm $SERVICE_FILE && sudo systemctl daemon-reload\" >> \"$report_file\"
        fi
        
        if ! crontab -l 2>/dev/null | grep -q \"tke_dify_sync\"; then
            echo \"2. 设置 cron 作业: ./scripts/setup_cron.sh\" >> \"$report_file\"
        fi
        
        echo \"3. 重新运行验证: ./scripts/validate_migration.sh\" >> \"$report_file\"
        echo \"4. 如需帮助，运行: ./scripts/migrate_to_cron.sh --help\" >> \"$report_file\"
    fi
    
    echo \"\" >> \"$report_file\"
    echo \"## 故障排除\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"如果问题持续存在：\" >> \"$report_file\"
    echo \"1. 查看迁移日志: cat $PROJECT_DIR/logs/migration.log\" >> \"$report_file\"
    echo \"2. 运行完整分析: ./scripts/analyze_deployment.sh\" >> \"$report_file\"
    echo \"3. 手动迁移: ./scripts/migrate_to_cron.sh\" >> \"$report_file\"
    
    log_success \"验证报告已生成: $report_file\"
}

# 主函数
main() {
    local verbose=false
    local quiet=false
    local fix_issues=false
    
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
            --fix-issues)
                fix_issues=true
                shift
                ;;
            -*)
                log_error \"未知选项: $1\"
                show_help
                exit 1
                ;;
            *)
                log_error \"未知参数: $1\"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置全局变量
    VERBOSE=$verbose
    QUIET=$quiet
    FIX_ISSUES=$fix_issues
    
    if [ \"$quiet\" != true ]; then
        echo \"🔍 TKE 文档同步系统 - 迁移验证工具\"
        echo \"===================================\"
        echo
        
        if [ \"$fix_issues\" = true ]; then
            echo \"🔧 自动修复模式已启用\"
            echo
        fi
    fi
    
    local total_issues=0
    
    # 执行各项检查
    check_systemd_status
    local systemd_issues=$?
    ((total_issues += systemd_issues))
    
    check_cron_configuration
    local cron_issues=$?
    ((total_issues += cron_issues))
    
    check_project_integrity
    local project_issues=$?
    ((total_issues += project_issues))
    
    test_script_execution
    local execution_issues=$?
    ((total_issues += execution_issues))
    
    check_log_files
    local log_issues=$?
    ((total_issues += log_issues))
    
    # 生成报告
    if [ \"$quiet\" != true ]; then
        generate_validation_report \"$total_issues\"
        
        echo
        echo \"🎯 验证结果摘要\"
        echo \"===============\"
        
        if [ $total_issues -eq 0 ]; then
            log_success \"✅ 迁移验证通过！系统已成功迁移到 cron 调度方式\"
        else
            log_warning \"⚠️ 发现 $total_issues 个问题需要处理\"
            
            if [ \"$fix_issues\" != true ]; then
                echo
                log_info \"💡 提示: 使用 --fix-issues 选项自动修复部分问题\"
            fi
        fi
        
        echo
        echo \"📊 问题分布:\"
        echo \"  systemd 相关: $systemd_issues 个\"
        echo \"  cron 相关: $cron_issues 个\"
        echo \"  项目文件: $project_issues 个\"
        echo \"  脚本执行: $execution_issues 个\"
        echo \"  日志文件: $log_issues 个\"
    fi
    
    exit $total_issues
}

# 运行主函数
main \"$@\"
"