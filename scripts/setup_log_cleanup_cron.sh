#!/bin/bash

# TKE 文档同步系统 - 日志清理 cron 作业设置脚本
# 设置自动清理旧日志文件的 cron 作业

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
SETUP_LOG=\"$PROJECT_DIR/logs/log_cleanup_cron_setup_$(date +%Y%m%d_%H%M%S).log\"

# 默认配置
DEFAULT_CLEANUP_TIME=\"0 2 * * 0\"  # 每周日凌晨2点
DEFAULT_LOG_RETENTION_DAYS=7
DEFAULT_LARGE_LOG_SIZE=\"100M\"

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
    echo \"TKE 文档同步系统 - 日志清理 cron 作业设置\"
    echo \"==========================================\"
    echo
    echo \"用法: $0 [选项]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help              显示此帮助信息\"
    echo \"  -t, --time CRON_TIME    设置清理时间 (默认: '$DEFAULT_CLEANUP_TIME')\"
    echo \"  -d, --days DAYS         日志保留天数 (默认: $DEFAULT_LOG_RETENTION_DAYS)\"
    echo \"  -s, --size SIZE         大文件清理阈值 (默认: $DEFAULT_LARGE_LOG_SIZE)\"
    echo \"  -r, --remove            删除日志清理 cron 作业\"
    echo \"  --status               显示当前配置状态\"
    echo \"  --dry-run              模拟运行，不执行实际操作\"
    echo \"  -f, --force            强制执行，跳过确认\"
    echo
    echo \"时间格式说明:\"
    echo \"  使用标准 cron 时间格式: '分 时 日 月 周'\"
    echo \"  例如:\"
    echo \"    '0 2 * * 0'    - 每周日凌晨2点\"
    echo \"    '0 1 * * *'    - 每天凌晨1点\"
    echo \"    '30 3 1 * *'   - 每月1日凌晨3:30\"
    echo
    echo \"示例:\"
    echo \"  $0                      # 使用默认设置\"
    echo \"  $0 -t '0 1 * * *' -d 14 # 每天1点清理，保留14天\"
    echo \"  $0 -r                   # 删除清理作业\"
    echo \"  $0 --status             # 查看状态\"
    echo
}

# 验证 cron 时间格式
validate_cron_time() {
    local cron_time=\"$1\"
    
    # 简单的 cron 格式验证
    if [[ ! \"$cron_time\" =~ ^[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+[[:space:]]+[0-9*,-/]+$ ]]; then
        log_error \"无效的 cron 时间格式: $cron_time\"
        log_info \"正确格式: '分 时 日 月 周'，例如 '0 2 * * 0'\"
        return 1
    fi
    
    return 0
}

# 创建日志清理脚本
create_cleanup_script() {
    local retention_days=\"$1\"
    local large_log_size=\"$2\"
    local cleanup_script=\"$PROJECT_DIR/scripts/cleanup_logs.sh\"
    
    log_info \"创建日志清理脚本: $cleanup_script\"
    
    cat > \"$cleanup_script\" << EOF
#!/bin/bash

# TKE 文档同步系统 - 自动日志清理脚本
# 由 setup_log_cleanup_cron.sh 自动生成
# 生成时间: $(date)

set -e

# 配置
PROJECT_DIR=\"$PROJECT_DIR\"
LOG_DIR=\"\\$PROJECT_DIR/logs\"
RETENTION_DAYS=$retention_days
LARGE_LOG_SIZE=\"$large_log_size\"
CLEANUP_LOG=\"\\$LOG_DIR/cleanup_$(date +%Y%m%d_%H%M%S).log\"

# 日志函数
log_cleanup() {
    echo \"\\$(date '+%Y-%m-%d %H:%M:%S'): \\$1\" >> \"\\$CLEANUP_LOG\"
}

# 开始清理
log_cleanup \"开始日志清理任务\"
echo \"🧹 TKE 日志清理任务开始 - \\$(date)\"

# 统计清理前的状态
BEFORE_COUNT=\\$(find \"\\$LOG_DIR\" -name \"*.log*\" -type f | wc -l)
BEFORE_SIZE=\\$(du -sh \"\\$LOG_DIR\" | cut -f1)

log_cleanup \"清理前: \\$BEFORE_COUNT 个文件, 总大小: \\$BEFORE_SIZE\"
echo \"📊 清理前状态: \\$BEFORE_COUNT 个日志文件, 总大小: \\$BEFORE_SIZE\"

# 1. 清理过期的日志文件
echo \"🗑️ 清理 \\$RETENTION_DAYS 天前的日志文件...\"
EXPIRED_FILES=\\$(find \"\\$LOG_DIR\" -name \"*.log*\" -type f -mtime +\\$RETENTION_DAYS -print)
EXPIRED_COUNT=\\$(echo \"\\$EXPIRED_FILES\" | grep -c . || echo 0)

if [ \\$EXPIRED_COUNT -gt 0 ]; then
    echo \"\\$EXPIRED_FILES\" | while read -r file; do
        if [ -f \"\\$file\" ]; then
            log_cleanup \"删除过期文件: \\$file\"
            rm \"\\$file\"
        fi
    done
    echo \"✅ 删除了 \\$EXPIRED_COUNT 个过期日志文件\"
    log_cleanup \"删除了 \\$EXPIRED_COUNT 个过期日志文件\"
else
    echo \"ℹ️ 未发现过期的日志文件\"
    log_cleanup \"未发现过期的日志文件\"
fi

# 2. 清理过大的日志文件
echo \"📏 检查过大的日志文件 (>\\$LARGE_LOG_SIZE)...\"
LARGE_FILES=\\$(find \"\\$LOG_DIR\" -name \"*.log\" -type f -size +\\$LARGE_LOG_SIZE -print)
LARGE_COUNT=\\$(echo \"\\$LARGE_FILES\" | grep -c . || echo 0)

if [ \\$LARGE_COUNT -gt 0 ]; then
    echo \"\\$LARGE_FILES\" | while read -r file; do
        if [ -f \"\\$file\" ]; then
            # 备份大文件并截断
            backup_file=\"\\${file}.large.\\$(date +%Y%m%d_%H%M%S)\"
            log_cleanup \"备份大文件: \\$file -> \\$backup_file\"
            cp \"\\$file\" \"\\$backup_file\"
            
            # 截断原文件
            > \"\\$file\"
            log_cleanup \"截断大文件: \\$file\"
            echo \"  📦 备份并截断: \\$(basename \"\\$file\")\"
        fi
    done
    echo \"✅ 处理了 \\$LARGE_COUNT 个过大的日志文件\"
    log_cleanup \"处理了 \\$LARGE_COUNT 个过大的日志文件\"
else
    echo \"ℹ️ 未发现过大的日志文件\"
    log_cleanup \"未发现过大的日志文件\"
fi

# 3. 压缩旧的日志文件
echo \"🗜️ 压缩旧的日志文件...\"
OLD_UNCOMPRESSED=\\$(find \"\\$LOG_DIR\" -name \"*.log.*\" -not -name \"*.gz\" -type f -mtime +1 -print)
COMPRESS_COUNT=\\$(echo \"\\$OLD_UNCOMPRESSED\" | grep -c . || echo 0)

if [ \\$COMPRESS_COUNT -gt 0 ] && command -v gzip >/dev/null 2>&1; then
    echo \"\\$OLD_UNCOMPRESSED\" | while read -r file; do
        if [ -f \"\\$file\" ]; then
            log_cleanup \"压缩文件: \\$file\"
            gzip \"\\$file\"
            echo \"  🗜️ 压缩: \\$(basename \"\\$file\")\"
        fi
    done
    echo \"✅ 压缩了 \\$COMPRESS_COUNT 个日志文件\"
    log_cleanup \"压缩了 \\$COMPRESS_COUNT 个日志文件\"
else
    if [ \\$COMPRESS_COUNT -eq 0 ]; then
        echo \"ℹ️ 未发现需要压缩的日志文件\"
        log_cleanup \"未发现需要压缩的日志文件\"
    else
        echo \"⚠️ gzip 不可用，跳过压缩\"
        log_cleanup \"gzip 不可用，跳过压缩\"
    fi
fi

# 4. 清理空的日志文件
echo \"🗂️ 清理空的日志文件...\"
EMPTY_FILES=\\$(find \"\\$LOG_DIR\" -name \"*.log\" -type f -empty -print)
EMPTY_COUNT=\\$(echo \"\\$EMPTY_FILES\" | grep -c . || echo 0)

if [ \\$EMPTY_COUNT -gt 0 ]; then
    echo \"\\$EMPTY_FILES\" | while read -r file; do
        if [ -f \"\\$file\" ]; then
            log_cleanup \"删除空文件: \\$file\"
            rm \"\\$file\"
        fi
    done
    echo \"✅ 删除了 \\$EMPTY_COUNT 个空日志文件\"
    log_cleanup \"删除了 \\$EMPTY_COUNT 个空日志文件\"
else
    echo \"ℹ️ 未发现空的日志文件\"
    log_cleanup \"未发现空的日志文件\"
fi

# 统计清理后的状态
AFTER_COUNT=\\$(find \"\\$LOG_DIR\" -name \"*.log*\" -type f | wc -l)
AFTER_SIZE=\\$(du -sh \"\\$LOG_DIR\" | cut -f1)

log_cleanup \"清理后: \\$AFTER_COUNT 个文件, 总大小: \\$AFTER_SIZE\"
echo \"📊 清理后状态: \\$AFTER_COUNT 个日志文件, 总大小: \\$AFTER_SIZE\"

# 清理完成
log_cleanup \"日志清理任务完成\"
echo \"🎉 日志清理任务完成 - \\$(date)\"

# 清理旧的清理日志（保留最近5个）
find \"\\$LOG_DIR\" -name \"cleanup_*.log\" -type f | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true

exit 0
EOF
    
    # 设置执行权限
    chmod +x \"$cleanup_script\"
    log_success \"日志清理脚本已创建: $cleanup_script\"
}

# 添加日志清理 cron 作业
add_cleanup_cron() {
    local cron_time=\"$1\"
    local retention_days=\"$2\"
    local large_log_size=\"$3\"
    
    log_info \"添加日志清理 cron 作业...\"
    
    # 创建清理脚本
    create_cleanup_script \"$retention_days\" \"$large_log_size\"
    
    # 检查是否已存在清理作业
    if crontab -l 2>/dev/null | grep -q \"cleanup_logs.sh\"; then
        if [ \"$FORCE\" != true ]; then
            log_warning \"已存在日志清理 cron 作业\"
            read -p \"是否替换现有作业？(y/N): \" -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info \"用户取消操作\"
                return 1
            fi
        fi
        
        # 删除现有的清理作业
        log_info \"删除现有的日志清理作业\"
        crontab -l 2>/dev/null | grep -v \"cleanup_logs.sh\" | crontab -
    fi
    
    # 添加新的清理作业
    local cleanup_job=\"$cron_time $PROJECT_DIR/scripts/cleanup_logs.sh >> $PROJECT_DIR/logs/cleanup_cron.log 2>&1\"
    
    if [ \"$DRY_RUN\" != true ]; then
        (crontab -l 2>/dev/null; echo \"# TKE 文档同步系统 - 日志清理作业 ($(date))\"; echo \"$cleanup_job\") | crontab -
        log_success \"日志清理 cron 作业已添加\"
        log_info \"清理时间: $cron_time\"
        log_info \"保留天数: $retention_days 天\"
        log_info \"大文件阈值: $large_log_size\"
    else
        echo \"[DRY RUN] 将添加 cron 作业: $cleanup_job\"
    fi
}

# 删除日志清理 cron 作业
remove_cleanup_cron() {
    log_info \"删除日志清理 cron 作业...\"
    
    if ! crontab -l 2>/dev/null | grep -q \"cleanup_logs.sh\"; then
        log_warning \"未发现日志清理 cron 作业\"
        return 0
    fi
    
    # 确认删除
    if [ \"$FORCE\" != true ]; then
        read -p \"确认删除日志清理 cron 作业？(y/N): \" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info \"用户取消删除\"
            return 1
        fi
    fi
    
    # 删除清理作业
    if [ \"$DRY_RUN\" != true ]; then
        crontab -l 2>/dev/null | grep -v \"cleanup_logs.sh\" | grep -v \"TKE 文档同步系统 - 日志清理作业\" | crontab -
        log_success \"日志清理 cron 作业已删除\"
    else
        echo \"[DRY RUN] 将删除日志清理 cron 作业\"
    fi
    
    # 询问是否删除清理脚本
    if [ -f \"$PROJECT_DIR/scripts/cleanup_logs.sh\" ]; then
        if [ \"$FORCE\" != true ]; then
            read -p \"是否同时删除清理脚本？(y/N): \" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm \"$PROJECT_DIR/scripts/cleanup_logs.sh\"
                log_success \"清理脚本已删除\"
            fi
        fi
    fi
}

# 显示配置状态
show_status() {
    echo \"📊 TKE 文档同步系统 - 日志清理配置状态\"
    echo \"=======================================\"
    echo
    
    # 检查 cron 服务
    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
        echo \"✅ cron 服务正在运行\"
    else
        echo \"❌ cron 服务未运行\"
    fi
    
    # 检查清理 cron 作业
    if crontab -l 2>/dev/null | grep -q \"cleanup_logs.sh\"; then
        echo \"✅ 日志清理 cron 作业已配置\"
        echo \"   作业详情:\"
        crontab -l 2>/dev/null | grep \"cleanup_logs.sh\" | while read -r job; do
            echo \"     📋 $job\"
        done
    else
        echo \"❌ 日志清理 cron 作业未配置\"
    fi
    
    # 检查清理脚本
    if [ -f \"$PROJECT_DIR/scripts/cleanup_logs.sh\" ]; then
        echo \"✅ 清理脚本存在\"
        echo \"   位置: $PROJECT_DIR/scripts/cleanup_logs.sh\"
        echo \"   大小: $(stat -c%s \"$PROJECT_DIR/scripts/cleanup_logs.sh\") bytes\"
        echo \"   权限: $(stat -c%a \"$PROJECT_DIR/scripts/cleanup_logs.sh\")\"
    else
        echo \"❌ 清理脚本不存在\"
    fi
    
    # 检查日志目录状态
    if [ -d \"$PROJECT_DIR/logs\" ]; then
        echo \"📁 日志目录状态:\"
        echo \"   位置: $PROJECT_DIR/logs\"
        echo \"   总大小: $(du -sh \"$PROJECT_DIR/logs\" | cut -f1)\"
        
        local log_count=$(find \"$PROJECT_DIR/logs\" -name \"*.log*\" -type f | wc -l)
        echo \"   文件数量: $log_count\"
        
        if [ $log_count -gt 0 ]; then
            echo \"   最新文件:\"
            find \"$PROJECT_DIR/logs\" -name \"*.log*\" -type f -printf \"     %TY-%Tm-%Td %TH:%TM %p\\n\" | sort -r | head -3
            
            echo \"   最旧文件:\"
            find \"$PROJECT_DIR/logs\" -name \"*.log*\" -type f -printf \"     %TY-%Tm-%Td %TH:%TM %p\\n\" | sort | head -3
        fi
    else
        echo \"❌ 日志目录不存在: $PROJECT_DIR/logs\"
    fi
    
    # 检查清理历史
    local cleanup_logs=$(find \"$PROJECT_DIR/logs\" -name \"cleanup_*.log\" -type f 2>/dev/null | wc -l)
    if [ $cleanup_logs -gt 0 ]; then
        echo \"📋 清理历史记录: $cleanup_logs 个清理日志\"
        echo \"   最近清理:\"
        find \"$PROJECT_DIR/logs\" -name \"cleanup_*.log\" -type f -printf \"     %TY-%Tm-%Td %TH:%TM %p\\n\" | sort -r | head -3
    else
        echo \"📋 无清理历史记录\"
    fi
    
    echo
}

# 测试清理脚本
test_cleanup_script() {
    log_info \"测试日志清理脚本...\"
    
    local cleanup_script=\"$PROJECT_DIR/scripts/cleanup_logs.sh\"
    
    if [ ! -f \"$cleanup_script\" ]; then
        log_error \"清理脚本不存在，请先创建\"
        return 1
    fi
    
    # 创建一些测试日志文件
    log_info \"创建测试日志文件...\"
    
    local test_files=(
        \"test_old.log\"
        \"test_current.log\"
        \"test_large.log\"
        \"test_empty.log\"
    )
    
    for file in \"${test_files[@]}\"; do
        local test_file=\"$PROJECT_DIR/logs/$file\"
        
        case \"$file\" in
            \"test_old.log\")
                echo \"Old log content\" > \"$test_file\"
                touch -d \"10 days ago\" \"$test_file\"
                ;;
            \"test_current.log\")
                echo \"Current log content\" > \"$test_file\"
                ;;
            \"test_large.log\")
                # 创建一个大文件
                dd if=/dev/zero of=\"$test_file\" bs=1M count=1 2>/dev/null
                ;;
            \"test_empty.log\")
                touch \"$test_file\"
                ;;
        esac
    done
    
    log_success \"测试文件已创建\"
    
    # 运行清理脚本
    if [ \"$DRY_RUN\" != true ]; then
        log_info \"执行清理脚本...\"
        if \"$cleanup_script\"; then
            log_success \"清理脚本执行成功\"
        else
            log_error \"清理脚本执行失败\"
            return 1
        fi
    else
        echo \"[DRY RUN] 将执行清理脚本: $cleanup_script\"
    fi
}

# 主函数
main() {
    local cron_time=\"$DEFAULT_CLEANUP_TIME\"
    local retention_days=$DEFAULT_LOG_RETENTION_DAYS
    local large_log_size=\"$DEFAULT_LARGE_LOG_SIZE\"
    local remove_config=false
    local show_status_only=false
    local dry_run=false
    local force=false
    local test_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--time)
                cron_time=\"$2\"
                shift 2
                ;;
            -d|--days)
                retention_days=\"$2\"
                shift 2
                ;;
            -s|--size)
                large_log_size=\"$2\"
                shift 2
                ;;
            -r|--remove)
                remove_config=true
                shift
                ;;
            --status)
                show_status_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            --test)
                test_only=true
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
    DRY_RUN=$dry_run
    FORCE=$force
    
    echo \"🧹 TKE 文档同步系统 - 日志清理 cron 设置\"
    echo \"========================================\"
    echo
    
    if [ \"$dry_run\" = true ]; then
        echo \"🔍 模拟运行模式 - 不会执行实际操作\"
        echo
    fi
    
    # 记录操作开始
    log_message \"开始日志清理 cron 设置\"
    
    # 根据选项执行相应操作
    if [ \"$show_status_only\" = true ]; then
        show_status
        exit 0
    elif [ \"$test_only\" = true ]; then
        test_cleanup_script
        exit $?
    elif [ \"$remove_config\" = true ]; then
        remove_cleanup_cron
        exit $?
    else
        # 验证参数
        if ! validate_cron_time \"$cron_time\"; then
            exit 1
        fi
        
        if ! [[ \"$retention_days\" =~ ^[0-9]+$ ]] || [ \"$retention_days\" -lt 1 ]; then
            log_error \"无效的保留天数: $retention_days\"
            exit 1
        fi
        
        # 添加清理作业
        add_cleanup_cron \"$cron_time\" \"$retention_days\" \"$large_log_size\"
        
        echo
        echo \"🎉 日志清理 cron 作业设置完成！\"
        echo \"===============================\"
        echo
        echo \"⏰ 清理时间: $cron_time\"
        echo \"📅 保留天数: $retention_days 天\"
        echo \"📏 大文件阈值: $large_log_size\"
        echo \"📁 清理脚本: $PROJECT_DIR/scripts/cleanup_logs.sh\"
        echo \"📋 设置日志: $SETUP_LOG\"
        echo
        echo \"🔧 验证命令:\"
        echo \"  crontab -l | grep cleanup\"
        echo \"  $0 --status\"
        echo
        echo \"🧪 测试命令:\"
        echo \"  $0 --test\"
        echo \"  $PROJECT_DIR/scripts/cleanup_logs.sh\"
        echo
        echo \"📚 更多信息请查看 cron 手册: man crontab\"
    fi
    
    log_message \"日志清理 cron 设置完成\"
}

# 运行主函数
main \"$@\"