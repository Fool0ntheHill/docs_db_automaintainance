# 用户使用指南

> 详细的功能说明和高级配置指南

## 📋 目录

- [基础配置](#基础配置)
- [多知识库配置](#多知识库配置)
- [高级功能](#高级功能)
- [故障排除](#故障排除)
- [性能优化](#性能优化)

## 🔧 基础配置

### 配置文件说明

系统只需要一个配置文件：`.env`

```bash
# === 必填配置 ===
DIFY_API_KEY=dataset-m6r1gc2q4BKVKPKR0xy1KVPS
DIFY_KNOWLEDGE_BASE_ID=781c5e51-c317-4861-823e-143f13ab69ce
DIFY_API_BASE_URL=http://119.91.201.9/v1

# === 可选配置 ===
KB_STRATEGY=primary
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
RETRY_DELAY=2
STATE_FILE=data/crawl_state.json
LOG_FILE=logs/tke_sync.log
BASE_URL=https://cloud.tencent.com
START_URL=https://cloud.tencent.com/document/product/457
```

### 配置参数详解

| 参数 | 必填 | 说明 | 默认值 |
|------|------|------|--------|
| `DIFY_API_KEY` | ✅ | Dify API 密钥 | - |
| `DIFY_KNOWLEDGE_BASE_ID` | ✅ | 知识库 ID（支持多个，逗号分隔） | - |
| `DIFY_API_BASE_URL` | ✅ | Dify API 地址 | - |
| `KB_STRATEGY` | ❌ | 知识库策略：primary/all/round_robin | primary |
| `REQUEST_TIMEOUT` | ❌ | 请求超时时间（秒） | 30 |
| `RETRY_ATTEMPTS` | ❌ | 重试次数 | 3 |
| `RETRY_DELAY` | ❌ | 重试延迟（秒） | 2 |

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

#### 方式二：不同配置的多知识库（当前配置）

系统已预配置两个知识库，每个都有独立的配置文件：

**知识库配置**

| 配置文件 | 知识库名称 | 知识库ID | 用途 |
|----------|------------|----------|------|
| `.env.tke_docs_base` | TKE基础文档库 | `781c5e51-c317-4861-823e-143f13ab69ce` | 主要文档库 |
| `.env.tke_knowledge_base` | TKE知识库 | `ee0c2549-96cd-4ff4-97ab-88c1704eae21` | 备用知识库 |

**使用方法**

```bash
# 方法一：手动切换
cp .env.tke_docs_base .env && python tke_dify_sync.py
cp .env.tke_knowledge_base .env && python tke_dify_sync.py

# 方法二：批量同步（推荐）
./scripts/sync_all_kb.sh

# 方法三：定时任务
# 每天凌晨2点同步到 tke_docs_base
0 2 * * * cd /path/to/project && cp .env.tke_docs_base .env && python tke_dify_sync.py

# 每天凌晨3点同步到 tke_knowledge_base  
0 3 * * * cd /path/to/project && cp .env.tke_knowledge_base .env && python tke_dify_sync.py
```

**配置差异**

| 配置项 | tke_docs_base | tke_knowledge_base |
|--------|---------------|-------------------|
| 超时时间 | 60秒 | 30秒 |
| 重试次数 | 5次 | 3次 |
| 重试延迟 | 3秒 | 2秒 |
| 状态文件 | `crawl_state_tke_docs_base.json` | `crawl_state_tke_knowledge_base.json` |
| 日志文件 | `tke_sync_tke_docs_base.log` | `tke_sync_tke_knowledge_base.log` |

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