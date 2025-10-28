# TKE 文档智能同步系统 - 用户使用指南

## 🎯 系统简介

这是一个智能的 TKE 文档同步系统，能够：
- 自动抓取 TKE 文档
- 智能检测内容变更（哈希对比）
- 自动同步到 Dify 知识库
- 跳过未变更的内容，节省时间和API调用

## 📋 快速开始

### 1. 配置文件设置

**只需要配置一个文件：`.env`**

创建或编辑 `.env` 文件：

```bash
# === 必填配置 ===
# Dify API 密钥（必须）
DIFY_API_KEY=your_dify_api_key_here

# Dify 知识库 ID（必须，支持多个，用逗号分隔）
DIFY_KNOWLEDGE_BASE_ID=your_knowledge_base_id_here

# Dify API 地址（必须）
DIFY_API_BASE_URL=https://api.dify.ai/v1

# === 可选配置 ===
# 知识库策略：primary（只用第一个）| all（同步到所有）| round_robin（轮询）
KB_STRATEGY=primary

# 请求超时时间（秒）
REQUEST_TIMEOUT=30

# 重试次数
RETRY_ATTEMPTS=3

# 重试延迟（秒）
RETRY_DELAY=1

# 状态文件名
STATE_FILE=crawl_state.json

# 日志文件名
LOG_FILE=tke_sync.log

# TKE 文档基础URL
BASE_URL=https://cloud.tencent.com

# TKE 文档起始URL
START_URL=https://cloud.tencent.com/document/product/457
```

### 2. 获取 Dify 配置信息

#### 获取 API Key：
1. 登录 Dify 控制台
2. 进入"设置" → "API Keys"
3. 创建新的 API Key，复制到 `DIFY_API_KEY`

#### 获取知识库 ID：
1. 进入 Dify 知识库页面
2. 选择要同步的知识库
3. 从 URL 中获取知识库 ID（类似：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`）
4. 填入 `DIFY_KNOWLEDGE_BASE_ID`

### 3. 运行同步

#### 方式一：使用主程序（推荐）
```bash
python tke_dify_sync.py
```

#### 方式二：在代码中使用
```python
from tke_dify_sync import ConfigManager, sync_to_dify

# 加载配置
config_manager = ConfigManager()
config = config_manager.load_config()

# 同步单个文档
url = "https://cloud.tencent.com/document/product/457/example"
content = "文档内容"
metadata = {"document_type": "操作类文档"}

success = sync_to_dify(url, content, config, metadata)
print(f"同步结果: {'成功' if success else '失败'}")
```

#### 方式三：使用 DifySyncManager（高级用法）
```python
from dify_sync_manager import DifySyncManager
from tke_dify_sync import ConfigManager

config_manager = ConfigManager()
config = config_manager.load_config()

dify_manager = DifySyncManager(config)
success = dify_manager.sync_document(url, content, metadata)
```

## 🔍 智能哈希对比功能

系统会自动：

1. **第一次同步**：创建文档并保存内容哈希
   ```
   [Dify] 创建新文档: 文档标题
   [Dify] 内容哈希: abc123def456...
   [Dify] 文档创建成功
   ```

2. **再次同步相同内容**：自动跳过
   ```
   [Dify] 获取到现有文档哈希: abc123def456...
   [Dify] 内容未变更，跳过同步: 文档标题
   ```

3. **内容变更时**：自动更新
   ```
   [Dify] 检测到内容变更: 文档标题
   [Dify] 旧哈希: abc123def456...
   [Dify] 新哈希: def789ghi012...
   [Dify] 文档更新成功
   ```

## 📊 运行效果

### 性能优化
- **新文档创建**：正常API调用
- **跳过未变更内容**：减少50%的API调用
- **智能更新**：只在真正需要时更新

### 日志输出示例
```
🚀 TKE 文档同步到 Dify 知识库
[配置] 成功加载配置，知识库数量: 1, 策略: primary
[任务 1] 正在启动 Selenium...
[任务 1] 发现 156 个文档 URL
[任务 2] 开始抓取文档内容...
[任务 3] 开始变更检测...
[任务 4] 开始同步到 Dify...
[Dify] 内容未变更，跳过同步: 某个文档
[Dify] 检测到内容变更: 另一个文档
[Dify] 文档更新成功
✅ 同步完成！
```

## ⚙️ 高级配置

### 多知识库同步

#### 方式一：相同配置的多知识库
```bash
# 同步到多个知识库（使用相同配置）
DIFY_KNOWLEDGE_BASE_ID=kb1,kb2,kb3
KB_STRATEGY=all
```

#### 方式二：不同配置的多知识库（推荐）

**步骤1：创建多个配置文件**

`.env.main` (主知识库):
```bash
DIFY_API_KEY=your_api_key
DIFY_KNOWLEDGE_BASE_ID=8c6b8e3c-f69c-48ea-b34e-a71798c800ed
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
```

`.env.test` (测试知识库):
```bash
DIFY_API_KEY=your_api_key
DIFY_KNOWLEDGE_BASE_ID=2ac0e7aa-9eba-4363-8f9d-e426d0b2451e
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
```

**步骤2：分别运行同步**
```bash
# 同步到主知识库
cp .env.main .env
python tke_dify_sync.py

# 同步到测试知识库
cp .env.test .env
python tke_dify_sync.py
```

**优势：**
- ✅ 每个知识库独立配置
- ✅ 可以使用不同的处理策略
- ✅ 便于环境隔离（生产/测试/开发）
- ✅ 配置清晰，易于维护

### 自定义重试策略
```bash
# 增加重试次数和延迟
RETRY_ATTEMPTS=5
RETRY_DELAY=2
REQUEST_TIMEOUT=60
```

## 🛠️ 故障排除

### 常见问题

1. **配置文件找不到**
   - 确保 `.env` 文件在运行目录中
   - 检查文件编码是否为 UTF-8

2. **API Key 无效**
   - 检查 `DIFY_API_KEY` 是否正确
   - 确认 API Key 有相应权限

3. **知识库 ID 错误**
   - 检查 `DIFY_KNOWLEDGE_BASE_ID` 格式
   - 确认知识库存在且可访问

4. **网络连接问题**
   - 检查网络连接
   - 尝试增加 `REQUEST_TIMEOUT` 值

### 调试模式
```bash
# 设置详细日志
export LOG_LEVEL=DEBUG
python tke_dify_sync.py
```

## 📁 文件结构

```
项目目录/
├── .env                    # 配置文件（唯一需要配置的文件）
├── tke_dify_sync.py       # 主程序
├── dify_sync_manager.py   # 核心同步管理器
├── dify_sync.py           # 兼容性同步器
├── enhanced_metadata_generator.py  # 元数据生成器
├── smart_retry_manager.py # 智能重试管理器
├── tke_logger.py          # 日志系统
├── secure_temp_manager.py # 临时文件管理器
├── crawl_state.json       # 状态文件（自动生成）
├── tke_sync.log          # 日志文件（自动生成）
└── USER_GUIDE.md         # 本使用指南
```

## 🎯 总结

1. **只需配置一个文件**：`.env`
2. **三个必填项**：`DIFY_API_KEY`、`DIFY_KNOWLEDGE_BASE_ID`、`DIFY_API_BASE_URL`
3. **一条命令运行**：`python tke_dify_sync.py`
4. **智能同步**：自动检测变更，跳过重复内容
5. **完整日志**：详细的运行状态和统计信息

**就这么简单！** 🚀