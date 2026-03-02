#!/bin/bash
set -e

#=============================================
# OpenClaw 一键安装脚本
# 作者: 小爪
# 功能: 自动检测并配置国内镜像，一键安装 OpenClaw
#=============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#=============================================
# 1. 网络检测
#=============================================
check_network() {
    log_info "检测网络连接..."
    
    local test_urls=(
        "https://registry.npmmirror.com"
        "https://github.com"
        "https://nodejs.org"
    )
    
    local failed=0
    for url in "${test_urls[@]}"; do
        if curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
            log_success "✓ $url 可访问"
        else
            log_warn "✗ $url 无法访问"
            failed=1
        fi
    done
    
    if [ $failed -eq 1 ]; then
        log_warn "部分节点不可用，将尝试使用可用镜像"
    fi
}

#=============================================
# 2. 检测操作系统
#=============================================
detect_os() {
    log_info "检测操作系统..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        log_success "检测到 macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        log_success "检测到 Linux"
    elif [[ "$OSTYPE" == "MSYS"* ]] || [[ "$OSTYPE" == "MINGW"* ]]; then
        OS="windows"
        log_success "检测到 Windows (Git Bash / MSYS)"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

#=============================================
# 3. 安装 Node.js
#=============================================
install_nodejs() {
    log_info "检查 Node.js..."
    
    if command -v node &> /dev/null; then
        local node_version=$(node -v)
        log_success "Node.js 已安装: $node_version"
        
        # 检查版本是否 >= 18
        local major=$(echo $node_version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$major" -lt 18 ]; then
            log_warn "Node.js 版本过低 ($node_version)，建议升级到 18+"
            log_info "正在尝试升级..."
            install_nodejs_from_source
        fi
    else
        log_info "Node.js 未安装，正在安装..."
        install_nodejs_from_source
    fi
}

# 使用 nvm 安装 Node.js（国内镜像）
install_nodejs_from_source() {
    log_info "通过 nvm 安装 Node.js..."
    
    # 检查是否有 nvm
    if [ -d "$HOME/.nvm" ]; then
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        log_success "使用已有 nvm"
    else
        # 安装 nvm（使用国内镜像）
        log_info "安装 nvm..."
        export NVM_DIR="$HOME/.nvm"
        
        # 尝试使用国内镜像安装 nvm
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh 2>/dev/null | \
            NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist bash || {
            # 备用：使用 gitee 镜像
            log_warn "官方 nvm 安装失败，尝试镜像..."
            curl -o- https://gitee.com/mirrors/nvm-sh-nvm/raw/master/install.sh 2>/dev/null | bash
        }
        
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    # 安装 Node.js 22（使用清华镜像）
    log_info "安装 Node.js 22..."
    export NVM_NODEJS_ORG_MIRROR=https://mirrors.ustc.edu.cn/node/
    nvm install 22 || nvm install 20 || nvm install 18
    nvm use 22 || nvm use 20 || nvm use 18
    
    log_success "Node.js 安装完成: $(node -v)"
}

#=============================================
# 4. 配置 NPM 镜像
#=============================================
config_npm_mirror() {
    log_info "配置 NPM 镜像..."
    
    # 测试各个镜像速度
    local mirrors=(
        "https://registry.npmmirror.com"
        "https://registry.npmmi.com"
        "https://npm.tuna.tsinghua.edu.cn"
    )
    
    local best_mirror=""
    local best_time=999
    
    for mirror in "${mirrors[@]}"; do
        local start=$(date +%s%N)
        if curl -s --max-time 3 "$mirror" > /dev/null 2>&1; then
            local end=$(date +%s%N)
            local time=$(( (end - start) / 1000000 ))
            if [ $time -lt $best_time ]; then
                best_time=$time
                best_mirror=$mirror
            fi
            log_info "  $mirror - ${time}ms"
        fi
    done
    
    if [ -n "$best_mirror" ]; then
        npm config set registry "$best_mirror"
        log_success "已配置 NPM 镜像: $best_mirror"
    else
        npm config set registry "https://registry.npmjs.org"
        log_warn "使用官方 NPM 镜像（无可用国内镜像）"
    fi
}

#=============================================
# 5. 安装 OpenClaw
#=============================================
install_openclaw() {
    log_info "安装 OpenClaw..."
    
    # 检查是否已安装
    if command -v openclaw &> /dev/null; then
        log_success "OpenClaw 已安装: $(openclaw --version 2>/dev/null || echo 'unknown')"
        
        read -p "是否更新到最新版本? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "跳过更新"
            return 0
        fi
    fi
    
    # 全局安装 OpenClaw
    log_info "执行: npm install -g openclaw"
    npm install -g openclaw
    
    if command -v openclaw &> /dev/null; then
        log_success "OpenClaw 安装成功!"
    else
        log_error "OpenClaw 安装失败"
        exit 1
    fi
}

#=============================================
# 6. 配置 GitHub 加速
#=============================================
config_github_mirror() {
    log_info "配置 GitHub 加速..."
    
    # 测试各个加速镜像
    local mirrors=(
        "https://ghproxy.com"
        "https://mirror.ghproxy.com"
        "https://moeyy.cn"
        "https://gh.api.99988866.xyz"
    )
    
    local best_mirror=""
    for mirror in "${mirrors[@]}"; do
        if curl -s --max-time 3 -o /dev/null -w "%{http_code}" "$mirror/https://github.com" | grep -q "200"; then
            best_mirror=$mirror
            break
        fi
    done
    
    if [ -n "$best_mirror" ]; then
        # 配置 git 加速
        git config --global url."$best_mirror".insteadOf "https://github.com"
        log_success "已配置 GitHub 加速: $best_mirror"
    else
        log_warn "无可用 GitHub 加速镜像"
    fi
}

#=============================================
# 7. 初始化 OpenClaw
#=============================================
init_openclaw() {
    log_info "初始化 OpenClaw..."
    
    # 检查是否已初始化
    if [ -d "$HOME/.openclaw" ]; then
        log_info "OpenClaw 已初始化"
        
        read -p "是否重新初始化? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # 运行初始化
    openclaw init
    
    log_success "OpenClaw 初始化完成"
    log_info "配置文件位置: ~/.openclaw/openclaw.json"
}

#=============================================
# 8. 启动服务（可选）
#=============================================
start_gateway() {
    log_info "启动 OpenClaw Gateway..."
    
    if command -v openclaw &> /dev/null; then
        openclaw gateway start
        log_success "Gateway 已启动"
        log_info "查看状态: openclaw gateway status"
    else
        log_error "OpenClaw 未安装"
    fi
}

#=============================================
# 主流程
#=============================================
main() {
    echo "========================================"
    echo "  OpenClaw 一键安装脚本"
    echo "  作者: 小爪 🐾"
    echo "========================================"
    echo
    
    # 执行各步骤
    detect_os
    check_network
    install_nodejs
    config_npm_mirror
    config_github_mirror
    install_openclaw
    init_openclaw
    
    echo
    echo "========================================"
    log_success "安装完成! 🎉"
    echo "========================================"
    echo
    echo "常用命令:"
    echo "  openclaw gateway start   # 启动服务"
    echo "  openclaw gateway status # 查看状态"
    echo "  openclaw help           # 查看帮助"
    echo
    
    read -p "是否立即启动 Gateway? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        start_gateway
    fi
}

# 运行主流程
main "$@"
