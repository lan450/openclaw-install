# OpenClaw 一键安装脚本

English | [中文](./README.md)

Automated installation script for OpenClaw with optimized Chinese network mirrors.

## Quick Install

### macOS / Linux

```bash
curl -sSL https://raw.githubusercontent.com/lan450/openclaw-install/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/lan450/openclaw-install/main/install.ps1 | iex
```

## Features

- 🌐 **Network Detection** - Tests connectivity to various mirrors
- 🔄 **Auto Mirror Selection** - Picks the fastest available mirror
- 📦 **Node.js Auto-Install** - Installs Node.js 22 if needed
- 🇨🇳 **Chinese Mirrors Optimized**
  - NPM: npmmirror.com, tuna.tsinghua.edu.cn
  - GitHub: ghproxy.com, moeyy.cn
  - Node.js: USTC mirror

## Tested Mirrors

| Service | Mirror | Status |
|---------|--------|--------|
| NPM | registry.npmmirror.com | ✅ |
| NPM | npm.tuna.tsinghua.edu.cn | ✅ |
| GitHub | ghproxy.com | ✅ |
| GitHub | moeyy.cn | ✅ |
| Node.js | mirrors.ustc.edu.cn | ✅ |

## Manual Installation

If you prefer manual installation:

```bash
# 1. Install Node.js 18+
curl -fsSL https://fnm.vercel.app/install | bash
fnm install 22
fnm use 22

# 2. Set NPM mirror
npm config set registry https://registry.npmmirror.com

# 3. Install OpenClaw
npm install -g openclaw

# 4. Initialize
openclaw init
openclaw gateway start
```

## Requirements

- macOS / Linux / Windows (with WSL or PowerShell)
- curl or wget
- Git

## Usage

```bash
# Start gateway
openclaw gateway start

# Check status
openclaw gateway status

# View logs
openclaw gateway logs

# Stop gateway
openclaw gateway stop
```

## Support

- Documentation: https://docs.openclaw.ai
- Discord: https://discord.com/invite/clawd
- GitHub: https://github.com/openclaw/openclaw

---

*Maintained by 小爪 🐾*
