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

# 检查服务状态
check_service() {
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        echo "$(date): ✅ 服务运行正常" >> $LOG_FILE
        return 0
    elif pgrep -f "python.*tke_dify_sync.py" > /dev/null; then
        echo "$(date): ✅ 进程运行正常" >> $LOG_FILE
        return 0
    else
        echo "$(date): ❌ 服务已停止" >> $LOG_FILE
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

# 创建系统服务
create_systemd_service() {
    log_info "创建系统服务..."
    
    sudo tee /etc/systemd/system/tke-dify-sync.service > /dev/null << EOF
[Unit]
Description=TKE Dify Sync Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python tke_dify_sync.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载 systemd
    sudo systemctl daemon-reload
    
    # 启用服务
    sudo systemctl enable tke-dify-sync
    
    log_success "系统服务创建完成"
}

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

# 配置定时任务
setup_cron_jobs() {
    log_info "配置定时任务..."
    
    # 创建临时 crontab 文件
    TEMP_CRON=$(mktemp)
    
    # 获取现有的 crontab（如果有）
    crontab -l 2>/dev/null > $TEMP_CRON || true
    
    # 添加监控任务（每5分钟检查一次）
    echo "*/5 * * * * $INSTALL_DIR/scripts/monitor.sh" >> $TEMP_CRON
    
    # 添加定时同步任务（每天凌晨2点执行）
    echo "0 2 * * * cd $INSTALL_DIR && $INSTALL_DIR/venv/bin/python tke_dify_sync.py >> $INSTALL_DIR/logs/cron.log 2>&1" >> $TEMP_CRON
    
    # 安装新的 crontab
    crontab $TEMP_CRON
    
    # 清理临时文件
    rm $TEMP_CRON
    
    log_success "定时任务配置完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装..."
    
    # 检查 Python 环境
    cd $INSTALL_DIR
    source venv/bin/activate
    
    # 检查依赖包
    python -c "import requests, selenium, bs4; print('✅ Python 依赖包正常')"
    
    # 检查 Chrome
    google-chrome --version
    
    # 检查配置文件
    if [ -f "$INSTALL_DIR/.env" ]; then
        log_success "配置文件存在"
    else
        log_error "配置文件不存在"
    fi
    
    # 检查服务
    if systemctl is-enabled tke-dify-sync &>/dev/null; then
        log_success "系统服务已启用"
    else
        log_warning "系统服务未启用"
    fi
    
    log_success "安装验证完成"
}

# 显示部署信息
show_deployment_info() {
    echo
    echo "🎉 TKE 文档同步系统部署完成！"
    echo
    echo "📁 安装目录: $INSTALL_DIR"
    echo "📝 配置文件: $INSTALL_DIR/.env"
    echo "📊 日志目录: $INSTALL_DIR/logs"
    echo
    echo "🔧 下一步操作："
    echo "1. 编辑配置文件："
    echo "   nano $INSTALL_DIR/.env"
    echo
    echo "2. 配置 Dify API Key 和知识库 ID"
    echo
    echo "3. 测试配置："
    echo "   cd $INSTALL_DIR && python test_config.py"
    echo
    echo "4. 启动服务："
    echo "   sudo systemctl start tke-dify-sync"
    echo
    echo "5. 查看服务状态："
    echo "   sudo systemctl status tke-dify-sync"
    echo
    echo "6. 查看日志："
    echo "   tail -f $INSTALL_DIR/logs/tke_sync.log"
    echo
    echo "📚 更多信息请查看 DEPLOYMENT_GUIDE.md"
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
    create_systemd_service
    set_permissions
    setup_cron_jobs
    verify_installation
    show_deployment_info
    
    log_success "部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 运行主函数
main "$@"