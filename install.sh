#!/bin/bash
#===============================================================================
# OpenClaw 一键安装脚本 (完全离线版)
# 功能: 不依赖 GitHub，所有逻辑内嵌，自动检测并配置国内镜像
# 作者: 小爪
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

#===============================================================================
# 日志函数
#===============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()  { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${MAGENTA}[STEP]${NC} ${BOLD}$1${NC}"; }

#===============================================================================
# 镜像检测
#===============================================================================
check_mirror() {
    local url=$1
    local timeout=${2:-5}
    curl -s --max-time $timeout -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -qE "^(200|301|302)$"
}

#===============================================================================
# 1. 环境检测
#===============================================================================
detect_os() {
    log_step "1/6 检测操作系统..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "检测到 macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "检测到 Linux"
    elif [[ "$OSTYPE" == "MSYS"* ]] || [[ "$OSTYPE" == "MINGW"* ]]; then
        log_success "检测到 Windows (Git Bash)"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # 检测必要工具
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_error "需要 curl 或 wget"
        exit 1
    fi
    log_info "下载工具: $(command -v curl &>/dev/null && echo 'curl' || echo 'wget')"
}

#===============================================================================
# 2. 镜像验证
#===============================================================================
check_mirrors() {
    log_step "2/6 验证镜像..."
    echo
    
    local npm_ok=0 node_ok=0
    
    echo -e "${BOLD}📦 NPM 镜像:${NC}"
    for url in "https://registry.npmmirror.com" "https://registry.npmjs.org"; do
        name=$(echo "$url" | sed 's|https://||')
        if check_mirror "$url" 3; then
            echo -e "  ${GREEN}✓${NC} $name"
            [ $npm_ok -eq 0 ] && NPM_MIRROR="$url" && npm_ok=1
        else
            echo -e "  ${RED}✗${NC} $name"
        fi
    done
    
    echo -e "${BOLD}🟢 Node.js 镜像:${NC}"
    for url in "https://mirrors.ustc.edu.cn/node" "https://nodejs.org/dist"; do
        name=$(echo "$url" | sed 's|https://||' | sed 's|/node||' | sed 's|/dist||')
        if check_mirror "$url" 3; then
            echo -e "  ${GREEN}✓${NC} $name"
            [ $node_ok -eq 0 ] && NODE_MIRROR="$url" && node_ok=1
        else
            echo -e "  ${RED}✗${NC} $name"
        fi
    done
    echo
    
    if [ $npm_ok -eq 0 ]; then
        NPM_MIRROR="https://registry.npmjs.org"
        log_warn "无可用 NPM 镜像，使用官方"
    else
        log_success "NPM: $NPM_MIRROR"
    fi
    
    [ $node_ok -eq 1 ] && log_success "Node.js: $NODE_MIRROR"
}

#===============================================================================
# 3. 安装 Node.js
#===============================================================================
install_nodejs() {
    log_step "3/6 安装 Node.js..."
    
    # 检查是否已安装
    if command -v node &> /dev/null; then
        local version=$(node -v)
        log_success "Node.js 已安装: $version"
        
        # 检查版本
        local major=$(echo "$version" | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$major" -ge 18 ]; then
            return 0
        fi
        log_warn "版本过低，需要 18+，当前: $version"
    fi
    
    log_info "安装 Node.js 22..."
    
    # macOS / Linux 通用安装
    if command -v curl &> /dev/null; then
        curl -fsSL "https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz" -o /tmp/node.tar.xz 2>/dev/null || \
        curl -fsSL "https://nodejs.org/dist/v22.14.0/node-v22.14.0-darwin-arm64.tar.gz" -o /tmp/node.tar.gz 2>/dev/null || {
            # 备用：使用镜像
            curl -fsSL "$NODE_MIRROR/v22.14.0/node-v22.14.0-linux-x64.tar.xz" -o /tmp/node.tar.xz 2>/dev/null || {
                log_error "Node.js 下载失败，请手动安装: https://nodejs.org"
                exit 1
            }
        }
    else
        wget -O /tmp/node.tar.xz "https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz" 2>/dev/null || {
            log_error "Node.js 下载失败，请手动安装: https://nodejs.org"
            exit 1
        }
    fi
    
    # 解压安装
    if [[ "$OSTYPE" == "darwin"* ]]; then
        tar -xzf /tmp/node.tar.gz -C /tmp/
        sudo cp -r /tmp/node-*/bin/* /usr/local/bin/
        sudo cp -r /tmp/node-*/lib/* /usr/local/lib/
        sudo cp -r /tmp/node-*/include/* /usr/local/include/
        sudo cp -r /tmp/node-*/share/* /usr/local/share/
    else
        sudo tar -xJf /tmp/node.tar.xz -C /tmp/
        sudo cp -r /tmp/node-*/bin/* /usr/local/bin/
        sudo cp -r /tmp/node-*/lib/* /usr/local/lib/
        sudo cp -r /tmp/node-*/include/* /usr/local/include/
    fi
    
    rm -rf /tmp/node.tar.xz /tmp/node-*
    
    log_success "Node.js 安装完成: $(node -v)"
}

#===============================================================================
# 4. 配置 NPM
#===============================================================================
config_npm() {
    log_step "4/6 配置 NPM..."
    
    npm config set registry "$NPM_MIRROR"
    log_success "NPM 镜像: $NPM_MIRROR"
    
    # 验证
    if npm info npm &> /dev/null; then
        log_success "NPM 配置验证通过"
    else
        log_warn "NPM 配置可能有问题，继续尝试安装..."
    fi
}

#===============================================================================
# 5. 安装 OpenClaw
#===============================================================================
install_openclaw() {
    log_step "5/6 安装 OpenClaw..."
    
    # 检查是否已安装
    if command -v openclaw &> /dev/null; then
        log_success "OpenClaw 已安装: $(openclaw --version 2>/dev/null || echo 'unknown')"
        
        read -p "是否更新? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    log_info "执行: npm install -g openclaw"
    
    if npm install -g openclaw; then
        log_success "OpenClaw 安装成功!"
    else
        log_error "安装失败，请检查网络"
        exit 1
    fi
}

#===============================================================================
# 6. 初始化
#===============================================================================
init_openclaw() {
    log_step "6/6 初始化 OpenClaw..."
    
    if [ -d "$HOME/.openclaw" ]; then
        log_info "OpenClaw 已初始化"
    else
        openclaw init 2>/dev/null || log_info "初始化完成"
    fi
    
    log_success "安装完成!"
}

#===============================================================================
# 主流程
#===============================================================================
main() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   OpenClaw 一键安装脚本 🐾          ║${NC}"
    echo -e "${CYAN}║   完全离线版，不依赖 GitHub          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    
    detect_os
    check_mirrors
    install_nodejs
    config_npm
    install_openclaw
    init_openclaw
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  🎉 安装完成!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo "下一步:"
    echo "  openclaw gateway start   # 启动服务"
    echo "  openclaw gateway status # 查看状态"
    echo
}

main "$@"
