# TKE 文档同步系统 - 迁移工具使用指南

本目录包含了完整的迁移工具集，帮助您安全地从 systemd 服务模式迁移到 cron 调度模式。

## 🛠️ 工具概览

### 1. 主迁移工具 - `migrate_to_cron.sh`
**功能**: 自动将系统从 systemd 服务迁移到 cron 调度
**特点**: 
- 自动检测当前部署状态
- 安全备份现有配置
- 智能处理多知识库配置
- 完整的验证和报告

**使用方法**:
```bash
# 标准迁移（推荐）
./scripts/migrate_to_cron.sh

# 仅检查当前状态
./scripts/migrate_to_cron.sh --check-only

# 模拟运行（查看将要执行的操作）
./scripts/migrate_to_cron.sh --dry-run

# 强制迁移（跳过确认）
./scripts/migrate_to_cron.sh --force

# 仅创建备份
./scripts/migrate_to_cron.sh --backup-only
```

### 2. 配置转换器 - `config_converter.sh`
**功能**: 将单知识库配置转换为多知识库配置
**特点**:
- 支持多种预定义模板
- 智能分析现有配置
- 保留原有设置

**使用方法**:
```bash
# 转换现有配置文件
./scripts/config_converter.sh .env

# 使用企业级模板
./scripts/config_converter.sh --template enterprise

# 使用简单双知识库模板
./scripts/config_converter.sh --template simple

# 使用多环境模板
./scripts/config_converter.sh --template multi-env

# 模拟运行
./scripts/config_converter.sh --dry-run --template simple

# 备份现有配置
./scripts/config_converter.sh --backup .env
```

**支持的模板类型**:
- `enterprise`: 企业级三层架构（生产/开发/API参考）
- `multi-env`: 多环境部署（生产/测试/开发）
- `simple`: 简单双知识库（基础文档/扩展知识库）

### 3. 迁移验证工具 - `validate_migration.sh`
**功能**: 验证迁移是否成功完成
**特点**:
- 全面的系统检查
- 自动问题修复
- 详细的验证报告

**使用方法**:
```bash
# 标准验证
./scripts/validate_migration.sh

# 详细输出模式
./scripts/validate_migration.sh --verbose

# 自动修复发现的问题
./scripts/validate_migration.sh --fix-issues

# 静默模式（仅显示错误）
./scripts/validate_migration.sh --quiet

# 仅生成报告
./scripts/validate_migration.sh --report-only
```

### 4. 回滚工具 - `rollback_migration.sh`
**功能**: 将系统从 cron 调度回滚到 systemd 服务
**特点**:
- 安全的回滚过程
- 自动备份查找
- 完整的状态恢复

**使用方法**:
```bash
# 交互式回滚
./scripts/rollback_migration.sh

# 使用指定备份
./scripts/rollback_migration.sh migration_backup_20231201_120000

# 自动使用最新备份
./scripts/rollback_migration.sh --auto-find

# 列出可用备份
./scripts/rollback_migration.sh --list-backups

# 模拟回滚
./scripts/rollback_migration.sh --dry-run --auto-find

# 强制回滚（跳过确认）
./scripts/rollback_migration.sh --force
```

## 🚀 完整迁移流程

### 步骤 1: 准备阶段
```bash
# 1. 检查当前状态
./scripts/migrate_to_cron.sh --check-only

# 2. 创建配置备份（可选）
./scripts/config_converter.sh --backup .env

# 3. 准备多知识库配置（如需要）
./scripts/config_converter.sh --template simple
```

### 步骤 2: 执行迁移
```bash
# 1. 模拟迁移（推荐先执行）
./scripts/migrate_to_cron.sh --dry-run

# 2. 执行实际迁移
./scripts/migrate_to_cron.sh

# 3. 验证迁移结果
./scripts/validate_migration.sh
```

### 步骤 3: 验证和测试
```bash
# 1. 详细验证
./scripts/validate_migration.sh --verbose

# 2. 自动修复问题（如有）
./scripts/validate_migration.sh --fix-issues

# 3. 手动测试同步
cd /opt/tke-dify-sync && ./scripts/start.sh

# 4. 查看日志
tail -f logs/cron.log
```

## 🔧 故障排除

### 常见问题及解决方案

#### 1. 迁移工具报告 systemd 服务仍在运行
```bash
# 立即停止服务
sudo systemctl stop tke-dify-sync

# 重新运行迁移
./scripts/migrate_to_cron.sh
```

#### 2. cron 作业未正确配置
```bash
# 检查 cron 服务状态
sudo systemctl status cron

# 手动验证 crontab
crontab -l

# 使用验证工具自动修复
./scripts/validate_migration.sh --fix-issues
```

#### 3. 配置文件问题
```bash
# 检查配置文件完整性
./scripts/validate_migration.sh --verbose

# 重新生成配置
./scripts/config_converter.sh --template simple
```

#### 4. 需要回滚到原始状态
```bash
# 列出可用备份
./scripts/rollback_migration.sh --list-backups

# 执行回滚
./scripts/rollback_migration.sh --auto-find
```

### 紧急情况处理

#### 系统同时运行 systemd 和 cron
```bash
# 1. 立即停止 systemd 服务
sudo systemctl stop tke-dify-sync
sudo systemctl disable tke-dify-sync

# 2. 检查 cron 作业
crontab -l | grep tke_dify_sync

# 3. 运行完整验证
./scripts/validate_migration.sh --fix-issues
```

#### 迁移过程中断
```bash
# 1. 检查备份目录
ls -la migration_backup_*

# 2. 使用最新备份回滚
./scripts/rollback_migration.sh --auto-find

# 3. 重新开始迁移
./scripts/migrate_to_cron.sh
```

## 📊 日志和报告

### 日志文件位置
- 迁移日志: `logs/migration.log`
- 验证日志: `logs/validation.log`
- 回滚日志: `logs/rollback.log`
- 配置转换日志: `logs/config_conversion.log`

### 报告文件
- 迁移报告: `logs/migration_report_YYYYMMDD_HHMMSS.md`
- 验证报告: `logs/validation_report_YYYYMMDD_HHMMSS.md`
- 回滚报告: `logs/rollback_report_YYYYMMDD_HHMMSS.md`

### 备份目录结构
```
migration_backup_YYYYMMDD_HHMMSS/
├── backup_report.md              # 备份报告
├── tke-dify-sync.service         # systemd 服务文件
├── current_crontab.txt           # 当前 crontab
├── service_status.txt            # 服务状态
├── service_enabled.txt           # 服务启用状态
├── service_active.txt            # 服务运行状态
├── .env*                         # 配置文件
├── logs/                         # 日志文件
└── data/                         # 状态文件
```

## ⚠️ 重要注意事项

1. **备份重要性**: 所有工具都会自动创建备份，请妥善保存备份目录
2. **权限要求**: 某些操作需要 sudo 权限（systemd 服务管理）
3. **服务冲突**: 避免同时运行 systemd 服务和 cron 作业
4. **测试建议**: 在生产环境使用前，建议在测试环境先行验证
5. **日志监控**: 迁移后请持续监控日志文件确保正常运行

## 🆘 获取帮助

每个工具都支持 `--help` 参数查看详细使用说明：

```bash
./scripts/migrate_to_cron.sh --help
./scripts/config_converter.sh --help
./scripts/validate_migration.sh --help
./scripts/rollback_migration.sh --help
```

如遇到问题，请查看相应的日志文件和报告文件获取详细信息。