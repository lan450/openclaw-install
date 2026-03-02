# 🇨🇳 OpenClaw 国内一键安装脚本

> 在国内网络环境下快速安装 OpenClaw

## 功能特性

- 🎯 **自动检测最佳镜像** - 每个环节都验证国内连接
- 🌍 **智能镜像切换** - NPM/GitHub/NVM 自动选最优
- 🔄 **失败自动重试** - 某镜像不可用时自动切换
- 🖥️ **跨平台支持** - macOS / Linux / Windows

## 快速开始

### macOS / Linux

```bash
curl -sSL https://raw.githubusercontent.com/lan450/openclaw-install/main/install.sh | bash
```

或者指定安装目录：

```bash
curl -sSL https://raw.githubusercontent.com/lan450/openclaw-install/main/install.sh | bash -s -- --dir ~/openclaw
```

### Windows (管理员 PowerShell)

```powershell
irm https://raw.githubusercontent.com/lan450/openclaw-install/main/install.ps1 | iex
```

或者保存后执行：

```powershell
irm https://raw.githubusercontent.com/lan450/openclaw-install/main/install.ps1 -o install.ps1
.\install.ps1
```

## 安装后

```bash
cd ~/openclaw

# 初始化配置
openclaw init

# 启动
openclaw start
```

## 镜像说明

| 类别 | 备用镜像 |
|------|---------|
| NPM | registry.npmmirror.com, npmjs.org |
| GitHub | moeyy.cn, github.com |
| Node.js | nodejs.org, nvm.uihtm.com |

## 常见问题

### Q: 安装失败怎么办？
A: 检查网络连接，或手动指定镜像后重试。

### Q: Node.js 版本过低？
A: 脚本会自动安装 Node.js 22 LTS。

### Q: Windows 上提示权限不足？
A: 请以管理员身份运行 PowerShell。

## 作者

- Author: lan450
- GitHub: https://github.com/lan450/openclaw-install

## 许可证

MIT
