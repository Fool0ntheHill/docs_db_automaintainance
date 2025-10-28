# 多知识库配置使用指南

## 🎯 概述

本指南详细说明如何使用配置文件分离的方式管理多个知识库。这是最清晰、最易维护的多知识库管理方案。

## 📋 配置文件分离方案

### 优势

- ✅ **配置清晰** - 每个知识库有独立的配置文件
- ✅ **状态隔离** - 独立的状态文件，避免冲突
- ✅ **日志分离** - 独立的日志文件，便于调试
- ✅ **易于维护** - 可以针对不同知识库调整参数
- ✅ **API Key 通用** - 只需修改知识库 ID

### 适用场景

1. **不同用途的知识库** - 技术文档库、用户手册库、API文档库
2. **多环境部署** - 开发、测试、生产环境
3. **团队协作** - 不同团队使用不同知识库
4. **内容分类** - 按产品、版本、语言分离

## 🔧 配置步骤

### 步骤1：创建配置文件

从示例文件复制并修改：

```bash
# 复制主知识库配置
cp test/.env.main.example .env.main

# 复制测试知识库配置  
cp test/.env.test.example .env.test
```

### 步骤2：修改知识库 ID

编辑 `.env.main`：
```bash
# 主知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=8c6b8e3c-f69c-48ea-b34e-a71798c800ed  # 修改为你的主知识库ID
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
STATE_FILE=crawl_state_main.json
LOG_FILE=tke_sync_main.log
```

编辑 `.env.test`：
```bash
# 测试知识库配置
DIFY_API_KEY=dataset-ecFZ4CQ2obkwZHdyYRFo2Lih
DIFY_KNOWLEDGE_BASE_ID=2ac0e7aa-9eba-4363-8f9d-e426d0b2451e  # 修改为你的测试知识库ID
DIFY_API_BASE_URL=https://api.dify.ai/v1
KB_STRATEGY=primary
STATE_FILE=crawl_state_test.json
LOG_FILE=tke_sync_test.log
```

### 步骤3：分别运行同步

```bash
# 同步到主知识库
cp .env.main .env && python tke_dify_sync.py

# 同步到测试知识库
cp .env.test .env && python tke_dify_sync.py
```

## 📊 配置参数说明

### 必填参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `DIFY_API_KEY` | Dify API 密钥 | `dataset-ecFZ4CQ2obkwZHdyYRFo2Lih` |
| `DIFY_KNOWLEDGE_BASE_ID` | 知识库 ID | `8c6b8e3c-f69c-48ea-b34e-a71798c800ed` |
| `DIFY_API_BASE_URL` | Dify API 基础 URL | `https://api.dify.ai/v1` |

### 可选参数

| 参数 | 说明 | 默认值 | 推荐值 |
|------|------|--------|--------|
| `KB_STRATEGY` | 同步策略 | `primary` | `primary` |
| `REQUEST_TIMEOUT` | 请求超时时间(秒) | `10` | `30` |
| `RETRY_ATTEMPTS` | 重试次数 | `3` | `3` |
| `RETRY_DELAY` | 重试延迟(秒) | `1` | `1` |
| `STATE_FILE` | 状态文件名 | `crawl_state.json` | `crawl_state_xxx.json` |
| `LOG_FILE` | 日志文件名 | `tke_sync.log` | `tke_sync_xxx.log` |

## 🧪 测试配置

运行测试脚本验证配置：

```bash
cd test
python test_multi_kb_config.py
```

测试内容包括：
- ✅ 配置文件加载
- ✅ Dify 管理器创建
- ✅ 文档同步功能
- ✅ 状态文件隔离
- ✅ 日志文件分离

## 📁 文件结构

使用配置文件分离后的文件结构：

```
项目根目录/
├── .env.main              # 主知识库配置
├── .env.test              # 测试知识库配置
├── crawl_state_main.json  # 主知识库状态文件
├── crawl_state_test.json  # 测试知识库状态文件
├── tke_sync_main.log      # 主知识库日志
├── tke_sync_test.log      # 测试知识库日志
└── tke_dify_sync.py       # 主程序
```

## 🚀 实际使用示例

### 示例1：技术文档分类

```bash
# API 文档库
# .env.api
DIFY_KNOWLEDGE_BASE_ID=api-kb-id
STATE_FILE=crawl_state_api.json
LOG_FILE=tke_sync_api.log

# 用户指南库
# .env.guide  
DIFY_KNOWLEDGE_BASE_ID=guide-kb-id
STATE_FILE=crawl_state_guide.json
LOG_FILE=tke_sync_guide.log

# 故障排除库
# .env.troubleshoot
DIFY_KNOWLEDGE_BASE_ID=troubleshoot-kb-id
STATE_FILE=crawl_state_troubleshoot.json
LOG_FILE=tke_sync_troubleshoot.log
```

### 示例2：多环境部署

```bash
# 开发环境
# .env.dev
DIFY_KNOWLEDGE_BASE_ID=dev-kb-id
STATE_FILE=crawl_state_dev.json
LOG_FILE=tke_sync_dev.log

# 测试环境
# .env.staging
DIFY_KNOWLEDGE_BASE_ID=staging-kb-id
STATE_FILE=crawl_state_staging.json
LOG_FILE=tke_sync_staging.log

# 生产环境
# .env.prod
DIFY_KNOWLEDGE_BASE_ID=prod-kb-id
STATE_FILE=crawl_state_prod.json
LOG_FILE=tke_sync_prod.log
```

### 示例3：批量同步脚本

创建 `sync_all.sh`：
```bash
#!/bin/bash

echo "开始多知识库同步..."

# 同步到主知识库
echo "同步到主知识库..."
cp .env.main .env
python tke_dify_sync.py

# 同步到测试知识库
echo "同步到测试知识库..."
cp .env.test .env
python tke_dify_sync.py

echo "多知识库同步完成！"
```

运行：
```bash
chmod +x sync_all.sh
./sync_all.sh
```

## 🛠️ 故障排除

### 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 配置文件找不到 | 文件路径错误 | 确保配置文件在正确位置 |
| 知识库 ID 错误 | ID 配置错误 | 检查 Dify 控制台中的知识库 ID |
| 状态文件冲突 | 使用了相同的状态文件名 | 为每个知识库配置独立的状态文件 |
| 日志混乱 | 使用了相同的日志文件名 | 为每个知识库配置独立的日志文件 |

### 调试技巧

1. **检查配置加载**：
```bash
python -c "from tke_dify_sync import ConfigManager; cm = ConfigManager('.env.main'); print(cm.load_config())"
```

2. **查看日志文件**：
```bash
tail -f tke_sync_main.log
tail -f tke_sync_test.log
```

3. **检查状态文件**：
```bash
cat crawl_state_main.json
cat crawl_state_test.json
```

## 📈 性能对比

| 方案 | 配置复杂度 | 维护难度 | 隔离程度 | 推荐指数 |
|------|------------|----------|----------|----------|
| 单配置文件 | ⭐ | ⭐ | ⭐ | ⭐⭐ |
| 相同配置多知识库 | ⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| 配置文件分离 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 🎯 总结

配置文件分离是管理多知识库的最佳方案：

1. **清晰的配置管理** - 每个知识库有独立配置
2. **完全的状态隔离** - 避免不同知识库间的冲突
3. **便于调试维护** - 独立的日志和状态文件
4. **灵活的参数调整** - 可以为不同知识库设置不同参数
5. **简单的使用方式** - 只需复制配置文件并运行

开始使用：
```bash
# 1. 复制配置文件模板
cp test/.env.main.example .env.main
cp test/.env.test.example .env.test

# 2. 修改知识库 ID
vim .env.main  # 修改 DIFY_KNOWLEDGE_BASE_ID
vim .env.test  # 修改 DIFY_KNOWLEDGE_BASE_ID

# 3. 测试配置
cd test && python test_multi_kb_config.py

# 4. 运行同步
cp .env.main .env && python tke_dify_sync.py
cp .env.test .env && python tke_dify_sync.py
```