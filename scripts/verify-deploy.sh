#!/usr/bin/env bash
set -euo pipefail

# ==========
# Config
# ==========
HOST="${HOST:-host.docker.internal}"
USER_NAME="${USER_NAME:-claw}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY="${SSH_KEY:-/home/node/.ssh/id_ed25519}"
KNOWN_HOSTS="${KNOWN_HOSTS:-/home/node/.ssh/known_hosts}"
VM_RUN_PATH="${VM_RUN_PATH:-/home/node/.openclaw/workspace/vm-run}"
SSH_BIN="${SSH_BIN:-ssh}"

# ==========
# Helpers
# ==========
PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "[PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "[FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
  echo "[INFO] $1"
}

section() {
  echo
  echo "==== $1 ===="
}

run_check() {
  local name="$1"
  local cmd="$2"

  echo "-- $name"
  if bash -lc "$cmd"; then
    pass "$name"
  else
    fail "$name"
  fi
}

SSH_OPTS=(
  -o BatchMode=yes
  -o ConnectTimeout=5
  -o StrictHostKeyChecking=yes
  -p "$SSH_PORT"
  -i "$SSH_KEY"
  -o UserKnownHostsFile="$KNOWN_HOSTS"
)

REMOTE="${USER_NAME}@${HOST}"

# ==========
# Preflight
# ==========
section "Preflight"

if [ ! -f "$SSH_KEY" ]; then
  echo "[FATAL] SSH key not found: $SSH_KEY"
  exit 1
fi

if [ ! -f "$KNOWN_HOSTS" ]; then
  echo "[FATAL] known_hosts not found: $KNOWN_HOSTS"
  exit 1
fi

if [ ! -f "$VM_RUN_PATH" ]; then
  echo "[FATAL] vm-run not found: $VM_RUN_PATH"
  exit 1
fi

if [ ! -x "$VM_RUN_PATH" ]; then
  info "vm-run is not executable, trying chmod +x"
  chmod +x "$VM_RUN_PATH" || true
fi

pass "Required files exist"

# ==========
# SSH checks
# ==========
section "SSH connectivity"

run_check \
  "SSH whoami" \
  "$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'whoami | grep -qx \"$USER_NAME\"'"

run_check \
  "SSH hostname" \
  "$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'hostname' >/dev/null"

run_check \
  "SSH non-interactive mode" \
  "$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'echo ok' | grep -qx 'ok'"

# ==========
# sudo checks
# ==========
section "Restricted sudo commands"

run_check \
  "sudo docker ps" \
  "$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'sudo docker ps >/dev/null'"

run_check \
  "sudo systemctl status docker" \
  "$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'sudo systemctl status docker >/dev/null'"

run_check \
  "sudo journalctl access" \
  \"$SSH_BIN ${SSH_OPTS[*]} $REMOTE 'sudo journalctl -n 1 >/dev/null'\"

# ==========
# vm-run checks
# ==========
section "vm-run wrapper"

run_check \
  "vm-run sys" \
  "'$VM_RUN_PATH' sys >/dev/null"

run_check \
  "vm-run docker" \
  "'$VM_RUN_PATH' docker >/dev/null"

run_check \
  "vm-run exec date" \
  "'$VM_RUN_PATH' exec 'date' >/dev/null"

# ==========
# Optional safety check
# ==========
section "Optional negative check"

if $SSH_BIN "${SSH_OPTS[@]}" "$REMOTE" 'sudo -n bash -lc "echo should_not_work"' >/dev/null 2>&1; then
  fail "Unexpected unrestricted sudo access"
else
  pass "Unrestricted sudo is blocked"
fi

# ==========
# Summary
# ==========
section "Summary"
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "[RESULT] Deployment verification FAILED"
  exit 1
else
  echo
  echo "[RESULT] Deployment verification PASSED"
fi
