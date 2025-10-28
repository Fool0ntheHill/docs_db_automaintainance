# Git 仓库设置和维护指南

## 🚀 初始化 Git 仓库

### 1. 本地仓库初始化

```bash
# 在项目根目录执行
git init

# 添加远程仓库
git remote add origin https://github.com/Fool0ntheHill/docs_db_automaintainance.git

# 创建 .gitignore 文件
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# 虚拟环境
venv/
env/
ENV/

# 配置文件（包含敏感信息）
.env
.env.production
.env.testing
.env.local
.env.*.local

# 日志文件
logs/
*.log

# 数据文件
data/
*.json
*.db
*.sqlite

# 临时文件
temp/
tmp/
*.tmp
*.temp

# 系统文件
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Chrome 驱动
chromedriver*

# 备份文件
*.backup
*.bak
EOF

# 添加所有文件
git add .

# 提交初始版本
git commit -m "Initial commit: TKE 文档智能同步系统

- 完整的文档抓取和同步功能
- 智能哈希对比，避免重复同步
- 多知识库支持
- 完整的部署脚本和文档
- 错误处理和重试机制
- 监控和日志系统"

# 推送到远程仓库
git branch -M main
git push -u origin main
```

### 2. 文件结构说明

推送到 Git 的文件包括：

```
.
├── README.md                        # 项目说明
├── requirements.txt                  # Python 依赖
├── .gitignore                       # Git 忽略文件
├── 
├── # 核心程序文件
├── tke_dify_sync.py                 # 主程序
├── dify_sync_manager.py             # Dify 同步管理器
├── enhanced_metadata_generator.py    # 元数据生成器
├── smart_retry_manager.py           # 智能重试管理器
├── tke_logger.py                    # 日志管理器
├── secure_temp_manager.py           # 临时文件管理器
├── 
├── # 配置文件模板
├── .env.example                     # 基础配置模板
├── .env.production.example          # 生产环境配置模板
├── .env.testing.example             # 测试环境配置模板
├── 
├── # 部署相关
├── deploy.sh                        # 完整部署脚本
├── quick_deploy.sh                  # 快速部署脚本
├── config_wizard.py                 # 配置向导
├── 
├── # 文档
├── DEPLOYMENT_GUIDE.md              # 完整部署指南
├── QUICK_START_CVM.md              # 快速开始指南
├── CVM_DEPLOYMENT_SUMMARY.md       # 部署总结
├── GIT_SETUP.md                    # 本文档
├── 
├── # 脚本目录
├── scripts/
│   ├── start.sh                    # 启动脚本
│   ├── stop.sh                     # 停止脚本
│   ├── status.sh                   # 状态检查脚本
│   ├── monitor.sh                  # 监控脚本
│   └── sync_all_kb.sh              # 多知识库同步脚本
├── 
└── # 测试目录
    └── test/
        ├── test_config.py          # 配置测试
        └── ...
```

### 3. 不推送的文件（.gitignore）

以下文件不会推送到 Git 仓库：
- `.env` - 实际配置文件（包含敏感信息）
- `logs/` - 日志文件
- `data/` - 数据文件和状态文件
- `venv/` - Python 虚拟环境
- `temp/` - 临时文件

## 📥 从 Git 仓库部署

### 方法一：使用部署脚本（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/Fool0ntheHill/docs_db_automaintainance.git
cd docs_db_automaintainance

# 2. 运行部署脚本
chmod +x deploy.sh
./deploy.sh

# 3. 配置系统
python config_wizard.py

# 4. 测试运行
python test_config.py
python tke_dify_sync.py
```

### 方法二：手动部署

```bash
# 1. 克隆仓库
git clone https://github.com/Fool0ntheHill/docs_db_automaintainance.git
cd docs_db_automaintainance

# 2. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 3. 安装依赖
pip install -r requirements.txt

# 4. 创建配置文件
cp .env.example .env
nano .env  # 编辑配置

# 5. 创建必要目录
mkdir -p {data,logs,temp}

# 6. 设置脚本权限
chmod +x scripts/*.sh

# 7. 测试运行
python test_config.py
python tke_dify_sync.py
```

## 🔄 更新和维护

### 1. 更新代码

```bash
# 拉取最新代码
git pull origin main

# 更新依赖（如果 requirements.txt 有变化）
source venv/bin/activate
pip install -r requirements.txt --upgrade

# 重启服务
sudo systemctl restart tke-dify-sync
```

### 2. 更新配置文件

**场景：需要修改配置但不想影响现有配置**

```bash
# 1. 备份当前配置
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

# 2. 查看新的配置模板
diff .env .env.example

# 3. 手动合并配置
nano .env

# 4. 测试新配置
python test_config.py

# 5. 重启服务
sudo systemctl restart tke-dify-sync
```

**场景：添加新的知识库配置**

```bash
# 1. 创建新的配置文件
cp .env.production.example .env.newkb

# 2. 编辑新配置
nano .env.newkb

# 3. 测试新配置
cp .env.newkb .env && python test_config.py

# 4. 添加到批量同步脚本
nano scripts/sync_all_kb.sh
```

### 3. 版本管理

**创建新版本标签**

```bash
# 1. 提交所有更改
git add .
git commit -m "版本更新: 添加新功能或修复"

# 2. 创建版本标签
git tag -a v1.1.0 -m "版本 1.1.0: 功能描述"

# 3. 推送标签
git push origin v1.1.0
git push origin main
```

**回滚到特定版本**

```bash
# 1. 查看可用版本
git tag -l

# 2. 切换到特定版本
git checkout v1.0.0

# 3. 创建新分支（如果需要修改）
git checkout -b hotfix-v1.0.0

# 4. 返回主分支
git checkout main
```

## 🔧 开发工作流

### 1. 功能开发

```bash
# 1. 创建功能分支
git checkout -b feature/new-feature

# 2. 开发和测试
# ... 编写代码 ...

# 3. 提交更改
git add .
git commit -m "feat: 添加新功能描述"

# 4. 推送分支
git push origin feature/new-feature

# 5. 创建 Pull Request（在 GitHub 上）

# 6. 合并后删除分支
git checkout main
git pull origin main
git branch -d feature/new-feature
```

### 2. 热修复

```bash
# 1. 创建热修复分支
git checkout -b hotfix/critical-bug

# 2. 修复问题
# ... 修复代码 ...

# 3. 测试修复
python test_config.py

# 4. 提交修复
git add .
git commit -m "fix: 修复关键问题描述"

# 5. 合并到主分支
git checkout main
git merge hotfix/critical-bug
git push origin main

# 6. 创建修复版本标签
git tag -a v1.0.1 -m "版本 1.0.1: 修复关键问题"
git push origin v1.0.1
```

## 📋 部署检查清单

### 首次部署
- [ ] Git 仓库已创建并推送
- [ ] 服务器环境已准备
- [ ] 代码已克隆到服务器
- [ ] 依赖已安装
- [ ] 配置文件已创建
- [ ] 测试运行成功
- [ ] 系统服务已配置
- [ ] 监控已设置

### 更新部署
- [ ] 代码已更新
- [ ] 配置文件已检查
- [ ] 依赖已更新
- [ ] 测试通过
- [ ] 服务已重启
- [ ] 日志正常
- [ ] 监控正常

## 🚨 故障恢复

### 1. 配置文件损坏

```bash
# 1. 从备份恢复
cp .env.backup .env

# 2. 或从模板重新创建
cp .env.example .env
nano .env

# 3. 测试配置
python test_config.py
```

### 2. 代码问题回滚

```bash
# 1. 查看提交历史
git log --oneline

# 2. 回滚到上一个工作版本
git reset --hard HEAD~1

# 3. 或回滚到特定提交
git reset --hard <commit-hash>

# 4. 强制推送（谨慎使用）
git push --force origin main
```

### 3. 完整重新部署

```bash
# 1. 备份配置和数据
cp .env .env.backup
cp -r data data.backup
cp -r logs logs.backup

# 2. 重新克隆仓库
cd ..
rm -rf docs_db_automaintainance
git clone https://github.com/Fool0ntheHill/docs_db_automaintainance.git
cd docs_db_automaintainance

# 3. 恢复配置和数据
cp ../old-project/.env.backup .env
cp -r ../old-project/data.backup data
cp -r ../old-project/logs.backup logs

# 4. 重新部署
./deploy.sh
```

## 📞 支持和维护

### 获取帮助
- 查看项目文档：`README.md`
- 检查部署指南：`DEPLOYMENT_GUIDE.md`
- 查看故障排除：`DEPLOYMENT_GUIDE.md` 中的故障排除部分

### 报告问题
1. 在 GitHub 上创建 Issue
2. 提供详细的错误信息和日志
3. 说明操作系统和环境信息
4. 提供复现步骤

### 贡献代码
1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 创建 Pull Request
5. 等待代码审查

---

通过遵循这个指南，您可以有效地管理 TKE 文档同步系统的 Git 仓库，确保代码的版本控制和部署的一致性。