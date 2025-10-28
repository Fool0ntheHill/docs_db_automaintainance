#!/bin/bash

# TKE 文档同步系统停止脚本

echo "🛑 停止 TKE 文档同步系统"

# 查找并停止进程
PIDS=$(pgrep -f "python.*tke_dify_sync.py")

if [ -z "$PIDS" ]; then
    echo "ℹ️ 没有找到运行中的 TKE 同步进程"
else
    echo "📋 找到以下进程："
    ps -p $PIDS -o pid,ppid,cmd
    
    echo "🔄 正在停止进程..."
    kill $PIDS
    
    # 等待进程结束
    sleep 3
    
    # 检查是否还有进程
    REMAINING=$(pgrep -f "python.*tke_dify_sync.py")
    if [ -z "$REMAINING" ]; then
        echo "✅ 所有进程已停止"
    else
        echo "⚠️ 强制停止剩余进程"
        kill -9 $REMAINING
        echo "✅ 强制停止完成"
    fi
fi