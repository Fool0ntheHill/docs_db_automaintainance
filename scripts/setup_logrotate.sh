#!/bin/bash

# TKE 文档同步系统 - logrotate 配置安装脚本
# 安装和配置日志轮转功能

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
LOGROTATE_CONFIG_SOURCE=\"$PROJECT_DIR/config/logrotate.conf\"
LOGROTATE_CONFIG_TARGET=\"/etc/logrotate.d/tke-dify-sync\"
SETUP_LOG=\"$PROJECT_DIR/logs/logrotate_setup_$(date +%Y%m%d_%H%M%S).log\"

# 确保日志目录存在
mkdir -p \"$PROJECT_DIR/logs\"

# 日志函数
log_message() {
    echo \"$(date '+%Y-%m-%d %H:%M:%S'): $1\" >> \"$SETUP_LOG\"
}

log_info() {
    echo -e \"${BLUE}[INFO]${NC} $1\"
    log_message \"INFO: $1\"
}

log_success() {
    echo -e \"${GREEN}[SUCCESS]${NC} $1\"
    log_message \"SUCCESS: $1\"
}

log_error() {
    echo -e \"${RED}[ERROR]${NC} $1\"
    log_message \"ERROR: $1\"
}

log_warning() {
    echo -e \"${YELLOW}[WARNING]${NC} $1\"
    log_message \"WARNING: $1\"
}

# 显示帮助信息
show_help() {
    echo \"TKE 文档同步系统 - logrotate 配置安装脚本\"
    echo \"===========================================\"
    echo
    echo \"用法: $0 [选项]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help          显示此帮助信息\"
    echo \"  -f, --force         强制覆盖现有配置\"
    echo \"  -t, --test          仅测试配置，不安装\"
    echo \"  -r, --remove        删除 logrotate 配置\"
    echo \"  -s, --status        显示当前配置状态\"
    echo \"  --dry-run          模拟运行，显示将要执行的操作\"
    echo
    echo \"示例:\"
    echo \"  $0                  # 安装 logrotate 配置\"
    echo \"  $0 -t               # 测试配置文件\"
    echo \"  $0 -s               # 查看状态\"
    echo \"  $0 -r               # 删除配置\"
    echo
}

# 检查系统要求
check_requirements() {
    log_info \"检查系统要求...\"
    
    # 检查是否为 root 用户或有 sudo 权限
    if [ \"$EUID\" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        log_error \"需要 root 权限或 sudo 权限来安装 logrotate 配置\"
        return 1
    fi
    
    # 检查 logrotate 是否安装
    if ! command -v logrotate >/dev/null 2>&1; then
        log_error \"logrotate 未安装，请先安装 logrotate\"
        log_info \"Ubuntu/Debian: sudo apt-get install logrotate\"
        log_info \"CentOS/RHEL: sudo yum install logrotate\"
        return 1
    fi
    
    # 检查源配置文件是否存在
    if [ ! -f \"$LOGROTATE_CONFIG_SOURCE\" ]; then
        log_error \"源配置文件不存在: $LOGROTATE_CONFIG_SOURCE\"
        return 1
    fi
    
    # 检查项目日志目录
    if [ ! -d \"$PROJECT_DIR/logs\" ]; then
        log_warning \"项目日志目录不存在，将创建: $PROJECT_DIR/logs\"
        mkdir -p \"$PROJECT_DIR/logs\"
    fi
    
    log_success \"系统要求检查通过\"
    return 0
}

# 测试 logrotate 配置
test_logrotate_config() {
    log_info \"测试 logrotate 配置...\"
    
    local temp_config=\"/tmp/tke-dify-sync-logrotate-test\"
    
    # 创建临时配置文件
    cp \"$LOGROTATE_CONFIG_SOURCE\" \"$temp_config\"
    
    # 测试配置语法
    if logrotate -d \"$temp_config\" >/dev/null 2>&1; then
        log_success \"logrotate 配置语法正确\"
        
        # 显示配置详情
        if [ \"$VERBOSE\" = true ]; then
            log_info \"配置详情:\"
            logrotate -d \"$temp_config\" 2>&1 | head -20 | while read -r line; do
                echo \"  $line\"
            done
        fi
        
        rm \"$temp_config\"
        return 0
    else
        log_error \"logrotate 配置语法错误\"
        logrotate -d \"$temp_config\" 2>&1 | head -10 | while read -r line; do
            echo \"  $line\"
        done
        rm \"$temp_config\"
        return 1
    fi
}

# 安装 logrotate 配置
install_logrotate_config() {
    log_info \"安装 logrotate 配置...\"
    
    # 检查目标文件是否已存在
    if [ -f \"$LOGROTATE_CONFIG_TARGET\" ] && [ \"$FORCE\" != true ]; then
        log_warning \"logrotate 配置文件已存在: $LOGROTATE_CONFIG_TARGET\"
        read -p \"是否覆盖现有配置？(y/N): \" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info \"用户取消安装\"
            return 1
        fi
    fi
    
    # 备份现有配置（如果存在）
    if [ -f \"$LOGROTATE_CONFIG_TARGET\" ]; then
        local backup_file=\"${LOGROTATE_CONFIG_TARGET}.backup.$(date +%Y%m%d_%H%M%S)\"
        if [ \"$DRY_RUN\" != true ]; then
            sudo cp \"$LOGROTATE_CONFIG_TARGET\" \"$backup_file\"
            log_info \"现有配置已备份到: $backup_file\"
        else
            echo \"[DRY RUN] 将备份现有配置到: $backup_file\"
        fi
    fi
    
    # 复制配置文件
    if [ \"$DRY_RUN\" != true ]; then
        if sudo cp \"$LOGROTATE_CONFIG_SOURCE\" \"$LOGROTATE_CONFIG_TARGET\"; then
            log_success \"logrotate 配置文件已安装\"
        else
            log_error \"安装 logrotate 配置文件失败\"
            return 1
        fi
        
        # 设置正确的权限
        sudo chmod 644 \"$LOGROTATE_CONFIG_TARGET\"
        sudo chown root:root \"$LOGROTATE_CONFIG_TARGET\"
        
        log_success \"配置文件权限已设置\"
    else
        echo \"[DRY RUN] sudo cp $LOGROTATE_CONFIG_SOURCE $LOGROTATE_CONFIG_TARGET\"
        echo \"[DRY RUN] sudo chmod 644 $LOGROTATE_CONFIG_TARGET\"
        echo \"[DRY RUN] sudo chown root:root $LOGROTATE_CONFIG_TARGET\"
    fi
    
    return 0
}

# 验证安装
verify_installation() {
    log_info \"验证 logrotate 配置安装...\"
    
    # 检查配置文件是否存在
    if [ ! -f \"$LOGROTATE_CONFIG_TARGET\" ]; then
        log_error \"配置文件不存在: $LOGROTATE_CONFIG_TARGET\"
        return 1
    fi
    
    # 测试配置
    if logrotate -d \"$LOGROTATE_CONFIG_TARGET\" >/dev/null 2>&1; then
        log_success \"配置文件语法正确\"
    else
        log_error \"配置文件语法错误\"
        return 1
    fi
    
    # 检查权限
    local perms=$(stat -c \"%a\" \"$LOGROTATE_CONFIG_TARGET\" 2>/dev/null)
    if [ \"$perms\" = \"644\" ]; then
        log_success \"配置文件权限正确 ($perms)\"
    else
        log_warning \"配置文件权限可能不正确 ($perms)\"
    fi
    
    # 测试 logrotate 是否能识别配置
    if logrotate -d /etc/logrotate.conf 2>&1 | grep -q \"tke-dify-sync\"; then
        log_success \"logrotate 已识别 TKE 配置\"
    else
        log_warning \"logrotate 可能未识别 TKE 配置\"
    fi
    
    log_success \"安装验证完成\"
    return 0
}

# 删除 logrotate 配置
remove_logrotate_config() {
    log_info \"删除 logrotate 配置...\"
    
    if [ ! -f \"$LOGROTATE_CONFIG_TARGET\" ]; then
        log_warning \"配置文件不存在，无需删除\"
        return 0
    fi
    
    # 确认删除
    if [ \"$FORCE\" != true ]; then
        read -p \"确认删除 logrotate 配置？(y/N): \" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info \"用户取消删除\"
            return 1
        fi
    fi
    
    # 备份后删除
    local backup_file=\"${LOGROTATE_CONFIG_TARGET}.removed.$(date +%Y%m%d_%H%M%S)\"
    if [ \"$DRY_RUN\" != true ]; then
        sudo cp \"$LOGROTATE_CONFIG_TARGET\" \"$backup_file\"
        sudo rm \"$LOGROTATE_CONFIG_TARGET\"
        log_success \"配置文件已删除，备份保存在: $backup_file\"
    else
        echo \"[DRY RUN] sudo cp $LOGROTATE_CONFIG_TARGET $backup_file\"
        echo \"[DRY RUN] sudo rm $LOGROTATE_CONFIG_TARGET\"
    fi
    
    return 0
}

# 显示配置状态
show_status() {
    echo \"📊 TKE 文档同步系统 - logrotate 配置状态\"
    echo \"=========================================\"
    echo
    
    # 检查 logrotate 服务
    if command -v logrotate >/dev/null 2>&1; then
        echo \"✅ logrotate 已安装: $(logrotate --version | head -1)\"
    else
        echo \"❌ logrotate 未安装\"
    fi
    
    # 检查配置文件
    if [ -f \"$LOGROTATE_CONFIG_TARGET\" ]; then
        echo \"✅ TKE logrotate 配置已安装\"
        echo \"   位置: $LOGROTATE_CONFIG_TARGET\"
        echo \"   大小: $(stat -c%s \"$LOGROTATE_CONFIG_TARGET\") bytes\"
        echo \"   修改时间: $(stat -c%y \"$LOGROTATE_CONFIG_TARGET\")\"
        echo \"   权限: $(stat -c%a \"$LOGROTATE_CONFIG_TARGET\")\"
        
        # 测试配置
        if logrotate -d \"$LOGROTATE_CONFIG_TARGET\" >/dev/null 2>&1; then
            echo \"✅ 配置语法正确\"
        else
            echo \"❌ 配置语法错误\"
        fi
    else
        echo \"❌ TKE logrotate 配置未安装\"
    fi
    
    # 检查日志目录
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        echo \"✅ 日志目录存在: $PROJECT_DIR/logs\"
        local log_count=$(find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f | wc -l)
        echo \"   日志文件数量: $log_count\"
        
        if [ $log_count -gt 0 ]; then
            echo \"   最新日志文件:\"
            find \"$PROJECT_DIR/logs\" -name \"*.log\" -type f -printf \"   %TY-%Tm-%Td %TH:%TM %p\\n\" | sort -r | head -3
        fi
    else
        echo \"❌ 日志目录不存在: $PROJECT_DIR/logs\"
    fi
    
    # 检查 logrotate 状态文件
    local logrotate_status=\"/var/lib/logrotate/status\"
    if [ -f \"$logrotate_status\" ]; then
        echo \"📋 logrotate 状态信息:\"
        if grep -q \"tke-dify-sync\" \"$logrotate_status\" 2>/dev/null; then
            grep \"tke-dify-sync\" \"$logrotate_status\" | while read -r line; do
                echo \"   $line\"
            done
        else
            echo \"   未找到 TKE 相关记录\"
        fi
    fi
    
    echo
}

# 创建测试日志文件
create_test_logs() {
    log_info \"创建测试日志文件...\"
    
    local test_logs=(\"test.log\" \"cron_test.log\" \"error_test.log\")
    
    for log_file in \"${test_logs[@]}\"; do
        local log_path=\"$PROJECT_DIR/logs/$log_file\"
        
        if [ \"$DRY_RUN\" != true ]; then
            # 创建测试内容
            cat > \"$log_path\" << EOF
$(date): Test log entry for $log_file
$(date): This is a test log file created by setup_logrotate.sh
$(date): Used for testing logrotate configuration
$(date): File: $log_file
$(date): Path: $log_path
EOF
            log_success \"创建测试日志: $log_file\"
        else
            echo \"[DRY RUN] 将创建测试日志: $log_path\"
        fi
    done
}

# 手动触发 logrotate 测试
trigger_logrotate_test() {
    log_info \"手动触发 logrotate 测试...\"
    
    if [ ! -f \"$LOGROTATE_CONFIG_TARGET\" ]; then
        log_error \"配置文件不存在，请先安装配置\"
        return 1
    fi
    
    # 创建测试日志
    create_test_logs
    
    # 强制执行 logrotate
    if [ \"$DRY_RUN\" != true ]; then
        if sudo logrotate -f \"$LOGROTATE_CONFIG_TARGET\"; then
            log_success \"logrotate 测试执行成功\"
            
            # 检查轮转结果
            log_info \"检查轮转结果:\"
            find \"$PROJECT_DIR/logs\" -name \"*.log*\" -type f | sort | while read -r file; do
                echo \"  $(ls -la \"$file\")\""
            done
        else
            log_error \"logrotate 测试执行失败\"
            return 1
        fi
    else
        echo \"[DRY RUN] sudo logrotate -f $LOGROTATE_CONFIG_TARGET\"
    fi
}

# 主函数
main() {
    local force=false
    local test_only=false
    local remove_config=false
    local show_status_only=false
    local dry_run=false
    local verbose=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -t|--test)
                test_only=true
                shift
                ;;
            -r|--remove)
                remove_config=true
                shift
                ;;
            -s|--status)
                show_status_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -v|--verbose)
                verbose=true
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
    FORCE=$force
    DRY_RUN=$dry_run
    VERBOSE=$verbose
    
    echo \"🔄 TKE 文档同步系统 - logrotate 配置管理\"
    echo \"=======================================\"
    echo
    
    if [ \"$dry_run\" = true ]; then
        echo \"🔍 模拟运行模式 - 不会执行实际操作\"
        echo
    fi
    
    # 记录操作开始
    log_message \"开始 logrotate 配置管理\"
    
    # 根据选项执行相应操作
    if [ \"$show_status_only\" = true ]; then
        show_status
        exit 0
    elif [ \"$remove_config\" = true ]; then
        check_requirements
        remove_logrotate_config
        exit $?
    elif [ \"$test_only\" = true ]; then
        check_requirements
        test_logrotate_config
        trigger_logrotate_test
        exit $?
    else
        # 正常安装流程
        check_requirements
        test_logrotate_config
        install_logrotate_config
        verify_installation
        
        echo
        echo \"🎉 logrotate 配置安装完成！\"
        echo \"============================\"
        echo
        echo \"📁 配置文件: $LOGROTATE_CONFIG_TARGET\"
        echo \"📊 日志目录: $PROJECT_DIR/logs\"
        echo \"📋 设置日志: $SETUP_LOG\"
        echo
        echo \"🔧 验证命令:\"
        echo \"  sudo logrotate -d $LOGROTATE_CONFIG_TARGET\"
        echo \"  $0 -s\"
        echo
        echo \"🧪 测试命令:\"
        echo \"  $0 -t\"
        echo \"  sudo logrotate -f $LOGROTATE_CONFIG_TARGET\"
        echo
        echo \"📚 更多信息请查看 logrotate 手册: man logrotate\"
    fi
    
    log_message \"logrotate 配置管理完成\"
}

# 运行主函数
main \"$@\"