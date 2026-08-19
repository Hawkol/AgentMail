# ============================================================
# Agent Mail CLI 一键安装配置脚本（腾讯 QQ 邮箱 Agent Mail）
# 用法：在 PowerShell 中运行本脚本，按提示操作
#   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1
#
# 流程：检测 Node → 安装 CLI → OAuth 浏览器授权 → 验证 → 导出帮助日志
# 日志输出到 E:\AgentMail\logs\
# ============================================================

$ErrorActionPreference = 'Continue'
$LogDir = 'E:\AgentMail\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Agent Mail CLI 安装配置" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# ---------- 1. 检查 Node.js ----------
Write-Host "`n[1/4] 检查 Node.js ..." -ForegroundColor Cyan
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    # 检查常见安装路径（可能装了但不在 PATH）
    $nodePaths = @(
        "$env:ProgramFiles\nodejs\node.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe",
        "${env:ProgramFiles(x86)}\nodejs\node.exe"
    )
    $found = $nodePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($found) {
        $env:Path = "$(Split-Path $found);$env:Path"
        $node = Get-Command node -ErrorAction SilentlyContinue
    }
}
if (-not $node) {
    Write-Host "[提示] 未检测到 Node.js。" -ForegroundColor Yellow
    Write-Host "  方式1（自动）：尝试 winget 安装 ..." -ForegroundColor Yellow
    try {
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-File "$LogDir\winget.log"
        # winget 安装后刷新 PATH
        $env:Path = "$env:ProgramFiles\nodejs;$env:LOCALAPPDATA\Programs\nodejs;$env:Path"
        $node = Get-Command node -ErrorAction SilentlyContinue
    } catch { }
    if (-not $node) {
        Write-Host "  方式2（手动）：请到 https://nodejs.org/zh-cn 下载 LTS 版安装（一路默认），" -ForegroundColor Yellow
        Write-Host "  装完后重新运行本脚本。" -ForegroundColor Yellow
        Read-Host "按回车退出"
        exit 1
    }
}
Write-Host "  Node.js 版本：$(& node --version)" -ForegroundColor Green

# ---------- 2. 安装 CLI ----------
Write-Host "`n[2/4] 安装 @tencent-qqmail/agently-cli ..." -ForegroundColor Cyan
& npm install -g @tencent-qqmail/agently-cli 2>&1 | Out-File "$LogDir\npm-install.log" -Encoding utf8
if ($LASTEXITCODE -ne 0) {
    Write-Host "  全局安装失败，尝试用户级安装 ..." -ForegroundColor Yellow
    npm config set prefix "$env:APPDATA\npm" 2>&1 | Out-Null
    & npm install -g @tencent-qqmail/agently-cli 2>&1 | Out-File "$LogDir\npm-install-user.log" -Encoding utf8
    $env:Path = "$env:APPDATA\npm;$env:Path"
}
$cli = Get-Command agently-cli -ErrorAction SilentlyContinue
if (-not $cli) {
    Write-Host "[错误] agently-cli 安装失败！请查看日志：$LogDir\npm-install*.log" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}
Write-Host "  agently-cli 已安装：$($cli.Source)" -ForegroundColor Green

# ---------- 3. OAuth 授权 ----------
Write-Host "`n[3/4] OAuth 授权登录 ..." -ForegroundColor Cyan
Write-Host "  下方会输出一个授权链接，请【点击或复制到浏览器】完成授权，" -ForegroundColor Yellow
Write-Host "  授权成功后命令会自动退出。" -ForegroundColor Yellow
& agently-cli auth login 2>&1 | Tee-Object -FilePath "$LogDir\auth-login.log"

# ---------- 4. 验证 ----------
Write-Host "`n[4/4] 验证授权 ..." -ForegroundColor Cyan
& agently-cli '+me' 2>&1 | Tee-Object -FilePath "$LogDir\me.log"

# ---------- 5. 导出帮助日志（供后续校准发送命令） ----------
Write-Host "`n导出 CLI 帮助信息到日志 ..." -ForegroundColor Cyan
& agently-cli --help 2>&1 | Out-File "$LogDir\cli-help.txt" -Encoding utf8
& agently-cli mail --help 2>&1 | Out-File "$LogDir\cli-help-mail.txt" -Encoding utf8
& agently-cli send --help 2>&1 | Out-File "$LogDir\cli-help-send.txt" -Encoding utf8

Write-Host "`n======================================" -ForegroundColor Green
Write-Host "  安装配置流程结束" -ForegroundColor Green
Write-Host "  若上面出现『邮箱地址 xxx 已授权成功』即成功" -ForegroundColor Green
Write-Host "  下一步：运行 E:\DeepWork\notify\send-notify.ps1 发送测试邮件" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Read-Host "按回车退出"

