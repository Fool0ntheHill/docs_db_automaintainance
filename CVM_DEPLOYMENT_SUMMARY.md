# TKE 文档同步系统 - CVM 部署总结

## 📦 部署文件清单

### 核心程序文件（必需）
```
tke_dify_sync.py              # 主程序
dify_sync_manager.py          # Dify 同步管理器
enhanced_metadata_generator.py # 元数据生成器
smart_retry_manager.py        # 智能重试管理器
tke_logger.py                 # 日志管理器
secure_temp_manager.py        # 临时文件管理器
```

### 部署脚本（推荐）
```
deploy.sh                     # 完整自动部署脚本
quick_deploy.sh               # 快速部署脚本
config_wizard.py              # 配置向导
```

### 文档文件
```
DEPLOYMENT_GUIDE.md           # 完整部署指南
QUICK_START_CVM.md           # 快速开始指南
CVM_DEPLOYMENT_SUMMARY.md    # 本文档
README.md                    # 项目说明
```

## 🚀 三种部署方式

### 方式一：一键自动部署（最简单）

```bash
# 1. 下载部署脚本
curl -O https://raw.githubusercontent.com/your-repo/tke-dify-sync/main/deploy.sh

# 2. 运行部署脚本
chmod +x deploy.sh
./deploy.sh

# 3. 按提示上传项目文件

# 4. 编辑配置文件
nano /opt/tke-dify-sync/.env

# 5. 启动服务
sudo systemctl start tke-dify-sync
```

### 方式二：快速部署（适合有经验用户）

```bash
# 1. 运行快速部署
curl -O https://raw.githubusercontent.com/your-repo/tke-dify-sync/main/quick_deploy.sh
chmod +x quick_deploy.sh
./quick_deploy.sh

# 2. 上传项目文件到 /opt/tke-dify-sync/

# 3. 配置系统
cd /opt/tke-dify-sync
python config_wizard.py

# 4. 测试运行
python tke_dify_sync.py
```

### 方式三：手动部署（完全控制）

```bash
# 1. 安装系统依赖
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git curl wget
# 安装 Chrome...

# 2. 创建项目目录
sudo mkdir -p /opt/tke-dify-sync
sudo chown $USER:$USER /opt/tke-dify-sync
cd /opt/tke-dify-sync

# 3. 上传项目文件

# 4. 设置 Python 环境
python3 -m venv venv
source venv/bin/activate
pip install requests beautifulsoup4 selenium webdriver-manager lxml

# 5. 创建配置文件
nano .env

# 6. 测试和运行
python test_config.py
python tke_dify_sync.py
```

## ⚙️ 必需配置项

### Dify API 配置
```bash
DIFY_API_KEY=dataset-xxxxxxxxxx        # 从 Dify 控制台获取
DIFY_KNOWLEDGE_BASE_ID=uuid-format     # 从知识库 URL 获取
DIFY_API_BASE_URL=https://api.dify.ai/v1
```

### 获取配置信息步骤

**1. 获取 Dify API Key：**
- 登录 https://dify.ai
- 设置 → API Keys → 创建新 Key
- 复制 API Key（格式：dataset-xxxxxxxxxx）

**2. 获取知识库 ID：**
- 进入知识库页面
- 从 URL 获取 ID：`https://dify.ai/datasets/{这里是知识库ID}`
- 格式：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`

## 📁 标准目录结构

```
/opt/tke-dify-sync/
├── tke_dify_sync.py              # 主程序
├── dify_sync_manager.py          # 同步管理器
├── enhanced_metadata_generator.py # 元数据生成器
├── smart_retry_manager.py        # 重试管理器
├── tke_logger.py                 # 日志管理器
├── secure_temp_manager.py        # 临时文件管理器
├── config_wizard.py              # 配置向导
├── test_config.py                # 配置测试
├── .env                          # 配置文件
├── venv/                         # Python 虚拟环境
├── data/                         # 数据目录
│   └── crawl_state.json         # 爬取状态
├── logs/                         # 日志目录
│   ├── tke_sync.log             # 同步日志
│   └── monitor.log              # 监控日志
└── scripts/                      # 脚本目录
    ├── start.sh                 # 启动脚本
    ├── stop.sh                  # 停止脚本
    └── monitor.sh               # 监控脚本
```

## 🔧 系统服务配置

### 创建 systemd 服务

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

sudo systemctl daemon-reload
sudo systemctl enable tke-dify-sync
sudo systemctl start tke-dify-sync
```

### 服务管理命令

```bash
# 启动服务
sudo systemctl start tke-dify-sync

# 停止服务
sudo systemctl stop tke-dify-sync

# 重启服务
sudo systemctl restart tke-dify-sync

# 查看状态
sudo systemctl status tke-dify-sync

# 查看日志
sudo journalctl -u tke-dify-sync -f
```

## 📊 监控和维护

### 日志查看

```bash
# 应用日志
tail -f /opt/tke-dify-sync/logs/tke_sync.log

# 系统服务日志
sudo journalctl -u tke-dify-sync -f

# 错误日志
grep "ERROR\|❌" /opt/tke-dify-sync/logs/tke_sync.log
```

### 定时任务

```bash
# 编辑 crontab
crontab -e

# 监控任务（每5分钟）
*/5 * * * * /opt/tke-dify-sync/scripts/monitor.sh

# 定时同步（每天凌晨2点）
0 2 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1

# 日志清理（每天凌晨清理7天前的日志）
0 0 * * * find /opt/tke-dify-sync/logs -name "*.log" -mtime +7 -delete
```

## 🧪 验证部署

### 1. 配置测试

```bash
cd /opt/tke-dify-sync
source venv/bin/activate
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

### 2. 手动运行测试

```bash
python tke_dify_sync.py
```

预期输出：
```
🚀 TKE 文档同步到 Dify 知识库
[配置] ✅ 成功加载配置，知识库数量: 1, 策略: primary
[任务 1] 发现 156 个文档 URL
[任务 2] 开始抓取文档内容...
✅ 同步完成！创建: 5, 更新: 3, 跳过: 148
```

### 3. 服务状态检查

```bash
sudo systemctl status tke-dify-sync
```

预期输出：
```
● tke-dify-sync.service - TKE Dify Sync Service
   Loaded: loaded (/etc/systemd/system/tke-dify-sync.service; enabled)
   Active: active (running) since ...
```

## 🛠️ 故障排除

### 常见问题及解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Chrome 启动失败 | 缺少依赖库 | `sudo apt install -y libnss3 libgconf-2-4` |
| 配置文件错误 | API Key 或知识库 ID 错误 | 重新获取并配置 |
| 网络连接失败 | 防火墙或网络问题 | 检查网络连接和防火墙设置 |
| 权限问题 | 文件权限不正确 | `sudo chown -R $USER:$USER /opt/tke-dify-sync` |
| Python 依赖问题 | 依赖包安装失败 | 重新安装：`pip install -r requirements.txt` |

### 调试命令

```bash
# 检查系统环境
python3 --version
google-chrome --version
pip list | grep -E "(requests|selenium|beautifulsoup4)"

# 检查网络连接
curl -I https://cloud.tencent.com
curl -I https://api.dify.ai

# 检查文件权限
ls -la /opt/tke-dify-sync/
ls -la /opt/tke-dify-sync/.env

# 检查进程
ps aux | grep tke_dify_sync
pgrep -f "python.*tke_dify_sync"
```

## 📋 部署检查清单

### 环境准备
- [ ] Ubuntu 20.04+ 或 CentOS 7+ 系统
- [ ] 4GB+ 内存，20GB+ 存储空间
- [ ] 公网访问能力
- [ ] Python 3.8+ 安装完成
- [ ] Chrome 浏览器安装完成

### 文件部署
- [ ] 核心程序文件上传完成
- [ ] Python 虚拟环境创建完成
- [ ] 依赖包安装完成
- [ ] 目录结构创建完成
- [ ] 文件权限设置正确

### 配置设置
- [ ] .env 配置文件创建完成
- [ ] Dify API Key 配置正确
- [ ] 知识库 ID 配置正确
- [ ] 网络参数配置合理
- [ ] 文件路径配置正确

### 功能测试
- [ ] 配置测试通过
- [ ] 手动运行测试成功
- [ ] 日志文件正常生成
- [ ] 网络连接正常

### 服务配置（可选）
- [ ] systemd 服务创建完成
- [ ] 服务启动成功
- [ ] 监控脚本配置完成
- [ ] 定时任务配置完成

## 🎉 部署完成

恭喜！您已成功在 CVM 上部署了 TKE 文档智能同步系统。

### 快速验证

```bash
# 1. 测试配置
cd /opt/tke-dify-sync && python test_config.py

# 2. 查看服务状态
sudo systemctl status tke-dify-sync

# 3. 查看实时日志
tail -f /opt/tke-dify-sync/logs/tke_sync.log
```

### 日常使用

- **启动同步**：`sudo systemctl start tke-dify-sync`
- **停止同步**：`sudo systemctl stop tke-dify-sync`
- **查看日志**：`tail -f /opt/tke-dify-sync/logs/tke_sync.log`
- **手动运行**：`cd /opt/tke-dify-sync && python tke_dify_sync.py`

### 技术支持

如遇到问题，请：
1. 查看日志文件获取详细错误信息
2. 运行 `python test_config.py` 验证配置
3. 检查网络连接和防火墙设置
4. 参考完整的 `DEPLOYMENT_GUIDE.md` 文档

系统已准备就绪，开始享受自动化的文档同步服务吧！🚀