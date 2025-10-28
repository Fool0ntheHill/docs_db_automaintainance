# 📚 文档使用指南

## 🎯 用户旅程

根据您的使用场景，选择合适的文档：

### 🚀 场景一：本地开发/测试
**用户旅程**: 快速上手 → 本地运行 → 功能测试

1. **[README.md](README.md)** - 项目概览和核心特性
2. **[QUICK_START.md](QUICK_START.md)** - 本地开发详细步骤
3. **[USER_GUIDE.md](USER_GUIDE.md)** - 详细功能说明和配置

### 🏢 场景二：生产环境部署
**用户旅程**: 环境准备 → 系统部署 → 服务配置 → 监控维护

1. **[README.md](README.md)** - 了解项目功能
2. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - 完整的生产环境部署指南
3. **[USER_GUIDE.md](USER_GUIDE.md)** - 高级配置和故障排除
4. **[GIT_SETUP.md](GIT_SETUP.md)** - 代码管理和版本控制

### 🔧 场景三：开发维护
**用户旅程**: 代码管理 → 功能开发 → 测试部署 → 版本发布

1. **[GIT_SETUP.md](GIT_SETUP.md)** - Git 工作流和版本管理
2. **[USER_GUIDE.md](USER_GUIDE.md)** - 系统架构和配置详解
3. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - 部署和运维指南

## 📖 文档详细说明

### 核心文档

| 文档 | 用途 | 目标用户 | 阅读时间 |
|------|------|----------|----------|
| **README.md** | 项目入口，快速了解和上手 | 所有用户 | 3分钟 |
| **QUICK_START.md** | 本地开发快速指南 | 开发者、测试人员 | 5分钟 |
| **DEPLOYMENT_GUIDE.md** | 生产环境完整部署指南 | 运维人员、系统管理员 | 30分钟 |
| **USER_GUIDE.md** | 详细使用说明和高级配置 | 高级用户、管理员 | 15分钟 |

### 专业文档

| 文档 | 用途 | 目标用户 | 阅读时间 |
|------|------|----------|----------|
| **GIT_SETUP.md** | Git 管理和开发工作流 | 开发者、维护人员 | 20分钟 |
| **DOCS_GUIDE.md** | 本文档，文档使用指南 | 所有用户 | 5分钟 |

### 🆕 v2.0 新增文档

| 文档 | 用途 | 目标用户 | 阅读时间 |
|------|------|----------|----------|
| **DEPLOYMENT_CHECKLIST.md** | 部署验证清单 | 运维人员、系统管理员 | 10分钟 |
| **MIGRATION_SUMMARY.md** | systemd 到 cron 迁移总结 | 升级用户、管理员 | 15分钟 |
| **CHANGELOG.md** | 版本更新日志 | 所有用户 | 5分钟 |

### 配置文件模板

| 文件 | 用途 | 说明 |
|------|------|------|
| `.env.production.example` | tke_docs_base 知识库配置模板 | 复制为 `.env` 使用 |
| `.env.testing.example` | tke_knowledge_base 知识库配置模板 | 复制为 `.env` 使用 |

### 管理脚本

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `scripts/start.sh` | 启动系统 | 手动启动服务 |
| `scripts/stop.sh` | 停止系统 | 手动停止服务 |
| `scripts/status.sh` | 查看状态 | 检查系统运行状态 |
| `scripts/monitor.sh` | 系统监控 | 定时任务监控 |
| `scripts/sync_all_kb.sh` | 多知识库同步 | 批量同步多个知识库 |

## 🗂️ 文档层次结构

```
📚 文档体系
├── 🚀 入门级 (README.md)
│   ├── 项目概览
│   ├── 核心特性
│   └── 5分钟快速开始
│
├── 📖 基础级 (QUICK_START.md)
│   ├── 本地开发环境
│   ├── 基础配置
│   └── 功能测试
│
├── 🔧 进阶级 (USER_GUIDE.md)
│   ├── 详细配置说明
│   ├── 多知识库管理
│   ├── 高级功能
│   └── 故障排除
│
├── 🏢 专业级 (DEPLOYMENT_GUIDE.md)
│   ├── 生产环境部署
│   ├── 系统服务配置
│   ├── 监控和维护
│   └── 安全配置
│
└── 🛠️ 开发级 (GIT_SETUP.md)
    ├── 代码管理
    ├── 开发工作流
    ├── 版本控制
    └── 协作开发
```

## 💡 使用建议

### 首次使用
1. 先读 **README.md** 了解项目
2. 根据场景选择 **QUICK_START.md** 或 **DEPLOYMENT_GUIDE.md**
3. 遇到问题时查看 **USER_GUIDE.md**

### 日常使用
- 配置问题 → **USER_GUIDE.md**
- 部署问题 → **DEPLOYMENT_GUIDE.md**
- 代码管理 → **GIT_SETUP.md**

### 团队协作
- 新成员入门 → **README.md** + **QUICK_START.md**
- 运维部署 → **DEPLOYMENT_GUIDE.md**
- 开发维护 → **GIT_SETUP.md** + **USER_GUIDE.md**

## 🔄 文档更新

文档会随着系统功能更新而更新，建议：
- 定期查看 **README.md** 了解新功能
- 部署前检查 **DEPLOYMENT_GUIDE.md** 的更新
- 遇到问题时查看最新的 **USER_GUIDE.md**

---

**需要帮助？** 
- 🐛 问题反馈：创建 GitHub Issue
- 💬 使用交流：查看项目 Wiki
- 📧 联系维护者：通过 GitHub