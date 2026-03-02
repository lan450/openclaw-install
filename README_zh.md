# OpenClaw 一键安装脚本

[English](./README_en.md) | 中文

自动化安装脚本，自动配置国内镜像 OpenClaw。

，安装## 一键安装

### macOS / Linux

```bash
curl -sSL https://raw.githubusercontent.com/lan450/openclaw-install/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/lan450/openclaw-install/main/install.ps1 | iex
```

## 功能特性

- 🌐 **网络检测** - 测试到各镜像的连接状态
- 🔄 **自动选优** - 智能选择最快的可用镜像
- 📦 **自动装 Node.js** - 如未安装则自动安装 Node.js 22
- 🇨🇳 **国内镜像优化**
  - NPM: npmmirror.com, tuna.tsinghua.edu.cn
  - GitHub: ghproxy.com, moeyy.cn
  - Node.js: 中科大镜像

## 已验证镜像

| 服务 | 镜像 | 状态 |
|------|------|------|
| NPM | registry.npmmirror.com | ✅ 可用 |
| NPM | npm.tuna.tsinghua.edu.cn | ✅ 可用 |
| GitHub | ghproxy.com | ✅ 可用 |
| GitHub | moeyy.cn | ✅ 可用 |
| Node.js | mirrors.ustc.edu.cn | ✅ 可用 |

## 手动安装

如果想手动安装：

```bash
# 1. 安装 Node.js 18+
curl -fsSL https://fnm.vercel.app/install | bash
fnm install 22
fnm use 22

# 2. 配置 NPM 镜像
npm config set registry https://registry.npmmirror.com

# 3. 安装 OpenClaw
npm install -g openclaw

# 4. 初始化
openclaw init
openclaw gateway start
```

## 系统要求

- macOS / Linux / Windows (需要 WSL 或 PowerShell)
- curl 或 wget
- Git

## 使用方法

```bash
# 启动服务
openclaw gateway start

# 查看状态
openclaw gateway status

# 查看日志
openclaw gateway logs

# 停止服务
openclaw gateway stop
```

## 相关链接

- 文档: https://docs.openclaw.ai
- Discord: https://discord.com/invite/clawd
- GitHub: https://github.com/openclaw/openclaw

---

*由小爪 🐾 维护*
