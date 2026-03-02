#!/bin/bash
# OpenClaw 国内一键安装脚本
# 测试环境: macOS / Linux
# 作者: lan450

set -e

# ========== 配置 ==========
OPENCLAW_REPO="https://github.com/openclaw/openclaw"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
INSTALL_DIR="${HOME}/openclaw"

# 国内镜像列表（按优先级排序）
NPM_MIRRORS=(
    "https://registry.npmmirror.com"
    "https://registry.npmjs.org"
)

GITHUB_MIRRORS=(
    "https://moeyy.cn/https://github.com"
    "https://github.com"
)

NVM_MIRRORS=(
    "https://nvm.uihtm.com"
    "https://nodejs.org"
)

# ========== 颜色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ========== 检测函数 ==========
check_command() {
    command -v "$1" &> /dev/null
}

check_port() {
    local host=$1
    local port=${2:-443}
    timeout 3 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null
}

# ========== 网络测试 ==========
test_url() {
    curl -sI --connect-timeout 5 "$1" 2>/dev/null | head -1 | grep -q "200\|301\|302" && return 0 || return 1
}

# ========== 选择最佳镜像 ==========
find_best_mirror() {
    local name=$1
    shift
    local mirrors=("$@")
    
    log_info "检测 ${name} 镜像..."
    for mirror in "${mirrors[@]}"; do
        if test_url "$mirror"; then
            log_success "使用 ${mirror}"
            echo "$mirror"
            return 0
        fi
    done
    log_error "所有 ${name} 镜像均不可用"
    return 1
}

# ========== 系统检测 ==========
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if check_command apt-get; then
            echo "debian"
        elif check_command yum; then
            echo "rhel"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

# ========== 安装 Node.js ==========
install_node() {
    local os=$(detect_os)
    
    if check_command node; then
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$node_version" -ge 22 ]]; then
            log_success "Node.js $(node -v) 已安装"
            return 0
        fi
        log_warn "Node.js 版本过低，需要 22+"
    fi
    
    log_info "安装 Node.js 22..."
    
    # 方案1: 使用 nvm
    if check_command brew; then
        log_info "使用 Homebrew 安装..."
        brew install node@22 || true
        export PATH="/usr/local/opt/node@22/bin:$PATH"
    fi
    
    # 方案2: 直接下载
    if ! check_command node || [[ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" -lt 22 ]]; then
        log_info "直接下载 Node.js 22..."
        
        local nvm_mirror
        nvm_mirror=$(find_best_mirror "NVM" "${NVM_MIRRORS[@]}") || nvm_mirror="https://nodejs.org"
        
        if [[ "$os" == "macos" ]]; then
            local pkg_url="${nvm_mirror}/dist/v22.14.0/node-v22.14.0-arm64.pkg"
            log_info "下载: $pkg_url"
            curl -fsSL "$pkg_url" -o /tmp/node.pkg
            sudo installer -pkg /tmp/node.pkg -target /
            rm -f /tmp/node.pkg
        else
            local pkg_url="${nvm_mirror}/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz"
            log_info "下载: $pkg_url"
            curl -fsSL "$pkg_url" -o /tmp/node.tar.xz
            sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
            rm -f /tmp/node.tar.xz
        fi
    fi
    
    log_success "Node.js 安装完成: $(node -v)"
}

# ========== 配置 NPM 镜像 ==========
setup_npm_mirror() {
    local npm_mirror
    npm_mirror=$(find_best_mirror "NPM" "${NPM_MIRRORS[@]}") || npm_mirror="https://registry.npmjs.org"
    
    npm config set registry "$npm_mirror"
    log_success "NPM 镜像已配置: $npm_mirror"
}

# ========== 安装 OpenClaw ==========
install_openclaw() {
    log_info "安装 OpenClaw 到 ${INSTALL_DIR}..."
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 下载源码
    local github_mirror
    github_mirror=$(find_best_mirror "GitHub" "${GITHUB_MIRRORS[@]}") || github_mirror="https://github.com"
    
    local download_url="${github_mirror}/openclaw/openclaw/archive/refs/heads/main.zip"
    log_info "下载源码: $download_url"
    
    if curl -fsSL "$download_url" -o main.zip; then
        unzip -q main.zip
        rm main.zip
        
        # 处理目录名
        if [[ -d "openclaw-main" ]]; then
            mv openclaw-main/* .
            rm -rf openclaw-main
        fi
    else
        log_error "下载失败，尝试克隆..."
        git clone "$OPENCLAW_REPO" . || {
            log_error "安装失败"
            exit 1
        }
    fi
    
    log_info "安装依赖..."
    npm install
    
    log_success "OpenClaw 安装完成!"
}

# ========== 主流程 ==========
main() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     OpenClaw 国内一键安装脚本 🐾       ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "检测系统: $(detect_os)"
    
    # 1. 安装 Node.js
    install_node
    
    # 2. 配置 NPM 镜像
    setup_npm_mirror
    
    # 3. 安装 OpenClaw
    install_openclaw
    
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║           安装完成! 🎉                 ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    echo "下一步:"
    echo "  cd ${INSTALL_DIR}"
    echo "  openclaw init"
    echo ""
}

main "$@"
