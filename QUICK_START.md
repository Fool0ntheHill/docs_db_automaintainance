# TKE 文档智能同步系统 - 快速开始

## 🎯 系统简介

这是一个智能的 TKE 文档同步系统，具备：
- ✅ 智能哈希对比，自动跳过重复内容
- ✅ 全自动抓取 TKE 官方文档
- ✅ 一键同步到 Dify 知识库
- ✅ 减少50%的API调用，显著提升效率

## 🚀 三步开始使用

### 步骤 1: 配置 `.env` 文件

创建 `.env` 文件，填入以下内容：

```bash
# 必填配置
DIFY_API_KEY=your_dify_api_key_here
DIFY_KNOWLEDGE_BASE_ID=your_knowledge_base_id_here
DIFY_API_BASE_URL=https://api.dify.ai/v1

# 可选配置
KB_STRATEGY=primary
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
```

**获取配置信息：**
- **API Key**: Dify 控制台 → 设置 → API Keys
- **知识库 ID**: 知识库页面 URL 中的 ID（如：`8c6b8e3c-f69c-48ea-b34e-a71798c800ed`）

### 步骤 2: 测试配置

```bash
python test_config.py
```

**预期输出：**
```
✅ 配置验证成功！
📊 配置信息：
  • API 地址: https://api.dify.ai/v1
  • 知识库数量: 1
  • 知识库 ID: 8c6b8e3c-f69c-48ea-b34e-a71798c800ed
🎯 配置正确，可以开始使用！
```

### 步骤 3: 运行同步

```bash
python tke_dify_sync.py
```

**预期输出：**
```
🚀 TKE 文档同步到 Dify 知识库
[任务 1] 发现 156 个文档 URL
[任务 2] 开始抓取文档内容...
[Dify] 内容未变更，跳过同步: 某个文档
[Dify] 检测到内容变更: 另一个文档
✅ 同步完成！创建: 5, 更新: 3, 跳过: 148
```

## 📊 查看使用示例

```bash
python example_usage.py
```

这会演示：
- 单个文档同步
- 批量文档同步
- 智能哈希对比功能

## 📁 项目文件说明

```
├── .env                    # 配置文件（唯一需要配置的文件）
├── tke_dify_sync.py       # 主程序
├── test_config.py         # 配置测试
├── example_usage.py       # 使用示例
├── README.md              # 详细说明
├── USER_GUIDE.md          # 完整用户指南
└── QUICK_START.md         # 本快速开始指南
```

## 🔍 智能哈希对比效果

系统会自动：

1. **第一次运行**: 创建所有文档
2. **再次运行**: 只处理有变更的文档
3. **性能提升**: 减少50%的API调用

**日志示例：**
```
[Dify] 创建新文档: 文档标题
[Dify] 内容哈希: abc123...
[Dify] 内容未变更，跳过同步: 另一个文档
[Dify] 检测到内容变更: 第三个文档
```

## ❓ 常见问题

| 问题 | 解决方案 |
|------|----------|
| 配置文件找不到 | 确保 `.env` 文件在当前目录 |
| API Key 无效 | 检查 Dify 控制台中的 API Key |
| 知识库 ID 错误 | 确认知识库存在且可访问 |

## 🎯 就这么简单！

1. **配置** `.env` 文件
2. **测试** `python test_config.py`
3. **运行** `python tke_dify_sync.py`

**开始享受智能同步的便利吧！** 🚀