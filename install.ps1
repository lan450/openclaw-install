# OpenClaw 国内一键安装脚本
# 测试环境: Windows PowerShell
# 作者: lan450

param(
    [string]$InstallDir = "$env:USERPROFILE\openclaw",
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

# ========== 配置 ==========
$Script:OpenclawRepo = "https://github.com/openclaw/openclaw"

# 国内镜像列表
$Script:NpmMirrors = @(
    "https://registry.npmmirror.com",
    "https://registry.npmjs.org"
)

$Script:GithubMirrors = @(
    "https://moeyy.cn/https://github.com",
    "https://github.com"
)

# ========== 颜色输出 ==========
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $colors = @{
        "Red"     = [ConsoleColor]::Red
        "Green"   = [ConsoleColor]::Green
        "Yellow"  = [ConsoleColor]::Yellow
        "Blue"    = [ConsoleColor]::Cyan
        "White"   = [ConsoleColor]::White
    }
    Write-Host $Message -ForegroundColor $colors[$Color]
}

function Log-Info { Write-ColorOutput "[INFO] $args" "Blue" }
function Log-Success { Write-ColorOutput "[OK] $args" "Green" }
function Log-Warn { Write-ColorOutput "[WARN] $args" "Yellow" }
function Log-Error { Write-ColorOutput "[ERROR] $args" "Red" }

# ========== 网络测试 ==========
function Test-Url {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 5 -UseBasicParsing
        return $response.StatusCode -in @(200, 301, 302)
    } catch {
        return $false
    }
}

# ========== 选择最佳镜像 ==========
function Find-BestMirror {
    param([string]$Name, [string[]]$Mirrors)
    
    Log-Info "检测 $Name 镜像..."
    foreach ($mirror in $Mirrors) {
        if (Test-Url $mirror) {
            Log-Success "使用 $mirror"
            return $mirror
        }
    }
    Log-Error "所有 $Name 镜像均不可用"
    return $null
}

# ========== 检测 Node.js ==========
function Test-NodeInstalled {
    try {
        $version = node --version
        if ($version -match "v(\d+)\.") {
            return [int]$Matches[1] -ge 22
        }
    } catch {}
    return $false
}

# ========== 安装 Node.js ==========
function Install-Node {
    if (Test-NodeInstalled) {
        Log-Success "Node.js $(node --version) 已安装"
        return
    }
    
    Log-Warn "需要安装 Node.js 22+"
    
    # 检测 winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Log-Info "使用 winget 安装 Node.js 22..."
        winget install OpenJS.NodeJS.LTS -v 22.14.0 --silent --accept-package-agreements --accept-source-agreements
    } else {
        # 手动下载
        Log-Info "手动下载 Node.js 22..."
        
        $nodeMirror = Find-BestMirror "Node.js" @("https://nodejs.org", "https://nvm.uihtm.com")
        if (-not $nodeMirror) { $nodeMirror = "https://nodejs.org" }
        
        $url = "$nodeMirror/dist/v22.14.0/node-v22.14.0-x64.msi"
        $output = "$env:TEMP\node.msi"
        
        Log-Info "下载: $url"
        Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
        
        Log-Info "安装中..."
        Start-Process msiexec.exe -ArgumentList "/i", $output, "/quiet", "/norestart" -Wait
        Remove-Item $output -Force
        
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    
    Log-Success "Node.js 安装完成: $(node --version)"
}

# ========== 配置 NPM 镜像 ==========
function Setup-NpmMirror {
    $npmMirror = Find-BestMirror "NPM" $Script:NpmMirrors
    if (-not $npmMirror) { $npmMirror = "https://registry.npmjs.org" }
    
    npm config set registry $npmMirror
    Log-Success "NPM 镜像已配置: $npmMirror"
}

# ========== 安装 OpenClaw ==========
function Install-Openclaw {
    Log-Info "安装 OpenClaw 到 $InstallDir..."
    
    # 创建目录
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    Set-Location $InstallDir
    
    # 下载源码
    $githubMirror = Find-BestMirror "GitHub" $Script:GithubMirrors
    if (-not $githubMirror) { $githubMirror = "https://github.com" }
    
    $downloadUrl = "$githubMirror/openclaw/openclaw/archive/refs/heads/main.zip"
    $zipFile = "$InstallDir\main.zip"
    
    Log-Info "下载源码: $downloadUrl"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        
        Log-Info "解压中..."
        Expand-Archive -Path $zipFile -DestinationPath $InstallDir -Force
        
        # 处理目录
        if (Test-Path "$InstallDir\openclaw-main") {
            Get-ChildItem "$InstallDir\openclaw-main\*" | Move-Item -Destination $InstallDir -Force
            Remove-Item "$InstallDir\openclaw-main" -Recurse -Force
        }
        
        Remove-Item $zipFile -Force
    } catch {
        Log-Warn "下载失败，尝试 git 克隆..."
        if (Get-Command git -ErrorAction SilentlyContinue) {
            git clone $Script:OpenclawRepo .
        } else {
            Log-Error "git 未安装，请先安装 git"
            exit 1
        }
    }
    
    Log-Info "安装依赖..."
    npm install
    
    Log-Success "OpenClaw 安装完成!"
}

# ========== 主流程 ==========
function Main {
    Write-ColorOutput @"

╔═══════════════════════════════════════╗
║     OpenClaw 国内一键安装脚本 🐾        ║
╚═══════════════════════════════════════╝
"@ "Green"
    
    Log-Info "检测 Windows 版本..."
    
    # 1. 安装 Node.js
    Install-Node
    
    # 2. 配置 NPM 镜像
    Setup-NpmMirror
    
    # 3. 安装 OpenClaw
    Install-Openclaw
    
    Write-ColorOutput @"

╔═══════════════════════════════════════╗
║           安装完成! 🎉                ║
╚═══════════════════════════════════════╝
"@ "Green"
    
    Write-Host "下一步:" -ForegroundColor White
    Write-Host "  cd $InstallDir" -ForegroundColor Gray
    Write-Host "  npx openclaw init" -ForegroundColor Gray
    Write-Host ""
}

Main
