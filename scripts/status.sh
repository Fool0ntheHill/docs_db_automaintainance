#!/bin/bash

# TKE 文档同步系统状态检查脚本

echo "📊 TKE 文档同步系统状态检查"
echo "=" * 40

# 检查进程状态
PIDS=$(pgrep -f "python.*tke_dify_sync.py")

if [ -z "$PIDS" ]; then
    echo "❌ TKE 同步服务未运行"
    SERVICE_RUNNING=false
else
    echo "✅ TKE 同步服务正在运行"
    echo "📋 进程信息："
    ps -p $PIDS -o pid,ppid,etime,cmd
    SERVICE_RUNNING=true
fi

echo

# 检查系统服务状态
if systemctl is-active --quiet tke-dify-sync 2>/dev/null; then
    echo "✅ 系统服务状态：运行中"
    systemctl status tke-dify-sync --no-pager -l
elif systemctl list-unit-files | grep -q tke-dify-sync; then
    echo "❌ 系统服务状态：已停止"
    echo "💡 启动服务：sudo systemctl start tke-dify-sync"
else
    echo "ℹ️ 系统服务未配置"
fi

echo

# 检查配置文件
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    echo "✅ 配置文件存在：$PROJECT_DIR/.env"
else
    echo "❌ 配置文件不存在：$PROJECT_DIR/.env"
fi

# 检查日志文件
if [ -d "$PROJECT_DIR/logs" ]; then
    echo "📊 日志文件："
    ls -la "$PROJECT_DIR/logs/" | grep -E "\.(log|json)$" | while read line; do
        echo "  $line"
    done
else
    echo "⚠️ 日志目录不存在"
fi

echo

# 检查最近的日志
if [ -f "$PROJECT_DIR/logs/tke_sync.log" ]; then
    echo "📝 最近的日志（最后10行）："
    tail -10 "$PROJECT_DIR/logs/tke_sync.log"
fi

echo
echo "🔧 管理命令："
echo "  启动：$SCRIPT_DIR/start.sh"
echo "  停止：$SCRIPT_DIR/stop.sh"
echo "  监控：$SCRIPT_DIR/monitor.sh"
echo "  日志：tail -f $PROJECT_DIR/logs/tke_sync.log"