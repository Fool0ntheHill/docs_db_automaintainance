#!/bin/bash

# 多知识库配置切换脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔄 TKE 多知识库配置切换工具"
echo "================================"

# 显示可用配置
echo "📋 可用配置文件:"
configs=()
for config in "$PROJECT_DIR"/.env.*; do
    if [ -f "$config" ] && [[ "$config" != *.example ]]; then
        basename_config=$(basename "$config")
        configs+=("$basename_config")
        echo "   - $basename_config"
    fi
done

if [ ${#configs[@]} -eq 0 ]; then
    echo "❌ 没有找到可用的配置文件"
    echo ""
    echo "💡 创建配置文件:"
    echo "   cp .env.production.example .env.production"
    echo "   cp .env.testing.example .env.testing"
    echo "   # 然后编辑配置文件"
    exit 1
fi

echo ""

# 显示当前配置
if [ -f "$PROJECT_DIR/.env" ]; then
    current_config="未知"
    for config in "${configs[@]}"; do
        if cmp -s "$PROJECT_DIR/.env" "$PROJECT_DIR/$config" 2>/dev/null; then
            current_config="$config"
            break
        fi
    done
    echo "📌 当前配置: $current_config"
else
    echo "📌 当前配置: 无"
fi

echo ""

# 如果提供了参数，直接切换
if [ $# -eq 1 ]; then
    target_config="$1"
    if [[ ! "$target_config" =~ ^\.env\. ]]; then
        target_config=".env.$target_config"
    fi
    
    if [ -f "$PROJECT_DIR/$target_config" ]; then
        echo "🔄 切换到配置: $target_config"
        cp "$PROJECT_DIR/$target_config" "$PROJECT_DIR/.env"
        echo "✅ 配置切换完成"
        
        # 显示新配置信息
        echo ""
        echo "📋 新配置信息:"
        grep -E "^(DIFY_KNOWLEDGE_BASE_ID|KB_STRATEGY|STATE_FILE|LOG_FILE)=" "$PROJECT_DIR/.env" | sed 's/^/   /'
        
        exit 0
    else
        echo "❌ 配置文件不存在: $target_config"
        exit 1
    fi
fi

# 交互式选择
echo "请选择要切换的配置:"
select config in "${configs[@]}" "取消"; do
    case $config in
        "取消")
            echo "❌ 已取消"
            exit 0
            ;;
        "")
            echo "❌ 无效选择，请重新选择"
            ;;
        *)
            echo ""
            echo "🔄 切换到配置: $config"
            
            # 备份当前配置
            if [ -f "$PROJECT_DIR/.env" ]; then
                cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
                echo "📄 已备份当前配置"
            fi
            
            # 切换配置
            cp "$PROJECT_DIR/$config" "$PROJECT_DIR/.env"
            echo "✅ 配置切换完成"
            
            # 显示新配置信息
            echo ""
            echo "📋 新配置信息:"
            grep -E "^(DIFY_KNOWLEDGE_BASE_ID|KB_STRATEGY|STATE_FILE|LOG_FILE)=" "$PROJECT_DIR/.env" | sed 's/^/   /'
            
            echo ""
            echo "💡 提示:"
            echo "   - 重新启动服务以使配置生效"
            echo "   - 使用 scripts/start.sh 启动同步"
            echo "   - 使用 scripts/status.sh 检查状态"
            
            break
            ;;
    esac
done