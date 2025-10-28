#!/bin/bash

# TKE 文档同步系统 - 部署分析脚本
# 分析当前部署状态，识别 systemd 服务和 cron 作业

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SERVICE_NAME="tke-dify-sync"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PROJECT_DIR="/opt/tke-dify-sync"

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

# 检查 systemd 服务状态
check_systemd_service() {
    echo "🔍 检查 systemd 服务状态"
    echo "=========================="
    
    if [ -f "$SERVICE_FILE" ]; then
        log_warning "发现 systemd 服务文件: $SERVICE_FILE"
        
        # 检查服务状态
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_error "❌ systemd 服务正在运行 - 这会导致无限重启问题！"
            echo "   服务状态: $(systemctl is-active $SERVICE_NAME)"
        else
            log_info "systemd 服务已停止"
        fi
        
        # 检查服务是否启用
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            log_warning "systemd 服务已启用，系统重启后会自动启动"
        else
            log_info "systemd 服务未启用"
        fi
        
        # 显示服务配置
        echo
        echo "📄 systemd 服务配置:"
        echo "-------------------"
        cat "$SERVICE_FILE" | grep -E "(Restart|ExecStart|Type)" || echo "无关键配置项"
        
        return 1  # 存在 systemd 服务
    else
        log_success "✅ 未发现 systemd 服务文件"
        return 0  # 不存在 systemd 服务
    fi
}

# 检查 cron 作业
check_cron_jobs() {
    echo
    echo "🕐 检查 cron 作业"
    echo "================"
    
    # 获取当前用户的 cron 作业
    CRON_JOBS=$(crontab -l 2>/dev/null | grep -v "^#" | grep -E "(tke_dify_sync|tke-dify)" || true)
    
    if [ -n "$CRON_JOBS" ]; then
        log_success "✅ 发现相关 cron 作业:"
        echo "$CRON_JOBS" | while read -r line; do
            if [ -n "$line" ]; then
                echo "   $line"
            fi
        done
        return 0  # 存在 cron 作业
    else
        log_warning "未发现相关 cron 作业"
        return 1  # 不存在 cron 作业
    fi
}

# 检查运行中的进程
check_running_processes() {
    echo
    echo "🔄 检查运行中的进程"
    echo "=================="
    
    RUNNING_PROCESSES=$(pgrep -f "python.*tke_dify_sync.py" 2>/dev/null || true)
    
    if [ -n "$RUNNING_PROCESSES" ]; then
        log_info "发现运行中的同步进程:"
        echo "$RUNNING_PROCESSES" | while read -r pid; do
            if [ -n "$pid" ]; then
                echo "   PID: $pid - $(ps -p $pid -o cmd --no-headers 2>/dev/null || echo '进程已结束')"
            fi
        done
    else
        log_info "未发现运行中的同步进程"
    fi
}

# 检查项目文件结构
check_project_structure() {
    echo
    echo "📁 检查项目文件结构"
    echo "=================="
    
    if [ -d "$PROJECT_DIR" ]; then
        log_success "✅ 项目目录存在: $PROJECT_DIR"
        
        # 检查关键文件
        CRITICAL_FILES=(
            "tke_dify_sync.py"
            "dify_sync_manager.py"
            ".env"
            "requirements.txt"
        )
        
        for file in "${CRITICAL_FILES[@]}"; do
            if [ -f "$PROJECT_DIR/$file" ]; then
                log_success "  ✅ $file"
            else
                log_warning "  ❌ $file (缺失)"
            fi
        done
        
        # 检查脚本目录
        if [ -d "$PROJECT_DIR/scripts" ]; then
            log_info "  📂 scripts/ 目录存在"
            ls -la "$PROJECT_DIR/scripts/" | grep -E "\.(sh)$" | while read -r line; do
                echo "    $line"
            done
        else
            log_warning "  ❌ scripts/ 目录不存在"
        fi
        
    else
        log_error "❌ 项目目录不存在: $PROJECT_DIR"
    fi
}

# 检查配置文件
check_configuration() {
    echo
    echo "⚙️ 检查配置文件"
    echo "=============="
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        log_success "✅ 主配置文件存在: .env"
        
        # 检查关键配置项
        REQUIRED_CONFIGS=(
            "DIFY_API_KEY"
            "DIFY_KNOWLEDGE_BASE_ID"
            "DIFY_API_BASE_URL"
        )
        
        for config in "${REQUIRED_CONFIGS[@]}"; do
            if grep -q "^$config=" "$PROJECT_DIR/.env" 2>/dev/null; then
                log_success "  ✅ $config 已配置"
            else
                log_warning "  ❌ $config 未配置或注释"
            fi
        done
    else
        log_warning "❌ 主配置文件不存在: .env"
    fi
    
    # 检查多知识库配置
    MULTI_KB_CONFIGS=(
        ".env.tke_docs_base"
        ".env.tke_knowledge_base"
    )
    
    echo
    echo "📚 多知识库配置:"
    for config in "${MULTI_KB_CONFIGS[@]}"; do
        if [ -f "$PROJECT_DIR/$config" ]; then
            log_success "  ✅ $config"
        else
            log_info "  ➖ $config (可选)"
        fi
    done
}

# 分析部署冲突
analyze_conflicts() {
    echo
    echo "⚠️ 部署冲突分析"
    echo "==============="
    
    local has_systemd=false
    local has_cron=false
    
    # 检查是否存在 systemd 服务
    if [ -f "$SERVICE_FILE" ]; then
        has_systemd=true
    fi
    
    # 检查是否存在 cron 作业
    if crontab -l 2>/dev/null | grep -q -E "(tke_dify_sync|tke-dify)"; then
        has_cron=true
    fi
    
    if [ "$has_systemd" = true ] && [ "$has_cron" = true ]; then
        log_error "🚨 严重冲突：同时存在 systemd 服务和 cron 作业！"
        echo "   这会导致："
        echo "   - systemd 服务持续重启脚本"
        echo "   - cron 作业定时启动脚本"
        echo "   - 资源浪费和不可预测的行为"
        echo
        echo "   建议操作："
        echo "   1. 立即停止并删除 systemd 服务"
        echo "   2. 保留 cron 作业作为唯一的调度方式"
        return 2
    elif [ "$has_systemd" = true ]; then
        log_error "🚨 问题：仅存在 systemd 服务（会导致无限重启）"
        echo "   建议操作："
        echo "   1. 删除 systemd 服务"
        echo "   2. 配置 cron 作业进行定时同步"
        return 1
    elif [ "$has_cron" = true ]; then
        log_success "✅ 正确：仅存在 cron 作业（推荐配置）"
        return 0
    else
        log_warning "⚠️ 未配置任何自动化调度"
        echo "   建议操作："
        echo "   1. 配置 cron 作业进行定时同步"
        return 1
    fi
}

# 生成修复建议
generate_recommendations() {
    echo
    echo "💡 修复建议"
    echo "=========="
    
    if [ -f "$SERVICE_FILE" ]; then
        echo "🔧 删除 systemd 服务："
        echo "   sudo systemctl stop $SERVICE_NAME"
        echo "   sudo systemctl disable $SERVICE_NAME"
        echo "   sudo rm $SERVICE_FILE"
        echo "   sudo systemctl daemon-reload"
        echo
    fi
    
    if ! crontab -l 2>/dev/null | grep -q -E "(tke_dify_sync|tke-dify)"; then
        echo "🕐 配置 cron 作业："
        echo "   crontab -e"
        echo "   # 添加以下行（每天凌晨2点执行）："
        echo "   0 2 * * * cd $PROJECT_DIR && $PROJECT_DIR/venv/bin/python tke_dify_sync.py >> $PROJECT_DIR/logs/cron.log 2>&1"
        echo
    fi
    
    echo "📋 验证配置："
    echo "   # 检查 cron 作业"
    echo "   crontab -l | grep tke"
    echo "   # 手动测试执行"
    echo "   cd $PROJECT_DIR && ./scripts/start.sh"
}

# 创建分析报告
create_analysis_report() {
    local report_file="$PROJECT_DIR/deployment_analysis_$(date +%Y%m%d_%H%M%S).md"
    
    echo
    echo "📊 生成分析报告: $report_file"
    
    cat > "$report_file" << EOF
# TKE 文档同步系统 - 部署分析报告

生成时间: $(date)

## 系统信息
- 操作系统: $(uname -a)
- 用户: $(whoami)
- 项目目录: $PROJECT_DIR

## systemd 服务状态
EOF

    if [ -f "$SERVICE_FILE" ]; then
        echo "- 服务文件: 存在 ❌" >> "$report_file"
        echo "- 服务状态: $(systemctl is-active $SERVICE_NAME 2>/dev/null || echo '未知')" >> "$report_file"
        echo "- 启用状态: $(systemctl is-enabled $SERVICE_NAME 2>/dev/null || echo '未知')" >> "$report_file"
    else
        echo "- 服务文件: 不存在 ✅" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "## cron 作业状态" >> "$report_file"
    echo '```' >> "$report_file"
    crontab -l 2>/dev/null | grep -E "(tke_dify_sync|tke-dify)" >> "$report_file" || echo "无相关 cron 作业" >> "$report_file"
    echo '```' >> "$report_file"

    echo "" >> "$report_file"
    echo "## 运行中的进程" >> "$report_file"
    echo '```' >> "$report_file"
    ps aux | grep -E "(python.*tke_dify_sync)" | grep -v grep >> "$report_file" || echo "无相关进程" >> "$report_file"
    echo '```' >> "$report_file"

    log_success "分析报告已生成: $report_file"
}

# 主函数
main() {
    echo "🔍 TKE 文档同步系统 - 部署分析"
    echo "================================"
    
    check_systemd_service
    systemd_status=$?
    
    check_cron_jobs
    cron_status=$?
    
    check_running_processes
    check_project_structure
    check_configuration
    
    analyze_conflicts
    conflict_status=$?
    
    generate_recommendations
    create_analysis_report
    
    echo
    echo "🎯 分析完成！"
    
    # 返回状态码
    if [ $conflict_status -eq 2 ]; then
        log_error "发现严重冲突，需要立即修复"
        exit 2
    elif [ $conflict_status -eq 1 ]; then
        log_warning "发现配置问题，建议修复"
        exit 1
    else
        log_success "配置正常"
        exit 0
    fi
}

# 运行主函数
main "$@"