#!/bin/bash

# TKE 文档同步系统 - 多知识库调度测试
# 专门测试多知识库的 cron 调度配置和冲突检测

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
TEST_LOG=\"$PROJECT_DIR/logs/multi_kb_scheduling_test_$(date +%Y%m%d_%H%M%S).log\"

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 确保日志目录存在
mkdir -p \"$PROJECT_DIR/logs\"

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
    ((PASSED_TESTS++))
}

log_error() {
    echo -e \"${RED}[FAIL]${NC} $1\"
    log_message \"FAIL: $1\"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e \"${YELLOW}[WARN]${NC} $1\"
    log_message \"WARN: $1\"
}

# 测试多知识库配置文件存在性
test_multi_kb_configs() {
    echo \"🔍 测试多知识库配置文件\"
    echo \"======================\"
    ((TOTAL_TESTS++))
    
    local kb_configs=()
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ]; then
            local basename_config=$(basename \"$config_file\")
            if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                kb_configs+=(\"$basename_config\")
            fi
        fi
    done
    
    if [ ${#kb_configs[@]} -gt 1 ]; then
        log_success \"发现 ${#kb_configs[@]} 个知识库配置文件\"
        for config in \"${kb_configs[@]}\"; do
            log_info \"  - $config\"
        done
        return 0
    elif [ ${#kb_configs[@]} -eq 1 ]; then
        log_warning \"仅发现 1 个知识库配置文件，无法测试多知识库调度\"
        return 1
    else
        log_error \"未发现任何知识库配置文件\"
        return 1
    fi
}

# 测试配置文件完整性
test_config_completeness() {
    echo
    echo \"📋 测试配置文件完整性\"
    echo \"===================\"
    
    local required_vars=(\"DIFY_API_KEY\" \"DIFY_KNOWLEDGE_BASE_ID\" \"DIFY_API_BASE_URL\")
    
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ]; then
            local basename_config=$(basename \"$config_file\")
            if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                ((TOTAL_TESTS++))
                
                local missing_vars=()
                for var in \"${required_vars[@]}\"; do
                    if ! grep -q \"^$var=\" \"$config_file\"; then
                        missing_vars+=(\"$var\")
                    fi
                done
                
                if [ ${#missing_vars[@]} -eq 0 ]; then
                    log_success \"$basename_config 配置完整\"
                else
                    log_error \"$basename_config 缺少配置项: ${missing_vars[*]}\"
                fi
            fi
        fi
    done
}

# 测试知识库 ID 唯一性
test_kb_id_uniqueness() {
    echo
    echo \"🆔 测试知识库 ID 唯一性\"
    echo \"=====================\"
    ((TOTAL_TESTS++))
    
    local kb_ids=()
    local duplicate_found=false
    
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ]; then
            local basename_config=$(basename \"$config_file\")
            if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                local kb_id=$(grep \"^DIFY_KNOWLEDGE_BASE_ID=\" \"$config_file\" | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\")
                if [ -n \"$kb_id\" ]; then
                    # 检查是否已存在
                    for existing_id in \"${kb_ids[@]}\"; do
                        if [ \"$existing_id\" = \"$kb_id\" ]; then
                            log_error \"发现重复的知识库 ID: $kb_id\"
                            duplicate_found=true
                        fi
                    done
                    kb_ids+=(\"$kb_id\")
                fi
            fi
        fi
    done
    
    if [ \"$duplicate_found\" = false ]; then
        log_success \"所有知识库 ID 都是唯一的\"
    fi
}

# 测试 cron 调度时间冲突
test_cron_scheduling_conflicts() {
    echo
    echo \"⏰ 测试 cron 调度时间冲突\"
    echo \"=======================\"
    ((TOTAL_TESTS++))
    
    if ! crontab -l 2>/dev/null | grep -q \"tke_dify_sync\\|tke-dify\"; then
        log_error \"未发现 TKE 相关的 cron 作业\"
        return 1
    fi
    
    # 提取所有 TKE 相关 cron 作业的时间
    local cron_times=()
    while IFS= read -r cron_job; do
        # 提取时间部分 (前5个字段)
        local time_part=$(echo \"$cron_job\" | awk '{print $1\" \"$2\" \"$3\" \"$4\" \"$5}')
        cron_times+=(\"$time_part\")
    done < <(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\")
    
    # 检查时间冲突
    local conflicts_found=false
    for i in \"${!cron_times[@]}\"; do
        for j in \"${!cron_times[@]}\"; do
            if [ $i -ne $j ] && [ \"${cron_times[i]}\" = \"${cron_times[j]}\" ]; then
                log_error \"发现 cron 调度时间冲突: ${cron_times[i]}\"
                conflicts_found=true
            fi
        done
    done
    
    if [ \"$conflicts_found\" = false ]; then
        log_success \"未发现 cron 调度时间冲突\"
    fi
    
    # 检查调度间隔是否合理
    local schedule_intervals=()
    for time_part in \"${cron_times[@]}\"; do
        # 简单解析小时字段
        local hour=$(echo \"$time_part\" | awk '{print $2}')
        if [[ \"$hour\" =~ ^[0-9]+$ ]]; then
            schedule_intervals+=(\"$hour\")
        fi
    done
    
    # 检查是否有足够的间隔
    if [ ${#schedule_intervals[@]} -gt 1 ]; then
        local sorted_intervals=($(printf '%s\\n' \"${schedule_intervals[@]}\" | sort -n))
        local min_interval=24
        for i in $(seq 1 $((${#sorted_intervals[@]} - 1))); do
            local interval=$((${sorted_intervals[i]} - ${sorted_intervals[i-1]}))
            if [ $interval -lt $min_interval ]; then
                min_interval=$interval
            fi
        done
        
        if [ $min_interval -ge 1 ]; then
            log_success \"调度间隔合理 (最小间隔: ${min_interval}小时)\"
        else
            log_warning \"调度间隔可能过短 (最小间隔: ${min_interval}小时)\"
        fi
    fi
}

# 测试日志文件分离
test_log_file_separation() {
    echo
    echo \"📄 测试日志文件分离\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    # 检查 cron 作业是否使用了不同的日志文件
    local log_files=()
    while IFS= read -r cron_job; do
        # 提取日志文件路径
        local log_file=$(echo \"$cron_job\" | grep -o '>> [^[:space:]]*.log' | cut -d' ' -f2)
        if [ -n \"$log_file\" ]; then
            log_files+=(\"$log_file\")
        fi
    done < <(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\")
    
    if [ ${#log_files[@]} -eq 0 ]; then
        log_error \"cron 作业未配置日志输出\"
        return 1
    fi
    
    # 检查日志文件是否唯一
    local unique_logs=($(printf '%s\\n' \"${log_files[@]}\" | sort -u))
    
    if [ ${#unique_logs[@]} -eq ${#log_files[@]} ]; then
        log_success \"每个知识库使用独立的日志文件\"
        for log_file in \"${unique_logs[@]}\"; do
            log_info \"  - $log_file\"
        done
    else
        log_warning \"某些知识库共享日志文件\"
    fi
}

# 测试状态文件分离
test_state_file_separation() {
    echo
    echo \"💾 测试状态文件分离\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    local state_files=()
    
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ]; then
            local basename_config=$(basename \"$config_file\")
            if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                local state_file=$(grep \"^STATE_FILE=\" \"$config_file\" | cut -d'=' -f2- | tr -d '\"' | tr -d \"'\")
                if [ -n \"$state_file\" ]; then
                    state_files+=(\"$state_file\")
                fi
            fi
        fi
    done
    
    if [ ${#state_files[@]} -eq 0 ]; then
        log_warning \"未在配置文件中发现 STATE_FILE 配置\"
        return 0
    fi
    
    # 检查状态文件是否唯一
    local unique_states=($(printf '%s\\n' \"${state_files[@]}\" | sort -u))
    
    if [ ${#unique_states[@]} -eq ${#state_files[@]} ]; then
        log_success \"每个知识库使用独立的状态文件\"
        for state_file in \"${unique_states[@]}\"; do
            log_info \"  - $state_file\"
        done
    else
        log_error \"某些知识库共享状态文件，可能导致数据冲突\"
    fi
}

# 测试配置切换机制
test_config_switching() {
    echo
    echo \"🔄 测试配置切换机制\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    # 检查 cron 作业是否包含配置切换命令
    local switching_jobs=0
    while IFS= read -r cron_job; do
        if echo \"$cron_job\" | grep -q \"cp .env\\.\"; then
            ((switching_jobs++))
        fi
    done < <(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\")
    
    if [ $switching_jobs -gt 0 ]; then
        log_success \"发现 $switching_jobs 个使用配置切换的 cron 作业\"
    else
        log_warning \"未发现使用配置切换的 cron 作业\"
    fi
    
    # 测试配置切换的实际执行
    if [ -f \"$PROJECT_DIR/.env\" ]; then
        local original_env=\"/tmp/original_env_$$\"
        cp \"$PROJECT_DIR/.env\" \"$original_env\"
        
        local switch_success=true
        for config_file in \"$PROJECT_DIR\"/.env.*; do
            if [ -f \"$config_file\" ]; then
                local basename_config=$(basename \"$config_file\")
                if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                    if ! cp \"$config_file\" \"$PROJECT_DIR/.env\" 2>/dev/null; then
                        switch_success=false
                        break
                    fi
                fi
            fi
        done
        
        # 恢复原始配置
        cp \"$original_env\" \"$PROJECT_DIR/.env\"
        rm \"$original_env\"
        
        if [ \"$switch_success\" = true ]; then
            log_success \"配置切换机制工作正常\"
        else
            log_error \"配置切换机制存在问题\"
        fi
    else
        log_warning \"主配置文件不存在，无法测试配置切换\"
    fi
}

# 测试并发执行保护
test_concurrent_execution_protection() {
    echo
    echo \"🔒 测试并发执行保护\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    # 检查是否有锁文件机制
    if grep -r \"lock\\|pid\" \"$PROJECT_DIR\"/*.py 2>/dev/null | grep -v \"#\" >/dev/null; then
        log_success \"代码中包含锁定机制\"
    else
        log_warning \"未发现并发执行保护机制\"
    fi
    
    # 检查 cron 作业是否有适当的间隔
    local cron_jobs=($(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" | wc -l))
    if [ $cron_jobs -gt 1 ]; then
        log_info \"发现 $cron_jobs 个 cron 作业，建议确保有足够的执行间隔\"
    fi
}

# 模拟多知识库调度执行
test_simulated_execution() {
    echo
    echo \"🎭 模拟多知识库调度执行\"
    echo \"======================\"
    ((TOTAL_TESTS++))
    
    local simulation_success=true
    local configs_tested=0
    
    for config_file in \"$PROJECT_DIR\"/.env.*; do
        if [ -f \"$config_file\" ]; then
            local basename_config=$(basename \"$config_file\")
            if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
                log_info \"模拟执行配置: $basename_config\"
                
                # 备份当前配置
                local backup_env=\"/tmp/backup_env_$$\"
                if [ -f \"$PROJECT_DIR/.env\" ]; then
                    cp \"$PROJECT_DIR/.env\" \"$backup_env\"
                fi
                
                # 切换配置
                if cp \"$config_file\" \"$PROJECT_DIR/.env\" 2>/dev/null; then
                    # 测试脚本语法
                    if cd \"$PROJECT_DIR\" && \"$PROJECT_DIR/venv/bin/python\" -m py_compile tke_dify_sync.py 2>/dev/null; then
                        log_info \"  ✅ $basename_config 语法检查通过\"
                        ((configs_tested++))
                    else
                        log_error \"  ❌ $basename_config 语法检查失败\"
                        simulation_success=false
                    fi
                else
                    log_error \"  ❌ 无法切换到 $basename_config\"
                    simulation_success=false
                fi
                
                # 恢复配置
                if [ -f \"$backup_env\" ]; then
                    cp \"$backup_env\" \"$PROJECT_DIR/.env\"
                    rm \"$backup_env\"
                fi
            fi
        fi
    done
    
    if [ \"$simulation_success\" = true ] && [ $configs_tested -gt 0 ]; then
        log_success \"模拟执行测试通过 (测试了 $configs_tested 个配置)\"
    else
        log_error \"模拟执行测试失败\"
    fi
}

# 生成多知识库调度报告
generate_scheduling_report() {
    local report_file=\"$PROJECT_DIR/logs/multi_kb_scheduling_report_$(date +%Y%m%d_%H%M%S).md\"
    
    log_info \"生成多知识库调度报告: $report_file\"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    cat > \"$report_file\" << EOF
# TKE 文档同步系统 - 多知识库调度测试报告

生成时间: $(date)
测试用户: $(whoami)
项目目录: $PROJECT_DIR

## 测试摘要

- 总测试数: $TOTAL_TESTS
- 通过测试: $PASSED_TESTS
- 失败测试: $FAILED_TESTS
- 成功率: ${success_rate}%

## 多知识库配置分析

### 发现的配置文件
$(for config in \"$PROJECT_DIR\"/.env.*; do
    if [ -f \"$config\" ]; then
        basename_config=$(basename \"$config\")
        if [[ \"$basename_config\" != \".env.example\" ]] && [[ \"$basename_config\" != \".env.template\" ]]; then
            echo \"- $basename_config\"
        fi
    fi
done)

### 当前 cron 调度
\\`\\`\\`
$(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" || echo \"无相关 cron 作业\")
\\`\\`\\`

## 调度分析

### 时间分布
$(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" | while read -r job; do
    time_part=$(echo \"$job\" | awk '{print $1\" \"$2\" \"$3\" \"$4\" \"$5}')
    echo \"- $time_part\"
done)

### 日志文件分离
$(crontab -l 2>/dev/null | grep \"tke_dify_sync\\|tke-dify\" | while read -r job; do
    log_file=$(echo \"$job\" | grep -o '>> [^[:space:]]*.log' | cut -d' ' -f2)
    if [ -n \"$log_file\" ]; then
        echo \"- $log_file\"
    fi
done)

## 建议和优化

EOF

    if [ $FAILED_TESTS -eq 0 ]; then
        echo \"✅ 多知识库调度配置正确，无需额外操作\" >> \"$report_file\"
    else
        echo \"⚠️ 发现 $FAILED_TESTS 个问题，建议修复：\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"1. 检查配置文件完整性\" >> \"$report_file\"
        echo \"2. 确保知识库 ID 唯一性\" >> \"$report_file\"
        echo \"3. 避免 cron 调度时间冲突\" >> \"$report_file\"
        echo \"4. 使用独立的日志和状态文件\" >> \"$report_file\"
    fi
    
    echo \"\" >> \"$report_file\"
    echo \"## 最佳实践建议\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"1. **调度间隔**: 建议不同知识库之间至少间隔 1 小时\" >> \"$report_file\"
    echo \"2. **日志分离**: 每个知识库使用独立的日志文件\" >> \"$report_file\"
    echo \"3. **状态分离**: 每个知识库使用独立的状态文件\" >> \"$report_file\"
    echo \"4. **错误处理**: 确保单个知识库的失败不影响其他知识库\" >> \"$report_file\"
    echo \"5. **监控**: 定期检查所有知识库的同步状态\" >> \"$report_file\"
    
    log_success \"多知识库调度报告已生成: $report_file\"
}

# 主函数
main() {
    echo \"📚 TKE 文档同步系统 - 多知识库调度测试\"
    echo \"=======================================\"
    echo
    echo \"测试日志: $TEST_LOG\"
    echo
    
    # 记录测试开始
    log_message \"开始多知识库调度测试\"
    
    # 执行测试
    if test_multi_kb_configs; then
        test_config_completeness
        test_kb_id_uniqueness
        test_cron_scheduling_conflicts
        test_log_file_separation
        test_state_file_separation
        test_config_switching
        test_concurrent_execution_protection
        test_simulated_execution
    else
        log_warning \"跳过多知识库相关测试\"
    fi
    
    # 生成报告
    generate_scheduling_report
    
    echo
    echo \"🎯 多知识库调度测试结果\"
    echo \"======================\"
    echo \"总测试数: $TOTAL_TESTS\"
    echo \"通过测试: $PASSED_TESTS\"
    echo \"失败测试: $FAILED_TESTS\"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    echo \"成功率: ${success_rate}%\"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success \"✅ 多知识库调度测试全部通过！\"
    else
        log_error \"❌ $FAILED_TESTS 个测试失败，需要修复\"
    fi
    
    log_message \"多知识库调度测试完成，通过: $PASSED_TESTS, 失败: $FAILED_TESTS\"
    exit $FAILED_TESTS
}

# 运行主函数
main \"$@\"