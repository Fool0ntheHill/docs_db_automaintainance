#!/bin/bash

# TKE 文档同步系统 - 完整测试套件运行器
# 运行所有 cron 部署相关的测试

set -e

# 颜色定义
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[0;34m'
CYAN='\\033[0;36m'
NC='\\033[0m' # No Color

# 配置
SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"
PROJECT_DIR=\"$(dirname \"$SCRIPT_DIR\")\"
MASTER_LOG=\"$PROJECT_DIR/logs/all_tests_$(date +%Y%m%d_%H%M%S).log\"

# 测试套件列表
TEST_SUITES=(
    \"test_cron_deployment.sh:基础 cron 部署测试\"
    \"test_multi_kb_scheduling.sh:多知识库调度测试\"
    \"test_log_rotation.sh:日志轮转测试\"
    \"validate_migration.sh:迁移验证测试\"
)

# 测试统计
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# 确保日志目录存在
mkdir -p \"$PROJECT_DIR/logs\"

# 日志函数
log_message() {
    echo \"$(date '+%Y-%m-%d %H:%M:%S'): $1\" >> \"$MASTER_LOG\"
}

log_info() {
    echo -e \"${BLUE}[INFO]${NC} $1\"
    log_message \"INFO: $1\"
}

log_success() {
    echo -e \"${GREEN}[PASS]${NC} $1\"
    log_message \"PASS: $1\"
}

log_error() {
    echo -e \"${RED}[FAIL]${NC} $1\"
    log_message \"FAIL: $1\"
}

log_warning() {
    echo -e \"${YELLOW}[WARN]${NC} $1\"
    log_message \"WARN: $1\"
}

log_skip() {
    echo -e \"${CYAN}[SKIP]${NC} $1\"
    log_message \"SKIP: $1\"
}

# 显示帮助信息
show_help() {
    echo \"TKE 文档同步系统 - 完整测试套件\"
    echo \"==============================\"
    echo
    echo \"用法: $0 [选项]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help          显示此帮助信息\"
    echo \"  -v, --verbose       详细输出\"
    echo \"  -q, --quiet         静默模式\"
    echo \"  -f, --fast          快速模式（跳过耗时测试）\"
    echo \"  -s, --suite NAME    仅运行指定的测试套件\"
    echo \"  --continue-on-fail  测试失败时继续执行\"
    echo \"  --cleanup-only      仅执行清理操作\"
    echo
    echo \"可用的测试套件:\"
    for suite_info in \"${TEST_SUITES[@]}\"; do
        local suite_name=$(echo \"$suite_info\" | cut -d':' -f1)
        local suite_desc=$(echo \"$suite_info\" | cut -d':' -f2)
        echo \"  $suite_name - $suite_desc\"
    done
    echo
    echo \"示例:\"
    echo \"  $0                              # 运行所有测试\"
    echo \"  $0 -f                           # 快速测试\"
    echo \"  $0 -s test_cron_deployment.sh   # 仅运行指定测试\"
    echo \"  $0 -v --continue-on-fail        # 详细输出，失败时继续\"
    echo
}

# 检查测试环境
check_test_environment() {
    echo \"🔍 检查测试环境\"
    echo \"===============\"
    
    local env_issues=0
    
    # 检查项目目录
    if [ ! -d \"$PROJECT_DIR\" ]; then
        log_error \"项目目录不存在: $PROJECT_DIR\"
        ((env_issues++))
    fi
    
    # 检查关键文件
    local required_files=(\"tke_dify_sync.py\" \".env\")
    for file in \"${required_files[@]}\"; do
        if [ ! -f \"$PROJECT_DIR/$file\" ]; then
            log_error \"关键文件缺失: $file\"
            ((env_issues++))
        fi
    done
    
    # 检查 Python 环境
    if [ ! -f \"$PROJECT_DIR/venv/bin/python\" ]; then
        log_error \"Python 虚拟环境不存在\"
        ((env_issues++))
    fi
    
    # 检查脚本目录
    if [ ! -d \"$SCRIPT_DIR\" ]; then
        log_error \"脚本目录不存在: $SCRIPT_DIR\"
        ((env_issues++))
    fi
    
    # 检查测试脚本
    for suite_info in \"${TEST_SUITES[@]}\"; do
        local suite_name=$(echo \"$suite_info\" | cut -d':' -f1)
        if [ ! -f \"$SCRIPT_DIR/$suite_name\" ]; then
            log_warning \"测试脚本不存在: $suite_name\"
        fi
    done
    
    if [ $env_issues -eq 0 ]; then
        log_success \"测试环境检查通过\"
        return 0
    else
        log_error \"测试环境检查发现 $env_issues 个问题\"
        return 1
    fi
}

# 运行单个测试套件
run_test_suite() {
    local suite_name=\"$1\"
    local suite_desc=\"$2\"
    local fast_mode=\"$3\"
    local verbose=\"$4\"
    
    echo
    echo \"🧪 运行测试套件: $suite_desc\"
    echo \"$(printf '=%.0s' {1..50})\"
    
    ((TOTAL_SUITES++))
    
    local suite_path=\"$SCRIPT_DIR/$suite_name\"
    
    if [ ! -f \"$suite_path\" ]; then
        log_skip \"$suite_name: 测试脚本不存在\"
        ((SKIPPED_SUITES++))
        return 0
    fi
    
    # 构建测试命令
    local test_cmd=\"$suite_path\"
    
    if [ \"$fast_mode\" = true ]; then
        test_cmd=\"$test_cmd --skip-slow\"
    fi
    
    if [ \"$verbose\" = true ]; then
        test_cmd=\"$test_cmd -v\"
    elif [ \"$QUIET\" = true ]; then
        test_cmd=\"$test_cmd -q\"
    fi
    
    # 运行测试
    local start_time=$(date +%s)
    local suite_log=\"$PROJECT_DIR/logs/${suite_name%.*}_$(date +%Y%m%d_%H%M%S).log\"
    
    log_info \"开始执行: $suite_name\"
    log_message \"开始测试套件: $suite_name\"
    
    if $test_cmd > \"$suite_log\" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success \"$suite_name: 测试通过 (${duration}s)\"
        log_message \"测试套件通过: $suite_name (${duration}s)\"
        ((PASSED_SUITES++))
        
        if [ \"$verbose\" = true ]; then
            echo \"详细输出: $suite_log\"
        fi
        
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error \"$suite_name: 测试失败 (${duration}s)\"
        log_message \"测试套件失败: $suite_name (${duration}s)\"
        ((FAILED_SUITES++))
        
        echo \"错误日志: $suite_log\"
        if [ \"$verbose\" = true ]; then
            echo \"最后几行输出:\"
            tail -10 \"$suite_log\" | while read -r line; do
                echo \"  $line\"
            done
        fi
        
        return 1
    fi
}

# 生成综合测试报告
generate_comprehensive_report() {
    local report_file=\"$PROJECT_DIR/logs/comprehensive_test_report_$(date +%Y%m%d_%H%M%S).md\"
    
    log_info \"生成综合测试报告: $report_file\"
    
    local success_rate=0
    if [ $TOTAL_SUITES -gt 0 ]; then
        success_rate=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
    fi
    
    cat > \"$report_file\" << EOF
# TKE 文档同步系统 - 综合测试报告

生成时间: $(date)
测试用户: $(whoami)
项目目录: $PROJECT_DIR

## 测试摘要

- 总测试套件: $TOTAL_SUITES
- 通过套件: $PASSED_SUITES
- 失败套件: $FAILED_SUITES
- 跳过套件: $SKIPPED_SUITES
- 成功率: ${success_rate}%

## 测试套件结果

EOF

    for suite_info in \"${TEST_SUITES[@]}\"; do
        local suite_name=$(echo \"$suite_info\" | cut -d':' -f1)
        local suite_desc=$(echo \"$suite_info\" | cut -d':' -f2)
        
        # 查找最新的测试日志
        local latest_log=$(find \"$PROJECT_DIR/logs\" -name \"${suite_name%.*}_*.log\" -type f 2>/dev/null | sort | tail -1)
        
        if [ -n \"$latest_log\" ]; then
            echo \"### $suite_desc\" >> \"$report_file\"
            echo \"\" >> \"$report_file\"
            echo \"- 脚本: $suite_name\" >> \"$report_file\"
            echo \"- 日志: $(basename \"$latest_log\")\" >> \"$report_file\"
            
            # 尝试从日志中提取结果
            if grep -q \"测试全部通过\\|所有测试通过\" \"$latest_log\" 2>/dev/null; then
                echo \"- 状态: ✅ 通过\" >> \"$report_file\"
            elif grep -q \"测试失败\\|个测试失败\" \"$latest_log\" 2>/dev/null; then
                echo \"- 状态: ❌ 失败\" >> \"$report_file\"
            else
                echo \"- 状态: ⏭️ 跳过\" >> \"$report_file\"
            fi
            echo \"\" >> \"$report_file\"
        else
            echo \"### $suite_desc\" >> \"$report_file\"
            echo \"\" >> \"$report_file\"
            echo \"- 脚本: $suite_name\" >> \"$report_file\"
            echo \"- 状态: ⏭️ 未运行\" >> \"$report_file\"
            echo \"\" >> \"$report_file\"
        fi
    done
    
    cat >> \"$report_file\" << EOF

## 系统状态概览

### cron 配置
\\`\\`\\`
$(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" || echo \"无相关 cron 作业\")
\\`\\`\\`

### systemd 服务状态
$(if [ -f \"/etc/systemd/system/tke-dify-sync.service\" ]; then
    echo \"⚠️ systemd 服务文件仍然存在\"
else
    echo \"✅ systemd 服务文件已删除\"
fi)

### 项目文件状态
- 主脚本: $([ -f \"$PROJECT_DIR/tke_dify_sync.py\" ] && echo \"✅ 存在\" || echo \"❌ 缺失\")
- 配置文件: $([ -f \"$PROJECT_DIR/.env\" ] && echo \"✅ 存在\" || echo \"❌ 缺失\")
- Python 环境: $([ -f \"$PROJECT_DIR/venv/bin/python\" ] && echo \"✅ 存在\" || echo \"❌ 缺失\")
- 日志目录: $([ -d \"$PROJECT_DIR/logs\" ] && echo \"✅ 存在\" || echo \"❌ 缺失\")

### 多知识库配置
$(for config in \"$PROJECT_DIR\"/.env.*; do
    if [ -f \"$config\" ]; then
        basename_config=$(basename \"$config\")
        if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
            echo \"- $basename_config\"
        fi
    fi
done)

## 建议操作

EOF

    if [ $FAILED_SUITES -eq 0 ]; then
        echo \"✅ 所有测试套件通过，系统配置正确\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"系统已准备好进行生产部署。建议定期运行测试以确保系统健康。\" >> \"$report_file\"
    else
        echo \"⚠️ $FAILED_SUITES 个测试套件失败，需要修复\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"建议操作：\" >> \"$report_file\"
        echo \"1. 查看失败的测试日志了解具体问题\" >> \"$report_file\"
        echo \"2. 修复发现的配置问题\" >> \"$report_file\"
        echo \"3. 重新运行失败的测试套件\" >> \"$report_file\"
        echo \"4. 运行完整测试确保所有问题已解决\" >> \"$report_file\"
    fi
    
    if [ $SKIPPED_SUITES -gt 0 ]; then
        echo \"\" >> \"$report_file\"
        echo \"注意: $SKIPPED_SUITES 个测试套件被跳过，可能需要额外配置或依赖。\" >> \"$report_file\"
    fi
    
    echo \"\" >> \"$report_file\"
    echo \"## 详细日志\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"主日志文件: $MASTER_LOG\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"各测试套件的详细日志:\" >> \"$report_file\"
    find \"$PROJECT_DIR/logs\" -name \"*test*.log\" -type f -newer \"$MASTER_LOG\" 2>/dev/null | while read -r log_file; do
        echo \"- $(basename \"$log_file\")\" >> \"$report_file\"
    done
    
    log_success \"综合测试报告已生成: $report_file\"
}

# 清理测试文件
cleanup_test_files() {
    log_info \"清理测试文件...\"
    
    # 清理临时测试文件
    find \"/tmp\" -name \"tke_*_test_*\" -type d -mtime +1 -exec rm -rf {} \\; 2>/dev/null || true
    find \"/tmp\" -name \"*tke*test*\" -type f -mtime +1 -delete 2>/dev/null || true
    
    # 清理旧的测试日志（保留最近7天）
    find \"$PROJECT_DIR/logs\" -name \"*test*.log\" -mtime +7 -delete 2>/dev/null || true
    
    log_success \"测试文件清理完成\"
}

# 主函数
main() {
    local verbose=false
    local quiet=false
    local fast_mode=false
    local specific_suite=\"\"
    local continue_on_fail=false
    local cleanup_only=false
    
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
            -f|--fast)
                fast_mode=true
                shift
                ;;
            -s|--suite)
                specific_suite=\"$2\"
                shift 2
                ;;
            --continue-on-fail)
                continue_on_fail=true
                shift
                ;;
            --cleanup-only)
                cleanup_only=true
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
    QUIET=$quiet
    
    if [ \"$cleanup_only\" = true ]; then
        cleanup_test_files
        exit 0
    fi
    
    if [ \"$quiet\" != true ]; then
        echo \"🧪 TKE 文档同步系统 - 完整测试套件\"
        echo \"===================================\"
        echo
        echo \"主日志: $MASTER_LOG\"
        if [ \"$fast_mode\" = true ]; then
            echo \"模式: 快速测试\"
        fi
        if [ -n \"$specific_suite\" ]; then
            echo \"指定套件: $specific_suite\"
        fi
        echo
    fi
    
    # 记录测试开始
    log_message \"开始完整测试套件\"
    
    # 检查测试环境
    if ! check_test_environment; then
        log_error \"测试环境检查失败，退出\"
        exit 1
    fi
    
    # 运行测试套件
    if [ -n \"$specific_suite\" ]; then
        # 运行指定的测试套件
        local found=false
        for suite_info in \"${TEST_SUITES[@]}\"; do
            local suite_name=$(echo \"$suite_info\" | cut -d':' -f1)
            local suite_desc=$(echo \"$suite_info\" | cut -d':' -f2)
            
            if [ \"$suite_name\" = \"$specific_suite\" ]; then
                run_test_suite \"$suite_name\" \"$suite_desc\" \"$fast_mode\" \"$verbose\"
                found=true
                break
            fi
        done
        
        if [ \"$found\" = false ]; then
            log_error \"未找到测试套件: $specific_suite\"
            exit 1
        fi
    else
        # 运行所有测试套件
        for suite_info in \"${TEST_SUITES[@]}\"; do
            local suite_name=$(echo \"$suite_info\" | cut -d':' -f1)
            local suite_desc=$(echo \"$suite_info\" | cut -d':' -f2)
            
            if ! run_test_suite \"$suite_name\" \"$suite_desc\" \"$fast_mode\" \"$verbose\"; then
                if [ \"$continue_on_fail\" != true ]; then
                    log_error \"测试套件失败，停止执行\"
                    break
                fi
            fi
        done
    fi
    
    # 生成综合报告
    if [ \"$quiet\" != true ]; then
        generate_comprehensive_report
        
        echo
        echo \"🎯 完整测试结果摘要\"
        echo \"==================\"
        echo \"总测试套件: $TOTAL_SUITES\"
        echo \"通过套件: $PASSED_SUITES\"
        echo \"失败套件: $FAILED_SUITES\"
        echo \"跳过套件: $SKIPPED_SUITES\"
        
        local success_rate=0
        if [ $TOTAL_SUITES -gt 0 ]; then
            success_rate=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
        fi
        echo \"成功率: ${success_rate}%\"
        
        if [ $FAILED_SUITES -eq 0 ]; then
            log_success \"✅ 所有测试套件通过！系统配置正确\"
        else
            log_error \"❌ $FAILED_SUITES 个测试套件失败，需要修复\"
        fi
        
        echo
        echo \"📋 详细信息:\"
        echo \"  主日志: $MASTER_LOG\"
        echo \"  测试报告: 查看 logs/ 目录中的最新报告\"
    fi
    
    # 清理测试文件
    cleanup_test_files
    
    log_message \"完整测试套件完成，通过: $PASSED_SUITES, 失败: $FAILED_SUITES, 跳过: $SKIPPED_SUITES\"
    exit $FAILED_SUITES
}

# 运行主函数
main \"$@\"