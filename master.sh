#!/bin/bash
#===============================================================================
# OpenClaw 主安装脚本
# 功能: 自动检测环境，验证镜像可用性，一键安装
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

# 全局变量
SCRIPT_DIR=""
OS=""
SCRIPT_NAME=""
NPM_BEST=""
GITHUB_BEST=""
NODE_BEST=""

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
    
    if curl -s --max-time $timeout -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -qE "^(200|301|302)$"; then
        return 0
    else
        return 1
    fi
}

#===============================================================================
# 1. 环境检测
#===============================================================================
detect_environment() {
    log_step "1/5 检测操作系统..."
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    
    # 检测操作系统
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        SCRIPT_NAME="install.sh"
        log_success "检测到 macOS → 使用 $SCRIPT_NAME"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        SCRIPT_NAME="install.sh"
        log_success "检测到 Linux → 使用 $SCRIPT_NAME"
    elif [[ "$OSTYPE" == "MSYS"* ]] || [[ "$OSTYPE" == "MINGW"* ]]; then
        OS="windows"
        SCRIPT_NAME="install.ps1"
        log_success "检测到 Windows → 使用 $SCRIPT_NAME"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # 检测下载工具
    if command -v curl &> /dev/null; then
        log_info "下载工具: curl"
    elif command -v wget &> /dev/null; then
        log_info "下载工具: wget"
    else
        log_error "需要 curl 或 wget"
        exit 1
    fi
}

#===============================================================================
# 2. 镜像检测
#===============================================================================
check_all_mirrors() {
    log_step "2/5 验证所有镜像连接..."
    echo
    
    local npm_ok=0 gh_ok=0 node_ok=0 nvm_ok=0
    
    # NPM 镜像
    echo -e "${BOLD}📦 NPM 镜像:${NC}"
    for url in "https://registry.npmmirror.com" "https://npm.tuna.tsinghua.edu.cn" "https://registry.npmjs.org"; do
        name=$(echo "$url" | sed 's|https://||' | sed 's|npm.tuna.tsinghua.edu.cn|tsinghua|' | sed 's|registry.npmmirror.com|npmmirror|' | sed 's|registry.npmjs.org|npmjs|')
        if check_mirror "$url" 3; then
            echo -e "  ${GREEN}✓${NC} $name: $url"
            npm_ok=1
        else
            echo -e "  ${RED}✗${NC} $name: $url"
        fi
    done
    echo
    
    # GitHub 镜像
    echo -e "${BOLD}🐙 GitHub 加速:${NC}"
    for url in "https://ghproxy.com" "https://moeyy.cn" "https://mirror.ghproxy.com"; do
        name=$(echo "$url" | sed 's|https://||')
        if check_mirror "$url/https://github.com" 3; then
            echo -e "  ${GREEN}✓${NC} $name"
            gh_ok=1
        else
            echo -e "  ${RED}✗${NC} $name"
        fi
    done
    echo
    
    # Node.js 镜像
    echo -e "${BOLD}🟢 Node.js 镜像:${NC}"
    for url in "https://mirrors.ustc.edu.cn/node" "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release"; do
        name=$(echo "$url" | sed 's|https://mirrors.ustc.edu.cn/node|ustc|' | sed 's|https://mirrors.tuna.tsinghua.edu.cn/nodejs-release|tsinghua|')
        if check_mirror "$url" 3; then
            echo -e "  ${GREEN}✓${NC} $name: $url"
            node_ok=1
        else
            echo -e "  ${RED}✗${NC} $name: $url"
        fi
    done
    echo
    
    # NVM 镜像
    echo -e "${BOLD}📐 NVM 镜像:${NC}"
    for url in "https://nvm.uihtm.com" "https://github.com"; do
        name=$(echo "$url" | sed 's|https://||')
        if check_mirror "$url" 3; then
            echo -e "  ${GREEN}✓${NC} $name"
            nvm_ok=1
        else
            echo -e "  ${RED}✗${NC} $name"
        fi
    done
    echo
    
    [ $npm_ok -eq 0 ] && log_warn "无可用 NPM 镜像"
    [ $gh_ok -eq 0 ] && log_warn "无可用 GitHub 加速"
    [ $node_ok -eq 0 ] && log_warn "无可用 Node.js 镜像"
    [ $nvm_ok -eq 0 ] && log_warn "无可用 NVM 镜像"
    
    log_success "镜像检测完成"
}

#===============================================================================
# 3. 选择最佳镜像
#===============================================================================
select_best_mirrors() {
    log_step "3/5 选择最佳镜像..."
    
    # NPM
    for url in "https://registry.npmmirror.com" "https://npm.tuna.tsinghua.edu.cn" "https://registry.npmjs.org"; do
        if check_mirror "$url" 3; then
            NPM_BEST="$url"
            log_info "最佳 NPM: $NPM_BEST"
            break
        fi
    done
    [ -z "$NPM_BEST" ] && NPM_BEST="https://registry.npmjs.org"
    
    # GitHub
    for url in "https://ghproxy.com" "https://moeyy.cn" "https://mirror.ghproxy.com"; do
        if check_mirror "$url/https://github.com" 3; then
            GITHUB_BEST="$url"
            log_info "最佳 GitHub: $GITHUB_BEST"
            break
        fi
    done
    [ -z "$GITHUB_BEST" ] && log_warn "无可用 GitHub 加速"
    
    # Node.js
    for url in "https://mirrors.ustc.edu.cn/node" "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release"; do
        if check_mirror "$url" 3; then
            NODE_BEST="$url"
            log_info "最佳 Node.js: $NODE_BEST"
            break
        fi
    done
    
    log_success "镜像选择完成"
}

#===============================================================================
# 4. 运行安装脚本
#===============================================================================
run_install_script() {
    log_step "4/5 运行安装脚本..."
    echo
    
    if [ ! -f "$SCRIPT_DIR/$SCRIPT_NAME" ]; then
        log_error "安装脚本不存在: $SCRIPT_DIR/$SCRIPT_NAME"
        exit 1
    fi
    
    # 导出环境变量
    export OPENCLAW_NPM_MIRROR="$NPM_BEST"
    export OPENCLAW_GITHUB_MIRROR="$GITHUB_BEST"
    export OPENCLAW_NODE_MIRROR="$NODE_BEST"
    
    log_info "NPM_MIRROR=$NPM_BEST"
    [ -n "$GITHUB_BEST" ] && log_info "GITHUB_MIRROR=$GITHUB_BEST"
    [ -n "$NODE_BEST" ] && log_info "NODE_MIRROR=$NODE_BEST"
    echo
    
    if [[ "$SCRIPT_NAME" == *.sh ]]; then
        chmod +x "$SCRIPT_DIR/$SCRIPT_NAME"
        bash "$SCRIPT_DIR/$SCRIPT_NAME"
    elif [[ "$SCRIPT_NAME" == *.ps1 ]]; then
        powershell -ExecutionPolicy Bypass -File "$SCRIPT_DIR/$SCRIPT_NAME"
    fi
}

#===============================================================================
# 5. 验证安装
#===============================================================================
verify_installation() {
    log_step "5/5 验证安装..."
    
    if command -v openclaw &> /dev/null; then
        log_success "OpenClaw 已安装"
    else
        log_error "OpenClaw 未正确安装"
        exit 1
    fi
    
    if command -v node &> /dev/null; then
        log_success "Node.js 已安装: $(node -v)"
    else
        log_error "Node.js 未安装"
        exit 1
    fi
}

#===============================================================================
# 主流程
#===============================================================================
main() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   OpenClaw 主安装脚本 🐾              ║${NC}"
    echo -e "${CYAN}║   自动检测环境 + 验证镜像 + 一键安装  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
    
    detect_environment
    check_all_mirrors
    select_best_mirrors
    run_install_script
    verify_installation
    
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
