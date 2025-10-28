#!/bin/bash

# TKE 文档同步系统 - cron 部署测试套件
# 全面测试基于 cron 的部署配置和功能

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
TEST_LOG=\"$PROJECT_DIR/logs/cron_deployment_test_$(date +%Y%m%d_%H%M%S).log\"
TEMP_DIR=\"/tmp/tke_cron_test_$$\"

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 确保日志目录存在
mkdir -p \"$PROJECT_DIR/logs\"
mkdir -p \"$TEMP_DIR\"

# 清理函数
cleanup() {
    rm -rf \"$TEMP_DIR\" 2>/dev/null || true
}
trap cleanup EXIT

# 日志函数
log_message() {
    echo \"$(date '+%Y-%m-%d %H:%M:%S'): $1\" >> \"$TEST_LOG\"
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

# 测试结果记录
record_test_result() {
    local test_name=\"$1\"
    local result=\"$2\"
    local message=\"$3\"
    
    ((TOTAL_TESTS++))
    
    case \"$result\" in
        \"pass\")
            ((PASSED_TESTS++))
            log_success \"$test_name: $message\"
            ;;
        \"fail\")
            ((FAILED_TESTS++))
            log_error \"$test_name: $message\"
            ;;
        \"skip\")
            ((SKIPPED_TESTS++))
            log_skip \"$test_name: $message\"
            ;;
    esac
}

# 显示帮助信息
show_help() {
    echo \"TKE 文档同步系统 - cron 部署测试套件\"
    echo \"====================================\"
    echo
    echo \"用法: $0 [选项]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help          显示此帮助信息\"
    echo \"  -v, --verbose       详细输出\"
    echo \"  -q, --quiet         静默模式\"
    echo \"  -t, --test TYPE     运行特定类型的测试\"
    echo \"  --skip-slow         跳过耗时的测试\"
    echo \"  --cleanup-only      仅执行清理操作\"
    echo
    echo \"测试类型:\"
    echo \"  basic              基础配置测试\"
    echo \"  cron               cron 作业测试\"
    echo \"  multi-kb           多知识库测试\"
    echo \"  logging            日志记录测试\"
    echo \"  integration        集成测试\"
    echo \"  all                所有测试（默认）\"
    echo
    echo \"示例:\"
    echo \"  $0                  # 运行所有测试\"
    echo \"  $0 -t basic         # 仅运行基础测试\"
    echo \"  $0 -v --skip-slow   # 详细输出，跳过慢测试\"
    echo
}
"# 基
础配置测试
test_basic_configuration() {
    echo
    echo \"🔧 基础配置测试\"
    echo \"===============\"
    
    # 测试项目目录结构
    local required_dirs=(\"logs\" \"data\" \"scripts\")
    for dir in \"${required_dirs[@]}\"; do
        if [ -d \"$PROJECT_DIR/$dir\" ]; then
            record_test_result \"目录结构\" \"pass\" \"$dir 目录存在\"
        else
            record_test_result \"目录结构\" \"fail\" \"$dir 目录不存在\"
        fi
    done
    
    # 测试关键文件
    local required_files=(
        \"tke_dify_sync.py\"
        \".env\"
        \"venv/bin/python\"
        \"scripts/monitor.sh\"
        \"scripts/health_check.sh\"
    )
    
    for file in \"${required_files[@]}\"; do
        if [ -f \"$PROJECT_DIR/$file\" ]; then
            record_test_result \"关键文件\" \"pass\" \"$file 存在\"
        else
            record_test_result \"关键文件\" \"fail\" \"$file 不存在\"
        fi
    done
    
    # 测试 Python 环境
    if cd \"$PROJECT_DIR\" && \"$PROJECT_DIR/venv/bin/python\" --version >/dev/null 2>&1; then
        local python_version=$(\"$PROJECT_DIR/venv/bin/python\" --version 2>&1)
        record_test_result \"Python环境\" \"pass\" \"Python 环境正常 ($python_version)\"
    else
        record_test_result \"Python环境\" \"fail\" \"Python 环境异常\"
    fi
    
    # 测试配置文件语法
    if [ -f \"$PROJECT_DIR/.env\" ]; then
        local required_vars=(\"DIFY_API_KEY\" \"DIFY_KNOWLEDGE_BASE_ID\" \"DIFY_API_BASE_URL\")
        local missing_vars=0
        
        for var in \"${required_vars[@]}\"; do
            if grep -q \"^$var=\" \"$PROJECT_DIR/.env\"; then
                record_test_result \"配置项\" \"pass\" \"$var 已配置\"
            else
                record_test_result \"配置项\" \"fail\" \"$var 未配置\"
                ((missing_vars++))
            fi
        done
        
        if [ $missing_vars -eq 0 ]; then
            record_test_result \"配置完整性\" \"pass\" \"所有必需配置项都存在\"
        else
            record_test_result \"配置完整性\" \"fail\" \"缺少 $missing_vars 个必需配置项\"
        fi
    else
        record_test_result \"配置文件\" \"fail\" \"主配置文件不存在\"
    fi
    
    # 测试脚本权限
    local scripts=(\"monitor.sh\" \"health_check.sh\" \"start.sh\")
    for script in \"${scripts[@]}\"; do
        if [ -f \"$PROJECT_DIR/scripts/$script\" ]; then
            if [ -x \"$PROJECT_DIR/scripts/$script\" ]; then
                record_test_result \"脚本权限\" \"pass\" \"$script 可执行\"
            else
                record_test_result \"脚本权限\" \"fail\" \"$script 不可执行\"
            fi
        else
            record_test_result \"脚本权限\" \"skip\" \"$script 不存在\"
        fi
    done
}

# cron 作业测试
test_cron_jobs() {
    echo
    echo \"🕐 cron 作业测试\"
    echo \"===============\"
    
    # 检查 cron 服务状态
    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
        record_test_result \"cron服务\" \"pass\" \"cron 服务正在运行\"
    else
        record_test_result \"cron服务\" \"fail\" \"cron 服务未运行\"
    fi
    
    # 检查 TKE 相关 cron 作业
    if crontab -l 2>/dev/null | grep -q \"tke_dify_sync\\|tke-dify\"; then
        local job_count=$(crontab -l 2>/dev/null | grep -c \"tke_dify_sync\\|tke-dify\" || echo 0)
        record_test_result \"cron作业\" \"pass\" \"发现 $job_count 个 TKE 相关 cron 作业\"
        
        # 验证 cron 作业语法
        crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" | while read -r job; do
            # 简单的语法检查
            if echo \"$job\" | grep -E '^[0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ .*' >/dev/null; then
                record_test_result \"cron语法\" \"pass\" \"cron 作业语法正确\"
            else
                record_test_result \"cron语法\" \"fail\" \"cron 作业语法可能有误: $job\"
            fi
        done
    else
        record_test_result \"cron作业\" \"fail\" \"未发现 TKE 相关 cron 作业\"
    fi
    
    # 测试 cron 作业创建
    local test_cron=\"*/5 * * * * echo 'test' > /tmp/tke_cron_test_$$\"
    echo \"$test_cron\" | crontab - 2>/dev/null
    if [ $? -eq 0 ]; then
        record_test_result \"cron创建\" \"pass\" \"可以创建 cron 作业\"
        # 清理测试 cron 作业
        crontab -r 2>/dev/null || true
    else
        record_test_result \"cron创建\" \"fail\" \"无法创建 cron 作业\"
    fi
    
    # 测试 cron 环境变量
    local test_env_cron=\"* * * * * env > $TEMP_DIR/cron_env.log\"
    echo \"$test_env_cron\" | crontab - 2>/dev/null
    if [ $? -eq 0 ]; then
        record_test_result \"cron环境\" \"pass\" \"可以测试 cron 环境变量\"
        sleep 65  # 等待 cron 执行
        if [ -f \"$TEMP_DIR/cron_env.log\" ]; then
            record_test_result \"cron执行\" \"pass\" \"cron 作业可以执行\"
        else
            record_test_result \"cron执行\" \"fail\" \"cron 作业未执行\"
        fi
        crontab -r 2>/dev/null || true
    else
        record_test_result \"cron环境\" \"skip\" \"无法创建测试 cron 作业\"
    fi
}

# 多知识库配置测试
test_multi_kb_configuration() {
    echo
    echo \"📚 多知识库配置测试\"
    echo \"==================\"
    
    # 检查多知识库配置文件
    local multi_kb_configs=()
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ] && [[ \"$(basename \"$config_file\")\" != \".env.example\" ]]; then
            multi_kb_configs+=(\"$(basename \"$config_file\")\")
        fi
    done
    
    if [ ${#multi_kb_configs[@]} -gt 0 ]; then
        record_test_result \"多知识库配置\" \"pass\" \"发现 ${#multi_kb_configs[@]} 个知识库配置\"
        
        # 验证每个配置文件
        for config in \"${multi_kb_configs[@]}\"; do
            local config_path=\"$PROJECT_DIR/$config\"
            
            # 检查必需配置项
            local required_vars=(\"DIFY_API_KEY\" \"DIFY_KNOWLEDGE_BASE_ID\" \"DIFY_API_BASE_URL\")
            local valid_config=true
            
            for var in \"${required_vars[@]}\"; do
                if ! grep -q \"^$var=\" \"$config_path\"; then
                    valid_config=false
                    break
                fi
            done
            
            if [ \"$valid_config\" = true ]; then
                record_test_result \"配置验证\" \"pass\" \"$config 配置完整\"
            else
                record_test_result \"配置验证\" \"fail\" \"$config 配置不完整\"
            fi
        done
        
        # 测试配置切换
        if [ -f \"$PROJECT_DIR/.env\" ]; then
            local original_env=\"$TEMP_DIR/original.env\"
            cp \"$PROJECT_DIR/.env\" \"$original_env\"
            
            for config in \"${multi_kb_configs[@]}\"; do
                if cp \"$PROJECT_DIR/$config\" \"$PROJECT_DIR/.env\" 2>/dev/null; then
                    record_test_result \"配置切换\" \"pass\" \"可以切换到 $config\"
                else
                    record_test_result \"配置切换\" \"fail\" \"无法切换到 $config\"
                fi
            done
            
            # 恢复原始配置
            cp \"$original_env\" \"$PROJECT_DIR/.env\"
        fi
    else
        record_test_result \"多知识库配置\" \"skip\" \"未发现多知识库配置\"
    fi
    
    # 测试多知识库 cron 调度
    if crontab -l 2>/dev/null | grep -q \"cp .env\\..*\\.env\"; then
        record_test_result \"多知识库调度\" \"pass\" \"发现多知识库 cron 调度\"
    else
        record_test_result \"多知识库调度\" \"skip\" \"未发现多知识库 cron 调度\"
    fi
}

# 日志记录测试
test_logging_functionality() {
    echo
    echo \"📄 日志记录测试\"
    echo \"===============\"
    
    # 测试日志目录权限
    if [ -w \"$PROJECT_DIR/logs\" ]; then
        record_test_result \"日志目录权限\" \"pass\" \"日志目录可写\"
    else
        record_test_result \"日志目录权限\" \"fail\" \"日志目录不可写\"
    fi
    
    # 测试日志文件创建
    local test_log=\"$PROJECT_DIR/logs/test_$(date +%s).log\"
    if echo \"test log entry\" > \"$test_log\" 2>/dev/null; then
        record_test_result \"日志文件创建\" \"pass\" \"可以创建日志文件\"
        rm \"$test_log\" 2>/dev/null || true
    else
        record_test_result \"日志文件创建\" \"fail\" \"无法创建日志文件\"
    fi
    
    # 检查现有日志文件
    local log_files=$(find \"$PROJECT_DIR/logs\" -name \"*.log\" 2>/dev/null | wc -l)
    if [ $log_files -gt 0 ]; then
        record_test_result \"现有日志\" \"pass\" \"发现 $log_files 个日志文件\"
        
        # 检查日志文件大小
        local large_logs=$(find \"$PROJECT_DIR/logs\" -name \"*.log\" -size +10M 2>/dev/null | wc -l)
        if [ $large_logs -gt 0 ]; then
            record_test_result \"日志大小\" \"warn\" \"发现 $large_logs 个大型日志文件 (>10MB)\"
        else
            record_test_result \"日志大小\" \"pass\" \"日志文件大小正常\"
        fi
    else
        record_test_result \"现有日志\" \"skip\" \"未发现现有日志文件\"
    fi
    
    # 测试日志轮转配置
    if [ -f \"/etc/logrotate.d/tke-dify-sync\" ]; then
        record_test_result \"日志轮转\" \"pass\" \"logrotate 配置存在\"
    else
        record_test_result \"日志轮转\" \"skip\" \"logrotate 配置不存在\"
    fi
    
    # 测试 cron 日志输出重定向
    if crontab -l 2>/dev/null | grep \"tke_dify_sync\" | grep -q \">> .*\\.log 2>&1\"; then
        record_test_result \"日志重定向\" \"pass\" \"cron 作业配置了日志重定向\"
    else
        record_test_result \"日志重定向\" \"fail\" \"cron 作业未配置日志重定向\"
    fi
}

# 集成测试
test_integration() {
    echo
    echo \"🔗 集成测试\"
    echo \"===========\"
    
    if [ \"$SKIP_SLOW\" = true ]; then
        record_test_result \"集成测试\" \"skip\" \"跳过耗时的集成测试\"
        return
    fi
    
    # 测试脚本语法检查
    if cd \"$PROJECT_DIR\" && \"$PROJECT_DIR/venv/bin/python\" -m py_compile tke_dify_sync.py 2>/dev/null; then
        record_test_result \"脚本语法\" \"pass\" \"主脚本语法正确\"
    else
        record_test_result \"脚本语法\" \"fail\" \"主脚本语法错误\"
    fi
    
    # 测试依赖包
    local required_packages=(\"requests\" \"beautifulsoup4\" \"python-dotenv\")
    for package in \"${required_packages[@]}\"; do
        if \"$PROJECT_DIR/venv/bin/python\" -c \"import $package\" 2>/dev/null; then
            record_test_result \"依赖包\" \"pass\" \"$package 已安装\"
        else
            record_test_result \"依赖包\" \"fail\" \"$package 未安装\"
        fi
    done
    
    # 测试网络连接
    if curl -s --connect-timeout 10 https://cloud.tencent.com >/dev/null 2>&1; then
        record_test_result \"网络连接\" \"pass\" \"可以连接到腾讯云\"
    else
        record_test_result \"网络连接\" \"fail\" \"无法连接到腾讯云\"
    fi
    
    # 测试 Dify API 连接（如果配置了）
    if [ -f \"$PROJECT_DIR/.env\" ]; then
        local api_url=$(grep \"^DIFY_API_BASE_URL=\" \"$PROJECT_DIR/.env\" | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\")
        local api_key=$(grep \"^DIFY_API_KEY=\" \"$PROJECT_DIR/.env\" | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\")
        
        if [ -n \"$api_url\" ] && [ -n \"$api_key\" ] && [[ \"$api_key\" != *\"your-key-here\"* ]]; then
            if curl -s --connect-timeout 10 -H \"Authorization: Bearer $api_key\" \"$api_url/datasets\" >/dev/null 2>&1; then
                record_test_result \"Dify API\" \"pass\" \"可以连接到 Dify API\"
            else
                record_test_result \"Dify API\" \"fail\" \"无法连接到 Dify API\"
            fi
        else
            record_test_result \"Dify API\" \"skip\" \"Dify API 配置不完整\"
        fi
    fi
    
    # 测试脚本快速执行
    local timeout_cmd=\"timeout 30s\"
    if command -v timeout >/dev/null 2>&1; then
        if cd \"$PROJECT_DIR\" && $timeout_cmd \"$PROJECT_DIR/venv/bin/python\" tke_dify_sync.py --help >/dev/null 2>&1; then
            record_test_result \"脚本执行\" \"pass\" \"脚本可以正常启动\"
        else
            record_test_result \"脚本执行\" \"fail\" \"脚本启动失败或超时\"
        fi
    else
        record_test_result \"脚本执行\" \"skip\" \"timeout 命令不可用\"
    fi
    
    # 测试监控脚本
    if [ -f \"$PROJECT_DIR/scripts/monitor.sh\" ]; then
        if \"$PROJECT_DIR/scripts/monitor.sh\" --test >/dev/null 2>&1; then
            record_test_result \"监控脚本\" \"pass\" \"监控脚本可以执行\"
        else
            record_test_result \"监控脚本\" \"fail\" \"监控脚本执行失败\"
        fi
    else
        record_test_result \"监控脚本\" \"skip\" \"监控脚本不存在\"
    fi
    
    # 测试健康检查脚本
    if [ -f \"$PROJECT_DIR/scripts/health_check.sh\" ]; then
        if \"$PROJECT_DIR/scripts/health_check.sh\" --quick >/dev/null 2>&1; then
            record_test_result \"健康检查\" \"pass\" \"健康检查脚本可以执行\"
        else
            record_test_result \"健康检查\" \"fail\" \"健康检查脚本执行失败\"
        fi
    else
        record_test_result \"健康检查\" \"skip\" \"健康检查脚本不存在\"
    fi
}

# 性能测试
test_performance() {
    echo
    echo \"⚡ 性能测试\"
    echo \"===========\"
    
    if [ \"$SKIP_SLOW\" = true ]; then
        record_test_result \"性能测试\" \"skip\" \"跳过耗时的性能测试\"
        return
    fi
    
    # 测试磁盘空间
    local available_space=$(df \"$PROJECT_DIR\" | awk 'NR==2 {print $4}')
    local required_space=1048576  # 1GB in KB
    
    if [ $available_space -gt $required_space ]; then
        record_test_result \"磁盘空间\" \"pass\" \"可用空间充足 ($(($available_space/1024))MB)\"
    else
        record_test_result \"磁盘空间\" \"warn\" \"可用空间不足 ($(($available_space/1024))MB)\"
    fi
    
    # 测试内存使用
    local available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ $available_memory -gt 512 ]; then
        record_test_result \"内存\" \"pass\" \"可用内存充足 (${available_memory}MB)\"
    else
        record_test_result \"内存\" \"warn\" \"可用内存不足 (${available_memory}MB)\"
    fi
    
    # 测试 Python 启动时间
    local start_time=$(date +%s%N)
    \"$PROJECT_DIR/venv/bin/python\" -c \"import sys; sys.exit(0)\" 2>/dev/null
    local end_time=$(date +%s%N)
    local startup_time=$(( (end_time - start_time) / 1000000 ))  # 转换为毫秒
    
    if [ $startup_time -lt 1000 ]; then
        record_test_result \"Python启动\" \"pass\" \"Python 启动时间正常 (${startup_time}ms)\"
    else
        record_test_result \"Python启动\" \"warn\" \"Python 启动时间较慢 (${startup_time}ms)\"
    fi
}

# 安全测试
test_security() {
    echo
    echo \"🔒 安全测试\"
    echo \"===========\"
    
    # 检查配置文件权限
    if [ -f \"$PROJECT_DIR/.env\" ]; then
        local env_perms=$(stat -c \"%a\" \"$PROJECT_DIR/.env\" 2>/dev/null || stat -f \"%A\" \"$PROJECT_DIR/.env\" 2>/dev/null)
        if [[ \"$env_perms\" =~ ^[0-7]00$ ]]; then
            record_test_result \"配置文件权限\" \"pass\" \"配置文件权限安全 ($env_perms)\"
        else
            record_test_result \"配置文件权限\" \"warn\" \"配置文件权限可能不安全 ($env_perms)\"
        fi
    fi
    
    # 检查敏感信息泄露
    if grep -r \"password\\|secret\\|token\" \"$PROJECT_DIR\"/*.py 2>/dev/null | grep -v \"#\" | grep -v \"example\"; then
        record_test_result \"敏感信息\" \"warn\" \"代码中可能包含敏感信息\"
    else
        record_test_result \"敏感信息\" \"pass\" \"未发现明文敏感信息\"
    fi
    
    # 检查日志文件权限
    local log_perms_issues=0
    find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f 2>/dev/null | while read -r log_file; do
        local log_perms=$(stat -c \"%a\" \"$log_file\" 2>/dev/null || stat -f \"%A\" \"$log_file\" 2>/dev/null)
        if [[ ! \"$log_perms\" =~ ^[0-7][0-7][0-4]$ ]]; then
            ((log_perms_issues++))
        fi
    done
    
    if [ $log_perms_issues -eq 0 ]; then
        record_test_result \"日志文件权限\" \"pass\" \"日志文件权限正常\"
    else
        record_test_result \"日志文件权限\" \"warn\" \"$log_perms_issues 个日志文件权限可能不安全\"
    fi
}

# 生成测试报告
generate_test_report() {
    local report_file=\"$PROJECT_DIR/logs/cron_deployment_test_report_$(date +%Y%m%d_%H%M%S).md\"
    
    log_info \"生成测试报告: $report_file\"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    cat > \"$report_file\" << EOF
# TKE 文档同步系统 - cron 部署测试报告

生成时间: $(date)
测试用户: $(whoami)
项目目录: $PROJECT_DIR

## 测试摘要

- 总测试数: $TOTAL_TESTS
- 通过测试: $PASSED_TESTS
- 失败测试: $FAILED_TESTS
- 跳过测试: $SKIPPED_TESTS
- 成功率: ${success_rate}%

## 测试结果分析

### 状态分布
- ✅ 通过: $PASSED_TESTS 个测试
- ❌ 失败: $FAILED_TESTS 个测试
- ⏭️ 跳过: $SKIPPED_TESTS 个测试

### 详细日志
详细的测试执行日志请查看: $TEST_LOG

## 建议操作

EOF

    if [ $FAILED_TESTS -eq 0 ]; then
        echo \"✅ 所有测试通过，cron 部署配置正确\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"系统已准备好进行生产部署。\" >> \"$report_file\"
    else
        echo \"⚠️ 发现 $FAILED_TESTS 个失败的测试，需要修复\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"建议操作：\" >> \"$report_file\"
        echo \"1. 查看详细日志: cat $TEST_LOG\" >> \"$report_file\"
        echo \"2. 修复失败的测试项\" >> \"$report_file\"
        echo \"3. 重新运行测试: $0\" >> \"$report_file\"
    fi
    
    if [ $SKIPPED_TESTS -gt 0 ]; then
        echo \"\" >> \"$report_file\"
        echo \"注意: $SKIPPED_TESTS 个测试被跳过，可能需要额外配置\" >> \"$report_file\"
    fi
    
    echo \"\" >> \"$report_file\"
    echo \"## 系统信息\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"- 操作系统: $(uname -s) $(uname -r)\" >> \"$report_file\"
    echo \"- Python 版本: $(\"$PROJECT_DIR/venv/bin/python\" --version 2>&1)\" >> \"$report_file\"
    echo \"- cron 服务: $(systemctl is-active cron 2>/dev/null || systemctl is-active crond 2>/dev/null || echo \"未知\")\" >> \"$report_file\"
    echo \"- 磁盘空间: $(df -h \"$PROJECT_DIR\" | awk 'NR==2 {print $4}') 可用\" >> \"$report_file\"
    
    log_success \"测试报告已生成: $report_file\"
}

# 主函数
main() {
    local verbose=false
    local quiet=false
    local test_type=\"all\"
    local skip_slow=false
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
            -t|--test)
                test_type=\"$2\"
                shift 2
                ;;
            --skip-slow)
                skip_slow=true
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
    VERBOSE=$verbose
    QUIET=$quiet
    SKIP_SLOW=$skip_slow
    
    if [ \"$cleanup_only\" = true ]; then
        log_info \"执行清理操作...\"
        cleanup
        exit 0
    fi
    
    if [ \"$quiet\" != true ]; then
        echo \"🧪 TKE 文档同步系统 - cron 部署测试套件\"
        echo \"=========================================\"
        echo
        echo \"测试类型: $test_type\"
        if [ \"$skip_slow\" = true ]; then
            echo \"跳过耗时测试: 是\"
        fi
        echo \"测试日志: $TEST_LOG\"
        echo
    fi
    
    # 记录测试开始
    log_message \"开始 cron 部署测试，类型: $test_type\"
    
    # 根据测试类型执行相应测试
    case \"$test_type\" in
        \"basic\")
            test_basic_configuration
            ;;
        \"cron\")
            test_cron_jobs
            ;;
        \"multi-kb\")
            test_multi_kb_configuration
            ;;
        \"logging\")
            test_logging_functionality
            ;;
        \"integration\")
            test_integration
            ;;
        \"performance\")
            test_performance
            ;;
        \"security\")
            test_security
            ;;
        \"all\")
            test_basic_configuration
            test_cron_jobs
            test_multi_kb_configuration
            test_logging_functionality
            test_integration
            test_performance
            test_security
            ;;
        *)
            log_error \"未知的测试类型: $test_type\"
            show_help
            exit 1
            ;;
    esac
    
    # 生成报告和摘要
    if [ \"$quiet\" != true ]; then
        generate_test_report
        
        echo
        echo \"🎯 测试结果摘要\"
        echo \"===============\"
        echo \"总测试数: $TOTAL_TESTS\"
        echo \"通过测试: $PASSED_TESTS\"
        echo \"失败测试: $FAILED_TESTS\"
        echo \"跳过测试: $SKIPPED_TESTS\"
        
        local success_rate=0
        if [ $TOTAL_TESTS -gt 0 ]; then
            success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
        fi
        echo \"成功率: ${success_rate}%\"
        
        if [ $FAILED_TESTS -eq 0 ]; then
            log_success \"✅ 所有测试通过！cron 部署配置正确\"
        else
            log_error \"❌ $FAILED_TESTS 个测试失败，需要修复\"
        fi
    fi
    
    log_message \"测试完成，通过: $PASSED_TESTS, 失败: $FAILED_TESTS, 跳过: $SKIPPED_TESTS\"
    exit $FAILED_TESTS
}

# 运行主函数
main \"$@\"