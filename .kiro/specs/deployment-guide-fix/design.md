# 设计文档

## 概述

本设计通过建立基于 cron 调度的清晰、单一部署方法来解决当前 DEPLOYMENT_GUIDE.md 中的关键逻辑矛盾。当前指南错误地混合了 systemd 守护进程模式（带有 Restart=always）和 cron 调度，这会导致同步脚本持续运行在无限重启循环中，而不是按计划间隔执行一次。

该设计将重构部署指南，仅使用基于 cron 的调度，删除所有 systemd 服务配置，并更新所有相关脚本和监控方法以与基于 cron 的执行模型保持一致。

## 架构

### 当前有问题的架构
```
用户遵循指南 → 创建带有 Restart=always 的 systemd 服务 → 脚本运行一次后退出 → systemd 立即重启它 → 无限循环
              ↘ 同时设置 cron 作业 → 与 systemd 服务冲突 → 不可预测的行为
```

### 修正后的架构
```
用户遵循指南 → 仅设置 cron 作业 → 脚本在计划时间运行 → 脚本完成后退出 → 等待下次计划时间
              ↘ 使用与 cron 兼容的监控 → 一致的行为 → 适当的日志记录
```

### 关键架构决策

1. **单一执行模型**：仅使用基于 cron 的调度，消除 systemd 服务方法
2. **运行一次模式**：保持脚本运行一次后退出的预期行为
3. **Cron 兼容监控**：用 cron 兼容的替代方案替换基于 systemd 的监控
4. **一致的日志记录**：确保所有日志记录方法都适用于 cron 执行
5. **多知识库支持**：通过单独的 cron 作业维护对多个知识库的支持

## 组件和接口

### 1. 部署指南结构

**修改的部分：**
- **环境设置**：保留现有的依赖安装和环境准备
- **配置**：维护所有 Dify API 和多知识库配置部分
- **部署方法**：用仅 cron 的方法替换 systemd 服务部分
- **监控**：用 cron 兼容的监控替换 systemd 监控
- **故障排除**：更新以专注于基于 cron 的执行问题

**删除的部分：**
- 系统服务配置（整个部分）
- 基于 systemd 的监控脚本
- 使用说明中的 systemctl 命令

### 2. 脚本修改

**需要修改的文件：**
- `deploy.sh`：删除 `create_systemd_service()` 函数和相关的 systemctl 调用
- `scripts/monitor.sh`：删除 systemd 服务检查，专注于基于进程的监控
- `scripts/status.sh`：删除 systemctl 状态检查
- `DEPLOYMENT_GUIDE.md`：完全重构以删除 systemd 引用

**保持不变的文件：**
- `tke_dify_sync.py`：主同步脚本（已设计为运行一次执行）
- `scripts/start.sh`：手动执行脚本（对测试有用）
- `scripts/stop.sh`：进程终止脚本（对紧急停止有用）

### 3. Cron 配置接口

**单知识库：**
```bash
# 每天凌晨2点同步
0 2 * * * cd /opt/tke-dify-sync && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron.log 2>&1
```

**多知识库：**
```bash
# tke_docs_base 凌晨2点
0 2 * * * cd /opt/tke-dify-sync && cp .env.tke_docs_base .env && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron_tke_docs_base.log 2>&1

# tke_knowledge_base 凌晨3点
0 3 * * * cd /opt/tke-dify-sync && cp .env.tke_knowledge_base .env && /opt/tke-dify-sync/venv/bin/python tke_dify_sync.py >> /opt/tke-dify-sync/logs/cron_tke_knowledge_base.log 2>&1
```

### 4. 监控接口

**Cron 兼容监控：**
- 基于进程的健康检查而不是 systemd 服务检查
- 执行状态的日志文件监控
- 磁盘空间和资源监控
- 网络连接检查
- Cron 作业执行验证

## 数据模型

### 配置文件结构
```
/opt/tke-dify-sync/
├── .env                          # 主配置
├── .env.tke_docs_base           # 知识库特定配置 1
├── .env.tke_knowledge_base      # 知识库特定配置 2
├── logs/
│   ├── cron.log                 # 单知识库 cron 输出
│   ├── cron_tke_docs_base.log   # 多知识库 cron 输出 1
│   ├── cron_tke_knowledge_base.log # 多知识库 cron 输出 2
│   ├── tke_sync.log             # 应用程序日志
│   └── monitor.log              # 监控日志
└── data/
    ├── crawl_state.json         # 单知识库状态
    ├── crawl_state_tke_docs_base.json    # 多知识库状态 1
    └── crawl_state_tke_knowledge_base.json # 多知识库状态 2
```

### Cron 作业数据模型
```bash
# 格式：分钟 小时 日 月 星期 命令
# 组件：
# - 时间：何时执行
# - 工作目录：cd /opt/tke-dify-sync
# - 环境设置：cp .env.specific .env（用于多知识库）
# - 执行：/opt/tke-dify-sync/venv/bin/python tke_dify_sync.py
# - 日志记录：>> logfile 2>&1
```

## 错误处理

### 1. Cron 执行错误

**错误类型：**
- 脚本执行失败
- 配置文件问题
- 网络连接问题
- Dify API 错误
- 文件权限问题

**处理策略：**
- 将所有输出（stdout 和 stderr）捕获到日志文件
- 为不同的知识库使用单独的日志文件
- 实施日志轮转以防止磁盘空间问题
- 为常见的 cron 问题提供清晰的故障排除步骤

### 2. 配置验证

**执行前检查：**
- 验证 .env 文件存在且可读
- 检查 Dify API 连接
- 验证知识库可访问性
- 确保所需目录存在

**错误恢复：**
- 带有详细错误消息的优雅失败
- 无自动重启（与 systemd 方法不同）
- 清晰的调试日志记录

### 3. 资源管理

**磁盘空间：**
- 监控日志文件大小
- 实施自动日志轮转
- 清理临时文件

**内存和 CPU：**
- 单次执行防止资源积累
- 完成后进程终止防止内存泄漏

## 测试策略

### 1. 部署指南测试

**测试场景：**
- 按照新指南进行全新安装
- 从基于 systemd 的部署升级
- 多知识库配置
- 不同操作系统（Ubuntu、CentOS、TencentOS）

**验证标准：**
- 未创建 systemd 服务
- Cron 作业配置正确
- 脚本执行成功
- 日志生成正确

### 2. Cron 执行测试

**测试用例：**
- 手动 cron 作业执行
- 计划执行验证
- 多知识库调度
- 错误条件处理
- 日志文件生成和轮转

### 3. 监控系统测试

**测试组件：**
- 基于进程的健康检查
- 日志文件监控
- 资源使用监控
- 网络连接检查
- 失败警报生成

### 4. 迁移测试

**场景：**
- 现有 systemd 服务删除
- Cron 作业迁移
- 配置文件更新
- 脚本修改

## 实施阶段

### 阶段 1：文档重构
1. 从 DEPLOYMENT_GUIDE.md 删除所有 systemd 服务部分
2. 添加为什么 cron 调度正确的清晰解释
3. 更新使用说明以专注于基于 cron 的执行
4. 修订故障排除部分以处理 cron 特定问题

### 阶段 2：脚本更新
1. 修改 `deploy.sh` 以删除 systemd 服务创建
2. 更新 `scripts/monitor.sh` 以删除 systemd 检查
3. 修改 `scripts/status.sh` 以专注于进程监控
4. 更新部署脚本中的 cron 作业设置

### 阶段 3：增强监控
1. 实施 cron 兼容的监控方法
2. 添加日志轮转配置
3. 为 cron 执行创建健康检查脚本
4. 更新监控文档

### 阶段 4：多知识库优化
1. 增强多知识库 cron 配置
2. 改进不同知识库的日志分离
3. 添加批量同步脚本
4. 优化调度以防止冲突

## 迁移策略

### 对于现有部署

**步骤 1：评估**
- 检查 systemd 服务是否当前正在运行
- 识别现有的 cron 作业
- 备份当前配置

**步骤 2：服务删除**
```bash
# 停止并禁用 systemd 服务
sudo systemctl stop tke-dify-sync
sudo systemctl disable tke-dify-sync
sudo rm /etc/systemd/system/tke-dify-sync.service
sudo systemctl daemon-reload
```

**步骤 3：Cron 设置**
- 根据需求配置适当的 cron 作业
- 测试手动执行
- 验证计划执行

**步骤 4：监控更新**
- 更新监控脚本
- 配置日志轮转
- 测试新的监控方法

## 安全考虑

### 文件权限
- 在 .env 文件上维护限制性权限（600）
- 确保 cron 作业以适当的用户权限运行
- 保护日志文件免受未授权访问

### 网络安全
- 维护现有的 HTTPS 配置
- 确保 API 密钥得到适当保护
- 使用安全的临时文件处理

## 性能考虑

### 资源使用
- 单次执行模型防止资源积累
- 每次运行后适当清理
- 高效调度以避免系统负载峰值

### 可扩展性
- 支持多个知识库
- 可配置的执行间隔
- 不同知识库的独立状态管理

## 维护和运营

### 日志管理
- 实施自动日志轮转
- 提供日志分析工具
- 清晰的日志文件命名约定

### 健康监控
- 基于进程的健康检查
- 执行成功/失败跟踪
- 资源使用监控
- 网络连接验证

### 备份和恢复
- 配置文件备份程序
- 状态文件备份策略
- 失败执行的恢复程序