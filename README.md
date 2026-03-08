# OpenClaw AI Ops Agent

**OpenClaw AI Ops Agent** 是一个基于 AI 的运维自动化工具，允许通过 LLM（大语言模型）自动执行宿主机上的运维操作。该系统设计了最小权限的安全模型，使用 **vm-run** 工具执行容器与宿主机之间的命令。

## 项目特点

- **AI 运维代理**：通过 LLM 生成并执行运维命令。
- **最小权限模型**：所有命令通过受限的 `claw` 用户执行，仅允许必要的系统命令。
- **跨容器与宿主机自动执行**：通过 `vm-run` 工具在宿主机上执行运维操作。
- **安全性高**：通过 SSH 密钥认证，避免使用密码。
- **自动化部署**：可通过 Docker 容器进行部署和管理，支持多机器迁移。

## 系统架构

OpenClaw AI Ops Agent 基于以下架构设计：

```

LLM Agent
↓
Agent Rules (AGENTS.md / TOOLS.md)
↓
Tool Execution
↓
vm-run wrapper (container)
↓
SSH
↓
claw user (host)
↓
sudo restricted commands
↓
host services

````

## 安全模型

1. **最小权限设计**：AI 代理通过 `claw` 用户执行运维任务，`claw` 用户只具有运行必要命令的权限。
2. **基于 SSH 密钥的认证**：通过 SSH 密钥而非密码进行身份验证，确保通信的安全性。
3. **受限的 sudo 权限**：`claw` 用户仅能执行通过 sudo 配置的受限命令，如 `systemctl`、`docker` 和 `journalctl`，其余命令均不允许执行。

## 部署步骤

### 1. 安装 Docker

确保目标服务器已安装 Docker 和 Docker Compose。可以使用以下命令进行安装：

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
````

### 2. 配置 SSH

1. 创建 `claw` 用户并为其设置 SSH 密钥认证。
2. 禁用 SSH 密码登录，仅允许通过 SSH 密钥进行认证。

### 3. 上传配置文件

将以下文件上传到目标服务器：

* `docker-compose.yml`
* `.env`
* `AGENTS.md`
* `TOOLS.md`
* `vm-run`

### 4. 配置 sudo 权限

为 `claw` 用户配置 sudo 权限，确保其能够执行受限命令（如 `systemctl`、`docker` 和 `journalctl`）。

### 5. 启动容器

在目标服务器上执行以下命令以启动 Docker 容器：

```bash
docker-compose up -d
```

### 6. 验证部署

运行 `verify-deploy.sh` 脚本以验证部署是否成功。

```bash
scripts/verify-deploy.sh
```

## 文件结构

```
openclaw-aiops/

README.md
.env.example
docker-compose.yml
.gitignore

workspace/
 ├── AGENTS.md
 ├── TOOLS.md
 └── vm-run

scripts/
 ├── prepare-ubuntu-for-openclaw.sh
 ├── init-host.sh
 └── verify-deploy.sh

ssh/
 ├── id_ed25519.example
 ├── id_ed25519.pub.example
 └── known_hosts.example

docs/
 ├── ARCHITECTURE.md
 ├── SECURITY.md
 ├── MIGRATION.md
 └── DEPLOYMENT.md
```

## 贡献

欢迎提交 issues 或 pull requests，帮助改进 OpenClaw AI Ops Agent。如果你有任何问题或建议，请在 [GitHub Issues](https://github.com/你的用户名/openclaw-aiops/issues) 提出。

## 许可证

此项目遵循 [MIT 许可证](LICENSE)。

```

### 说明：

- **项目简介**：介绍了 OpenClaw 的运维自动化特点和使用 LLM 生成运维命令。
- **系统架构**：描述了项目的架构，并给出了执行流程。
- **部署步骤**：详细列出了如何将该系统部署到目标服务器的步骤。
- **文件结构**：列出了项目的基本文件结构。
- **贡献指南**：鼓励开源贡献。
- **许可证**：遵循 MIT 开源协议。

```

