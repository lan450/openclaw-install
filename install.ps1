# OpenClaw 一键安装脚本 (Windows PowerShell)
# 作者: 小爪

param(
    [switch]$SkipNodeInstall,
    [switch]$SkipGatewayStart
)

$ErrorActionPreference = "Stop"

# 颜色函数
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  OpenClaw 一键安装脚本 (Windows)" -ForegroundColor Magenta
Write-Host "  作者: 小爪 🐾" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host

#=============================================
# 1. 检测操作系统
#=============================================
Write-Info "检测操作系统..."
$OS = $PSVersionTable.OS
if ($OS -match "Windows") {
    Write-Success "检测到 Windows"
} else {
    Write-Error "仅支持 Windows，请使用 install.sh (WSL/macOS/Linux)"
    exit 1
}

#=============================================
# 2. 网络检测
#=============================================
Write-Info "检测网络连接..."

function Test-Url {
    param([string]$Url, [int]$Timeout=5)
    try {
        $result = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $Timeout -UseBasicParsing -ErrorAction SilentlyContinue
        return $result.StatusCode -in @(200, 301, 302)
    } catch {
        return $false
    }
}

$testUrls = @(
    "https://registry.npmmirror.com",
    "https://github.com",
    "https://nodejs.org"
)

foreach ($url in $testUrls) {
    if (Test-Url -Url $url) {
        Write-Success "✓ $url 可访问"
    } else {
        Write-Warn "✗ $url 无法访问"
    }
}

#=============================================
# 3. 安装 Node.js
#=============================================
function Install-NodeJS {
    Write-Info "检查 Node.js..."
    
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $version = node --version
        Write-Success "Node.js 已安装: $version"
        
        # 检查版本
        $major = [int]($version -replace 'v', '' -split '\.')[0]
        if ($major -lt 18) {
            Write-Warn "Node.js 版本过低 ($version)，建议升级"
            $env:CHOICE = Read-Host "是否升级? (y/N)"
            if ($env:CHOICE -ne 'y') { return }
        } else {
            return
        }
    }
    
    Write-Info "正在安装 Node.js 22..."
    
    # 下载 nvm-windows
    $nvmDir = "$env:APPDATA\nvm"
    if (-not (Test-Path $nvmDir)) {
        Write-Info "下载 nvm for Windows..."
        $nvmZip = "$env:TEMP\nvm.zip"
        Invoke-WebRequest -Uri "https://github.com/coreybutler/nvm-windows/releases/download/1.77.1/nvm-setup.zip" -OutFile $nvmZip -UseBasicParsing
        Expand-Archive -Path $nvmZip -DestinationPath "$env:TEMP\nvm" -Force
        Start-Process -FilePath "$env:TEMP\nvm\nvm-setup.exe" -Wait
        Remove-Item $nvmZip, "$env:TEMP\nvm" -Recurse -Force
    }
    
    # 使用 nvm 安装 Node.js
    & "$nvmDir\nvm.exe" install 22
    & "$nvmDir\nvm.exe" use 22
    
    # 刷新环境变量
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    Write-Success "Node.js 安装完成: $(node --version)"
}

if (-not $SkipNodeInstall) {
    Install-NodeJS
}

#=============================================
# 4. 配置 NPM 镜像
#=============================================
Write-Info "配置 NPM 镜像..."

$mirrors = @(
    "https://registry.npmmirror.com",
    "https://npm.tuna.tsinghua.edu.cn",
    "https://registry.npmjs.org"
)

$bestMirror = ""
$bestTime = 999

foreach ($mirror in $mirrors) {
    Write-Info "测试 $mirror..."
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if (Test-Url -Url $mirror -Timeout 3) {
        $sw.Stop()
        $time = $sw.ElapsedMilliseconds
        Write-Info "  响应时间: ${time}ms"
        if ($time -lt $bestTime) {
            $bestTime = $time
            $bestMirror = $mirror
        }
    }
}

if ($bestMirror) {
    npm config set registry $bestMirror
    Write-Success "已配置 NPM 镜像: $bestMirror"
} else {
    Write-Warn "无可用镜像，使用默认"
}

#=============================================
# 5. 配置 GitHub 加速
#=============================================
Write-Info "配置 GitHub 加速..."

$ghMirrors = @(
    "https://ghproxy.com",
    "https://mirror.ghproxy.com",
    "https://moeyy.cn"
)

$bestGhMirror = ""
foreach ($mirror in $ghMirrors) {
    if (Test-Url -Url "$mirror/https://github.com" -Timeout 3) {
        $bestGhMirror = $mirror
        break
    }
}

if ($bestGhMirror) {
    git config --global url."$bestGhMirror".insteadOf "https://github.com"
    Write-Success "已配置 GitHub 加速: $bestGhMirror"
} else {
    Write-Warn "无可用 GitHub 加速镜像"
}

#=============================================
# 6. 安装 OpenClaw
#=============================================
Write-Info "安装 OpenClaw..."

$openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawCmd) {
    Write-Success "OpenClaw 已安装: $(openclaw --version)"
    
    $env:CHOICE = Read-Host "是否更新? (y/N)"
    if ($env:CHOICE -ne 'y') {
        Write-Info "跳过更新"
    } else {
        npm install -g openclaw --force
    }
} else {
    npm install -g openclaw
}

if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    Write-Success "OpenClaw 安装成功!"
} else {
    Write-Error "OpenClaw 安装失败"
    exit 1
}

#=============================================
# 7. 初始化
#=============================================
Write-Info "初始化 OpenClaw..."

if (Test-Path "$env:USERPROFILE\.openclaw") {
    Write-Info "OpenClaw 已初始化"
    $env:CHOICE = Read-Host "是否重新初始化? (y/N)"
    if ($env:CHOICE -ne 'y') {
        Write-Info "跳过初始化"
    } else {
        openclaw init
    }
} else {
    openclaw init
}

Write-Success "初始化完成"

#=============================================
# 8. 启动 Gateway
#=============================================
if (-not $SkipGatewayStart) {
    $env:CHOICE = Read-Host "是否启动 Gateway? (Y/n)"
    if ($env:CHOICE -ne 'n') {
        Write-Info "启动 Gateway..."
        openclaw gateway start
        Write-Success "Gateway 已启动"
    }
}

Write-Host
Write-Host "========================================" -ForegroundColor Magenta
Write-Success "安装完成! 🎉" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host
Write-Host "常用命令:"
Write-Host "  openclaw gateway start   # 启动服务"
Write-Host "  openclaw gateway status # 查看状态"
Write-Host "  openclaw help           # 查看帮助"
Write-Host
