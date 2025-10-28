# 快速开始 - 本地开发

> 适用于：本地开发、测试环境、个人使用

## ⚡ 5分钟快速上手

### 前置要求
- Python 3.8+
- Chrome 浏览器
- Git

### 步骤 1: 获取代码

```bash
# 克隆项目
git clone https://github.com/Fool0ntheHill/docs_db_automaintainance.git
cd docs_db_automaintainance

# 安装依赖
pip install -r requirements.txt
```

### 步骤 2: 配置系统

创建 `.env` 文件：

```bash
# 必填配置 - 默认使用 tke_docs_base 知识库
DIFY_API_KEY=dataset-m6r1gc2q4BKVKPKR0xy1KVPS
DIFY_KNOWLEDGE_BASE_ID=781c5e51-c317-4861-823e-143f13ab69ce
DIFY_API_BASE_URL=http://119.91.201.9/v1

# 可选配置
KB_STRATEGY=primary
REQUEST_TIMEOUT=30
RETRY_ATTEMPTS=3
```

### 步骤 3: 测试配置

```bash
python test_config.py
```

**预期输出：**
```
✅ 配置验证成功！
📊 配置信息：
  • API 地址: http://119.91.201.9/v1
  • 知识库数量: 1
  • 知识库 ID: 781c5e51-c317-4861-823e-143f13ab69ce
🎯 配置正确，可以开始使用！
```

### 步骤 4: 运行同步

```bash
python tke_dify_sync.py
```

## 🔄 多知识库使用

系统已配置两个知识库：

### 知识库 1: tke_docs_base
```bash
# 使用 tke_docs_base 知识库
cp .env.tke_docs_base .env
python tke_dify_sync.py
```

### 知识库 2: tke_knowledge_base
```bash
# 使用 tke_knowledge_base 知识库
cp .env.tke_knowledge_base .env
python tke_dify_sync.py
```

### 批量同步（推荐）
```bash
# 同时同步到两个知识库
./scripts/sync_all_kb.sh
```

## 📊 运行结果

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