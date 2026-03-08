# OpenClaw AI Ops Agent 部署指南

## 环境准备

1. **安装 Docker**：
    - 请确保新服务器上安装了 Docker 和 Docker Compose。

2. **配置 SSH**：
    - 配置 `claw` 用户，生成并上传 SSH 密钥。
    - 禁用 SSH 密码登录，只允许通过 SSH 密钥进行身份验证。

## 部署步骤

1. **上传配置文件**：
    - 将 `docker-compose.yml`、`.env`、`vm-run`、`AGENTS.md`、`TOOLS.md` 文件上传到新机器。

2. **设置权限**：
    - 确保 `claw` 用户有足够的权限执行 `sudo systemctl`、`sudo docker` 和 `sudo journalctl`。

3. **启动容器**：
    - 通过以下命令启动容器：
    ```bash
    docker-compose up -d
    ```

4. **检查服务**：
    - 使用 `docker ps` 检查容器状态。
    - 使用 `systemctl status <service>` 检查宿主机服务状态。

5. **验证运行**：
    - 运行 `verify-deploy.sh` 脚本，确认系统部署成功。

---
