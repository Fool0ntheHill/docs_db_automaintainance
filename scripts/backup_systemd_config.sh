#!/bin/bash

# TKE 文档同步系统 - systemd 配置备份脚本
# 在迁移到 cron 方式之前备份现有的 systemd 配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
BACKUP_DIR="/opt/tke-dify-sync/backup/systemd_$(date +%Y%m%d_%H%M%S)"
SERVICE_NAME="tke-dify-sync"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

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

# 创建备份目录
create_backup_directory() {
    log_info "创建备份目录: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    log_success "备份目录创建完成"
}

# 备份 systemd 服务文件
backup_systemd_service() {
    if [ -f "$SERVICE_FILE" ]; then
        log_info "备份 systemd 服务文件..."
        cp "$SERVICE_FILE" "$BACKUP_DIR/"
        log_success "systemd 服务文件已备份到: $BACKUP_DIR/$(basename $SERVICE_FILE)"
    else
        log_warning "systemd 服务文件不存在: $SERVICE_FILE"
    fi
}

# 备份服务状态信息
backup_service_status() {
    log_info "备份服务状态信息..."
    
    # 检查服务是否存在
    if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
        # 备份服务状态
        systemctl status "$SERVICE_NAME" --no-pager -l > "$BACKUP_DIR/service_status.txt" 2>&1 || true
        
        # 备份服务是否启用
        systemctl is-enabled "$SERVICE_NAME" > "$BACKUP_DIR/service_enabled.txt" 2>&1 || true
        
        # 备份服务是否活跃
        systemctl is-active "$SERVICE_NAME" > "$BACKUP_DIR/service_active.txt" 2>&1 || true
        
        log_success "服务状态信息已备份"
    else
        echo "服务不存在" > "$BACKUP_DIR/service_status.txt"
        log_warning "systemd 服务不存在，创建空状态文件"
    fi
}

# 备份当前 cron 作业
backup_current_cron() {
    log_info "备份当前用户的 cron 作业..."
    crontab -l > "$BACKUP_DIR/current_crontab.txt" 2>/dev/null || echo "无现有 cron 作业" > "$BACKUP_DIR/current_crontab.txt"
    log_success "当前 cron 作业已备份"
}

# 备份相关进程信息
backup_process_info() {
    log_info "备份相关进程信息..."
    
    # 查找相关进程
    pgrep -f "python.*tke_dify_sync.py" > "$BACKUP_DIR/running_processes.txt" 2>/dev/null || echo "无相关进程运行" > "$BACKUP_DIR/running_processes.txt"
    
    # 详细进程信息
    ps aux | grep -E "(python.*tke_dify_sync|systemd.*tke-dify)" | grep -v grep > "$BACKUP_DIR/process_details.txt" 2>/dev/null || echo "无相关进程详情" > "$BACKUP_DIR/process_details.txt"
    
    log_success "进程信息已备份"
}

# 创建备份报告
create_backup_report() {
    log_info "创建备份报告..."
    
    cat > "$BACKUP_DIR/backup_report.md" << EOF
# TKE 文档同步系统 - systemd 配置备份报告

## 备份信息
- 备份时间: $(date)
- 备份目录: $BACKUP_DIR
- 服务名称: $SERVICE_NAME

## 备份文件列表
$(ls -la "$BACKUP_DIR")

## systemd 服务状态
EOF

    if [ -f "$BACKUP_DIR/service_status.txt" ]; then
        echo "### 服务状态" >> "$BACKUP_DIR/backup_report.md"
        echo '```' >> "$BACKUP_DIR/backup_report.md"
        cat "$BACKUP_DIR/service_status.txt" >> "$BACKUP_DIR/backup_report.md"
        echo '```' >> "$BACKUP_DIR/backup_report.md"
        echo "" >> "$BACKUP_DIR/backup_report.md"
    fi

    if [ -f "$BACKUP_DIR/service_enabled.txt" ]; then
        echo "### 服务启用状态" >> "$BACKUP_DIR/backup_report.md"
        echo "启用状态: $(cat $BACKUP_DIR/service_enabled.txt)" >> "$BACKUP_DIR/backup_report.md"
        echo "" >> "$BACKUP_DIR/backup_report.md"
    fi

    if [ -f "$BACKUP_DIR/service_active.txt" ]; then
        echo "### 服务活跃状态" >> "$BACKUP_DIR/backup_report.md"
        echo "活跃状态: $(cat $BACKUP_DIR/service_active.txt)" >> "$BACKUP_DIR/backup_report.md"
        echo "" >> "$BACKUP_DIR/backup_report.md"
    fi

    echo "## 当前 cron 作业" >> "$BACKUP_DIR/backup_report.md"
    echo '```' >> "$BACKUP_DIR/backup_report.md"
    cat "$BACKUP_DIR/current_crontab.txt" >> "$BACKUP_DIR/backup_report.md"
    echo '```' >> "$BACKUP_DIR/backup_report.md"
    echo "" >> "$BACKUP_DIR/backup_report.md"

    echo "## 运行中的进程" >> "$BACKUP_DIR/backup_report.md"
    echo '```' >> "$BACKUP_DIR/backup_report.md"
    cat "$BACKUP_DIR/process_details.txt" >> "$BACKUP_DIR/backup_report.md"
    echo '```' >> "$BACKUP_DIR/backup_report.md"

    log_success "备份报告已创建: $BACKUP_DIR/backup_report.md"
}

# 显示备份摘要
show_backup_summary() {
    echo
    echo "🎉 systemd 配置备份完成！"
    echo
    echo "📁 备份目录: $BACKUP_DIR"
    echo "📊 备份报告: $BACKUP_DIR/backup_report.md"
    echo
    echo "📋 备份文件："
    ls -la "$BACKUP_DIR"
    echo
    echo "💡 提示："
    echo "  - 备份文件已保存，可以安全进行 systemd 服务删除"
    echo "  - 如需恢复，请参考备份报告中的信息"
    echo "  - 建议在迁移完成后保留备份文件一段时间"
}

# 主函数
main() {
    echo "🔄 开始备份 systemd 配置..."
    echo "=================================="
    
    create_backup_directory
    backup_systemd_service
    backup_service_status
    backup_current_cron
    backup_process_info
    create_backup_report
    show_backup_summary
    
    log_success "备份完成！"
}

# 运行主函数
main "$@"