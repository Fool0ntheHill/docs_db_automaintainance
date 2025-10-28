#!/bin/bash

# TKE 文档同步系统 - 日志轮转测试
# 测试日志文件的创建、轮转和清理功能

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
TEST_LOG=\"$PROJECT_DIR/logs/log_rotation_test_$(date +%Y%m%d_%H%M%S).log\"
TEST_LOG_DIR=\"/tmp/tke_log_test_$$\"

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 确保目录存在
mkdir -p \"$PROJECT_DIR/logs\"
mkdir -p \"$TEST_LOG_DIR\"

# 清理函数
cleanup() {
    rm -rf \"$TEST_LOG_DIR\" 2>/dev/null || true
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

# 测试日志目录权限
test_log_directory_permissions() {
    echo \"📁 测试日志目录权限\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        if [ -w \"$PROJECT_DIR/logs\" ]; then
            log_success \"日志目录可写\"
        else
            log_error \"日志目录不可写\"
        fi
    else
        log_error \"日志目录不存在\"
    fi
}

# 测试日志文件创建
test_log_file_creation() {
    echo
    echo \"📝 测试日志文件创建\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    local test_log_file=\"$PROJECT_DIR/logs/test_creation_$(date +%s).log\"
    
    if echo \"Test log entry $(date)\" > \"$test_log_file\" 2>/dev/null; then
        log_success \"可以创建日志文件\"
        rm \"$test_log_file\" 2>/dev/null || true
    else
        log_error \"无法创建日志文件\"
    fi
}

# 测试大文件处理
test_large_log_handling() {
    echo
    echo \"📊 测试大日志文件处理\"
    echo \"=====================\"
    ((TOTAL_TESTS++))
    
    local large_log=\"$TEST_LOG_DIR/large_test.log\"
    
    # 创建一个大文件 (约1MB)
    for i in {1..1000}; do
        echo \"This is test log line $i with some additional content to make it longer $(date)\" >> \"$large_log\"
    done
    
    local file_size=$(stat -c%s \"$large_log\" 2>/dev/null || stat -f%z \"$large_log\" 2>/dev/null)
    if [ $file_size -gt 50000 ]; then
        log_success \"可以处理大日志文件 (${file_size} bytes)\"
    else
        log_error \"大日志文件创建失败\"
    fi
}

# 测试日志轮转配置
test_logrotate_configuration() {
    echo
    echo \"🔄 测试 logrotate 配置\"
    echo \"=====================\"
    ((TOTAL_TESTS++))
    
    local logrotate_config=\"/etc/logrotate.d/tke-dify-sync\"
    
    if [ -f \"$logrotate_config\" ]; then
        log_success \"logrotate 配置文件存在\"
        
        # 验证配置语法
        if logrotate -d \"$logrotate_config\" >/dev/null 2>&1; then
            log_success \"logrotate 配置语法正确\"
        else
            log_error \"logrotate 配置语法错误\"
        fi
    else
        log_warning \"logrotate 配置文件不存在\"
    fi
}

# 测试手动日志轮转
test_manual_log_rotation() {
    echo
    echo \"🔧 测试手动日志轮转\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    local test_log=\"$TEST_LOG_DIR/rotation_test.log\"
    
    # 创建测试日志文件
    echo \"Original log content\" > \"$test_log\"
    
    # 模拟轮转
    if [ -f \"$test_log\" ]; then
        mv \"$test_log\" \"${test_log}.1\"
        touch \"$test_log\"
        
        if [ -f \"${test_log}.1\" ] && [ -f \"$test_log\" ]; then
            log_success \"手动日志轮转成功\"
        else
            log_error \"手动日志轮转失败\"
        fi
    else
        log_error \"无法创建测试日志文件\"
    fi
}

# 测试日志清理功能
test_log_cleanup() {
    echo
    echo \"🧹 测试日志清理功能\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    # 创建一些旧的测试日志文件
    local old_logs=(\"old1.log\" \"old2.log\" \"old3.log\")
    
    for log_file in \"${old_logs[@]}\"; do
        echo \"Old log content\" > \"$TEST_LOG_DIR/$log_file\"
        # 设置文件为8天前
        touch -d \"8 days ago\" \"$TEST_LOG_DIR/$log_file\"
    done
    
    # 创建一个新的日志文件
    echo \"New log content\" > \"$TEST_LOG_DIR/new.log\"
    
    # 执行清理 (删除7天前的文件)
    local deleted_count=$(find \"$TEST_LOG_DIR\" -name \"*.log\" -mtime +7 -delete -print | wc -l)
    
    if [ $deleted_count -eq 3 ]; then
        log_success \"日志清理功能正常 (删除了 $deleted_count 个旧文件)\"
    else
        log_error \"日志清理功能异常 (删除了 $deleted_count 个文件，期望3个)\"
    fi
    
    # 验证新文件仍然存在
    if [ -f \"$TEST_LOG_DIR/new.log\" ]; then
        log_success \"新日志文件保留正常\"
    else
        log_error \"新日志文件被误删\"
    fi
}

# 测试 cron 日志清理作业
test_cron_log_cleanup() {
    echo
    echo \"⏰ 测试 cron 日志清理作业\"
    echo \"========================\"
    ((TOTAL_TESTS++))
    
    # 检查是否有日志清理的 cron 作业
    if crontab -l 2>/dev/null | grep -q \"find.*logs.*-delete\\|logrotate\"; then
        log_success \"发现日志清理 cron 作业\"
        
        # 显示相关的 cron 作业
        log_info \"日志清理 cron 作业:\"
        crontab -l 2>/dev/null | grep \"find.*logs.*-delete\\|logrotate\" | while read -r job; do
            log_info \"  $job\"
        done
    else
        log_warning \"未发现日志清理 cron 作业\"
    fi
}

# 测试日志文件权限
test_log_file_permissions() {
    echo
    echo \"🔒 测试日志文件权限\"
    echo \"==================\"
    ((TOTAL_TESTS++))
    
    local permission_issues=0
    
    # 检查现有日志文件权限
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        while IFS= read -r -d '' log_file; do
            local perms=$(stat -c \"%a\" \"$log_file\" 2>/dev/null || stat -f \"%A\" \"$log_file\" 2>/dev/null)
            
            # 检查权限是否合理 (644, 664, 或类似)
            if [[ \"$perms\" =~ ^[0-7][0-7][0-4]$ ]]; then
                log_info \"$(basename \"$log_file\"): 权限正常 ($perms)\"
            else
                log_warning \"$(basename \"$log_file\"): 权限可能不安全 ($perms)\"
                ((permission_issues++))
            fi
        done < <(find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f -print0 2>/dev/null)
        
        if [ $permission_issues -eq 0 ]; then
            log_success \"所有日志文件权限正常\"
        else
            log_error \"$permission_issues 个日志文件权限异常\"
        fi
    else
        log_error \"日志目录不存在\"
    fi
}

# 测试日志文件大小监控
test_log_size_monitoring() {
    echo
    echo \"📏 测试日志文件大小监控\"
    echo \"=======================\"
    ((TOTAL_TESTS++))
    
    local large_files=0
    local total_size=0
    
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        while IFS= read -r -d '' log_file; do
            local size=$(stat -c%s \"$log_file\" 2>/dev/null || stat -f%z \"$log_file\" 2>/dev/null)
            total_size=$((total_size + size))
            
            # 检查是否有超过10MB的文件
            if [ $size -gt 10485760 ]; then
                log_warning \"$(basename \"$log_file\"): 文件较大 ($(($size/1024/1024))MB)\"
                ((large_files++))
            fi
        done < <(find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f -print0 2>/dev/null)
        
        log_info \"日志目录总大小: $(($total_size/1024/1024))MB\"
        
        if [ $large_files -eq 0 ]; then
            log_success \"所有日志文件大小正常\"
        else
            log_warning \"发现 $large_files 个大型日志文件\"
        fi
    else
        log_error \"日志目录不存在\"
    fi
}

# 测试日志格式一致性
test_log_format_consistency() {
    echo
    echo \"📋 测试日志格式一致性\"
    echo \"=====================\"
    ((TOTAL_TESTS++))
    
    local format_issues=0
    
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        while IFS= read -r -d '' log_file; do
            # 检查日志文件是否包含时间戳
            if head -5 \"$log_file\" | grep -q \"[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\|[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}\"; then
                log_info \"$(basename \"$log_file\"): 包含时间戳\"
            else
                log_warning \"$(basename \"$log_file\"): 可能缺少时间戳\"
                ((format_issues++))
            fi
        done < <(find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f -size +0c -print0 2>/dev/null)
        
        if [ $format_issues -eq 0 ]; then
            log_success \"日志格式一致性良好\"
        else
            log_warning \"$format_issues 个日志文件格式可能有问题\"
        fi
    else
        log_error \"日志目录不存在\"
    fi
}

# 创建 logrotate 配置模板
create_logrotate_template() {
    echo
    echo \"📄 创建 logrotate 配置模板\"
    echo \"==========================\"
    
    local template_file=\"$PROJECT_DIR/logrotate.conf.template\"
    
    cat > \"$template_file\" << EOF
# TKE 文档同步系统 - logrotate 配置
# 复制到 /etc/logrotate.d/tke-dify-sync

$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $(whoami) $(whoami)
    postrotate
        # 可以在这里添加重启服务的命令
        # systemctl reload tke-dify-sync || true
    endscript
}
EOF
    
    log_success \"logrotate 配置模板已创建: $template_file\"
    log_info \"使用方法: sudo cp $template_file /etc/logrotate.d/tke-dify-sync\"
}

# 生成日志轮转测试报告
generate_log_rotation_report() {
    local report_file=\"$PROJECT_DIR/logs/log_rotation_test_report_$(date +%Y%m%d_%H%M%S).md\"
    
    log_info \"生成日志轮转测试报告: $report_file\"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    
    cat > \"$report_file\" << EOF
# TKE 文档同步系统 - 日志轮转测试报告

生成时间: $(date)
测试用户: $(whoami)
项目目录: $PROJECT_DIR

## 测试摘要

- 总测试数: $TOTAL_TESTS
- 通过测试: $PASSED_TESTS
- 失败测试: $FAILED_TESTS
- 成功率: ${success_rate}%

## 日志目录分析

### 当前日志文件
$(if [ -d \"$PROJECT_DIR/logs\" ]; then
    ls -la \"$PROJECT_DIR/logs\"/*.log 2>/dev/null | while read -r line; do
        echo \"- $line\"
    done
else
    echo \"- 日志目录不存在\"
fi)

### 日志文件大小统计
$(if [ -d \"$PROJECT_DIR/logs\" ]; then
    find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f -exec ls -lh {} \\; 2>/dev/null | awk '{print \"- \" $9 \": \" $5}'
else
    echo \"- 无日志文件\"
fi)

### 磁盘使用情况
$(df -h \"$PROJECT_DIR/logs\" 2>/dev/null | tail -1 | awk '{print \"- 可用空间: \" $4 \" (\" $5 \" 已使用)\"}')

## logrotate 配置状态

$(if [ -f \"/etc/logrotate.d/tke-dify-sync\" ]; then
    echo \"✅ logrotate 配置已安装\"
    echo \"\"
    echo \"配置内容:\"
    echo \"\\`\\`\\`\"
    cat \"/etc/logrotate.d/tke-dify-sync\"
    echo \"\\`\\`\\`\"
else
    echo \"❌ logrotate 配置未安装\"
    echo \"\"
    echo \"建议安装配置文件到 /etc/logrotate.d/tke-dify-sync\"
fi)

## cron 日志清理作业

$(if crontab -l 2>/dev/null | grep -q \"find.*logs.*-delete\\|logrotate\"; then
    echo \"✅ 发现日志清理 cron 作业\"
    echo \"\"
    echo \"\\`\\`\\`\"
    crontab -l 2>/dev/null | grep \"find.*logs.*-delete\\|logrotate\"
    echo \"\\`\\`\\`\"
else
    echo \"❌ 未发现日志清理 cron 作业\"
    echo \"\"
    echo \"建议添加日志清理 cron 作业\"
fi)

## 建议和优化

EOF

    if [ $FAILED_TESTS -eq 0 ]; then
        echo \"✅ 日志轮转配置正确，系统运行良好\" >> \"$report_file\"
    else
        echo \"⚠️ 发现 $FAILED_TESTS 个问题，建议修复：\" >> \"$report_file\"
        echo \"\" >> \"$report_file\"
        echo \"1. 确保日志目录权限正确\" >> \"$report_file\"
        echo \"2. 配置 logrotate 进行自动轮转\" >> \"$report_file\"
        echo \"3. 设置 cron 作业清理旧日志\" >> \"$report_file\"
        echo \"4. 监控日志文件大小\" >> \"$report_file\"
    fi
    
    echo \"\" >> \"$report_file\"
    echo \"## 最佳实践建议\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"1. **自动轮转**: 使用 logrotate 每日轮转日志文件\" >> \"$report_file\"
    echo \"2. **压缩存储**: 压缩旧的日志文件以节省空间\" >> \"$report_file\"
    echo \"3. **保留策略**: 保留最近7天的日志文件\" >> \"$report_file\"
    echo \"4. **权限控制**: 确保日志文件权限安全\" >> \"$report_file\"
    echo \"5. **监控告警**: 监控日志目录磁盘使用情况\" >> \"$report_file\"
    
    echo \"\" >> \"$report_file\"
    echo \"## 配置命令\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"### 安装 logrotate 配置\" >> \"$report_file\"
    echo \"\\`\\`\\`bash\" >> \"$report_file\"
    echo \"sudo cp $PROJECT_DIR/logrotate.conf.template /etc/logrotate.d/tke-dify-sync\" >> \"$report_file\"
    echo \"sudo logrotate -d /etc/logrotate.d/tke-dify-sync  # 测试配置\" >> \"$report_file\"
    echo \"\\`\\`\\`\" >> \"$report_file\"
    echo \"\" >> \"$report_file\"
    echo \"### 添加日志清理 cron 作业\" >> \"$report_file\"
    echo \"\\`\\`\\`bash\" >> \"$report_file\"
    echo \"# 每周清理7天前的日志文件\" >> \"$report_file\"
    echo \"echo \\\"0 1 * * 0 find $PROJECT_DIR/logs -name '*.log' -mtime +7 -delete\\\" | crontab -\" >> \"$report_file\"
    echo \"\\`\\`\\`\" >> \"$report_file\"
    
    log_success \"日志轮转测试报告已生成: $report_file\"
}

# 主函数
main() {
    echo \"📄 TKE 文档同步系统 - 日志轮转测试\"
    echo \"==================================\"
    echo
    echo \"测试日志: $TEST_LOG\"
    echo
    
    # 记录测试开始
    log_message \"开始日志轮转测试\"
    
    # 执行测试
    test_log_directory_permissions
    test_log_file_creation
    test_large_log_handling
    test_logrotate_configuration
    test_manual_log_rotation
    test_log_cleanup
    test_cron_log_cleanup
    test_log_file_permissions
    test_log_size_monitoring
    test_log_format_consistency
    
    # 创建配置模板
    create_logrotate_template
    
    # 生成报告
    generate_log_rotation_report
    
    echo
    echo \"🎯 日志轮转测试结果\"
    echo \"==================\"
    echo \"总测试数: $TOTAL_TESTS\"
    echo \"通过测试: $PASSED_TESTS\"
    echo \"失败测试: $FAILED_TESTS\"
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    echo \"成功率: ${success_rate}%\"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success \"✅ 日志轮转测试全部通过！\"
    else
        log_error \"❌ $FAILED_TESTS 个测试失败，需要修复\"
    fi
    
    log_message \"日志轮转测试完成，通过: $PASSED_TESTS, 失败: $FAILED_TESTS\"
    exit $FAILED_TESTS
}

# 运行主函数
main \"$@\"