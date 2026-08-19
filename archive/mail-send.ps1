# ============================================================
# 通用邮件发送器（Agent Mail，含两步确认流程）
# 用法：
#   powershell -NoProfile -ExecutionPolicy Bypass -File mail-send.ps1 `
#     -To "someone@example.com" -Subject "标题" -Body "正文"
# 返回：成功时 $LASTEXITCODE = 0；日志写入 E:\DeepWork\mail-agent\logs\send.log
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$To,
    [string]$Subject = '',
    [string]$Body = '',
    [string]$BodyFile = ''
)

# 强制以 UTF-8 解码子进程输出（避免无控制台环境下的 GBK 乱码）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$LogDir = 'E:\DeepWork\mail-agent\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -Append -FilePath (Join-Path $LogDir 'send.log') -Encoding utf8
}

if (-not $Subject) { $Subject = '（无主题）' }
if (-not $Body) { $Body = '（无正文）' }

# ---------- CLI 可用性（优先 .cmd shim） ----------
$cliPath = Join-Path $env:APPDATA 'npm\agently-cli.cmd'
if (-not (Test-Path $cliPath)) {
    $cli = Get-Command agently-cli -ErrorAction SilentlyContinue
    if ($cli) { $cliPath = $cli.Source }
}
if (-not (Test-Path $cliPath)) {
    Write-Log "未找到 agently-cli"
    exit 1
}

# ---------- CLI 调用：优先 node 直调 JS 入口（避免 .cmd shim 在 PS5.1 下的参数转义缺陷）----------
$runJs = Join-Path $env:APPDATA 'npm\node_modules\@tencent-qqmail\agently-cli\scripts\run.js'
$useNode = Test-Path $runJs

function Invoke-Cli([string[]]$cliArgs) {
    if ($useNode) {
        return (& node $runJs @cliArgs 2>$null | Out-String)
    }
    return (& $cliPath @cliArgs 2>$null | Out-String)
}

# ---------- 发送（两步确认） ----------
$cmdArgs = @('message', '+send', '--to', $To, '--subject', $Subject)
$bodyFileRel = $null
if ($BodyFile -and (Test-Path $BodyFile)) {
    # CLI 要求 --body-file 为相对路径：切换到正文文件所在目录
    $bodyFileRel = Split-Path $BodyFile -Leaf
    Push-Location (Split-Path $BodyFile -Parent)
    $cmdArgs += @('--body-file', $bodyFileRel)
} else {
    $cmdArgs += @('--body', $Body)
}

$out1 = Invoke-Cli $cmdArgs
if ($bodyFileRel) { Pop-Location }
$out1 | Out-File -Append -FilePath (Join-Path $LogDir 'send.log') -Encoding utf8

$token = $null
if ($out1 -match '"confirmation_token"\s*:\s*"([^"]+)"') {
    $token = $Matches[1]
}

if ($token) {
    Write-Log "需要确认，携带 confirmation_token 重新发送 ..."
    $cmdArgs2 = @($cmdArgs) + @('--confirmation-token', $token)
    if ($bodyFileRel) { Push-Location (Split-Path $BodyFile -Parent) }
    $out2 = Invoke-Cli $cmdArgs2
    if ($bodyFileRel) { Pop-Location }
    $out2 | Out-File -Append -FilePath (Join-Path $LogDir 'send.log') -Encoding utf8
    if (($LASTEXITCODE -eq 0) -and ($out2 -notmatch '"confirmation_required"\s*:\s*true')) {
        Write-Log "发送成功: To=$To Subject=$Subject"
        exit 0
    }
    Write-Log "发送失败: To=$To Subject=$Subject"
    exit 1
}

if (($LASTEXITCODE -eq 0) -and ($out1 -notmatch '"confirmation_required"\s*:\s*true')) {
    Write-Log "发送成功: To=$To Subject=$Subject"
    exit 0
}
Write-Log "发送失败: To=$To Subject=$Subject"
exit 1
