#!/bin/bash

# TKE 文档同步系统快速部署脚本
# 适用于已有 Python 环境的服务器

set -e

echo "🚀 TKE 文档同步系统快速部署"
echo "============================="

# 配置变量
INSTALL_DIR="/opt/tke-dify-sync"
CURRENT_USER=$(whoami)

# 创建目录
echo "📁 创建项目目录..."
sudo mkdir -p $INSTALL_DIR
sudo chown $CURRENT_USER:$CURRENT_USER $INSTALL_DIR
mkdir -p $INSTALL_DIR/{config,data,logs,scripts}

# 进入项目目录
cd $INSTALL_DIR

# 安装系统依赖（Ubuntu/Debian）
echo "📦 安装系统依赖..."
if command -v apt &> /dev/null; then
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv curl wget
    
    # 安装 Chrome
    if ! command -v google-chrome &> /dev/null; then
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
        sudo apt update
        sudo apt install -y google-chrome-stable
    fi
elif command -v yum &> /dev/null; then
    sudo yum install -y python3 python3-pip curl wget
    sudo yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
fi

# 创建虚拟环境
echo "🐍 创建 Python 虚拟环境..."
python3 -m venv venv
source venv/bin/activate

# 安装 Python 依赖
echo "📦 安装 Python 依赖..."
pip install --upgrade pip
pip install requests beautifulsoup4 selenium webdriver-manager lxml

# 创建配置文件
echo "⚙️ 创建配置文件..."
cat > .env << 'EOF'
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

# 创建启动脚本
echo "📜 创建管理脚本..."
cat > scripts/start.sh << 'EOF'
#!/bin/bash
cd /opt/tke-dify-sync
source venv/bin/activate
python tke_dify_sync.py
EOF

cat > scripts/test_config.sh << 'EOF'
#!/bin/bash
cd /opt/tke-dify-sync
source venv/bin/activate
python test_config.py
EOF

chmod +x scripts/*.sh

# 设置权限
echo "🔐 设置文件权限..."
chmod 600 .env
chmod 755 $INSTALL_DIR

echo
echo "✅ 快速部署完成！"
echo
echo "📋 下一步操作："
echo "1. 上传项目文件到 $INSTALL_DIR 目录"
echo "2. 编辑配置文件: nano $INSTALL_DIR/.env"
echo "3. 测试配置: $INSTALL_DIR/scripts/test_config.sh"
echo "4. 运行程序: $INSTALL_DIR/scripts/start.sh"
echo
echo "📁 项目目录: $INSTALL_DIR"
echo "📝 配置文件: $INSTALL_DIR/.env"
echo "📊 日志目录: $INSTALL_DIR/logs"