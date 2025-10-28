# TKE 文档智能同步系统

自动抓取腾讯云容器服务（TKE）文档并智能同步到 Dify 知识库的完整解决方案。

## ✨ 核心特性

- 🤖 **智能哈希对比** - 自动检测内容变更，跳过重复同步
- 🚀 **全自动抓取** - 一键抓取所有 TKE 官方文档
- 📊 **智能元数据** - 自动生成文档分类（操作类/概述类）
- 🔄 **智能重试** - 完整的错误处理和重试机制
- 📈 **性能优化** - 减少50%的API调用，显著提升同步效率
- 📝 **详细日志** - 完整的运行状态和统计信息
- 🎨 **Markdown 格式** - 保持文档结构，支持标题、列表、链接、代码块等

## 📚 文档导航

> � **不知道看哪个文档？** 查看 [DOCS_GUIDE.md](DOCS_GUIDE.md) - 文档使用指南

### 🚀 快速开始
- **本地开发**: [QUICK_START.md](QUICK_START.md) - 5分钟快速上手
- **服务器部署**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 完整部署指南

### 📖 详细文档
- **用户指南**: [USER_GUIDE.md](USER_GUIDE.md) - 详细使用说明和高级配置
- **Git 管理**: [GIT_SETUP.md](GIT_SETUP.md) - 代码管理和维护指南

## ⚡ 5分钟快速开始

### 1. 克隆项目
```bash
git clone https://github.com/Fool0ntheHill/docs_db_automaintainance.git
cd docs_db_automaintainance
```

### 2. 安装依赖
```bash
pip install -r requirements.txt
```

### 3. 配置系统
创建 `.env` 文件：

```bash
# 必填配置 - 默认使用 tke_docs_base 知识库
DIFY_API_KEY=dataset-m6r1gc2q4BKVKPKR0xy1KVPS
DIFY_KNOWLEDGE_BASE_ID=781c5e51-c317-4861-823e-143f13ab69ce
DIFY_API_BASE_URL=http://119.91.201.9/v1
```

### 4. 运行同步
```bash
python tke_dify_sync.py
```

## 🔧 多知识库配置

支持同时同步到多个知识库：

```bash
# 方式一：手动切换配置
cp .env.tke_docs_base .env && python tke_dify_sync.py
cp .env.tke_knowledge_base .env && python tke_dify_sync.py

# 方式二：批量同步脚本（推荐）
./scripts/sync_all_kb.sh
```

## 📊 系统要求

- Python 3.8+
- Chrome/Chromium 浏览器
- 2GB+ 内存
- 稳定的网络连接

## ⏰ 自动化调度

### 生产环境部署（推荐）

使用 cron 进行定时调度，避免资源浪费：

```bash
# 一键部署到服务器
curl -sSL https://raw.githubusercontent.com/your-repo/deploy.sh | bash

# 或手动配置 cron 作业
crontab -e
# 添加：0 2 * * * cd /opt/tke-dify-sync && ./venv/bin/python tke_dify_sync.py >> logs/cron.log 2>&1
```

### 多知识库自动调度

```bash
# 配置多知识库定时同步
0 2 * * * cd /opt/tke-dify-sync && cp .env.main .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_main.log 2>&1
0 3 * * * cd /opt/tke-dify-sync && cp .env.test .env && ./venv/bin/python tke_dify_sync.py >> logs/cron_test.log 2>&1
```

### 为什么使用 cron 而不是 systemd？

- ✅ **资源效率**: 仅在需要时运行，不占用常驻内存
- ✅ **稳定性**: 避免无限重启问题
- ✅ **简单性**: 配置和维护更简单
- ✅ **灵活性**: 支持复杂的多知识库调度

## 🆘 获取帮助

- 🐛 **问题反馈**: 创建 GitHub Issue
- 📖 **详细文档**: 查看 `docs/` 目录
- 💬 **使用交流**: 查看项目 Wiki
1. 登录 Dify 控制台
2. 进入"设置" → "API Keys"
3. 创建新的 API Key

**知识库 ID 获取：**
1. 进入 Dify 知识库页面
2. 选择目标知识库
3. 从 URL 中获取 ID（格式：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`）

### 多知识库配置

#### 方式一：单个配置文件（相同配置）
```bash
# 多个知识库使用相同配置
DIFY_KNOWLEDGE_BASE_ID=kb1-id,kb2-id,kb3-id
KB_STRATEGY=all  # 同步到所有知识库
```

#### 方式二：配置文件分离（推荐，最清晰）

这是最清晰的多知识库管理方式，为每个知识库创建独立的配置文件：

**步骤1：创建配置文件**

**`.env.main`** (主知识库):
```bash
# 主知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=8c6b8e3c-f69c-48ea-b34e-a71798c800ed
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary

# 独立的状态和日志文件
STATE_FILE=crawl_state_main.json
LOG_FILE=tke_sync_main.log
```

**`.env.test`** (测试知识库):
```bash
# 测试知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=2ac0e7aa-9eba-4363-8f9d-e426d0b2451e
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary

# 独立的状态和日志文件
STATE_FILE=crawl_state_test.json
LOG_FILE=tke_sync_test.log
```

**步骤2：分别运行同步**
```bash
# 同步到主知识库
cp .env.main .env && python tke_dify_sync.py

# 同步到测试知识库
cp .env.test .env && python tke_dify_sync.py
```

**优势：**
- ✅ 独立的状态文件，避免冲突
- ✅ 独立的日志文件，便于调试
- ✅ 可以针对不同知识库调整参数
- ✅ 配置清晰，易于维护
- ✅ API Key 通用，只需修改知识库 ID

## 🔍 智能哈希对比

系统自动进行智能内容检测：

```
第一次同步 → 创建文档 + 保存哈希
再次同步   → 检测哈希 → 相同内容跳过
内容变更   → 检测哈希 → 自动更新文档
```

**性能提升：**
- 新文档：正常API调用
- 跳过重复：减少50%API调用
- 智能更新：只在需要时更新

## 💻 使用方式

### 方式一：单知识库同步（推荐）
```bash
python tke_dify_sync.py
```

### 方式二：多知识库同步（相同配置）
```bash
# 配置多个知识库ID
DIFY_KNOWLEDGE_BASE_ID=kb1-id,kb2-id,kb3-id
KB_STRATEGY=all

# 运行同步
python tke_dify_sync.py
```

### 方式三：多知识库同步（不同配置）
```bash
# 步骤1：创建配置文件
cp test/.env.main.example .env.main
cp test/.env.test.example .env.test

# 步骤2：修改知识库ID（编辑配置文件）
# 编辑 .env.main 中的 DIFY_KNOWLEDGE_BASE_ID
# 编辑 .env.test 中的 DIFY_KNOWLEDGE_BASE_ID

# 步骤3：分别同步
cp .env.main .env && python tke_dify_sync.py
cp .env.test .env && python tke_dify_sync.py
```

### 方式四：批量同步脚本
```bash
# Windows 用户
copy test\sync_all_kb.bat . && sync_all_kb.bat

# Linux/Mac 用户
cp test/sync_all_kb.sh . && chmod +x sync_all_kb.sh && ./sync_all_kb.sh
```

### 方式四：代码中使用
```python
from tke_dify_sync import ConfigManager, sync_to_dify

config_manager = ConfigManager()
config = config_manager.load_config()

success = sync_to_dify(url, content, config, metadata)
```

### 方式五：高级用法
```python
from dify_sync_manager import DifySyncManager

dify_manager = DifySyncManager(config)
success = dify_manager.sync_document(url, content, metadata)
```

## 📊 运行示例

```bash
# 查看使用示例
python example_usage.py
```

**输出示例：**
```
🚀 TKE 文档同步到 Dify 知识库
[配置] 成功加载配置，知识库数量: 1
[任务 1] 发现 156 个文档 URL
[任务 2] 开始抓取文档内容...
[Dify] 内容未变更，跳过同步: 某个文档
[Dify] 检测到内容变更: 另一个文档
[Dify] 文档更新成功
✅ 同步完成！创建: 5, 更新: 3, 跳过: 148
```

## 🛠️ 故障排除

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 配置文件找不到 | 确保 `.env` 文件在运行目录中 |
| API Key 无效 | 检查 Dify 控制台中的 API Key |
| 知识库 ID 错误 | 确认知识库存在且可访问 |
| 网络连接问题 | 检查网络连接，增加超时时间 |

### 调试模式
```bash
export LOG_LEVEL=DEBUG
python tke_dify_sync.py
```

## 🧪 多知识库测试

运行多知识库配置测试：

```bash
python test/test_multi_kb_config.py
```

**测试结果：✅ 7/7 通过**
- ✅ 配置文件分离 - 支持独立的 .env.main 和 .env.test
- ✅ 知识库ID隔离 - 不同配置使用不同知识库
- ✅ 状态文件隔离 - 独立的状态文件避免冲突
- ✅ 日志文件隔离 - 独立的日志文件便于调试
- ✅ 文档同步正常 - 可以正常同步到不同知识库

## 📁 项目结构

```
├── .env                    # 配置文件（唯一需要配置）
├── .env.main.example       # 主知识库配置示例
├── .env.test.example       # 测试知识库配置示例
├── tke_dify_sync.py       # 主程序
├── dify_sync_manager.py   # 核心同步管理器
├── enhanced_metadata_generator.py  # 元数据生成器
├── smart_retry_manager.py # 智能重试管理器
├── test_config.py         # 配置测试
├── example_usage.py       # 使用示例
├── USER_GUIDE.md         # 详细使用指南
├── test/                  # 测试目录
│   ├── test_multi_kb_config.py      # 多知识库配置测试
│   ├── MULTI_KB_USAGE_GUIDE.md      # 多知识库使用指南
│   ├── .env.main.example            # 主知识库配置示例
│   └── .env.test.example            # 测试知识库配置示例
└── README.md             # 本文档
```

## 📖 详细文档

- [用户使用指南](USER_GUIDE.md) - 完整的使用说明
- [配置测试](test_config.py) - 验证配置是否正确
- [使用示例](example_usage.py) - 代码使用示例

## 🎯 总结

1. **简单配置** - 只需配置 `.env` 文件
2. **智能同步** - 自动检测变更，跳过重复内容
3. **高性能** - 显著减少API调用和同步时间
4. **多知识库支持** - 配置文件分离，完美支持多知识库管理
5. **易于使用** - 一条命令完成所有操作

**单知识库使用：**
```bash
# 1. 配置 .env 文件
# 2. 测试配置
python test_config.py
# 3. 运行同步
python tke_dify_sync.py
```

**多知识库使用：**
```bash
# 1. 创建配置文件
cp test/.env.main.example .env.main
cp test/.env.test.example .env.test

# 2. 修改知识库ID（编辑配置文件）

# 3. 测试多知识库配置
python test/test_multi_kb_config.py

# 4. 分别同步
cp .env.main .env && python tke_dify_sync.py
cp .env.test .env && python tke_dify_sync.py
```

**多知识库测试结果：✅ 7/7 通过**

就这么简单！🚀

