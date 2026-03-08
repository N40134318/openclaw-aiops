# OpenClaw AI Ops Agent 架构

## 总体架构

OpenClaw AI Ops Agent 基于以下架构：

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

**核心思想**：

1. **LLM Agent**：负责根据自然语言指令生成并执行运维命令。
2. **vm-run wrapper**：容器内运行的工具，负责通过 SSH 执行宿主机上的命令。
3. **SSH**：安全地通过 SSH 连接宿主机，确保数据传输和命令执行的安全性。
4. **sudo restricted commands**：运维命令的执行被限制在指定的命令集范围内，避免不必要的权限暴露。

## 安全模型

1. **最小权限设计**：AI 代理通过 `claw` 用户执行运维任务，`claw` 用户只具有运行必要命令的权限。
2. **基于 SSH 密钥的认证**：通过 SSH 密钥而非密码进行身份验证，确保通信的安全性。
3. **受限的 sudo 权限**：`claw` 用户仅能执行通过 sudo 配置的受限命令，如 `systemctl`、`docker` 和 `journalctl`，其余命令均不允许执行。

## 工作流程

1. 用户通过 LLM Agent 提供自然语言运维请求。
2. Agent 根据规则和工具配置生成相应的运维命令。
3. 使用 `vm-run` wrapper 执行命令，命令通过 SSH 发送至宿主机。
4. 宿主机通过 `claw` 用户执行命令，并通过 sudo 限制执行特定的命令。
5. 操作完成后返回结果，若是容器操作，还可能通过 `docker` 或 `systemctl` 进行服务管理。

---
