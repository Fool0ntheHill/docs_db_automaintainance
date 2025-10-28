# TKE 文档同步系统 - 部署验证检查清单

## 📋 基于 cron 的部署验证清单

使用此清单确保 TKE 文档同步系统正确部署并配置为使用 cron 调度（而非 systemd 守护进程）。

### ✅ 系统环境检查

- [ ] **操作系统兼容性**
  - [ ] Ubuntu 18.04+ 或 CentOS 7+
  - [ ] 具有 sudo 权限的用户账户
  - [ ] 网络连接正常

- [ ] **系统依赖**
  - [ ] Python 3.8+ 已安装
  - [ ] pip 包管理器可用
  - [ ] cron 服务正在运行: `systemctl status cron`
  - [ ] curl 工具可用
  - [ ] 足够的磁盘空间 (至少 2GB)

### ✅ 项目文件结构检查

- [ ] **核心文件**
  - [ ] `tke_dify_sync.py` - 主同步脚本
  - [ ] `.env` - 主配置文件
  - [ ] `requirements.txt` - Python 依赖列表
  - [ ] `DEPLOYMENT_GUIDE.md` - 部署指南

- [ ] **目录结构**
  - [ ] `venv/` - Python 虚拟环境
  - [ ] `logs/` - 日志文件目录
  - [ ] `data/` - 数据文件目录
  - [ ] `scripts/` - 辅助脚本目录

- [ ] **关键脚本**
  - [ ] `scripts/start.sh` - 启动脚本
  - [ ] `scripts/monitor.sh` - 监控脚本
  - [ ] `scripts/health_check.sh` - 健康检查脚本
  - [ ] `scripts/validate_cron_setup.sh` - cron 配置验证

### ✅ Python 环境检查

- [ ] **虚拟环境**
  - [ ] 虚拟环境已创建: `ls -la venv/`
  - [ ] 虚拟环境可激活: `source venv/bin/activate`
  - [ ] Python 版本正确: `python --version`

- [ ] **依赖包**
  - [ ] requests 已安装
  - [ ] beautifulsoup4 已安装
  - [ ] selenium 已安装
  - [ ] python-dotenv 已安装
  - [ ] 验证命令: `pip list | grep -E "(requests|beautifulsoup4|selenium|python-dotenv)"`

### ✅ 配置文件检查

- [ ] **主配置文件 (.env)**
  - [ ] 文件存在且可读
  - [ ] `DIFY_API_KEY` 已设置
  - [ ] `DIFY_KNOWLEDGE_BASE_ID` 已设置
  - [ ] `DIFY_API_BASE_URL` 已设置
  - [ ] 文件权限安全 (600): `ls -la .env`

- [ ] **多知识库配置（如适用）**
  - [ ] `.env.*` 配置文件存在
  - [ ] 每个配置文件都包含必需变量
  - [ ] 知识库 ID 在各配置间唯一
  - [ ] 状态文件路径不冲突

### ✅ cron 作业配置检查

- [ ] **cron 服务状态**
  - [ ] cron 服务正在运行: `systemctl is-active cron`
  - [ ] cron 服务已启用: `systemctl is-enabled cron`

- [ ] **cron 作业配置**
  - [ ] TKE 相关 cron 作业已配置: `crontab -l | grep tke`
  - [ ] cron 作业语法正确
  - [ ] 日志输出重定向配置: `>> logs/*.log 2>&1`
  - [ ] 多知识库作业时间不冲突

- [ ] **cron 作业验证**
  - [ ] 可以创建测试 cron 作业
  - [ ] cron 环境变量正确
  - [ ] 脚本路径使用绝对路径

### ✅ systemd 服务清理检查

⚠️ **重要**: 确保没有遗留的 systemd 服务配置

- [ ] **systemd 服务文件**
  - [ ] `/etc/systemd/system/tke-dify-sync.service` 不存在
  - [ ] 如果存在，服务已停止: `systemctl is-active tke-dify-sync`
  - [ ] 如果存在，服务已禁用: `systemctl is-enabled tke-dify-sync`

- [ ] **清理验证**
  - [ ] 运行迁移验证: `./scripts/validate_migration.sh`
  - [ ] 无 systemd 相关进程运行

### ✅ 日志系统检查

- [ ] **日志目录**
  - [ ] `logs/` 目录存在且可写
  - [ ] 日志文件权限正确
  - [ ] 足够的磁盘空间用于日志

- [ ] **日志轮转**
  - [ ] logrotate 配置已安装（可选）
  - [ ] 日志清理 cron 作业已配置
  - [ ] 旧日志文件自动清理

### ✅ 网络连接检查

- [ ] **外部连接**
  - [ ] 可以访问腾讯云文档: `curl -I https://cloud.tencent.com`
  - [ ] 可以访问 Dify API: `curl -I $DIFY_API_BASE_URL`

- [ ] **API 认证**
  - [ ] Dify API 密钥有效
  - [ ] 知识库 ID 存在且可访问
  - [ ] API 权限配置正确

### ✅ 功能测试检查

- [ ] **脚本语法**
  - [ ] 主脚本语法正确: `python -m py_compile tke_dify_sync.py`
  - [ ] 辅助脚本可执行

- [ ] **手动执行测试**
  - [ ] 可以手动运行同步: `./scripts/start.sh`
  - [ ] 健康检查通过: `./scripts/health_check.sh`
  - [ ] 监控脚本正常: `./scripts/monitor.sh`

- [ ] **配置验证**
  - [ ] cron 配置验证通过: `./scripts/validate_cron_setup.sh`
  - [ ] 多知识库调度测试通过: `./scripts/test_multi_kb_scheduling.sh`

### ✅ 安全检查

- [ ] **文件权限**
  - [ ] 配置文件权限安全 (600)
  - [ ] 脚本文件可执行 (755)
  - [ ] 日志文件权限合理 (644)

- [ ] **敏感信息**
  - [ ] API 密钥不在代码中硬编码
  - [ ] 配置文件不包含明文密码
  - [ ] 日志文件不泄露敏感信息

### ✅ 监控和维护检查

- [ ] **监控设置**
  - [ ] 健康检查脚本定期运行
  - [ ] 日志监控配置
  - [ ] 错误告警机制（可选）

- [ ] **维护计划**
  - [ ] 日志清理策略
  - [ ] 配置备份计划
  - [ ] 更新升级流程

## 🧪 自动化验证

运行以下命令进行自动化验证：

```bash
# 快速验证
./scripts/run_all_tests.sh -f

# 完整验证
./scripts/run_all_tests.sh

# 特定验证
./scripts/test_cron_deployment.sh
./scripts/test_multi_kb_scheduling.sh
./scripts/test_log_rotation.sh
./scripts/validate_migration.sh
```

## 🚨 常见问题检查

### cron 作业不执行
- [ ] cron 服务运行状态
- [ ] cron 作业语法正确性
- [ ] 脚本路径绝对路径
- [ ] 文件执行权限
- [ ] 环境变量设置

### 配置文件问题
- [ ] 文件存在性和权限
- [ ] 必需变量完整性
- [ ] API 密钥有效性
- [ ] 知识库 ID 正确性

### 网络连接问题
- [ ] 防火墙设置
- [ ] DNS 解析
- [ ] 代理配置
- [ ] SSL 证书验证

### 日志问题
- [ ] 日志目录权限
- [ ] 磁盘空间充足
- [ ] 日志轮转配置
- [ ] 输出重定向正确

## 📞 获取帮助

如果检查清单中的任何项目失败：

1. **查看详细文档**: `DEPLOYMENT_GUIDE.md`
2. **运行诊断工具**: `./scripts/analyze_deployment.sh`
3. **查看错误日志**: `tail -f logs/*.log`
4. **运行故障排除**: 参考 `DEPLOYMENT_GUIDE.md` 中的故障排除部分

## ✅ 部署完成确认

当所有检查项目都通过时：

- [ ] 所有必需项目已验证 ✅
- [ ] 自动化测试全部通过 ✅
- [ ] 系统可以正常运行 ✅
- [ ] 监控和日志正常 ✅

**🎉 恭喜！TKE 文档同步系统已成功部署并配置为使用 cron 调度方式。**

---

*最后更新: $(date)*
*版本: 基于 cron 调度的部署验证清单 v1.0*