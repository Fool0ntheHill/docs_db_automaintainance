# TKE 文档同步系统 - CVM 快速部署

## 🚀 一键部署（推荐）

### 方法一：完整自动部署

```bash
# 下载并运行部署脚本
curl -O https://raw.githubusercontent.com/your-repo/tke-dify-sync/main/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

### 方法二：快速部署（适用于已有 Python 环境）

```bash
# 下载并运行快速部署脚本
curl -O https://raw.githubusercontent.com/your-repo/tke-dify-sync/main/quick_deploy.sh
chmod +x quick_deploy.sh
./quick_deploy.sh
```

## 📁 手动部署步骤

### 1. 准备服务器环境

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y python3 python3-pip python3-venv git curl wget

# 安装 Chrome 浏览器
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable
```

### 2. 创建项目目录

```bash
# 创建项目目录
sudo mkdir -p /opt/tke-dify-sync
sudo chown $USER:$USER /opt/tke-dify-sync
cd /opt/tke-dify-sync

# 创建子目录
mkdir -p {config,data,logs,scripts}
```

### 3. 上传项目文件

将以下文件上传到 `/opt/tke-dify-sync/` 目录：

**必需文件：**
- `tke_dify_sync.py` - 主程序
- `dify_sync_manager.py` - Dify 同步管理器
- `enhanced_metadata_generator.py` - 元数据生成器
- `smart_retry_manager.py` - 智能重试管理器
- `tke_logger.py` - 日志管理器
- `secure_temp_manager.py` - 临时文件管理器

**可选文件：**
- `test_config.py` - 配置测试脚本
- `config_wizard.py` - 配置向导
- `README.md` - 说明文档

### 4. 安装 Python 依赖

```bash
# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖包
pip install --upgrade pip
pip install requests beautifulsoup4 selenium webdriver-manager lxml
```

### 5. 配置系统

#### 方法一：使用配置向导（推荐）

```bash
python config_wizard.py
```

#### 方法二：手动创建配置文件

```bash
# 创建配置文件
nano .env
```

配置文件内容：
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

## ⚙️ 获取 Dify 配置信息

### 1. 获取 API Key

1. 登录 [Dify 控制台](https://dify.ai)
2. 进入 "设置" → "API Keys"
3. 创建新的 API Key
4. 复制 API Key（格式：`dataset-xxxxxxxxxx`）

### 2. 获取知识库 ID

1. 进入 Dify 知识库页面
2. 选择目标知识库
3. 从浏览器 URL 中获取知识库 ID
   - URL 格式：`https://dify.ai/datasets/{knowledge_base_id}`
   - 知识库 ID 格式：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`

## 🧪 测试配置

```bash
# 测试配置是否正确
python test_config.py
```

预期输出：
```
🔧 TKE 文档同步系统配置测试
================================
✅ 配置文件加载成功
✅ Dify API 连接正常
✅ 知识库访问正常
🎯 配置测试通过！
```

## 🚀 运行系统

### 方法一：直接运行

```bash
# 激活虚拟环境
source venv/bin/activate

# 运行同步
python tke_dify_sync.py
```

### 方法二：后台运行

```bash
# 使用 nohup 后台运行
nohup python tke_dify_sync.py > logs/nohup.log 2>&1 &

# 查看进程
ps aux | grep tke_dify_sync
```

### 方法三：系统服务（推荐）

创建系统服务：
```bash
sudo tee /etc/systemd/system/tke-dify-sync.service > /dev/null << 'EOF'
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

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable tke-dify-sync
sudo systemctl start tke-dify-sync

# 查看服务状态
sudo systemctl status tke-dify-sync
```

## 📊 监控和日志

### 查看日志

```bash
# 查看应用日志
tail -f /opt/tke-dify-sync/logs/tke_sync.log

# 查看系统服务日志
sudo journalctl -u tke-dify-sync -f

# 查看最近的错误
grep "ERROR\|❌" /opt/tke-dify-sync/logs/tke_sync.log | tail -10
```

### 监控脚本

创建监控脚本：
```bash
cat > /opt/tke-dify-sync/scripts/monitor.sh << 'EOF'
#!/bin/bash
if pgrep -f "python.*tke_dify_sync.py" > /dev/null; then
    echo "$(date): ✅ 服务运行正常"
else
    echo "$(date): ❌ 服务已停止"
    # 可以添加重启逻辑
fi
EOF

chmod +x /opt/tke-dify-sync/scripts/monitor.sh

# 添加到 crontab（每5分钟检查一次）
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/tke-dify-sync/scripts/monitor.sh >> /opt/tke-dify-sync/logs/monitor.log") | crontab -
```

## 🔧 定时同步

设置定时任务：
```bash
# 编辑 crontab
crontab -e

# 添加定时任务（每天凌晨2点执行）
0 2 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1

# 每6小时执行一次
0 */6 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1
```

## 🛠️ 常见问题

### 1. Chrome 浏览器问题

```bash
# 安装缺失的依赖
sudo apt install -y libnss3 libgconf-2-4 libxss1 libappindicator1

# 检查 Chrome 版本
google-chrome --version
```

### 2. 权限问题

```bash
# 修复文件权限
sudo chown -R $USER:$USER /opt/tke-dify-sync
chmod 600 /opt/tke-dify-sync/.env
```

### 3. 网络连接问题

```bash
# 测试网络连接
curl -I https://cloud.tencent.com
curl -I https://api.dify.ai

# 检查防火墙
sudo ufw status
```

### 4. Python 依赖问题

```bash
# 重新安装依赖
source venv/bin/activate
pip install --upgrade -r requirements.txt
```

## 📋 部署检查清单

- [ ] 服务器环境准备完成（Python 3.8+, Chrome）
- [ ] 项目文件上传完成
- [ ] Python 虚拟环境创建完成
- [ ] 依赖包安装完成
- [ ] 配置文件创建完成
- [ ] Dify API Key 配置正确
- [ ] 知识库 ID 配置正确
- [ ] 配置测试通过
- [ ] 系统服务配置完成（可选）
- [ ] 监控脚本配置完成（可选）
- [ ] 定时任务配置完成（可选）

## 🎉 部署完成

恭喜！您已成功在 CVM 上部署了 TKE 文档智能同步系统。

**验证部署：**
```bash
# 1. 测试配置
python test_config.py

# 2. 运行一次同步
python tke_dify_sync.py

# 3. 查看日志
tail -f logs/tke_sync.log
```

**后续维护：**
- 定期检查日志文件
- 监控系统资源使用
- 定期更新依赖包
- 备份配置和数据

如有问题，请查看完整的 `DEPLOYMENT_GUIDE.md` 或联系技术支持。