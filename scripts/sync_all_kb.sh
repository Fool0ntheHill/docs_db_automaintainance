#!/bin/bash

# 多知识库批量同步脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 多知识库批量同步"
echo "=" * 30

# 切换到项目目录
cd "$PROJECT_DIR"

# 激活虚拟环境
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ 虚拟环境不存在"
    exit 1
fi

# 定义配置文件列表
CONFIG_FILES=(
    ".env.tke_docs_base"
    ".env.tke_knowledge_base"
)

# 定义配置文件描述
declare -A CONFIG_DESCRIPTIONS
CONFIG_DESCRIPTIONS[".env.tke_docs_base"]="TKE基础文档库"
CONFIG_DESCRIPTIONS[".env.tke_knowledge_base"]="TKE知识库"

# 备份当前配置文件
if [ -f ".env" ]; then
    cp .env .env.backup
    echo "📄 已备份当前配置文件为 .env.backup"
fi

# 同步结果统计
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# 遍历配置文件进行同步
for config_file in "${CONFIG_FILES[@]}"; do
    echo
    echo "📋 处理配置: $config_file (${CONFIG_DESCRIPTIONS[$config_file]})"
    echo "-" * 50
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        echo "⚠️ 配置文件不存在，跳过: $config_file"
        ((SKIP_COUNT++))
        continue
    fi
    
    # 复制配置文件
    cp "$config_file" .env
    echo "📁 已切换到配置: $config_file"
    
    # 执行同步
    echo "🚀 开始同步..."
    START_TIME=$(date +%s)
    
    if python tke_dify_sync.py; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo "✅ 同步成功 (耗时: ${DURATION}秒)"
        ((SUCCESS_COUNT++))
    else
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo "❌ 同步失败 (耗时: ${DURATION}秒)"
        ((FAIL_COUNT++))
    fi
done

# 恢复原始配置文件
if [ -f ".env.backup" ]; then
    mv .env.backup .env
    echo "📄 已恢复原始配置文件"
fi

# 显示同步结果
echo
echo "📊 批量同步结果统计"
echo "=" * 30
echo "✅ 成功: $SUCCESS_COUNT"
echo "❌ 失败: $FAIL_COUNT"
echo "⚠️ 跳过: $SKIP_COUNT"
echo "📋 总计: $((SUCCESS_COUNT + FAIL_COUNT + SKIP_COUNT))"

if [ $FAIL_COUNT -eq 0 ]; then
    echo "🎉 所有配置的知识库同步完成！"
    exit 0
else
    echo "⚠️ 部分知识库同步失败，请检查日志"
    exit 1
fi