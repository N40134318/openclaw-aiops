#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Ubuntu pre-init script for OpenClaw host
# ==========================================

export DEBIAN_FRONTEND=noninteractive

APT_MIRROR="${APT_MIRROR:-tuna}"
INSTALL_DOCKER="${INSTALL_DOCKER:-yes}"
UPGRADE_SYSTEM="${UPGRADE_SYSTEM:-yes}"

log()  { echo "[INFO] $*"; }
ok()   { echo "[ OK ] $*"; }
warn() { echo "[WARN] $*"; }
err()  { echo "[ERR ] $*"; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "请使用 root 或 sudo 运行"
    exit 1
  fi
}

detect_ubuntu() {
  if [ ! -f /etc/os-release ]; then
    err "无法识别系统版本"
    exit 1
  fi

  . /etc/os-release

  if [ "${ID:-}" != "ubuntu" ]; then
    err "该脚本仅支持 Ubuntu"
    exit 1
  fi

  UBUNTU_CODENAME="${VERSION_CODENAME:-}"
  if [ -z "$UBUNTU_CODENAME" ]; then
    err "无法识别 Ubuntu 代号"
    exit 1
  fi

  ok "检测到 Ubuntu: ${PRETTY_NAME:-unknown}"
}

backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
    ok "已备份 $file"
  fi
}

setup_apt_mirror() {
  log "配置国内 apt 源: $APT_MIRROR"

  mkdir -p /etc/apt/keyrings

  if [ -f /etc/apt/sources.list ]; then
    backup_file /etc/apt/sources.list
  fi

  if [ -d /etc/apt/sources.list.d ]; then
    find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list' -o -name '*.sources' | while read -r f; do
      cp "$f" "${f}.bak.$(date +%Y%m%d%H%M%S)" || true
    done
  fi

  case "$APT_MIRROR" in
    tuna)
      cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
      ;;
    ustc)
      cat > /etc/apt/sources.list <<EOF
deb https://mirrors.ustc.edu.cn/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
      ;;
    aliyun)
      cat > /etc/apt/sources.list <<EOF
deb https://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
      ;;
    *)
      err "不支持的镜像源: $APT_MIRROR，可选: tuna / ustc / aliyun"
      exit 1
      ;;
  esac

  ok "apt 源已写入 /etc/apt/sources.list"
}

apt_update_and_upgrade() {
  log "刷新 apt 索引"
  apt-get update -y

  if [ "$UPGRADE_SYSTEM" = "yes" ]; then
    log "升级系统软件包"
    apt-get dist-upgrade -y
    ok "系统升级完成"
  else
    warn "跳过系统升级"
  fi
}

install_base_tools() {
  log "安装常用基础工具"

  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    wget \
    git \
    vim \
    nano \
    bash-completion \
    jq \
    yq \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    file \
    tree \
    htop \
    btop \
    iotop \
    iftop \
    tmux \
    screen \
    rsync \
    lsof \
    net-tools \
    iproute2 \
    dnsutils \
    telnet \
    nmap \
    traceroute \
    tcpdump \
    socat \
    ncdu \
    psmisc \
    procps \
    software-properties-common \
    gnupg \
    gnupg2 \
    lsb-release \
    build-essential \
    make \
    cmake \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    openssh-server \
    sudo \
    cron \
    acl \
    ripgrep \
    fd-find \
    locales \
    tzdata \
    dos2unix \
    parted \
    needrestart \
    ufw \
    fail2ban

  ok "基础工具安装完成"
}

setup_locale_and_timezone() {
  log "配置 locale 和时区"

  locale-gen en_US.UTF-8 zh_CN.UTF-8 || true
  update-locale LANG=en_US.UTF-8 || true

  timedatectl set-timezone Asia/Shanghai || true

  ok "locale/timezone 配置完成"
}

setup_useful_aliases() {
  log "写入全局常用别名"

  cat > /etc/profile.d/custom_aliases.sh <<'EOF'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias dc='docker compose'
EOF

  chmod 644 /etc/profile.d/custom_aliases.sh
  ok "常用别名已写入 /etc/profile.d/custom_aliases.sh"
}

install_docker() {
  if [ "$INSTALL_DOCKER" != "yes" ]; then
    warn "跳过 Docker 安装"
    return
  fi

  log "安装 Docker"

  apt-get remove -y docker docker-engine docker.io containerd runc || true

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable
EOF

  apt-get update -y

  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl restart docker

  ok "Docker 安装完成"
}

basic_sshd_prepare() {
  log "初始化 ssh 服务"

  systemctl enable ssh || true
  systemctl restart ssh || systemctl restart sshd || true

  ok "ssh 服务已处理"
}

basic_firewall_prepare() {
  log "初始化 UFW（默认不直接启用）"

  ufw allow OpenSSH || true

  ok "已放行 OpenSSH，可按需执行: ufw enable"
}

cleanup_system() {
  log "清理无用软件包"
  apt-get autoremove -y
  apt-get autoclean -y
  ok "清理完成"
}

show_summary() {
  echo
  echo "==================== 初始化完成 ===================="
  echo "系统: Ubuntu ${UBUNTU_CODENAME}"
  echo "APT 镜像: ${APT_MIRROR}"
  echo "Docker 安装: ${INSTALL_DOCKER}"
  echo
  echo "建议下一步："
  echo "1. 创建 OpenClaw 所需目录"
  echo "2. 拷贝 openclaw 项目文件"
  echo "3. 执行宿主机权限初始化脚本（如 init-host.sh）"
  echo "4. 检查 ssh / docker 状态"
  echo "5. docker compose up -d"
  echo
  echo "常用检查命令："
  echo "  docker --version"
  echo "  docker compose version"
  echo "  systemctl status docker"
  echo "  systemctl status ssh"
  echo "=================================================="
}

main() {
  require_root
  detect_ubuntu
  setup_apt_mirror
  apt_update_and_upgrade
  install_base_tools
  setup_locale_and_timezone
  setup_useful_aliases
  install_docker
  basic_sshd_prepare
  basic_firewall_prepare
  cleanup_system
  show_summary
}

main "$@"
