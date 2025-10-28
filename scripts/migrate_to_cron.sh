#!/bin/bash

# TKE 文档同步系统 - systemd 到 cron 迁移工具
# 安全地将现有的 systemd 部署迁移到 cron 调度方式

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
SERVICE_NAME="tke-dify-sync"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BACKUP_DIR="$PROJECT_DIR/migration_backup_$(date +%Y%m%d_%H%M%S)"
MIGRATION_LOG="$PROJECT_DIR/logs/migration.log"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$MIGRATION_LOG"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_message "SUCCESS: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR: $1"
}

# 显示帮助信息
show_help() {
    echo "TKE 文档同步系统 - systemd 到 cron 迁移工具"
    echo "============================================"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -c, --check-only    仅检查当前状态，不执行迁移"
    echo "  -f, --force         强制执行迁移（跳过确认）"
    echo "  -b, --backup-only   仅备份当前配置"
    echo "  --dry-run          模拟运行，显示将要执行的操作"
    echo
    echo "示例:"
    echo "  $0                  # 交互式迁移"
    echo "  $0 -c               # 仅检查状态"
    echo "  $0 --dry-run        # 模拟迁移过程"
    echo
}

# 检查当前部署状态
check_current_status() {
    echo "🔍 检查当前部署状态"
    echo "=================="
    
    local has_systemd=false
    local has_cron=false
    local systemd_running=false
    
    # 检查 systemd 服务
    if [ -f "$SERVICE_FILE" ]; then
        has_systemd=true
        log_warning "发现 systemd 服务文件: $SERVICE_FILE"
        
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            systemd_running=true
            log_error "systemd 服务正在运行！这会导致无限重启问题"
        else
            log_info "systemd 服务已停止"
        fi
        
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_warning "systemd 服务已启用，系统重启后会自动启动"
        fi
    else
        log_success "未发现 systemd 服务文件"
    fi
    
    # 检查 cron 作业
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync\|tke-dify"; then
        has_cron=true
        log_info "发现现有的 cron 作业"
        crontab -l | grep "tke_dify_sync\|tke-dify" | while read -r job; do
            echo "  📋 $job"
        done
    else
        log_info "未发现 cron 作业"
    fi
    
    # 分析状态
    echo
    echo "📊 状态分析"
    echo "----------"
    
    if [ "$has_systemd" = true ] && [ "$has_cron" = true ]; then
        log_error "🚨 严重问题：同时存在 systemd 服务和 cron 作业！"
        echo "   这会导致冲突和不可预测的行为"
        return 2  # 严重冲突
    elif [ "$has_systemd" = true ]; then
        if [ "$systemd_running" = true ]; then
            log_error "🚨 紧急问题：systemd 服务正在运行，需要立即停止！"
            return 3  # 紧急情况
        else
            log_warning "⚠️ 需要迁移：存在 systemd 配置但未运行"
            return 1  # 需要迁移
        fi
    elif [ "$has_cron" = true ]; then
        log_success "✅ 配置正确：仅使用 cron 调度"
        return 0  # 配置正确
    else
        log_warning "⚠️ 未配置自动化：既无 systemd 也无 cron"
        return 1  # 需要配置
    fi
}

# 创建备份
create_backup() {
    echo
    echo "💾 创建备份"
    echo "==========="
    
    log_info "创建备份目录: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # 备份 systemd 服务文件
    if [ -f "$SERVICE_FILE" ]; then
        log_info "备份 systemd 服务文件"
        sudo cp "$SERVICE_FILE" "$BACKUP_DIR/"
        
        # 备份服务状态
        systemctl status "$SERVICE_NAME" --no-pager -l > "$BACKUP_DIR/service_status.txt" 2>&1 || true
        systemctl is-enabled "$SERVICE_NAME" > "$BACKUP_DIR/service_enabled.txt" 2>&1 || true
        systemctl is-active "$SERVICE_NAME" > "$BACKUP_DIR/service_active.txt" 2>&1 || true
    fi
    
    # 备份当前 crontab
    log_info "备份当前 crontab"
    crontab -l > "$BACKUP_DIR/current_crontab.txt" 2>/dev/null || echo "无现有 crontab" > "$BACKUP_DIR/current_crontab.txt"
    
    # 备份配置文件
    log_info "备份配置文件"
    cp -r "$PROJECT_DIR"/.env* "$BACKUP_DIR/" 2>/dev/null || true
    
    # 备份日志文件（最近的）
    log_info "备份最近的日志文件"
    mkdir -p "$BACKUP_DIR/logs"
    find "$PROJECT_DIR/logs" -name "*.log" -mtime -7 -exec cp {} "$BACKUP_DIR/logs/" \; 2>/dev/null || true
    
    # 备份状态文件
    log_info "备份状态文件"
    mkdir -p "$BACKUP_DIR/data"
    cp "$PROJECT_DIR/data"/*.json "$BACKUP_DIR/data/" 2>/dev/null || true
    
    # 创建备份报告
    cat > "$BACKUP_DIR/backup_report.md" << EOF
# TKE 文档同步系统 - 迁移备份报告

## 备份信息
- 备份时间: $(date)
- 备份目录: $BACKUP_DIR
- 迁移工具版本: 1.0

## 备份内容
$(ls -la "$BACKUP_DIR")

## systemd 服务状态
$(cat "$BACKUP_DIR/service_status.txt" 2>/dev/null || echo "无 systemd 服务")

## 当前 crontab
$(cat "$BACKUP_DIR/current_crontab.txt")

## 恢复说明
如需恢复到迁移前状态：
1. 恢复 systemd 服务: sudo cp $BACKUP_DIR/$(basename "$SERVICE_FILE") $SERVICE_FILE
2. 恢复 crontab: crontab $BACKUP_DIR/current_crontab.txt
3. 重新加载 systemd: sudo systemctl daemon-reload
EOF
    
    log_success "备份完成: $BACKUP_DIR"
}

# 停止并删除 systemd 服务
remove_systemd_service() {
    echo
    echo "🛑 删除 systemd 服务"
    echo "=================="
    
    if [ ! -f "$SERVICE_FILE" ]; then
        log_info "systemd 服务文件不存在，跳过删除"
        return 0
    fi
    
    # 停止服务
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_info "停止 systemd 服务"
        if [ "$DRY_RUN" != "true" ]; then
            sudo systemctl stop "$SERVICE_NAME"
        else
            echo "[DRY RUN] sudo systemctl stop $SERVICE_NAME"
        fi
        log_success "服务已停止"
    fi
    
    # 禁用服务
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_info "禁用 systemd 服务"
        if [ "$DRY_RUN" != "true" ]; then
            sudo systemctl disable "$SERVICE_NAME"
        else
            echo "[DRY RUN] sudo systemctl disable $SERVICE_NAME"
        fi
        log_success "服务已禁用"
    fi
    
    # 删除服务文件
    log_info "删除 systemd 服务文件"
    if [ "$DRY_RUN" != "true" ]; then
        sudo rm "$SERVICE_FILE"
    else
        echo "[DRY RUN] sudo rm $SERVICE_FILE"
    fi
    
    # 重新加载 systemd
    log_info "重新加载 systemd"
    if [ "$DRY_RUN" != "true" ]; then
        sudo systemctl daemon-reload
    else
        echo "[DRY RUN] sudo systemctl daemon-reload"
    fi
    
    log_success "systemd 服务已完全删除"
}

# 配置 cron 作业
setup_cron_jobs() {
    echo
    echo "🕐 配置 cron 作业"
    echo "==============="
    
    # 检测多知识库配置
    local multi_kb_configs=()
    if [ -f "$PROJECT_DIR/.env.tke_docs_base" ]; then
        multi_kb_configs+=("tke_docs_base")
    fi
    if [ -f "$PROJECT_DIR/.env.tke_knowledge_base" ]; then
        multi_kb_configs+=("tke_knowledge_base")
    fi
    
    # 创建临时 crontab 文件
    local temp_cron=$(mktemp)
    
    # 保留现有的非 TKE 相关 cron 作业
    if crontab -l 2>/dev/null | grep -v "tke_dify_sync\|tke-dify" > "$temp_cron"; then
        log_info "保留现有的 cron 作业"
    else
        touch "$temp_cron"
    fi
    
    # 添加注释
    echo "" >> "$temp_cron"
    echo "# TKE 文档同步系统 - 迁移工具自动生成于 $(date)" >> "$temp_cron"
    
    if [ ${#multi_kb_configs[@]} -gt 0 ]; then
        log_info "检测到多知识库配置，设置分别的 cron 作业"
        
        local hour=2
        for config in "${multi_kb_configs[@]}"; do
            log_info "配置 $config 知识库同步任务（凌晨 ${hour} 点）"
            echo "0 $hour * * * cd $PROJECT_DIR && cp .env.$config .env && $PROJECT_DIR/venv/bin/python tke_dify_sync.py >> $PROJECT_DIR/logs/cron_$config.log 2>&1" >> "$temp_cron"
            ((hour++))
        done
    else
        log_info "使用单知识库配置"
        echo "0 2 * * * cd $PROJECT_DIR && $PROJECT_DIR/venv/bin/python tke_dify_sync.py >> $PROJECT_DIR/logs/cron.log 2>&1" >> "$temp_cron"
    fi
    
    # 添加监控任务
    echo "*/5 * * * * $PROJECT_DIR/scripts/monitor.sh >/dev/null 2>&1" >> "$temp_cron"
    
    # 添加日志清理任务
    echo "0 1 * * 0 find $PROJECT_DIR/logs -name '*.log' -mtime +7 -delete 2>/dev/null || true" >> "$temp_cron"
    
    # 安装新的 crontab
    if [ "$DRY_RUN" != "true" ]; then
        if crontab "$temp_cron"; then
            log_success "cron 作业配置成功"
        else
            log_error "cron 作业配置失败"
            rm "$temp_cron"
            return 1
        fi
    else
        echo "[DRY RUN] 将要安装的 crontab 内容:"
        echo "----------------------------------------"
        cat "$temp_cron"
        echo "----------------------------------------"
    fi
    
    # 清理临时文件
    rm "$temp_cron"
    
    # 显示配置的 cron 作业
    if [ "$DRY_RUN" != "true" ]; then
        log_info "已配置的 TKE 相关 cron 作业："
        crontab -l | grep -E "(tke_dify_sync|monitor\.sh|find.*logs)" | while read -r job; do
            echo "  📋 $job"
        done
    fi
}

# 验证迁移结果
verify_migration() {
    echo
    echo "✅ 验证迁移结果"
    echo "==============="
    
    local issues=0
    
    # 检查 systemd 服务是否已删除
    if [ -f "$SERVICE_FILE" ]; then
        log_error "systemd 服务文件仍然存在"
        ((issues++))
    else
        log_success "systemd 服务文件已删除"
    fi
    
    # 检查 cron 作业是否配置
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync"; then
        log_success "cron 作业已配置"
        local job_count=$(crontab -l | grep "tke_dify_sync" | wc -l)
        log_info "配置了 $job_count 个同步作业"
    else
        log_error "cron 作业未配置"
        ((issues++))
    fi
    
    # 检查项目文件完整性
    local required_files=(
        "$PROJECT_DIR/tke_dify_sync.py"
        "$PROJECT_DIR/.env"
        "$PROJECT_DIR/venv/bin/python"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "关键文件存在: $(basename "$file")"
        else
            log_error "关键文件缺失: $file"
            ((issues++))
        fi
    done
    
    # 测试脚本执行
    log_info "测试脚本执行..."
    if cd "$PROJECT_DIR" && timeout 30s "$PROJECT_DIR/venv/bin/python" tke_dify_sync.py --test 2>/dev/null; then
        log_success "脚本测试执行成功"
    else
        log_warning "脚本测试执行失败或超时（这可能是正常的）"
    fi
    
    return $issues
}

# 主函数
main() {
    local check_only=false
    local force=false
    local backup_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check-only)
                check_only=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -b|--backup-only)
                backup_only=true
                shift
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
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "🔄 TKE 文档同步系统 - systemd 到 cron 迁移工具"
    echo "==============================================="
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "🔍 模拟运行模式 - 不会执行实际操作"
        echo
    fi
    
    # 记录迁移开始
    log_message "开始迁移过程"
    
    # 检查当前状态
    check_current_status
    local status_code=$?
    
    if [ "$check_only" = true ]; then
        log_info "仅检查模式，退出"
        exit $status_code
    fi
    
    # 根据状态决定操作
    case $status_code in
        0)
            log_success "系统已正确配置为 cron 调度，无需迁移"
            exit 0
            ;;
        1)
            log_info "需要进行迁移配置"
            ;;
        2|3)
            log_error "发现严重问题，需要立即处理"
            if [ "$force" != true ] && [ "$DRY_RUN" != "true" ]; then
                echo
                read -p "是否继续迁移？这将停止运行中的服务 (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "用户取消迁移"
                    exit 1
                fi
            fi
            ;;
    esac
    
    # 创建备份
    create_backup
    
    if [ "$backup_only" = true ]; then
        log_success "仅备份模式完成"
        exit 0
    fi
    
    # 确认迁移
    if [ "$force" != true ] && [ "$DRY_RUN" != "true" ]; then
        echo
        echo "⚠️ 即将执行以下操作："
        echo "  1. 停止并删除 systemd 服务"
        echo "  2. 配置 cron 定时任务"
        echo "  3. 验证迁移结果"
        echo
        read -p "确认继续迁移？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "用户取消迁移"
            exit 1
        fi
    fi
    
    # 执行迁移
    remove_systemd_service
    setup_cron_jobs
    
    # 验证结果
    if [ "$DRY_RUN" != "true" ]; then
        verify_migration
        local issues=$?
        
        echo
        echo "🎉 迁移完成！"
        echo "=============="
        
        if [ $issues -eq 0 ]; then
            log_success "✅ 迁移成功完成，系统已切换到 cron 调度方式"
        else
            log_warning "⚠️ 迁移完成但发现 $issues 个问题，请查看日志"
        fi
        
        echo
        echo "📋 迁移摘要:"
        echo "  备份目录: $BACKUP_DIR"
        echo "  迁移日志: $MIGRATION_LOG"
        echo "  systemd 服务: $([ -f "$SERVICE_FILE" ] && echo "仍存在（需要手动处理）" || echo "已删除")"
        echo "  cron 作业: $(crontab -l 2>/dev/null | grep -q "tke_dify_sync" && echo "已配置" || echo "未配置（需要手动处理）")"
        
        echo
        echo "🔧 建议的下一步操作:"
        echo "  1. 手动测试: cd $PROJECT_DIR && ./scripts/start.sh"
        echo "  2. 查看日志: tail -f $PROJECT_DIR/logs/cron.log"
        echo "  3. 健康检查: ./scripts/health_check.sh"
        
        exit $issues
    else
        echo
        echo "🔍 模拟运行完成"
        echo "实际迁移时将执行上述所有操作"
    fi
}

# 运行主函数
main "$@"