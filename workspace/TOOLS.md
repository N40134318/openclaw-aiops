# TOOLS.md - Local Notes

## TTS Voice
- Preferred voice: "XiaoXu-TTS" (calm, mid-tone, 1.05x speed)

## What Goes Here
Things like:
- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames

[Add your first tool — e.g., "main-terminal: tmux + zsh, font: JetBrains Mono"]

---

## Host Control Wrapper (vm-run)

A wrapper script is provided for executing commands on the host machine:

/home/node/.openclaw/workspace/vm-run

The wrapper internally performs SSH execution using a safe configuration.

Agents should **prefer this wrapper instead of calling ssh directly**.

### Basic usage

sh /home/node/.openclaw/workspace/vm-run <subcommand>

### Available subcommands

System inspection:

- sys
- uptime
- mem
- disk

Docker management:

- docker
- docker-logs <container> [lines]

Service management:

- service <name>
- restart <name>
- journal <name> [lines]

### Raw command execution

If a command is not available as a predefined subcommand:

sh /home/node/.openclaw/workspace/vm-run exec "<command>"

Example:

sh /home/node/.openclaw/workspace/vm-run exec "docker ps -a"

### Notes

The wrapper provides:

- Non-interactive SSH
- Timeout protection
- Reliable stdout/stderr capture
- Consistent execution behavior

This prevents common issues where direct SSH calls hang inside container exec environments.

When running vm-run commands inside the container environment,
always call it through `sh`:

sh /home/node/.openclaw/workspace/vm-run <command>

### Workspace inspection

If a script or tool fails unexpectedly, verify workspace contents:

ls -la /home/node/.openclaw/workspace

---

## ChatOps-style Host Commands

The vm-run wrapper also supports ChatOps-style host commands:

- sh /home/node/.openclaw/workspace/vm-run host status
- sh /home/node/.openclaw/workspace/vm-run host uptime
- sh /home/node/.openclaw/workspace/vm-run host mem
- sh /home/node/.openclaw/workspace/vm-run host disk
- sh /home/node/.openclaw/workspace/vm-run host docker
- sh /home/node/.openclaw/workspace/vm-run host logs <container> [lines]
- sh /home/node/.openclaw/workspace/vm-run host service <name>
- sh /home/node/.openclaw/workspace/vm-run host restart <name>
- sh /home/node/.openclaw/workspace/vm-run host journal <name> [lines]
- sh /home/node/.openclaw/workspace/vm-run host exec "<raw command>"

## vm-run v2 command tree

Use vm-run as the preferred host operation entrypoint.

Examples:

- sh /home/node/.openclaw/workspace/vm-run health
- sh /home/node/.openclaw/workspace/vm-run docker ps
- sh /home/node/.openclaw/workspace/vm-run docker logs <container> 100
- sh /home/node/.openclaw/workspace/vm-run docker restart <container>
- sh /home/node/.openclaw/workspace/vm-run service status <name>
- sh /home/node/.openclaw/workspace/vm-run service restart <name>
- sh /home/node/.openclaw/workspace/vm-run service logs <name> 100
- sh /home/node/.openclaw/workspace/vm-run host status
- sh /home/node/.openclaw/workspace/vm-run host docker ps
- sh /home/node/.openclaw/workspace/vm-run host service status <name>
- sh /home/node/.openclaw/workspace/vm-run exec "<raw command>"
