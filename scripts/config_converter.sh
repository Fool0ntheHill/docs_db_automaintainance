#!/bin/bash

# TKE 文档同步系统 - 配置转换器
# 将旧的配置格式转换为新的多知识库配置格式

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
CONVERSION_LOG="$PROJECT_DIR/logs/config_conversion.log"

# 确保日志目录存在
mkdir -p "$PROJECT_DIR/logs"

# 日志函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$CONVERSION_LOG"
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
    echo "TKE 文档同步系统 - 配置转换器"
    echo "=============================="
    echo
    echo "用法: $0 [选项] [源配置文件]"
    echo
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -o, --output DIR        指定输出目录（默认：当前项目目录）"
    echo "  -t, --template TYPE     使用预定义模板"
    echo "  -b, --backup            备份现有配置文件"
    echo "  --dry-run              模拟运行，不创建实际文件"
    echo
    echo "模板类型:"
    echo "  enterprise             企业级三层架构"
    echo "  multi-env              多环境部署"
    echo "  simple                 简单双知识库"
    echo
    echo "示例:"
    echo "  $0 .env                           # 转换现有配置"
    echo "  $0 -t enterprise                 # 使用企业模板"
    echo "  $0 -o /tmp .env                   # 输出到指定目录"
    echo "  $0 --dry-run -t simple            # 模拟创建简单配置"
    echo
}

# 分析现有配置文件
analyze_existing_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    echo "🔍 分析现有配置文件: $config_file"
    echo "================================"
    
    # 提取关键配置项
    local api_key=$(grep "^DIFY_API_KEY=" "$config_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local kb_id=$(grep "^DIFY_KNOWLEDGE_BASE_ID=" "$config_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local api_url=$(grep "^DIFY_API_BASE_URL=" "$config_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    if [ -n "$api_key" ]; then
        log_success "发现 API Key: ${api_key:0:20}..."
    else
        log_warning "未找到 API Key"
    fi
    
    if [ -n "$kb_id" ]; then
        log_success "发现知识库 ID: $kb_id"
    else
        log_warning "未找到知识库 ID"
    fi
    
    if [ -n "$api_url" ]; then
        log_success "发现 API URL: $api_url"
    else
        log_warning "未找到 API URL"
    fi
    
    # 检查其他配置项
    local other_configs=$(grep -E "^[A-Z_]+=" "$config_file" | grep -v -E "^(DIFY_API_KEY|DIFY_KNOWLEDGE_BASE_ID|DIFY_API_BASE_URL)=" | wc -l)
    if [ $other_configs -gt 0 ]; then
        log_info "发现 $other_configs 个其他配置项"
    fi
    
    echo
    return 0
}

# 创建企业级配置模板
create_enterprise_template() {
    local output_dir="$1"
    local base_config="$2"
    
    log_info "创建企业级三层架构配置模板"
    
    # 从基础配置提取通用设置
    local api_url="https://your-dify-api.com/v1"
    local common_settings=""
    
    if [ -n "$base_config" ] && [ -f "$base_config" ]; then
        api_url=$(grep "^DIFY_API_BASE_URL=" "$base_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$api_url")
        common_settings=$(grep -E "^(REQUEST_TIMEOUT|RETRY_ATTEMPTS|RETRY_DELAY|CRAWL_DELAY)=" "$base_config" || true)
    fi
    
    # 生产环境配置
    cat > "$output_dir/.env.production_docs" << EOF
# TKE 文档同步系统 - 生产环境文档库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-your-production-key-here
DIFY_KNOWLEDGE_BASE_ID=production-docs-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 高可靠性配置
REQUEST_TIMEOUT=120
RETRY_ATTEMPTS=5
RETRY_DELAY=5
MAX_RETRIES=3

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_production.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_production.log

# 爬取配置
CRAWL_DELAY=3
MAX_PAGES=500
USER_AGENT=TKE-Sync-Production/1.0

# 其他配置
$common_settings
EOF
    
    # 开发环境配置
    cat > "$output_dir/.env.development_docs" << EOF
# TKE 文档同步系统 - 开发环境文档库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-your-development-key-here
DIFY_KNOWLEDGE_BASE_ID=development-docs-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 快速响应配置
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=2
MAX_RETRIES=2

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_development.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_development.log

# 爬取配置
CRAWL_DELAY=1
MAX_PAGES=200
USER_AGENT=TKE-Sync-Development/1.0

# 其他配置
$common_settings
EOF
    
    # API 参考文档配置
    cat > "$output_dir/.env.api_reference" << EOF
# TKE 文档同步系统 - API 参考文档库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-your-api-reference-key-here
DIFY_KNOWLEDGE_BASE_ID=api-reference-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 标准配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=4
RETRY_DELAY=3
MAX_RETRIES=3

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_api_reference.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_api_reference.log

# 爬取配置
CRAWL_DELAY=2
MAX_PAGES=300
USER_AGENT=TKE-Sync-API-Reference/1.0

# 其他配置
$common_settings
EOF
    
    log_success "企业级配置模板已创建"
    log_info "  - .env.production_docs (生产环境)"
    log_info "  - .env.development_docs (开发环境)"
    log_info "  - .env.api_reference (API 参考)"
}

# 创建多环境配置模板
create_multi_env_template() {
    local output_dir="$1"
    local base_config="$2"
    
    log_info "创建多环境部署配置模板"
    
    # 从基础配置提取设置
    local api_url="https://your-dify-api.com/v1"
    local common_settings=""
    
    if [ -n "$base_config" ] && [ -f "$base_config" ]; then
        api_url=$(grep "^DIFY_API_BASE_URL=" "$base_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$api_url")
        common_settings=$(grep -E "^(REQUEST_TIMEOUT|RETRY_ATTEMPTS|RETRY_DELAY|CRAWL_DELAY)=" "$base_config" || true)
    fi
    
    # 生产环境配置
    cat > "$output_dir/.env.production" << EOF
# TKE 文档同步系统 - 生产环境配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-production-key-here
DIFY_KNOWLEDGE_BASE_ID=production-kb-id-here
DIFY_API_BASE_URL=https://prod-dify.your-company.com/v1
KB_STRATEGY=primary

# 生产环境高可靠性配置
REQUEST_TIMEOUT=120
RETRY_ATTEMPTS=5
RETRY_DELAY=5
MAX_RETRIES=3

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_production.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_production.log

# 生产环境爬取配置
CRAWL_DELAY=3
MAX_PAGES=1000
USER_AGENT=TKE-Sync-Production/1.0

# 其他配置
$common_settings
EOF
    
    # 测试环境配置
    cat > "$output_dir/.env.staging" << EOF
# TKE 文档同步系统 - 测试环境配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-staging-key-here
DIFY_KNOWLEDGE_BASE_ID=staging-kb-id-here
DIFY_API_BASE_URL=https://staging-dify.your-company.com/v1
KB_STRATEGY=primary

# 测试环境配置
REQUEST_TIMEOUT=45
RETRY_ATTEMPTS=2
RETRY_DELAY=1
MAX_RETRIES=2

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_staging.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_staging.log

# 测试环境爬取配置（更激进）
CRAWL_DELAY=1
MAX_PAGES=500
USER_AGENT=TKE-Sync-Staging/1.0

# 其他配置
$common_settings
EOF
    
    log_success "多环境配置模板已创建"
    log_info "  - .env.production (生产环境)"
    log_info "  - .env.staging (测试环境)"
}

# 创建简单双知识库配置
create_simple_template() {
    local output_dir="$1"
    local base_config="$2"
    
    log_info "创建简单双知识库配置模板"
    
    # 从基础配置提取设置
    local api_url="https://your-dify-api.com/v1"
    local api_key=""
    local common_settings=""
    
    if [ -n "$base_config" ] && [ -f "$base_config" ]; then
        api_url=$(grep "^DIFY_API_BASE_URL=" "$base_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$api_url")
        api_key=$(grep "^DIFY_API_KEY=" "$base_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        common_settings=$(grep -E "^(REQUEST_TIMEOUT|RETRY_ATTEMPTS|RETRY_DELAY|CRAWL_DELAY)=" "$base_config" || true)
    fi
    
    # 基础文档知识库配置
    cat > "$output_dir/.env.tke_docs_base" << EOF
# TKE 文档同步系统 - 基础文档知识库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=${api_key:-dataset-your-base-docs-key-here}
DIFY_KNOWLEDGE_BASE_ID=base-docs-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 标准配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=3
RETRY_DELAY=2
MAX_RETRIES=3

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_base.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_base.log

# 爬取配置
CRAWL_DELAY=2
MAX_PAGES=400
USER_AGENT=TKE-Sync-Base/1.0

# 其他配置
$common_settings
EOF
    
    # 扩展知识库配置
    cat > "$output_dir/.env.tke_knowledge_base" << EOF
# TKE 文档同步系统 - 扩展知识库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=${api_key:-dataset-your-extended-kb-key-here}
DIFY_KNOWLEDGE_BASE_ID=extended-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=secondary

# 标准配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=3
RETRY_DELAY=2
MAX_RETRIES=3

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_extended.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_extended.log

# 爬取配置
CRAWL_DELAY=2
MAX_PAGES=600
USER_AGENT=TKE-Sync-Extended/1.0

# 其他配置
$common_settings
EOF
    
    log_success "简单双知识库配置模板已创建"
    log_info "  - .env.tke_docs_base (基础文档)"
    log_info "  - .env.tke_knowledge_base (扩展知识库)"
}

# 转换现有配置
convert_existing_config() {
    local source_config="$1"
    local output_dir="$2"
    
    if [ ! -f "$source_config" ]; then
        log_error "源配置文件不存在: $source_config"
        return 1
    fi
    
    log_info "转换现有配置文件: $source_config"
    
    # 分析现有配置
    analyze_existing_config "$source_config"
    
    # 提取配置值
    local api_key=$(grep "^DIFY_API_KEY=" "$source_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local kb_id=$(grep "^DIFY_KNOWLEDGE_BASE_ID=" "$source_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local api_url=$(grep "^DIFY_API_BASE_URL=" "$source_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    # 创建基于现有配置的多知识库版本
    if [ -n "$api_key" ] && [ -n "$kb_id" ] && [ -n "$api_url" ]; then
        log_info "创建基于现有配置的多知识库版本"
        
        # 主配置（保持原有）
        cp "$source_config" "$output_dir/.env.primary"
        
        # 创建第二个知识库配置模板
        cat > "$output_dir/.env.secondary" << EOF
# TKE 文档同步系统 - 第二知识库配置
# 基于 $source_config 转换生成于 $(date)

# Dify API 配置
DIFY_API_KEY=$api_key
DIFY_KNOWLEDGE_BASE_ID=your-second-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=secondary

# 从原配置复制的其他设置
$(grep -E "^[A-Z_]+=" "$source_config" | grep -v -E "^(DIFY_API_KEY|DIFY_KNOWLEDGE_BASE_ID|DIFY_API_BASE_URL)=")
EOF
        
        log_success "配置转换完成"
        log_info "  - .env.primary (基于原配置)"
        log_info "  - .env.secondary (第二知识库模板)"
        log_warning "请手动更新 .env.secondary 中的 DIFY_KNOWLEDGE_BASE_ID"
    else
        log_error "源配置文件缺少必要的配置项"
        return 1
    fi
}

# 主函数
main() {
    local output_dir="$PROJECT_DIR"
    local template_type=""
    local source_config=""
    local backup=false
    local dry_run=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -t|--template)
                template_type="$2"
                shift 2
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$source_config" ]; then
                    source_config="$1"
                else
                    log_error "只能指定一个源配置文件"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo "🔧 TKE 文档同步系统 - 配置转换器"
    echo "==============================="
    
    if [ "$dry_run" = true ]; then
        echo "🔍 模拟运行模式 - 不会创建实际文件"
        echo
    fi
    
    # 记录转换开始
    log_message "开始配置转换过程"
    
    # 创建输出目录
    if [ "$dry_run" != true ]; then
        mkdir -p "$output_dir"
    else
        echo "[DRY RUN] mkdir -p $output_dir"
    fi
    
    # 备份现有配置
    if [ "$backup" = true ]; then
        local backup_dir="$PROJECT_DIR/config_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "创建配置备份: $backup_dir"
        
        if [ "$dry_run" != true ]; then
            mkdir -p "$backup_dir"
            cp "$PROJECT_DIR"/.env* "$backup_dir/" 2>/dev/null || true
        else
            echo "[DRY RUN] mkdir -p $backup_dir"
            echo "[DRY RUN] cp $PROJECT_DIR/.env* $backup_dir/"
        fi
    fi
    
    # 执行转换
    if [ -n "$template_type" ]; then
        case "$template_type" in
            enterprise)
                if [ "$dry_run" != true ]; then
                    create_enterprise_template "$output_dir" "$source_config"
                else
                    echo "[DRY RUN] 将创建企业级配置模板"
                fi
                ;;
            multi-env)
                if [ "$dry_run" != true ]; then
                    create_multi_env_template "$output_dir" "$source_config"
                else
                    echo "[DRY RUN] 将创建多环境配置模板"
                fi
                ;;
            simple)
                if [ "$dry_run" != true ]; then
                    create_simple_template "$output_dir" "$source_config"
                else
                    echo "[DRY RUN] 将创建简单双知识库配置模板"
                fi
                ;;
            *)
                log_error "未知模板类型: $template_type"
                log_info "支持的模板类型: enterprise, multi-env, simple"
                exit 1
                ;;
        esac
    elif [ -n "$source_config" ]; then
        if [ "$dry_run" != true ]; then
            convert_existing_config "$source_config" "$output_dir"
        else
            echo "[DRY RUN] 将转换配置文件: $source_config"
        fi
    else
        log_error "必须指定模板类型或源配置文件"
        show_help
        exit 1
    fi
    
    echo
    echo "✅ 配置转换完成"
    echo "==============="
    
    if [ "$dry_run" != true ]; then
        log_success "配置文件已生成到: $output_dir"
        echo
        echo "📋 生成的配置文件:"
        ls -la "$output_dir"/.env.* 2>/dev/null || echo "  无配置文件生成"
        
        echo
        echo "🔧 下一步操作:"
        echo "  1. 检查并编辑生成的配置文件"
        echo "  2. 更新 API Key 和知识库 ID"
        echo "  3. 运行迁移工具: ./scripts/migrate_to_cron.sh"
        echo "  4. 测试配置: ./scripts/validate_cron_setup.sh"
    else
        echo "🔍 模拟运行完成"
        echo "实际运行时将在 $output_dir 创建配置文件"
    fi
    
    log_message "配置转换完成"
}

# 运行主函数
main "$@"    if [ -n 
"$base_config" ] && [ -f "$base_config" ]; then
        api_url=$(grep "^DIFY_API_BASE_URL=" "$base_config" | cut -d'=' -f2- | tr -d '"' | tr -d "'" || echo "$api_url")
        common_settings=$(grep -E "^(REQUEST_TIMEOUT|RETRY_ATTEMPTS|RETRY_DELAY|CRAWL_DELAY)=" "$base_config" || true)
    fi
    
    # 基础文档库配置
    cat > "$output_dir/.env.tke_docs_base" << EOF
# TKE 文档同步系统 - 基础文档库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-your-base-docs-key-here
DIFY_KNOWLEDGE_BASE_ID=base-docs-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 标准配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=3
RETRY_DELAY=2
MAX_RETRIES=2

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_base.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_base.log

# 爬取配置
CRAWL_DELAY=2
MAX_PAGES=500
USER_AGENT=TKE-Sync-Base/1.0

# 其他配置
$common_settings
EOF
    
    # 知识库配置
    cat > "$output_dir/.env.tke_knowledge_base" << EOF
# TKE 文档同步系统 - 知识库配置
# 生成时间: $(date)

# Dify API 配置
DIFY_API_KEY=dataset-your-knowledge-base-key-here
DIFY_KNOWLEDGE_BASE_ID=knowledge-base-kb-id-here
DIFY_API_BASE_URL=$api_url
KB_STRATEGY=primary

# 标准配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=3
RETRY_DELAY=2
MAX_RETRIES=2

# 文件路径配置
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_knowledge.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_knowledge.log

# 爬取配置
CRAWL_DELAY=2
MAX_PAGES=500
USER_AGENT=TKE-Sync-Knowledge/1.0

# 其他配置
$common_settings
EOF
    
    log_success "简单双知识库配置模板已创建"
    log_info "  - .env.tke_docs_base (基础文档)"
    log_info "  - .env.tke_knowledge_base (知识库)"
}

# 转换现有配置文件
convert_existing_config() {
    local source_file="$1"
    local output_dir="$2"
    
    if [ ! -f "$source_file" ]; then
        log_error "源配置文件不存在: $source_file"
        return 1
    fi
    
    log_info "转换现有配置文件: $source_file"
    
    # 分析现有配置
    analyze_existing_config "$source_file"
    
    # 提取配置值
    local api_key=$(grep "^DIFY_API_KEY=" "$source_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local kb_id=$(grep "^DIFY_KNOWLEDGE_BASE_ID=" "$source_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local api_url=$(grep "^DIFY_API_BASE_URL=" "$source_file" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    
    # 提取其他配置
    local other_configs=$(grep -E "^[A-Z_]+=" "$source_file" | grep -v -E "^(DIFY_API_KEY|DIFY_KNOWLEDGE_BASE_ID|DIFY_API_BASE_URL)=")
    
    # 创建基础配置（保持原有配置）
    cat > "$output_dir/.env" << EOF
# TKE 文档同步系统 - 主配置文件
# 从 $source_file 转换而来
# 转换时间: $(date)

# Dify API 配置
DIFY_API_KEY=$api_key
DIFY_KNOWLEDGE_BASE_ID=$kb_id
DIFY_API_BASE_URL=$api_url

# 其他配置
$other_configs
EOF
    
    # 创建多知识库配置示例
    if [ -n "$api_key" ] && [ -n "$api_url" ]; then
        cat > "$output_dir/.env.example_kb2" << EOF
# TKE 文档同步系统 - 第二知识库配置示例
# 基于 $source_file 创建
# 创建时间: $(date)

# Dify API 配置（需要修改为实际值）
DIFY_API_KEY=dataset-your-second-kb-key-here
DIFY_KNOWLEDGE_BASE_ID=your-second-kb-id-here
DIFY_API_BASE_URL=$api_url

# 继承的其他配置
$other_configs

# 独立的状态和日志文件
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_kb2.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_kb2.log
EOF
    fi
    
    log_success "配置转换完成"
    log_info "  - .env (主配置文件)"
    log_info "  - .env.example_kb2 (第二知识库示例)"
}

# 备份现有配置
backup_existing_configs() {
    local output_dir="$1"
    local backup_dir="$output_dir/config_backup_$(date +%Y%m%d_%H%M%S)"
    
    log_info "备份现有配置文件到: $backup_dir"
    mkdir -p "$backup_dir"
    
    # 备份所有 .env 文件
    find "$PROJECT_DIR" -maxdepth 1 -name ".env*" -type f -exec cp {} "$backup_dir/" \; 2>/dev/null || true
    
    # 备份 crontab
    crontab -l > "$backup_dir/current_crontab.txt" 2>/dev/null || echo "无现有 crontab" > "$backup_dir/current_crontab.txt"
    
    # 创建备份报告
    cat > "$backup_dir/backup_info.md" << EOF
# 配置备份报告

## 备份信息
- 备份时间: $(date)
- 备份目录: $backup_dir
- 备份工具: config_converter.sh

## 备份文件
$(ls -la "$backup_dir" 2>/dev/null || echo "无文件")

## 恢复说明
要恢复配置文件，请将备份目录中的文件复制回项目根目录：
\`\`\`bash
cp $backup_dir/.env* $PROJECT_DIR/
crontab $backup_dir/current_crontab.txt
\`\`\`
EOF
    
    log_success "配置备份完成: $backup_dir"
    echo "$backup_dir"
}

# 验证生成的配置
validate_generated_configs() {
    local output_dir="$1"
    
    echo
    echo "🔍 验证生成的配置文件"
    echo "===================="
    
    local issues=0
    
    # 检查生成的配置文件
    for config_file in "$output_dir"/.env*; do
        if [ -f "$config_file" ]; then
            local filename=$(basename "$config_file")
            log_info "验证配置文件: $filename"
            
            # 检查必需的配置项
            if grep -q "^DIFY_API_KEY=" "$config_file"; then
                if grep "^DIFY_API_KEY=" "$config_file" | grep -q "your.*key.*here"; then
                    log_warning "  $filename: API Key 需要替换为实际值"
                    ((issues++))
                else
                    log_success "  $filename: API Key 已配置"
                fi
            else
                log_error "  $filename: 缺少 DIFY_API_KEY"
                ((issues++))
            fi
            
            if grep -q "^DIFY_KNOWLEDGE_BASE_ID=" "$config_file"; then
                if grep "^DIFY_KNOWLEDGE_BASE_ID=" "$config_file" | grep -q "your.*id.*here"; then
                    log_warning "  $filename: 知识库 ID 需要替换为实际值"
                    ((issues++))
                else
                    log_success "  $filename: 知识库 ID 已配置"
                fi
            else
                log_error "  $filename: 缺少 DIFY_KNOWLEDGE_BASE_ID"
                ((issues++))
            fi
            
            if grep -q "^DIFY_API_BASE_URL=" "$config_file"; then
                log_success "  $filename: API URL 已配置"
            else
                log_error "  $filename: 缺少 DIFY_API_BASE_URL"
                ((issues++))
            fi
        fi
    done
    
    return $issues
}

# 生成配置使用说明
generate_usage_instructions() {
    local output_dir="$1"
    local template_type="$2"
    local instructions_file="$output_dir/CONFIG_USAGE.md"
    
    log_info "生成配置使用说明: $instructions_file"
    
    cat > "$instructions_file" << EOF
# TKE 文档同步系统 - 配置使用说明

生成时间: $(date)
模板类型: $template_type

## 配置文件说明

### 生成的配置文件
$(ls -la "$output_dir"/.env* 2>/dev/null | awk '{print "- " $9}' | grep -v "^- $")

## 使用步骤

### 1. 配置 API 密钥和知识库 ID

编辑每个 .env 文件，替换以下占位符：
- \`dataset-your-*-key-here\` → 实际的 Dify API 密钥
- \`*-kb-id-here\` → 实际的知识库 ID
- API URL（如果需要）

### 2. 设置 cron 作业

根据配置文件数量设置相应的 cron 作业：

EOF

    # 根据模板类型添加具体说明
    case "$template_type" in
        "enterprise")
            cat >> "$instructions_file" << EOF
#### 企业级三层架构
\`\`\`bash
# 生产环境文档库 - 每天凌晨2点
0 2 * * * cd /opt/tke-dify-sync && cp .env.production_docs .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_production.log 2>&1

# 开发环境文档库 - 每天凌晨3点
0 3 * * * cd /opt/tke-dify-sync && cp .env.development_docs .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_development.log 2>&1

# API 参考文档库 - 每天凌晨4点
0 4 * * * cd /opt/tke-dify-sync && cp .env.api_reference .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_api_reference.log 2>&1
\`\`\`
EOF
            ;;
        "multi-env")
            cat >> "$instructions_file" << EOF
#### 多环境部署
\`\`\`bash
# 生产环境 - 每天凌晨2点
0 2 * * * cd /opt/tke-dify-sync && cp .env.production .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_production.log 2>&1

# 测试环境 - 每天凌晨3点
0 3 * * * cd /opt/tke-dify-sync && cp .env.staging .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_staging.log 2>&1

# 开发环境 - 每天凌晨4点
0 4 * * * cd /opt/tke-dify-sync && cp .env.development .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_development.log 2>&1
\`\`\`
EOF
            ;;
        "simple")
            cat >> "$instructions_file" << EOF
#### 简单双知识库
\`\`\`bash
# 基础文档库 - 每天凌晨2点
0 2 * * * cd /opt/tke-dify-sync && cp .env.tke_docs_base .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_base.log 2>&1

# 知识库 - 每天凌晨3点
0 3 * * * cd /opt/tke-dify-sync && cp .env.tke_knowledge_base .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_knowledge.log 2>&1
\`\`\`
EOF
            ;;
        "converted")
            cat >> "$instructions_file" << EOF
#### 转换后的配置
\`\`\`bash
# 主配置 - 每天凌晨2点
0 2 * * * cd /opt/tke-dify-sync && ./venv/bin/python tke_dify_sync.py >> logs/cron.log 2>&1

# 如果有第二个知识库配置
0 3 * * * cd /opt/tke-dify-sync && cp .env.example_kb2 .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_kb2.log 2>&1
\`\`\`
EOF
            ;;
    esac

    cat >> "$instructions_file" << EOF

### 3. 安装 cron 作业

\`\`\`bash
# 编辑 crontab
crontab -e

# 或者使用脚本安装
echo "上述 cron 作业内容" | crontab -
\`\`\`

### 4. 验证配置

\`\`\`bash
# 检查 cron 作业
crontab -l

# 测试配置文件
cd /opt/tke-dify-sync
for env_file in .env.*; do
    echo "测试 \$env_file:"
    cp "\$env_file" .env
    ./venv/bin/python tke_dify_sync.py --test
done
\`\`\`

## 注意事项

1. **API 密钥安全**: 确保 .env 文件权限设置为 600
   \`\`\`bash
   chmod 600 .env*
   \`\`\`

2. **日志管理**: 定期清理日志文件
   \`\`\`bash
   # 添加到 crontab
   0 1 * * 0 find /opt/tke-dify-sync/logs -name "*.log" -mtime +7 -delete
   \`\`\`

3. **监控**: 使用监控脚本检查执行状态
   \`\`\`bash
   ./scripts/monitor.sh
   ./scripts/health_check.sh
   \`\`\`

## 故障排除

如果遇到问题：
1. 检查配置文件语法: \`./scripts/validate_cron_setup.sh\`
2. 查看执行日志: \`tail -f logs/cron*.log\`
3. 手动测试执行: \`./scripts/start.sh\`
4. 运行健康检查: \`./scripts/health_check.sh\`

## 回滚

如需回滚到原始配置，使用备份目录中的文件：
\`\`\`bash
# 恢复原始配置（如果有备份）
cp config_backup_*/env* ./
\`\`\`
EOF

    log_success "配置使用说明已生成: $instructions_file"
}

# 主函数
main() {
    local source_config=""
    local output_dir="$PROJECT_DIR"
    local template_type=""
    local backup=false
    local dry_run=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -t|--template)
                template_type="$2"
                shift 2
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$source_config" ]; then
                    source_config="$1"
                else
                    log_error "多余的参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo "🔄 TKE 文档同步系统 - 配置转换器"
    echo "================================="
    
    if [ "$dry_run" = true ]; then
        echo "🔍 模拟运行模式 - 不会创建实际文件"
        echo
    fi
    
    # 记录转换开始
    log_message "开始配置转换过程"
    
    # 创建输出目录
    if [ "$output_dir" != "$PROJECT_DIR" ]; then
        mkdir -p "$output_dir"
        log_info "使用输出目录: $output_dir"
    fi
    
    # 备份现有配置
    local backup_dir=""
    if [ "$backup" = true ] || [ -n "$source_config" ]; then
        if [ "$dry_run" != true ]; then
            backup_dir=$(backup_existing_configs "$output_dir")
        else
            echo "[DRY RUN] 将备份现有配置文件"
        fi
    fi
    
    # 执行转换或创建模板
    if [ -n "$template_type" ]; then
        log_info "使用模板类型: $template_type"
        
        case "$template_type" in
            "enterprise")
                if [ "$dry_run" != true ]; then
                    create_enterprise_template "$output_dir" "$source_config"
                    generate_usage_instructions "$output_dir" "enterprise"
                else
                    echo "[DRY RUN] 将创建企业级三层架构配置模板"
                fi
                ;;
            "multi-env")
                if [ "$dry_run" != true ]; then
                    create_multi_env_template "$output_dir" "$source_config"
                    generate_usage_instructions "$output_dir" "multi-env"
                else
                    echo "[DRY RUN] 将创建多环境部署配置模板"
                fi
                ;;
            "simple")
                if [ "$dry_run" != true ]; then
                    create_simple_template "$output_dir" "$source_config"
                    generate_usage_instructions "$output_dir" "simple"
                else
                    echo "[DRY RUN] 将创建简单双知识库配置模板"
                fi
                ;;
            *)
                log_error "未知的模板类型: $template_type"
                log_info "支持的模板类型: enterprise, multi-env, simple"
                exit 1
                ;;
        esac
    elif [ -n "$source_config" ]; then
        log_info "转换现有配置文件: $source_config"
        
        if [ "$dry_run" != true ]; then
            convert_existing_config "$source_config" "$output_dir"
            generate_usage_instructions "$output_dir" "converted"
        else
            echo "[DRY RUN] 将转换配置文件: $source_config"
        fi
    else
        log_error "必须指定源配置文件或模板类型"
        show_help
        exit 1
    fi
    
    # 验证生成的配置
    if [ "$dry_run" != true ]; then
        validate_generated_configs "$output_dir"
        local issues=$?
        
        echo
        echo "🎉 配置转换完成！"
        echo "=================="
        
        if [ $issues -eq 0 ]; then
            log_success "✅ 配置转换成功完成"
        else
            log_warning "⚠️ 配置转换完成但发现 $issues 个需要注意的问题"
        fi
        
        echo
        echo "📋 生成的文件:"
        ls -la "$output_dir"/.env* 2>/dev/null | while read -r line; do
            echo "  $line"
        done
        
        if [ -f "$output_dir/CONFIG_USAGE.md" ]; then
            echo "  $(ls -la "$output_dir/CONFIG_USAGE.md")"
        fi
        
        if [ -n "$backup_dir" ]; then
            echo
            echo "💾 备份目录: $backup_dir"
        fi
        
        echo
        echo "🔧 下一步操作:"
        echo "  1. 编辑配置文件，替换占位符为实际值"
        echo "  2. 阅读 CONFIG_USAGE.md 了解详细使用说明"
        echo "  3. 设置相应的 cron 作业"
        echo "  4. 运行验证脚本测试配置"
        
        log_message "配置转换完成，发现 $issues 个问题"
    else
        echo
        echo "🔍 模拟运行完成"
        echo "实际运行时将执行上述所有操作"
    fi
}

# 运行主函数
main "$@"