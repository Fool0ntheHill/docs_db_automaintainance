# TKE 文档同步系统 - 云端 CVM 部署指南

## 🎯 部署概述

本指南将帮助您在腾讯云 CVM 上部署 TKE 文档智能同步系统，实现自动化的文档抓取和同步到 Dify 知识库。

## 📋 系统要求

### 服务器配置
- **操作系统**: Ubuntu 20.04 LTS、CentOS 7+、TencentOS Server 2.4+ 或其他兼容发行版
- **CPU**: 2核心以上
- **内存**: 4GB 以上
- **存储**: 20GB 以上
- **网络**: 公网访问能力

### 软件依赖
- Python 3.8+
- Chrome/Chromium 浏览器
- Git

### 支持的操作系统
- **Ubuntu 20.04 LTS+**
- **CentOS 7+**
- **TencentOS Server 2.4+** (基于 CentOS)
- **Debian 10+**
- **Red Hat Enterprise Linux 7+**

## 🚀 一键部署脚本

### 1. 创建部署脚本

首先创建自动化部署脚本：

```bash
# 下载部署脚本
curl -O https://raw.githubusercontent.com/your-repo/tke-dify-sync/main/deploy.sh
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh
```

### 2. 手动部署步骤

如果需要手动部署，请按以下步骤操作：

#### 步骤 1: 系统环境准备

```bash
# 更新系统包
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y python3 python3-pip git curl wget unzip

# 安装 Chrome 浏览器
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

# 验证安装
python3 --version
google-chrome --version
```

#### 步骤 2: 创建项目目录

```bash
# 创建项目目录
sudo mkdir -p /opt/tke-dify-sync
sudo chown $USER:$USER /opt/tke-dify-sync
cd /opt/tke-dify-sync

# 创建必要的子目录
mkdir -p {logs,data,config,scripts}
```

#### 步骤 3: 下载项目文件

```bash
# 方式一：从 Git 仓库克隆（推荐）
git clone https://github.com/your-repo/tke-dify-sync.git .

# 方式二：手动上传文件（如果没有 Git 仓库）
# 将以下文件上传到 /opt/tke-dify-sync/ 目录：
# - tke_dify_sync.py
# - dify_sync_manager.py
# - enhanced_metadata_generator.py
# - smart_retry_manager.py
# - tke_logger.py
# - secure_temp_manager.py
# - requirements.txt
# - .env.example
```

#### 步骤 4: 安装 Python 依赖

```bash
# 安装 pip 依赖
pip3 install -r requirements.txt

# 如果遇到权限问题，使用用户安装
pip3 install --user -r requirements.txt
```

## 📦 依赖包一键安装脚本

创建 `install_dependencies.sh` 脚本：

```bash
#!/bin/bash

echo "🚀 开始安装 TKE 文档同步系统依赖..."

# 检查操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "❌ 无法检测操作系统版本"
    exit 1
fi

echo "📋 检测到操作系统: $OS $VER"

# Ubuntu/Debian 系统
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    echo "🔧 安装 Ubuntu/Debian 依赖..."
    
    # 更新包列表
    sudo apt update
    
    # 安装基础依赖
    sudo apt install -y python3 python3-pip python3-venv git curl wget unzip
    
    # 安装 Chrome
    if ! command -v google-chrome &> /dev/null; then
        echo "📦 安装 Google Chrome..."
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
        sudo apt update
        sudo apt install -y google-chrome-stable
    fi

# CentOS/RHEL/TencentOS 系统
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"TencentOS"* ]]; then
    if [[ "$OS" == *"TencentOS"* ]]; then
        echo "🔧 安装 TencentOS Server 依赖（兼容 CentOS 模式）..."
    else
        echo "🔧 安装 CentOS/RHEL 依赖..."
    fi
    
    # 安装 EPEL 仓库
    sudo yum install -y epel-release
    
    # 安装基础依赖
    sudo yum install -y python3 python3-pip git curl wget unzip
    
    # 安装 Chrome
    if ! command -v google-chrome &> /dev/null; then
        echo "📦 安装 Google Chrome..."
        sudo yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
    fi
else
    echo "❌ 不支持的操作系统: $OS"
    exit 1
fi

# 创建虚拟环境（推荐）
echo "🐍 创建 Python 虚拟环境..."
python3 -m venv venv
source venv/bin/activate

# 升级 pip
pip install --upgrade pip

# 安装 Python 依赖
echo "📦 安装 Python 依赖包..."
pip install requests beautifulsoup4 selenium webdriver-manager

# 验证安装
echo "✅ 验证安装..."
python3 --version
google-chrome --version
pip list | grep -E "(requests|beautifulsoup4|selenium|webdriver-manager)"

echo "🎉 依赖安装完成！"
```

## ⚙️ 配置文件设置

### 1. 创建配置文件

```bash
# 复制配置模板
cp .env.example .env

# 编辑配置文件
nano .env
```

### 2. 配置文件内容

在 `.env` 文件中填入以下配置：

```bash
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
```

### 3. Dify 知识库准备

#### 步骤 1：创建知识库

1. **登录 Dify 控制台**
   - 访问 [Dify 控制台](https://dify.ai)
   - 使用您的账号登录

2. **创建新知识库**
   - 点击 "知识库" → "创建知识库"
   - 输入知识库名称（如："TKE技术文档库"）
   - 选择知识库类型："文档知识库"
   - 点击 "创建"

3. **配置知识库设置**
   - 进入知识库设置页面
   - 设置文档处理方式："自动处理"
   - 选择文本分割方式："智能分割"
   - 设置分割长度：500-1000 字符

#### 步骤 2：配置元数据字段（重要）

**为什么需要配置元数据？**
- 元数据帮助更好地组织和检索文档
- 支持按文档类型、来源等进行筛选
- 提高知识库的可用性和准确性

**配置步骤：**

1. **进入知识库设置**
   - 选择您创建的知识库
   - 点击 "设置" → "元数据字段"

2. **添加推荐的元数据字段**

   **字段 1：文档类型**
   - 字段名：`document_type`
   - 字段类型：选择列表
   - 选项值：
     - `操作指南`
     - `API文档`
     - `概念说明`
     - `故障排除`
     - `最佳实践`
     - `产品介绍`

   **字段 2：文档来源**
   - 字段名：`source`
   - 字段类型：文本
   - 默认值：`腾讯云官方文档`

   **字段 3：更新时间**
   - 字段名：`last_updated`
   - 字段类型：日期时间
   - 自动填充：是

   **字段 4：文档URL**
   - 字段名：`url`
   - 字段类型：文本
   - 描述：原始文档链接

3. **保存元数据配置**
   - 点击 "保存" 确认元数据字段配置
   - 确保所有字段都已正确创建

#### 步骤 3：获取配置信息

**获取 API Key：**
1. 在 Dify 控制台中，进入 "设置" → "API Keys"
2. 点击 "创建 API Key"
3. 输入 API Key 名称（如："TKE文档同步"）
4. 选择权限："数据集管理"
5. 复制生成的 API Key（格式：`dataset-xxxxxxxxxx`）

**确定 API 基础 URL：**

Dify API 基础 URL 会根据您的 Dify 部署方式而不同：

1. **Dify Cloud（官方云服务）**
   ```bash
   DIFY_API_BASE_URL=https://api.dify.ai/v1
   ```

2. **私有部署（自建服务器）**
   ```bash
   # 替换为您的实际域名和端口
   DIFY_API_BASE_URL=https://your-dify-domain.com/v1
   DIFY_API_BASE_URL=http://your-server-ip:port/v1
   ```

3. **企业版部署**
   ```bash
   # 联系您的系统管理员获取正确的 API 地址
   DIFY_API_BASE_URL=https://dify.your-company.com/v1
   ```

**如何确认 API 基础 URL：**
- 查看 Dify 控制台的 API 文档页面
- 在控制台的 "设置" → "API Keys" 页面通常会显示 API 端点
- 联系您的 Dify 管理员确认正确的 API 地址

**重要提醒：**
- 确保 API 基础 URL 以 `/v1` 结尾
- 如果使用 HTTPS，确保 SSL 证书有效
- 如果是内网部署，确保服务器能访问该地址

**获取知识库 ID：**
1. 进入您创建的知识库页面
2. 从浏览器 URL 中获取知识库 ID
   - URL 格式：`https://dify.ai/datasets/{knowledge_base_id}`
   - 知识库 ID 格式：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`
3. 复制知识库 ID 备用

#### 步骤 4：验证知识库配置

**测试知识库访问：**
```bash
# 使用 curl 测试 API 连接
curl -X GET \
  "https://api.dify.ai/v1/datasets/{your_knowledge_base_id}" \
  -H "Authorization: Bearer {your_api_key}" \
  -H "Content-Type: application/json"
```

**预期响应：**
```json
{
  "id": "your_knowledge_base_id",
  "name": "TKE技术文档库",
  "description": "...",
  "permission": "only_me",
  "data_source_type": "upload_file",
  "indexing_technique": "high_quality",
  "created_at": "..."
}
```

#### 多知识库场景

如果您需要多个知识库（如生产环境和测试环境），请重复上述步骤：

1. **生产环境知识库**
   - 名称："TKE生产文档库"
   - 配置完整的元数据字段
   - 使用保守的处理设置

2. **测试环境知识库**
   - 名称："TKE测试文档库"
   - 可以使用简化的元数据字段
   - 使用快速处理设置

**重要提醒：**
- 每个知识库都需要单独配置元数据字段
- 确保 API Key 对所有目标知识库都有访问权限
- 记录每个知识库的 ID，用于后续配置

## 📁 文件部署结构

### 目录结构

```
/opt/tke-dify-sync/
├── tke_dify_sync.py              # 主程序
├── dify_sync_manager.py          # Dify 同步管理器
├── enhanced_metadata_generator.py # 元数据生成器
├── smart_retry_manager.py        # 智能重试管理器
├── tke_logger.py                 # 日志管理器
├── secure_temp_manager.py        # 临时文件管理器
├── requirements.txt              # Python 依赖
├── .env                          # 配置文件
├── .env.example                  # 配置模板
├── README.md                     # 说明文档
├── config/                       # 配置目录
│   ├── .env.production          # 生产环境配置
│   └── .env.backup              # 备份配置
├── data/                         # 数据目录
│   ├── crawl_state.json         # 爬取状态
│   └── temp/                    # 临时文件
├── logs/                         # 日志目录
│   ├── tke_sync.log             # 同步日志
│   └── error.log                # 错误日志
└── scripts/                      # 脚本目录
    ├── deploy.sh                # 部署脚本
    ├── start.sh                 # 启动脚本
    ├── stop.sh                  # 停止脚本
    └── monitor.sh               # 监控脚本
```

### 文件权限设置

```bash
# 设置目录权限
sudo chown -R $USER:$USER /opt/tke-dify-sync
chmod 755 /opt/tke-dify-sync
chmod 755 /opt/tke-dify-sync/{config,data,logs,scripts}

# 设置文件权限
chmod 644 /opt/tke-dify-sync/*.py
chmod 600 /opt/tke-dify-sync/.env
chmod 755 /opt/tke-dify-sync/scripts/*.sh
```

## 🔧 系统服务配置

### 1. 创建 systemd 服务

创建服务文件 `/etc/systemd/system/tke-dify-sync.service`：

```ini
[Unit]
Description=TKE Dify Sync Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/tke-dify-sync
Environment=PATH=/opt/tke-dify-sync/venv/bin
ExecStart=/opt/tke-dify-sync/venv/bin/python tke_dify_sync.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 2. 启用服务

```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启用服务
sudo systemctl enable tke-dify-sync

# 启动服务
sudo systemctl start tke-dify-sync

# 查看服务状态
sudo systemctl status tke-dify-sync
```

## 📊 监控和日志

### 1. 日志查看

```bash
# 查看实时日志
sudo journalctl -u tke-dify-sync -f

# 查看应用日志
tail -f /opt/tke-dify-sync/logs/tke_sync.log

# 查看错误日志
tail -f /opt/tke-dify-sync/logs/error.log
```

### 2. 监控脚本

创建 `scripts/monitor.sh`：

```bash
#!/bin/bash

SERVICE_NAME="tke-dify-sync"
LOG_FILE="/opt/tke-dify-sync/logs/monitor.log"

# 检查服务状态
check_service() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "$(date): ✅ 服务运行正常" >> $LOG_FILE
        return 0
    else
        echo "$(date): ❌ 服务已停止，尝试重启" >> $LOG_FILE
        sudo systemctl restart $SERVICE_NAME
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

# 执行检查
check_service
check_disk_space
```

### 3. 定时任务

```bash
# 编辑 crontab
crontab -e

# 添加监控任务（每5分钟检查一次）
*/5 * * * * /opt/tke-dify-sync/scripts/monitor.sh

# 添加日志清理任务（每天凌晨清理7天前的日志）
0 0 * * * find /opt/tke-dify-sync/logs -name "*.log" -mtime +7 -delete
```

## 🔄 多知识库配置方案

### 方案一：单知识库配置（推荐新手）
使用单个 `.env` 文件配置一个知识库。

### 方案二：多知识库相同配置
在单个 `.env` 文件中配置多个知识库 ID：
```bash
# 多个知识库使用相同配置
DIFY_KNOWLEDGE_BASE_ID=kb1-id,kb2-id,kb3-id
KB_STRATEGY=all  # 同步到所有知识库
```

### 方案三：多知识库不同配置（推荐生产环境）

**适用场景：**
- 不同知识库有不同用途（技术文档库、用户手册库、API文档库）
- 不同环境部署（开发、测试、生产）
- 需要独立的状态文件和日志文件

**实施步骤：**

1. **创建多个配置文件**

**`.env.production`** (生产环境知识库):
```bash
# 生产环境知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=8c6b8e3c-f69c-48ea-b34e-a71798c800ed
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary

# 独立的状态和日志文件
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_production.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_production.log

# 生产环境网络配置
REQUEST_TIMEOUT=60
RETRY_ATTEMPTS=5
RETRY_DELAY=3
```

**`.env.testing`** (测试环境知识库):
```bash
# 测试环境知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=2ac0e7aa-9eba-4363-8f9d-e426d0b2451e
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary

# 独立的状态和日志文件
STATE_FILE=/opt/tke-dify-sync/data/crawl_state_testing.json
LOG_FILE=/opt/tke-dify-sync/logs/tke_sync_testing.log

# 测试环境网络配置（更快的超时）
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=2
```

2. **分别运行同步**
```bash
# 同步到生产环境知识库
cp .env.production .env && python tke_dify_sync.py

# 同步到测试环境知识库
cp .env.testing .env && python tke_dify_sync.py
```

3. **创建批量同步脚本**
```bash
# 创建多知识库同步脚本
cat > /opt/tke-dify-sync/scripts/sync_all_kb.sh << 'EOF'
#!/bin/bash
cd /opt/tke-dify-sync
source venv/bin/activate

echo "开始多知识库同步..."

# 同步到生产环境
echo "同步到生产环境知识库..."
cp .env.production .env
python tke_dify_sync.py

# 同步到测试环境
echo "同步到测试环境知识库..."
cp .env.testing .env
python tke_dify_sync.py

echo "多知识库同步完成！"
EOF

chmod +x /opt/tke-dify-sync/scripts/sync_all_kb.sh
```

4. **配置定时任务**
```bash
# 编辑 crontab
crontab -e

# 生产环境每天凌晨2点同步
0 2 * * * cd /opt/tke-dify-sync && cp .env.production .env && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron_production.log 2>&1

# 测试环境每6小时同步
0 */6 * * * cd /opt/tke-dify-sync && cp .env.testing .env && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron_testing.log 2>&1
```

**优势：**
- ✅ 完全独立的配置管理
- ✅ 独立的状态文件，避免冲突
- ✅ 独立的日志文件，便于调试
- ✅ 可以针对不同知识库调整参数
- ✅ 支持不同的同步频率

## 🚀 使用方法

### 1. 手动运行

```bash
# 进入项目目录
cd /opt/tke-dify-sync

# 激活虚拟环境
source venv/bin/activate

# 测试配置
python test_config.py

# 运行同步
python tke_dify_sync.py
```

### 2. 服务方式运行

```bash
# 启动服务
sudo systemctl start tke-dify-sync

# 停止服务
sudo systemctl stop tke-dify-sync

# 重启服务
sudo systemctl restart tke-dify-sync

# 查看状态
sudo systemctl status tke-dify-sync
```

### 3. 定时同步

```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天凌晨2点执行）
0 2 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1

# 每6小时执行一次
0 */6 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1
```

## 🔍 故障排除

### 常见问题

1. **Chrome 浏览器问题**
```bash
# 安装缺失的依赖
sudo apt install -y libnss3 libgconf-2-4 libxss1 libappindicator1 libindicator7

# 检查 Chrome 版本
google-chrome --version
```

2. **Python 依赖问题**
```bash
# 重新安装依赖
pip install --upgrade -r requirements.txt

# 检查虚拟环境
which python
pip list
```

3. **权限问题**
```bash
# 修复文件权限
sudo chown -R $USER:$USER /opt/tke-dify-sync
chmod 755 /opt/tke-dify-sync
```

4. **网络连接问题**
```bash
# 测试网络连接
curl -I https://cloud.tencent.com
curl -I https://api.dify.ai

# 检查防火墙
sudo ufw status
```

### 日志分析

```bash
# 查看错误日志
grep "ERROR\|❌" /opt/tke-dify-sync/logs/tke_sync.log

# 查看同步统计
grep "同步完成\|✅" /opt/tke-dify-sync/logs/tke_sync.log

# 查看系统日志
sudo journalctl -u tke-dify-sync --since "1 hour ago"
```

## 📈 性能优化

### 1. 系统优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 2. 应用优化

在 `.env` 文件中调整参数：

```bash
# 增加超时时间
REQUEST_TIMEOUT=60

# 增加重试次数
RETRY_ATTEMPTS=5

# 调整重试延迟
RETRY_DELAY=3
```

## 🔐 安全配置

### 1. 防火墙设置

```bash
# 启用防火墙
sudo ufw enable

# 允许 SSH
sudo ufw allow ssh

# 允许 HTTP/HTTPS（如果需要）
sudo ufw allow 80
sudo ufw allow 443
```

### 2. 文件权限

```bash
# 保护配置文件
chmod 600 /opt/tke-dify-sync/.env

# 保护日志目录
chmod 750 /opt/tke-dify-sync/logs
```

## 📋 部署检查清单

- [ ] 系统环境准备完成
- [ ] Python 3.8+ 安装完成
- [ ] Chrome 浏览器安装完成
- [ ] 项目文件上传完成
- [ ] Python 依赖安装完成
- [ ] 配置文件设置完成
- [ ] Dify API Key 配置正确
- [ ] 知识库 ID 配置正确
- [ ] 文件权限设置正确
- [ ] 系统服务配置完成
- [ ] 监控脚本配置完成
- [ ] 定时任务配置完成
- [ ] 测试运行成功

## 🎉 部署完成

恭喜！您已成功在云端 CVM 上部署了 TKE 文档智能同步系统。

### 验证部署

```bash
# 1. 测试配置
cd /opt/tke-dify-sync
python test_config.py

# 2. 手动运行一次
python tke_dify_sync.py

# 3. 检查服务状态
sudo systemctl status tke-dify-sync

# 4. 查看日志
tail -f logs/tke_sync.log
```

### 后续维护

- 定期检查日志文件
- 监控系统资源使用情况
- 定期更新依赖包
- 备份配置文件和数据

如有问题，请查看故障排除部分或联系技术支持。