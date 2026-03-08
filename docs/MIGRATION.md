# OpenClaw AI Ops Agent 迁移指南

## 迁移步骤

1. **备份当前环境**：
    - 确保 `docker-compose.yml`、`.env`、`vm-run`、`AGENTS.md` 和 `TOOLS.md` 文件都已经备份。
    - 宿主机配置文件（如 `sudoers`）也需要备份。

2. **准备新机器**：
    - 确保新机器已安装 Docker，并启用 SSH 服务。
    - 配置 `claw` 用户，添加到 `docker` 组，并为其配置 SSH 密钥认证。

3. **部署到新机器**：
    - 将备份的文件上传到新机器的指定位置。
    - 确保新机器能够访问容器，并且 `vm-run` 能正确执行命令。

4. **更新配置**：
    - 在新机器上更新 `.env` 和相关配置文件，确保与旧环境一致。

5. **启动容器**：
    - 在新机器上执行 `docker-compose up -d` 启动容器。

6. **验证部署**：
    - 执行 `verify-deploy.sh` 脚本，确保新环境能够正常运行。

---
