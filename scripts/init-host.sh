#!/usr/bin/env bash
set -euo pipefail

CLAW_USER="${CLAW_USER:-claw}"
PUBKEY_FILE="${1:-./claw_agent.pub}"
SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
SUDOERS_FILE="${SUDOERS_FILE:-/etc/sudoers.d/claw}"

log() {
  echo "[INFO] $1"
}

ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

fatal() {
  echo "[ERROR] $1"
  exit 1
}

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    fatal "Please run as root or with sudo"
  fi
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
    ok "Backed up $file"
  fi
}

ensure_user() {
  if id "$CLAW_USER" >/dev/null 2>&1; then
    ok "User already exists: $CLAW_USER"
  else
    useradd -m -s /bin/bash "$CLAW_USER"
    ok "Created user: $CLAW_USER"
  fi
}

ensure_docker_group() {
  if getent group docker >/dev/null 2>&1; then
    ok "Group exists: docker"
  else
    groupadd docker
    ok "Created group: docker"
  fi

  usermod -aG docker "$CLAW_USER"
  ok "Added $CLAW_USER to docker group"
}

install_ssh_key() {
  [ -f "$PUBKEY_FILE" ] || fatal "Public key file not found: $PUBKEY_FILE"

  local home_dir
  home_dir="$(getent passwd "$CLAW_USER" | cut -d: -f6)"
  [ -n "$home_dir" ] || fatal "Could not determine home directory for $CLAW_USER"

  mkdir -p "$home_dir/.ssh"
  touch "$home_dir/.ssh/authorized_keys"

  if grep -F -x -f "$PUBKEY_FILE" "$home_dir/.ssh/authorized_keys" >/dev/null 2>&1; then
    ok "Public key already installed"
  else
    cat "$PUBKEY_FILE" >> "$home_dir/.ssh/authorized_keys"
    ok "Installed public key into authorized_keys"
  fi

  chown -R "$CLAW_USER:$CLAW_USER" "$home_dir/.ssh"
  chmod 700 "$home_dir/.ssh"
  chmod 600 "$home_dir/.ssh/authorized_keys"
  ok "Fixed SSH directory permissions"
}

write_sudoers() {
  backup_file "$SUDOERS_FILE"

  cat > "$SUDOERS_FILE" <<EOF
Defaults:${CLAW_USER} !requiretty
${CLAW_USER} ALL=(ALL) NOPASSWD: /bin/systemctl
${CLAW_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl
${CLAW_USER} ALL=(ALL) NOPASSWD: /usr/bin/docker
EOF

  chmod 440 "$SUDOERS_FILE"

  if visudo -cf "$SUDOERS_FILE" >/dev/null; then
    ok "Sudoers file validated: $SUDOERS_FILE"
  else
    fatal "Invalid sudoers file: $SUDOERS_FILE"
  fi
}

set_sshd_option() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >> "$SSHD_CONFIG"
  fi
}

configure_sshd() {
  [ -f "$SSHD_CONFIG" ] || fatal "sshd_config not found: $SSHD_CONFIG"

  backup_file "$SSHD_CONFIG"

  set_sshd_option "PasswordAuthentication" "no"
  set_sshd_option "PubkeyAuthentication" "yes"
  set_sshd_option "ChallengeResponseAuthentication" "no"
  set_sshd_option "KbdInteractiveAuthentication" "no"
  set_sshd_option "UsePAM" "yes"

  if sshd -t; then
    ok "sshd config validation passed"
  else
    fatal "sshd config validation failed"
  fi

  if systemctl list-unit-files | grep -q '^ssh.service'; then
    systemctl restart ssh
    systemctl enable ssh >/dev/null 2>&1 || true
    ok "Restarted ssh service"
  elif systemctl list-unit-files | grep -q '^sshd.service'; then
    systemctl restart sshd
    systemctl enable sshd >/dev/null 2>&1 || true
    ok "Restarted sshd service"
  else
    warn "Could not detect ssh/sshd service name, restart it manually"
  fi
}

verify_setup() {
  log "Running basic verification"

  if id "$CLAW_USER" >/dev/null 2>&1; then
    ok "Verified user exists"
  else
    fatal "User verification failed"
  fi

  if id "$CLAW_USER" | grep -q '\bdocker\b'; then
    ok "Verified docker group membership"
  else
    warn "docker group membership not visible yet; re-login may be needed"
  fi

  if sudo -u "$CLAW_USER" test -f "$(getent passwd "$CLAW_USER" | cut -d: -f6)/.ssh/authorized_keys"; then
    ok "Verified authorized_keys exists"
  else
    fatal "authorized_keys verification failed"
  fi

  if sudo -u "$CLAW_USER" docker ps >/dev/null 2>&1; then
    ok "Verified docker access for $CLAW_USER"
  else
    warn "docker ps failed for $CLAW_USER; session refresh may be needed after group change"
  fi
}

main() {
  require_root

  log "Initializing host for AI Ops Agent"
  log "User: $CLAW_USER"
  log "Public key file: $PUBKEY_FILE"

  ensure_user
  ensure_docker_group
  install_ssh_key
  write_sudoers
  configure_sshd
  verify_setup

  echo
  ok "Host initialization completed"
  echo "Next steps:"
  echo "1. Mount private key and known_hosts into the container"
  echo "2. Ensure vm-run uses user: $CLAW_USER"
  echo "3. Start container with docker compose up -d"
  echo "4. Run verify-deploy.sh inside the container"
}

main "$@"
