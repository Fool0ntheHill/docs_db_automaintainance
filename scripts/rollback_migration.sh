#!/bin/bash

# TKE 文档同步系统 - 迁移回滚工具
# 将系统从 cron 调度回滚到 systemd 服务模式

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
ROLLBACK_LOG=\"$PROJECT_DIR/logs/rollback.log\"

# 确保日志目录存在
mkdir -p \"$PROJECT_DIR/logs\"

# 日志函数
log_message() {
    echo \"$(date '+%Y-%m-%d %H:%M:%S'): $1\" >> \"$ROLLBACK_LOG\"
}

log_info() {
    echo -e \"${BLUE}[INFO]${NC} $1\"
    log_message \"INFO: $1\"
}

log_success() {
    echo -e \"${GREEN}[SUCCESS]${NC} $1\"
    log_message \"SUCCESS: $1\"
}

log_warning() {
    echo -e \"${YELLOW}[WARNING]${NC} $1\"
    log_message \"WARNING: $1\"
}

log_error() {
    echo -e \"${RED}[ERROR]${NC} $1\"
    log_message \"ERROR: $1\"
}

# 显示帮助信息
show_help() {
    echo \"TKE 文档同步系统 - 迁移回滚工具\"
    echo \"==============================\"
    echo
    echo \"⚠️ 警告: 此工具将系统从 cron 调度回滚到 systemd 服务模式\"
    echo \"   这会重新启用可能导致无限重启问题的 systemd 守护进程模式\"
    echo
    echo \"用法: $0 [选项] [备份目录]\"
    echo
    echo \"选项:\"
    echo \"  -h, --help          显示此帮助信息\"
    echo \"  -f, --force         强制执行回滚（跳过确认）\"
    echo \"  -b, --backup-dir    指定备份目录\"
    echo \"  --dry-run          模拟运行，显示将要执行的操作\"
    echo
    echo \"示例:\"
    echo \"  $0                                    # 交互式回滚\"
    echo \"  $0 -b /path/to/backup                # 使用指定备份\"
    echo \"  $0 --dry-run                         # 模拟回滚过程\"
    echo
}
"# 查找
备份目录
find_backup_directory() {
    local specified_backup="$1"
    
    if [ -n "$specified_backup" ] && [ -d "$specified_backup" ]; then
        echo "$specified_backup"
        return 0
    fi
    
    # 查找最新的备份目录
    local backup_dirs=($(find "$PROJECT_DIR" -maxdepth 1 -name "migration_backup_*" -type d 2>/dev/null | sort -r))
    
    if [ ${#backup_dirs[@]} -gt 0 ]; then
        echo "${backup_dirs[0]}"
        return 0
    fi
    
    return 1
}

# 验证备份目录
validate_backup_directory() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    log_info "验证备份目录: $backup_dir"
    
    # 检查必需的备份文件
    local required_files=("backup_report.md")
    local optional_files=("${SERVICE_NAME}.service" "current_crontab.txt")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$backup_dir/$file" ]; then
            log_error "备份目录缺少必需文件: $file"
            return 1
        fi
    done
    
    log_success "备份目录验证通过"
    
    # 显示备份信息
    if [ -f "$backup_dir/backup_report.md" ]; then
        log_info "备份信息:"
        head -10 "$backup_dir/backup_report.md" | while read -r line; do
            echo "  $line"
        done
    fi
    
    return 0
}

# 停止当前 cron 作业
stop_cron_jobs() {
    echo
    echo "🛑 停止当前 cron 作业"
    echo "=================="
    
    # 备份当前 crontab
    local current_cron_backup="$PROJECT_DIR/logs/crontab_before_rollback_$(date +%Y%m%d_%H%M%S).txt"
    crontab -l > "$current_cron_backup" 2>/dev/null || echo "无现有 crontab" > "$current_cron_backup"
    log_info "当前 crontab 已备份到: $current_cron_backup"
    
    # 删除 TKE 相关的 cron 作业
    if crontab -l 2>/dev/null | grep -v "tke_dify_sync\\|tke-dify" > /tmp/new_crontab; then
        if [ "$DRY_RUN" != "true" ]; then
            if crontab /tmp/new_crontab; then
                log_success "TKE 相关 cron 作业已删除"
            else
                log_error "删除 cron 作业失败"
                rm /tmp/new_crontab
                return 1
            fi
        else
            echo "[DRY RUN] 将删除 TKE 相关 cron 作业"
        fi
        rm /tmp/new_crontab
    else
        log_info "未发现 TKE 相关 cron 作业"
    fi
}

# 恢复 systemd 服务
restore_systemd_service() {
    local backup_dir="$1"
    
    echo
    echo "🔄 恢复 systemd 服务"
    echo "=================="
    
    # 检查备份中是否有 systemd 服务文件
    if [ -f "$backup_dir/${SERVICE_NAME}.service" ]; then
        log_info "恢复 systemd 服务文件"
        
        if [ "$DRY_RUN" != "true" ]; then
            if sudo cp "$backup_dir/${SERVICE_NAME}.service" "$SERVICE_FILE"; then
                log_success "systemd 服务文件已恢复"
            else
                log_error "恢复 systemd 服务文件失败"
                return 1
            fi
            
            # 重新加载 systemd
            sudo systemctl daemon-reload
            log_success "systemd 已重新加载"
            
            # 启用服务
            if sudo systemctl enable "$SERVICE_NAME"; then
                log_success "systemd 服务已启用"
            else
                log_error "启用 systemd 服务失败"
                return 1
            fi
            
        else
            echo "[DRY RUN] sudo cp $backup_dir/${SERVICE_NAME}.service $SERVICE_FILE"
            echo "[DRY RUN] sudo systemctl daemon-reload"
            echo "[DRY RUN] sudo systemctl enable $SERVICE_NAME"
        fi
    else
        log_warning "备份中未找到 systemd 服务文件"
        log_info "将创建新的 systemd 服务文件"
        
        # 创建新的 systemd 服务文件
        create_new_systemd_service
    fi
}

# 创建新的 systemd 服务文件
create_new_systemd_service() {
    log_info "创建新的 systemd 服务文件"
    
    local service_content="[Unit]
Description=TKE Documentation Sync Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/tke_dify_sync.py
Restart=always
RestartSec=30
Environment=PATH=$PROJECT_DIR/venv/bin
EnvironmentFile=$PROJECT_DIR/.env

[Install]
WantedBy=multi-user.target"
    
    if [ "$DRY_RUN" != "true" ]; then
        echo "$service_content" | sudo tee "$SERVICE_FILE" > /dev/null
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        log_success "新的 systemd 服务文件已创建并启用"
    else
        echo "[DRY RUN] 将创建新的 systemd 服务文件:"
        echo "$service_content"
    fi
}

# 恢复配置文件
restore_configuration_files() {
    local backup_dir="$1"
    
    echo
    echo "📁 恢复配置文件"
    echo "==============="
    
    # 恢复 .env 文件
    if [ -f "$backup_dir/.env" ]; then
        log_info "恢复主配置文件"
        
        if [ "$DRY_RUN" != "true" ]; then
            cp "$backup_dir/.env" "$PROJECT_DIR/.env"
            log_success "主配置文件已恢复"
        else
            echo "[DRY RUN] cp $backup_dir/.env $PROJECT_DIR/.env"
        fi
    else
        log_warning "备份中未找到主配置文件"
    fi
    
    # 恢复其他 .env 文件
    for env_file in "$backup_dir"/.env.*; do
        if [ -f "$env_file" ]; then
            local filename=$(basename "$env_file")
            log_info "恢复配置文件: $filename"
            
            if [ "$DRY_RUN" != "true" ]; then
                cp "$env_file" "$PROJECT_DIR/$filename"
            else
                echo "[DRY RUN] cp $env_file $PROJECT_DIR/$filename"
            fi
        fi
    done
    
    log_success "配置文件恢复完成"
}

# 恢复 crontab（如果需要）
restore_original_crontab() {
    local backup_dir="$1"
    
    if [ -f "$backup_dir/current_crontab.txt" ]; then
        log_info "发现原始 crontab 备份"
        
        # 检查是否有非 TKE 相关的 cron 作业
        if grep -v "tke_dify_sync\\|tke-dify" "$backup_dir/current_crontab.txt" | grep -q "^[^#]"; then
            log_info "恢复原始 crontab 中的其他作业"
            
            if [ "$DRY_RUN" != "true" ]; then
                crontab "$backup_dir/current_crontab.txt"
                log_success "原始 crontab 已恢复"
            else
                echo "[DRY RUN] crontab $backup_dir/current_crontab.txt"
            fi
        else
            log_info "原始 crontab 为空或仅包含 TKE 作业，跳过恢复"
        fi
    fi
}

# 启动 systemd 服务
start_systemd_service() {
    echo
    echo "🚀 启动 systemd 服务"
    echo "=================="
    
    if [ "$DRY_RUN" != "true" ]; then
        if sudo systemctl start "$SERVICE_NAME"; then
            log_success "systemd 服务已启动"
            
            # 检查服务状态
            sleep 2
            if systemctl is-active --quiet "$SERVICE_NAME"; then
                log_success "systemd 服务运行正常"
            else
                log_error "systemd 服务启动后异常"
                log_info "服务状态:"
                systemctl status "$SERVICE_NAME" --no-pager -l || true
                return 1
            fi
        else
            log_error "启动 systemd 服务失败"
            return 1
        fi
    else
        echo "[DRY RUN] sudo systemctl start $SERVICE_NAME"
    fi
}

# 验证回滚结果
verify_rollback() {
    echo
    echo "✅ 验证回滚结果"
    echo "==============="
    
    local issues=0
    
    # 检查 systemd 服务
    if [ -f "$SERVICE_FILE" ]; then
        log_success "systemd 服务文件已恢复"
        
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_success "systemd 服务已启用"
        else
            log_error "systemd 服务未启用"
            ((issues++))
        fi
        
        if [ "$DRY_RUN" != "true" ]; then
            if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
                log_success "systemd 服务正在运行"
            else
                log_error "systemd 服务未运行"
                ((issues++))
            fi
        fi
    else
        log_error "systemd 服务文件未恢复"
        ((issues++))
    fi
    
    # 检查 cron 作业
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync\\|tke-dify"; then
        log_warning "仍有 TKE 相关 cron 作业存在"
        ((issues++))
    else
        log_success "TKE 相关 cron 作业已清除"
    fi
    
    # 检查配置文件
    if [ -f "$PROJECT_DIR/.env" ]; then
        log_success "主配置文件存在"
    else
        log_error "主配置文件缺失"
        ((issues++))
    fi
    
    return $issues
}

# 生成回滚报告
generate_rollback_report() {
    local issues="$1"
    local backup_dir="$2"
    local report_file="$PROJECT_DIR/logs/rollback_report_$(date +%Y%m%d_%H%M%S).md"
    
    log_info "生成回滚报告: $report_file"
    
    cat > "$report_file" << EOF
# TKE 文档同步系统 - 回滚报告

生成时间: $(date)
回滚用户: $(whoami)
使用备份: $backup_dir

## 回滚摘要

- 发现问题: $issues 个
- systemd 服务: $([ -f "$SERVICE_FILE" ] && echo "✅ 已恢复" || echo "❌ 未恢复")
- 服务状态: $(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "未运行")
- cron 作业: $(crontab -l 2>/dev/null | grep -q "tke_dify_sync" && echo "❌ 仍存在" || echo "✅ 已清除")

## 当前系统状态

### systemd 服务
- 服务文件: $([ -f "$SERVICE_FILE" ] && echo "存在" || echo "不存在")
- 启用状态: $(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo "未启用")
- 运行状态: $(systemctl is-active "$SERVICE_NAME" 2>/dev/null || echo "未运行")

### 配置文件
- 主配置: $([ -f "$PROJECT_DIR/.env" ] && echo "存在" || echo "不存在")
- 其他配置: $(ls -1 "$PROJECT_DIR"/.env.* 2>/dev/null | wc -l) 个

## 下一步操作

EOF

    if [ $issues -eq 0 ]; then
        echo "✅ 回滚成功完成，系统已恢复到 systemd 服务模式" >> "$report_file"
        echo "" >> "$report_file"
        echo "⚠️ 重要提醒：" >> "$report_file"
        echo "systemd 守护进程模式可能导致无限重启问题。" >> "$report_file"
        echo "建议监控服务状态并考虑重新迁移到 cron 调度方式。" >> "$report_file"
        echo "" >> "$report_file"
        echo "监控命令：" >> "$report_file"
        echo "- 查看服务状态: systemctl status $SERVICE_NAME" >> "$report_file"
        echo "- 查看服务日志: journalctl -u $SERVICE_NAME -f" >> "$report_file"
        echo "- 停止服务: sudo systemctl stop $SERVICE_NAME" >> "$report_file"
    else
        echo "⚠️ 回滚完成但发现 $issues 个问题，需要手动处理" >> "$report_file"
        echo "" >> "$report_file"
        echo "故障排除：" >> "$report_file"
        echo "1. 检查服务状态: systemctl status $SERVICE_NAME" >> "$report_file"
        echo "2. 查看回滚日志: cat $ROLLBACK_LOG" >> "$report_file"
        echo "3. 手动启动服务: sudo systemctl start $SERVICE_NAME" >> "$report_file"
    fi
    
    log_success "回滚报告已生成: $report_file"
}

# 主函数
main() {
    local force=false
    local backup_dir=""
    
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
            -b|--backup-dir)
                backup_dir="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$backup_dir" ]; then
                    backup_dir="$1"
                else
                    log_error "多余的参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo "🔄 TKE 文档同步系统 - 迁移回滚工具"
    echo "=================================="
    echo
    echo "⚠️ 警告: 此操作将恢复到 systemd 守护进程模式"
    echo "   这可能重新引入无限重启问题"
    echo
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "🔍 模拟运行模式 - 不会执行实际操作"
        echo
    fi
    
    # 查找备份目录
    if [ -z "$backup_dir" ]; then
        backup_dir=$(find_backup_directory)
        if [ $? -ne 0 ]; then
            log_error "未找到备份目录"
            log_info "请使用 -b 选项指定备份目录"
            exit 1
        fi
        log_info "自动发现备份目录: $backup_dir"
    fi
    
    # 验证备份目录
    validate_backup_directory "$backup_dir"
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # 确认回滚
    if [ "$force" != true ] && [ "$DRY_RUN" != "true" ]; then
        echo
        echo "⚠️ 即将执行以下操作："
        echo "  1. 停止并删除当前 cron 作业"
        echo "  2. 恢复 systemd 服务文件"
        echo "  3. 启用并启动 systemd 服务"
        echo "  4. 恢复配置文件"
        echo
        read -p "确认继续回滚？这可能重新引入无限重启问题 (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "用户取消回滚"
            exit 1
        fi
    fi
    
    # 记录回滚开始
    log_message "开始回滚过程，使用备份: $backup_dir"
    
    # 执行回滚
    stop_cron_jobs
    restore_systemd_service "$backup_dir"
    restore_configuration_files "$backup_dir"
    restore_original_crontab "$backup_dir"
    
    if [ "$DRY_RUN" != "true" ]; then
        start_systemd_service
        
        # 验证结果
        verify_rollback
        local issues=$?
        
        generate_rollback_report "$issues" "$backup_dir"
        
        echo
        echo "🎉 回滚完成！"
        echo "============="
        
        if [ $issues -eq 0 ]; then
            log_success "✅ 回滚成功完成，系统已恢复到 systemd 服务模式"
            echo
            log_warning "⚠️ 重要提醒: systemd 守护进程模式可能导致无限重启问题"
            log_info "建议监控服务状态: systemctl status $SERVICE_NAME"
        else
            log_warning "⚠️ 回滚完成但发现 $issues 个问题，请查看报告"
        fi
        
        log_message "回滚完成，发现 $issues 个问题"
        exit $issues
    else
        echo
        echo "🔍 模拟运行完成"
        echo "实际回滚时将执行上述所有操作"
    fi
}

# 运行主函数
main "$@"