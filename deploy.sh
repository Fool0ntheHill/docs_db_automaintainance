#!/bin/bash

# TKE 文档同步系统一键部署脚本
# 适用于 Ubuntu 20.04+ 和 CentOS 7+

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_NAME="tke-dify-sync"
INSTALL_DIR="/opt/${PROJECT_NAME}"
SERVICE_USER="ubuntu"
PYTHON_VERSION="3.8"

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

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用 root 用户运行此脚本"
        log_info "建议使用普通用户（如 ubuntu）运行，脚本会在需要时请求 sudo 权限"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        
        # 特殊处理 TencentOS
        if [[ "$OS" == *"TencentOS"* ]]; then
            OS="TencentOS Server"
            log_info "检测到 TencentOS Server，将使用 CentOS 兼容模式"
        fi
    else
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    log_info "检测到操作系统: $OS $VER"
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    log_info "检测到操作系统: $OS $VER"
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."
    
    # 检查内存
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ $MEMORY_GB -lt 3 ]; then
        log_warning "系统内存少于 4GB，可能影响性能"
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ $DISK_SPACE -lt 10485760 ]; then  # 10GB in KB
        log_warning "根分区可用空间少于 10GB，可能不足"
    fi
    
    log_success "系统要求检查完成"
}

# 安装系统依赖
install_system_dependencies() {
    log_info "安装系统依赖..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        # Ubuntu/Debian 系统
        sudo apt update
        sudo apt install -y python3 python3-pip python3-venv git curl wget unzip software-properties-common
        
        # 安装 Chrome
        if ! command -v google-chrome &> /dev/null; then
            log_info "安装 Google Chrome..."
            wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
            echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
            sudo apt update
            sudo apt install -y google-chrome-stable
        fi
        
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"TencentOS"* ]]; then
        # CentOS/RHEL/TencentOS 系统
        if [[ "$OS" == *"TencentOS"* ]]; then
            log_info "配置 TencentOS Server 软件源..."
            # TencentOS 使用 yum，兼容 CentOS
        fi
        
        sudo yum update -y
        sudo yum install -y epel-release
        sudo yum install -y python3 python3-pip git curl wget unzip
        
        # 安装 Chrome
        if ! command -v google-chrome &> /dev/null; then
            log_info "安装 Google Chrome..."
            sudo yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
        fi
    else
        log_error "不支持的操作系统: $OS"
        exit 1
    fi
    
    log_success "系统依赖安装完成"
}

# 创建项目目录
create_project_directory() {
    log_info "创建项目目录..."
    
    # 创建主目录
    sudo mkdir -p $INSTALL_DIR
    sudo chown $USER:$USER $INSTALL_DIR
    
    # 创建子目录
    mkdir -p $INSTALL_DIR/{config,data,logs,scripts,temp}
    
    log_success "项目目录创建完成: $INSTALL_DIR"
}

# 下载项目文件
download_project_files() {
    log_info "下载项目文件..."
    
    cd $INSTALL_DIR
    
    # 如果有 Git 仓库，使用 git clone
    # git clone https://github.com/your-repo/tke-dify-sync.git .
    
    # 临时方案：创建必要的文件
    log_warning "请手动上传以下文件到 $INSTALL_DIR 目录："
    echo "  - tke_dify_sync.py"
    echo "  - dify_sync_manager.py"
    echo "  - enhanced_metadata_generator.py"
    echo "  - smart_retry_manager.py"
    echo "  - tke_logger.py"
    echo "  - secure_temp_manager.py"
    echo "  - requirements.txt"
    echo "  - .env.example"
    
    read -p "文件上传完成后，按 Enter 继续..."
    
    # 检查必要文件是否存在
    REQUIRED_FILES=(
        "tke_dify_sync.py"
        "dify_sync_manager.py"
        "enhanced_metadata_generator.py"
        "smart_retry_manager.py"
        "tke_logger.py"
        "secure_temp_manager.py"
        "requirements.txt"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "缺少必要文件: $file"
            exit 1
        fi
    done
    
    log_success "项目文件检查完成"
}

# 创建 requirements.txt
create_requirements() {
    log_info "创建 requirements.txt..."
    
    # 检查是否已存在 requirements.txt
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        log_info "requirements.txt 已存在，跳过创建"
        return
    fi
    
    cat > $INSTALL_DIR/requirements.txt << 'EOF'
# TKE 文档同步系统依赖包
# 核心依赖
requests>=2.28.0
beautifulsoup4>=4.11.0
selenium>=4.8.0
webdriver-manager>=3.8.0
lxml>=4.9.0

# 网络和编码
urllib3>=1.26.0
certifi>=2022.12.7
charset-normalizer>=3.0.0
idna>=3.4

# HTML 解析
soupsieve>=2.3.0

# Selenium 依赖
trio>=0.22.0
trio-websocket>=0.9.0
wsproto>=1.2.0
h11>=0.14.0
outcome>=1.2.0
sniffio>=1.3.0
sortedcontainers>=2.4.0
attrs>=22.2.0
exceptiongroup>=1.1.0
async-generator>=1.10
packaging>=23.0

# 代理支持
PySocks>=1.7.0
EOF
    
    log_success "requirements.txt 创建完成"
}

# 设置 Python 环境
setup_python_environment() {
    log_info "设置 Python 虚拟环境..."
    
    cd $INSTALL_DIR
    
    # 创建虚拟环境
    python3 -m venv venv
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    pip install --upgrade pip
    
    # 安装依赖
    pip install -r requirements.txt
    
    log_success "Python 环境设置完成"
}

# 创建配置文件
create_config_files() {
    log_info "创建配置文件..."
    
    # 创建 .env.example
    cat > $INSTALL_DIR/.env.example << 'EOF'
# === Dify API 配置 ===
DIFY_API_KEY=your_dify_api_key_here
DIFY_KNOWLEDGE_BASE_ID=your_knowledge_base_id_here
DIFY_API_BASE_URL=https://api.dify.ai/v1

# === 同步策略 ===
KB_STRATEGY=primary

# === 网络配置 ===
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=2

# === 文件配置 ===
STATE_FILE=/opt/tke-dify-sync/data/crawl_state.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync.log

# === TKE 文档配置 ===
BASE_URL=https://cloud.tencent.com
START_URL=https://cloud.tencent.com/document/product/457

# === 内容格式配置 ===
# 内容格式配置
# 注意：现在默认使用 Markdown 格式提取，保持文档结构和格式
# 支持标题、列表、链接、代码块等，无需配置项
EOF

    # 复制为实际配置文件
    cp $INSTALL_DIR/.env.example $INSTALL_DIR/.env
    
    log_success "配置文件创建完成"
    log_warning "请编辑 $INSTALL_DIR/.env 文件，填入正确的 Dify API 配置"
}

# 创建启动脚本
create_scripts() {
    log_info "创建管理脚本..."
    
    # 启动脚本
    cat > $INSTALL_DIR/scripts/start.sh << 'EOF'
#!/bin/bash
cd /opt/tke-dify-sync
source venv/bin/activate
python tke_dify_sync.py
EOF

    # 停止脚本
    cat > $INSTALL_DIR/scripts/stop.sh << 'EOF'
#!/bin/bash
pkill -f "python.*tke_dify_sync.py"
EOF

    # 状态检查脚本
    cat > $INSTALL_DIR/scripts/status.sh << 'EOF'
#!/bin/bash
if pgrep -f "python.*tke_dify_sync.py" > /dev/null; then
    echo "✅ TKE 同步服务正在运行"
    pgrep -f "python.*tke_dify_sync.py" | while read pid; do
        echo "  PID: $pid"
    done
else
    echo "❌ TKE 同步服务未运行"
fi
EOF

    # 监控脚本
    cat > $INSTALL_DIR/scripts/monitor.sh << 'EOF'
#!/bin/bash
SERVICE_NAME="tke-dify-sync"
LOG_FILE="/opt/tke-dify-sync/logs/monitor.log"
PID_FILE="/opt/tke-dify-sync/data/tke_sync.pid"

# 检查 cron 作业状态（不检查 systemd 服务）
check_cron_status() {
    # 检查 cron 作业是否配置
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync"; then
        echo "$(date): ✅ cron 作业已配置" >> $LOG_FILE
        return 0
    else
        echo "$(date): ⚠️ cron 作业未配置" >> $LOG_FILE
        return 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    USAGE=$(df /opt/tke-dify-sync | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $USAGE -gt 80 ]; then
        echo "$(date): ⚠️ 磁盘使用率过高: ${USAGE}%" >> $LOG_FILE
    fi
}

# 清理旧日志
cleanup_logs() {
    find /opt/tke-dify-sync/logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
}

# 执行检查
check_service
check_disk_space
cleanup_logs
EOF

    # 设置执行权限
    chmod +x $INSTALL_DIR/scripts/*.sh
    
    # 创建符号链接到 PATH（可选）
    if [ -d "/usr/local/bin" ]; then
        sudo ln -sf $INSTALL_DIR/scripts/start.sh /usr/local/bin/tke-start 2>/dev/null || true
        sudo ln -sf $INSTALL_DIR/scripts/stop.sh /usr/local/bin/tke-stop 2>/dev/null || true
        sudo ln -sf $INSTALL_DIR/scripts/status.sh /usr/local/bin/tke-status 2>/dev/null || true
    fi
    
    log_success "管理脚本创建完成"
}

# 注意：已删除 create_systemd_service() 函数
# 原因：systemd 服务会导致脚本无限重启，与 cron 调度冲突
# 现在只使用 cron 作业进行定时同步

# 设置文件权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置目录权限
    chmod 755 $INSTALL_DIR
    chmod 755 $INSTALL_DIR/{config,data,logs,scripts,temp}
    
    # 设置文件权限
    chmod 644 $INSTALL_DIR/*.py
    chmod 600 $INSTALL_DIR/.env*
    chmod 755 $INSTALL_DIR/scripts/*.sh
    
    # 确保用户拥有所有文件
    chown -R $USER:$USER $INSTALL_DIR
    
    log_success "文件权限设置完成"
}

# 生成 cron 作业模板
generate_cron_templates() {
    local template_dir="$INSTALL_DIR/config/cron_templates"
    mkdir -p "$template_dir"
    
    log_info "生成 cron 作业模板..."
    
    # 单知识库模板
    cat > "$template_dir/single_kb.cron" << EOF
# TKE 文档同步系统 - 单知识库配置
# 每天凌晨2点执行同步
0 2 * * * cd $INSTALL_DIR && $INSTALL_DIR/venv/bin/python tke_dify_sync.py >> $INSTALL_DIR/logs/cron.log 2>&1

# 监控任务（每5分钟检查一次）
*/5 * * * * $INSTALL_DIR/scripts/monitor.sh >/dev/null 2>&1

# 日志清理（每周日凌晨1点）
0 1 * * 0 find $INSTALL_DIR/logs -name '*.log' -mtime +7 -delete 2>/dev/null || true
EOF

    # 多知识库模板
    cat > "$template_dir/multi_kb.cron" << EOF
# TKE 文档同步系统 - 多知识库配置
# tke_docs_base 知识库（凌晨2点）
0 2 * * * cd $INSTALL_DIR && cp .env.tke_docs_base .env && $INSTALL_DIR/venv/bin/python tke_dify_sync.py >> $INSTALL_DIR/logs/cron_tke_docs_base.log 2>&1

# tke_knowledge_base 知识库（凌晨3点）
0 3 * * * cd $INSTALL_DIR && cp .env.tke_knowledge_base .env && $INSTALL_DIR/venv/bin/python tke_dify_sync.py >> $INSTALL_DIR/logs/cron_tke_knowledge_base.log 2>&1

# 监控任务（每5分钟检查一次）
*/5 * * * * $INSTALL_DIR/scripts/monitor.sh >/dev/null 2>&1

# 日志清理（每周日凌晨1点）
0 1 * * 0 find $INSTALL_DIR/logs -name '*.log' -mtime +7 -delete 2>/dev/null || true
EOF

    # 高频同步模板（每6小时）
    cat > "$template_dir/frequent_sync.cron" << EOF
# TKE 文档同步系统 - 高频同步配置
# 每6小时执行一次同步
0 */6 * * * cd $INSTALL_DIR && $INSTALL_DIR/venv/bin/python tke_dify_sync.py >> $INSTALL_DIR/logs/cron.log 2>&1

# 监控任务（每5分钟检查一次）
*/5 * * * * $INSTALL_DIR/scripts/monitor.sh >/dev/null 2>&1

# 日志清理（每周日凌晨1点）
0 1 * * 0 find $INSTALL_DIR/logs -name '*.log' -mtime +7 -delete 2>/dev/null || true
EOF

    log_success "cron 模板已生成到: $template_dir"
}

# 配置定时任务
setup_cron_jobs() {
    log_info "配置定时任务..."
    
    # 创建临时 crontab 文件
    local temp_cron=$(mktemp)
    
    # 获取现有的 crontab（如果有）
    if ! crontab -l 2>/dev/null > "$temp_cron"; then
        log_info "当前用户没有 crontab，创建新的"
        touch "$temp_cron"
    else
        log_info "保留现有的 crontab 条目"
    fi
    
    # 检查是否已存在相关的 cron 作业，避免重复添加
    if grep -q "tke_dify_sync\|tke-dify" "$temp_cron" 2>/dev/null; then
        log_warning "发现现有的 TKE 同步 cron 作业，将替换"
        # 删除现有的 TKE 相关作业
        grep -v "tke_dify_sync\|tke-dify" "$temp_cron" > "${temp_cron}.tmp" || touch "${temp_cron}.tmp"
        mv "${temp_cron}.tmp" "$temp_cron"
    fi
    
    # 添加注释说明
    echo "" >> "$temp_cron"
    echo "# TKE 文档同步系统 - 自动生成于 $(date)" >> "$temp_cron"
    
    # 添加监控任务（每5分钟检查一次）
    echo "*/5 * * * * $INSTALL_DIR/scripts/monitor.sh >/dev/null 2>&1" >> "$temp_cron"
    
    # 检查是否存在多知识库配置文件
    local multi_kb_configs=()
    if [ -f "$INSTALL_DIR/.env.tke_docs_base" ]; then
        multi_kb_configs+=("tke_docs_base")
    fi
    if [ -f "$INSTALL_DIR/.env.tke_knowledge_base" ]; then
        multi_kb_configs+=("tke_knowledge_base")
    fi
    
    if [ ${#multi_kb_configs[@]} -gt 0 ]; then
        log_info "检测到多知识库配置，设置分别的 cron 作业"
        
        local hour=2
        for config in "${multi_kb_configs[@]}"; do
            log_info "配置 $config 知识库同步任务（凌晨 ${hour} 点）"
            # 增强的日志记录：包含时间戳、执行状态和错误处理
            cat >> "$temp_cron" << EOF
0 $hour * * * cd $INSTALL_DIR && { echo "\$(date '+\%Y-\%m-\%d \%H:\%M:\%S') [START] 开始同步 $config 知识库"; cp .env.$config .env && $INSTALL_DIR/venv/bin/python tke_dify_sync.py && echo "\$(date '+\%Y-\%m-\%d \%H:\%M:\%S') [SUCCESS] $config 知识库同步完成" || echo "\$(date '+\%Y-\%m-\%d \%H:\%M:\%S') [ERROR] $config 知识库同步失败"; } >> $INSTALL_DIR/logs/cron_$config.log 2>&1
EOF
            ((hour++))
        done
    else
        log_info "使用单知识库配置"
        # 增强的日志记录：包含时间戳、执行状态和错误处理
        cat >> "$temp_cron" << 'EOF'
0 2 * * * cd $INSTALL_DIR && { echo "$(date '+%Y-%m-%d %H:%M:%S') [START] 开始 TKE 文档同步"; $INSTALL_DIR/venv/bin/python tke_dify_sync.py && echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] TKE 文档同步完成" || echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] TKE 文档同步失败"; } >> $INSTALL_DIR/logs/cron.log 2>&1
EOF
    fi
    
    # 添加日志清理任务（每周日凌晨1点）
    echo "0 1 * * 0 find $INSTALL_DIR/logs -name '*.log' -mtime +7 -delete 2>/dev/null || true" >> "$temp_cron"
    
    # 验证 crontab 格式
    if ! crontab -T "$temp_cron" 2>/dev/null; then
        log_error "crontab 格式验证失败"
        rm "$temp_cron"
        return 1
    fi
    
    # 安装新的 crontab
    if crontab "$temp_cron"; then
        log_success "crontab 安装成功"
    else
        log_error "crontab 安装失败"
        rm "$temp_cron"
        return 1
    fi
    
    # 清理临时文件
    rm "$temp_cron"
    
    # 显示配置的 cron 作业
    log_info "已配置的 cron 作业："
    crontab -l | grep -E "(tke_dify_sync|monitor\.sh|find.*logs)" | while read -r job; do
        echo "  📋 $job"
    done
    
    log_success "定时任务配置完成"
}

# 设置增强的日志记录系统
setup_enhanced_logging() {
    log_info "设置增强的日志记录系统..."
    
    # 创建日志目录结构
    local log_dirs=(
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/logs/archive"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "创建日志目录: $(basename "$dir")"
        fi
    done
    
    # 创建系统日志文件
    local system_log="$INSTALL_DIR/logs/system.log"
    if [ ! -f "$system_log" ]; then
        touch "$system_log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INIT] TKE 文档同步系统日志初始化" >> "$system_log"
        log_success "创建系统日志文件"
    fi
    
    # 创建错误日志文件
    local error_log="$INSTALL_DIR/logs/error.log"
    if [ ! -f "$error_log" ]; then
        touch "$error_log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [INIT] 错误日志初始化" >> "$error_log"
        log_success "创建错误日志文件"
    fi
    
    # 设置 logrotate 配置
    log_info "配置日志轮转..."
    if [ -f "$INSTALL_DIR/scripts/setup_logrotate.sh" ]; then
        if bash "$INSTALL_DIR/scripts/setup_logrotate.sh" --force >/dev/null 2>&1; then
            log_success "logrotate 配置已安装"
        else
            log_warning "logrotate 配置失败，将使用 cron 清理"
        fi
    else
        log_warning "logrotate 脚本不存在，将使用 cron 清理"
    fi
    
    # 设置日志清理 cron 作业
    log_info "配置日志清理任务..."
    if [ -f "$INSTALL_DIR/scripts/setup_log_cleanup_cron.sh" ]; then
        if bash "$INSTALL_DIR/scripts/setup_log_cleanup_cron.sh" --force >/dev/null 2>&1; then
            log_success "日志清理 cron 作业已配置"
        else
            log_warning "日志清理配置失败，请手动运行: ./scripts/setup_log_cleanup_cron.sh"
        fi
    else
        log_warning "日志清理脚本不存在，将使用简单清理"
    fi
    
    # 添加日志分析工具到 cron（可选）
    log_info "配置日志分析任务..."
    local temp_cron=$(mktemp)
    
    # 获取现有 crontab
    crontab -l 2>/dev/null > "$temp_cron" || touch "$temp_cron"
    
    # 检查是否已存在日志分析任务
    if ! grep -q "log_analyzer.sh" "$temp_cron"; then
        # 添加每日日志分析任务（早上8点）
        echo "0 8 * * * $INSTALL_DIR/scripts/log_analyzer.sh -s >> $INSTALL_DIR/logs/daily_analysis.log 2>&1" >> "$temp_cron"
        
        # 添加每周详细分析任务（周一早上9点）
        echo "0 9 * * 1 $INSTALL_DIR/scripts/log_analyzer.sh -r >> $INSTALL_DIR/logs/weekly_analysis.log 2>&1" >> "$temp_cron"
        
        # 安装更新的 crontab
        if crontab "$temp_cron"; then
            log_success "日志分析任务已添加到 crontab"
        else
            log_warning "添加日志分析任务失败"
        fi
    else
        log_info "日志分析任务已存在"
    fi
    
    rm "$temp_cron"
    
    log_success "增强日志记录系统配置完成"
}

# 验证 cron 作业配置
validate_cron_configuration() {
    log_info "验证 cron 作业配置..."
    
    local errors=0
    
    # 检查 crontab 是否存在
    if ! crontab -l >/dev/null 2>&1; then
        log_error "crontab 不存在"
        ((errors++))
        return $errors
    fi
    
    # 检查 TKE 相关的 cron 作业
    local tke_jobs=$(crontab -l | grep -E "(tke_dify_sync|monitor\.sh)" || true)
    if [ -z "$tke_jobs" ]; then
        log_error "未找到 TKE 相关的 cron 作业"
        ((errors++))
    else
        log_success "找到 TKE 相关的 cron 作业"
        echo "$tke_jobs" | while read -r job; do
            echo "  ✅ $job"
        done
    fi
    
    # 检查日志目录是否存在
    if [ ! -d "$INSTALL_DIR/logs" ]; then
        log_error "日志目录不存在: $INSTALL_DIR/logs"
        ((errors++))
    else
        log_success "日志目录存在"
    fi
    
    # 检查 Python 虚拟环境
    if [ ! -f "$INSTALL_DIR/venv/bin/python" ]; then
        log_error "Python 虚拟环境不存在"
        ((errors++))
    else
        log_success "Python 虚拟环境存在"
    fi
    
    return $errors
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    local verification_issues=0
    
    # 检查 Python 环境
    cd $INSTALL_DIR
    if source venv/bin/activate 2>/dev/null; then
        log_success "Python 虚拟环境正常"
    else
        log_error "Python 虚拟环境异常"
        ((verification_issues++))
    fi
    
    # 检查依赖包
    if python -c "import requests, selenium, bs4; print('✅ Python 依赖包正常')" 2>/dev/null; then
        log_success "Python 依赖包正常"
    else
        log_error "Python 依赖包缺失或异常"
        ((verification_issues++))
    fi
    
    # 检查 Chrome
    if google-chrome --version >/dev/null 2>&1; then
        log_success "Chrome 浏览器正常"
    else
        log_warning "Chrome 浏览器检查失败（可能影响某些功能）"
    fi
    
    # 检查配置文件
    if [ -f "$INSTALL_DIR/.env" ]; then
        log_success "主配置文件存在"
        
        # 检查必需的配置项
        local required_vars=("DIFY_API_KEY" "DIFY_KNOWLEDGE_BASE_ID" "DIFY_API_BASE_URL")
        local missing_vars=0
        
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" "$INSTALL_DIR/.env"; then
                log_info "  ✅ $var 已配置"
            else
                log_warning "  ⚠️ $var 未配置"
                ((missing_vars++))
            fi
        done
        
        if [ $missing_vars -gt 0 ]; then
            log_warning "需要配置 $missing_vars 个必需的环境变量"
        fi
    else
        log_error "配置文件不存在"
        ((verification_issues++))
    fi
    
    # 检查多知识库配置
    local multi_kb_configs=$(find "$INSTALL_DIR" -name ".env.*" -not -name "*.example" -not -name "*.template" | wc -l)
    if [ $multi_kb_configs -gt 0 ]; then
        log_success "发现 $multi_kb_configs 个多知识库配置文件"
    fi
    
    # 验证 cron 作业配置
    log_info "验证 cron 作业配置..."
    if validate_cron_configuration; then
        log_success "cron 作业配置验证通过"
    else
        log_warning "cron 作业配置存在问题"
        ((verification_issues++))
    fi
    
    # 检查 cron 服务状态
    if systemctl is-active --quiet cron 2>/dev/null || systemctl is-active --quiet crond 2>/dev/null; then
        log_success "cron 服务正在运行"
    else
        log_error "cron 服务未运行"
        ((verification_issues++))
    fi
    
    # 检查关键脚本
    local scripts=("monitor.sh" "health_check.sh" "start.sh")
    for script in "${scripts[@]}"; do
        if [ -f "$INSTALL_DIR/scripts/$script" ]; then
            log_success "脚本存在: $script"
        else
            log_warning "脚本缺失: $script"
        fi
    done
    
    # 检查日志目录
    if [ -d "$INSTALL_DIR/logs" ] && [ -w "$INSTALL_DIR/logs" ]; then
        log_success "日志目录可写"
    else
        log_error "日志目录不存在或不可写"
        ((verification_issues++))
    fi
    
    # 检查数据目录
    if [ -d "$INSTALL_DIR/data" ] && [ -w "$INSTALL_DIR/data" ]; then
        log_success "数据目录可写"
    else
        log_warning "数据目录不存在或不可写"
    fi
    
    # 运行快速语法检查
    if python -m py_compile tke_dify_sync.py 2>/dev/null; then
        log_success "主脚本语法检查通过"
    else
        log_error "主脚本语法检查失败"
        ((verification_issues++))
    fi
    
    # 总结验证结果
    if [ $verification_issues -eq 0 ]; then
        log_success "✅ 安装验证完全通过！系统已准备就绪"
    else
        log_warning "⚠️ 安装验证发现 $verification_issues 个问题，请查看上述输出"
    fi
    
    return $verification_issues
}

# 显示部署信息
show_deployment_info() {
    echo
    echo "🎉 TKE 文档同步系统部署完成！"
    echo "=================================="
    echo
    echo "📁 安装目录: $INSTALL_DIR"
    echo "📝 主配置文件: $INSTALL_DIR/.env"
    echo "📊 日志目录: $INSTALL_DIR/logs"
    echo "📦 数据目录: $INSTALL_DIR/data"
    echo "🔧 脚本目录: $INSTALL_DIR/scripts"
    echo
    
    # 显示多知识库配置（如果存在）
    local multi_kb_configs=$(find "$INSTALL_DIR" -name ".env.*" -not -name "*.example" -not -name "*.template" 2>/dev/null)
    if [ -n "$multi_kb_configs" ]; then
        echo "📚 多知识库配置文件:"
        echo "$multi_kb_configs" | while read -r config; do
            echo "   $(basename "$config")"
        done
        echo
    fi
    
    echo "🕐 已配置的 cron 作业:"
    if crontab -l 2>/dev/null | grep -q "tke_dify_sync\|tke-dify"; then
        crontab -l 2>/dev/null | grep "tke_dify_sync\|tke-dify" | while read -r job; do
            echo "   📋 $job"
        done
    else
        echo "   ⚠️ 未发现 cron 作业，可能需要手动配置"
    fi
    echo
    
    echo "🔧 必需的下一步操作："
    echo "1. 📝 编辑配置文件，设置 API 密钥和知识库 ID："
    echo "   nano $INSTALL_DIR/.env"
    echo
    echo "2. 🔑 配置必需的环境变量："
    echo "   - DIFY_API_KEY=your-dify-api-key"
    echo "   - DIFY_KNOWLEDGE_BASE_ID=your-knowledge-base-id"
    echo "   - DIFY_API_BASE_URL=your-dify-api-url"
    echo
    echo "3. ✅ 验证配置："
    echo "   cd $INSTALL_DIR && ./scripts/validate_cron_setup.sh"
    echo
    echo "4. 🧪 手动测试运行："
    echo "   cd $INSTALL_DIR && ./scripts/start.sh"
    echo
    echo "5. 📊 运行健康检查："
    echo "   cd $INSTALL_DIR && ./scripts/health_check.sh"
    echo
    echo "🔍 验证和监控命令："
    echo "• 查看 cron 作业状态: crontab -l | grep tke"
    echo "• 查看实时日志: tail -f $INSTALL_DIR/logs/cron*.log"
    echo "• 检查系统状态: $INSTALL_DIR/scripts/monitor.sh"
    echo "• 分析部署状态: $INSTALL_DIR/scripts/analyze_deployment.sh"
    echo "• 运行完整测试: $INSTALL_DIR/scripts/run_all_tests.sh"
    echo
    
    # 显示多知识库特定说明
    if [ -n "$multi_kb_configs" ]; then
        echo "📚 多知识库配置说明："
        echo "• 每个 .env.* 文件对应一个知识库"
        echo "• cron 作业会自动切换配置文件"
        echo "• 查看多知识库调度: $INSTALL_DIR/scripts/test_multi_kb_scheduling.sh"
        echo
    fi
    
    echo "🚨 重要提醒："
    echo "• 本系统使用 cron 调度，不是 systemd 守护进程"
    echo "• 如果之前使用过 systemd 版本，请运行迁移工具："
    echo "  $INSTALL_DIR/scripts/migrate_to_cron.sh"
    echo "• 定期运行健康检查确保系统正常运行"
    echo
    echo "📚 详细文档和故障排除："
    echo "• 部署指南: $INSTALL_DIR/DEPLOYMENT_GUIDE.md"
    echo "• 使用文档: $INSTALL_DIR/DOCS_GUIDE.md"
    echo "• 在线支持: https://github.com/your-repo/issues"
    echo
    echo "🎯 快速验证部署是否成功："
    echo "   cd $INSTALL_DIR && ./scripts/run_all_tests.sh -f"
}

# 主函数
main() {
    echo "🚀 TKE 文档同步系统一键部署脚本"
    echo "=================================="
    
    check_root
    detect_os
    check_requirements
    install_system_dependencies
    create_project_directory
    create_requirements
    download_project_files
    setup_python_environment
    create_config_files
    create_scripts
    generate_cron_templates
    set_permissions
    setup_cron_jobs
    setup_enhanced_logging
    
    # 验证安装并根据结果显示不同信息
    if verify_installation; then
        show_deployment_info
        log_success "🎉 部署完成！系统已准备就绪"
        echo
        echo "✅ 所有验证检查通过，可以开始使用系统"
        echo "💡 建议运行快速测试确认一切正常: cd $INSTALL_DIR && ./scripts/run_all_tests.sh -f"
    else
        show_deployment_info
        log_warning "⚠️ 部署完成但发现一些问题"
        echo
        echo "🔧 请按照上述说明完成配置，然后运行验证："
        echo "   cd $INSTALL_DIR && ./scripts/validate_cron_setup.sh"
        echo
        echo "📞 如需帮助，请查看故障排除文档或运行诊断工具："
        echo "   cd $INSTALL_DIR && ./scripts/analyze_deployment.sh"
    fi
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"