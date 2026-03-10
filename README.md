# OpenClaw AI Ops Agent

AI-powered operations agent for securely executing host-side automation through containerized LLM agents.

OpenClaw AI Ops Agent 是一个基于 LLM 的 AI 运维代理框架，允许 AI Agent 在受控权限下安全地执行宿主机运维任务。

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

### 架构说明

1. **LLM Agent**：负责根据自然语言指令生成并执行运维命令。
2. **vm-run wrapper**：容器内运行的工具，负责通过 SSH 执行宿主机上的命令。
3. **SSH**：安全地通过 SSH 连接宿主机，确保数据传输和命令执行的安全性。
4. **sudo restricted commands**：运维命令的执行被限制在指定的命令集范围内，避免不必要的权限暴露。

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

- `docker-compose.yml`
    
- `.env`
    
- `AGENTS.md`
    
- `TOOLS.md`
    
- `vm-run`
    

### 4. 配置 sudo 权限

为 `claw` 用户配置 sudo 权限，确保其能够执行受限命令（如 `systemctl`、`docker` 和 `journalctl`）。

### 5. 启动容器

在目标服务器上执行以下命令以启动 Docker 容器：

```bash
docker compose up -d (or docker-compose up -d)
```

### 6. 验证部署

在容器内运行 `verify-deploy.sh` 脚本以验证部署是否成功。

它验证的是“容器 → vm-run → SSH → sudo → 宿主机 ”整条链路：

```bash
scripts/verify-deploy.sh
```

## 文件结构

```bash
openclaw-aiops/

README.md
.env.example
docker-compose.yml
.gitignore
openclaw.json.example

workspace/
 ├── AGENTS.md
 ├── TOOLS.md
 └── vm-run

tools/
 └── weather/
     ├── adapter/
     ├── scripts/
     ├── docs/
     └── README.md

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

## 环境变量

### `.env.example`

```bash
# OPENCLAW_CONFIG_DIR=/home/character/.openclaw
# OPENCLAW_WORKSPACE_DIR=/home/character/.openclaw/workspace
# OPENCLAW_GATEWAY_PORT=18789
# OPENCLAW_BRIDGE_PORT=18790
# OPENCLAW_GATEWAY_BIND=lan
# OPENCLAW_GATEWAY_TOKEN=your-new-token-here
# OPENCLAW_IMAGE=openclaw:local
# OPENCLAW_EXTRA_MOUNTS=
# OPENCLAW_HOME_VOLUME=
# OPENCLAW_DOCKER_APT_PACKAGES=
# OPENCLAW_SANDBOX=
# OPENCLAW_DOCKER_SOCKET=/var/run/docker.sock
# DOCKER_GID=
# OPENCLAW_INSTALL_DOCKER_CLI=
# OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=
```

请将 `.env.example` 文件中的配置复制到一个新的 `.env` 文件，并替换相应的值。

## 脚本说明

### 1. `prepare-ubuntu-for-openclaw.sh`

用于 **新 Ubuntu 系统初始化**，安装所需的依赖项并配置环境。具体功能包括：

- 配置 apt 镜像源
    
- 安装 Docker 和 Docker Compose
    
- 安装常用的系统工具
    
- 启用并配置 Docker
    

### 2. `init-host.sh`

该脚本用于 **初始化宿主机环境**，包括：

- 创建 `claw` 用户并配置 SSH 密钥
    
- 配置 `sudo` 权限，允许执行特定命令
    
- 配置宿主机的网络和端口绑定
    

### 3. `verify-deploy.sh`

该脚本用于 **验证部署是否成功**，它会检查容器状态、宿主机服务以及命令是否可以正确执行。具体检查内容包括：

- 检查 SSH 是否可以正常连接
    
- 检查 `docker` 是否可以正常运行
    
- 检查 `systemctl` 是否可以执行服务管理命令

## 扩展模块（Extension Modules）

OpenClaw-AIOps 支持通过模块化工具扩展系统能力。

扩展模块统一放在 `tools/` 目录下，通过宿主机桥接机制调用，使 Agent 在保持容器隔离的同时，仍然能够安全地使用宿主机工具与外部服务，从而实现更多实际的 AIOps 场景。

每个模块可以为 Agent 提供新的操作能力，例如系统查询、运维工具或外部服务调用。

目前已实现的模块包括：

- **weather**：提供结构化天气查询能力（实时天气、天气预报、生活指数等）

该扩展体系设计为可持续扩展，未来可以加入更多模块，例如：

- 监控与指标查询
- 日志分析工具
- 系统诊断工具
- 基础设施自动化
- 外部服务集成

每个模块都在其独立目录中提供脚本、适配器和相关文档。

## 贡献

欢迎提交 issues 或 pull requests，帮助改进 OpenClaw AI Ops Agent。如果你有任何问题或建议，请在 [GitHub Issues](https://github.com/N40134318/openclaw-aiops/issues) 提出。

## 许可证

此项目遵循 [MIT License](LICENSE)。


---
