#!/bin/bash

# TKE 文档同步系统启动脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 启动 TKE 文档同步系统"
echo "项目目录: $PROJECT_DIR"

# 切换到项目目录
cd "$PROJECT_DIR"

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "❌ 虚拟环境不存在，请先运行部署脚本"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

# 检查配置文件
if [ ! -f ".env" ]; then
    echo "❌ 配置文件 .env 不存在"
    echo "请先创建配置文件或运行配置向导：python config_wizard.py"
    exit 1
fi

# 启动程序
echo "📋 开始同步..."
python tke_dify_sync.py