# ============================================================
# Agent Mail 收件轮询（P0 邮件处理闭环）
# 由计划任务 DSH-Mail-Poll 每 2 分钟运行：
#   1. 拉取收件箱列表（agently-cli message +list）
#   2. 按 seen.log 去重
#   3. 白名单过滤（config.allowedSenders）
#   4. 读取正文（+read），HTML 转纯文本，存入 inbox/
#   5. 对每个白名单新邮件，触发 headless 会话处理并回复
# 日志：E:\DeepWork\mail-agent\logs\poll.log / headless.log
# ============================================================

# 强制以 UTF-8 解码子进程输出（避免计划任务无控制台环境下的 GBK 乱码破坏 JSON）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CfgFile = 'E:\DeepWork\mail-agent\config.json'
if (-not (Test-Path $CfgFile)) { Write-Host "缺少配置文件: $CfgFile"; exit 1 }
$cfg = Get-Content $CfgFile -Raw -Encoding UTF8 | ConvertFrom-Json

$LogDir = $cfg.logDir
$InboxDir = $cfg.inboxDir
New-Item -ItemType Directory -Force -Path $LogDir, $InboxDir | Out-Null

function Write-Log($msg) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File -Append -FilePath (Join-Path $LogDir 'poll.log') -Encoding utf8
}

# ---------- 稳健文本读取（自动识别 UTF-8 / GBK，兼容 headless 写入的编码）----------
function Read-TextRobust([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        return $utf8.GetString($bytes)
    } catch {
        return [System.Text.Encoding]::GetEncoding(936).GetString($bytes)
    }
}

# ---------- CLI（优先 .cmd shim，避免 .ps1 shim 的 stderr 噪音）----------
$cliPath = Join-Path $env:APPDATA "npm\$($cfg.cli).cmd"
if (-not (Test-Path $cliPath)) {
    $cli = Get-Command $cfg.cli -ErrorAction SilentlyContinue
    if ($cli) { $cliPath = $cli.Source }
}
if (-not (Test-Path $cliPath)) { Write-Log "未找到 agently-cli，跳过本轮"; exit 0 }

# ---------- CLI 调用：优先 node 直调 JS 入口（避免 .cmd shim 在 PS5.1 下的参数转义缺陷）----------
$runJs = Join-Path $env:APPDATA 'npm\node_modules\@tencent-qqmail\agently-cli\scripts\run.js'
$useNode = Test-Path $runJs

function Invoke-Cli([string[]]$cliArgs) {
    if ($useNode) {
        return (& node $runJs @cliArgs 2>$null | Out-String)
    }
    return (& $cliPath @cliArgs 2>$null | Out-String)
}

# ---------- 已见 / 已触发 记录 ----------
$seen = @{}
if (Test-Path $cfg.seenFile) { Get-Content $cfg.seenFile | ForEach-Object { $seen[$_] = $true } }
$triggered = @{}
if (Test-Path $cfg.triggeredFile) { Get-Content $cfg.triggeredFile | ForEach-Object { $triggered[$_] = $true } }

# ---------- HTML 转纯文本 ----------
function ConvertTo-PlainText([string]$html) {
    if (-not $html) { return '' }
    $t = $html
    $t = $t -replace '<br\s*/?>', "`n" -replace '</p>', "`n" -replace '</div>', "`n" -replace '</tr>', "`n"
    $t = $t -replace '<[^>]+>', ''
    $t = $t -replace '&nbsp;', ' ' -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'"
    $t = $t -replace '[ \t]+', ' '
    $t = $t -replace '(\r?\n){3,}', "`n`n"
    return $t.Trim()
}

# ---------- 拉取列表 ----------
$out = Invoke-Cli @('message', '+list', '--limit', ([string]$cfg.pollLimit))
$parsed = $null
try { $parsed = $out | ConvertFrom-Json } catch { Write-Log "list 输出解析失败: $($_.Exception.Message)"; exit 1 }
if (-not $parsed.ok) { Write-Log "list 失败: $out"; exit 1 }

$newMailFiles = @()
foreach ($m in @($parsed.data.data)) {
    $id = [string]$m.message_id
    if ($seen[$id]) { continue }
    $seen[$id] = $true
    Add-Content -Path $cfg.seenFile -Value $id -Encoding utf8

    $from = [string]$m.from.email
    $allowed = @($cfg.allowedSenders) -contains $from
    if (-not $allowed) {
        Write-Log "忽略非白名单邮件: $from - $($m.subject)"
        continue
    }
    Write-Log "新邮件(白名单): $from - $($m.subject) [$id]"

    # 读取正文
    $out2 = Invoke-Cli @('message', '+read', '--id', $id)
    $detail = $null
    try { $detail = $out2 | ConvertFrom-Json } catch { }
    $bodyHtml = ''
    if ($detail -and $detail.ok) { $bodyHtml = [string]$detail.data.body }
    $bodyText = ConvertTo-PlainText $bodyHtml
    if (-not $bodyText) { $bodyText = [string]$m.snippet }

    $fileName = ($id -replace '[^A-Za-z0-9_-]', '_') + '.json'
    $mail = @{
        message_id = $id
        from       = $from
        from_name  = [string]$m.from.name
        subject    = [string]$m.subject
        time       = [string]$m.created_at
        body_text  = $bodyText
    }
    $mail | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $InboxDir $fileName) -Encoding utf8
    $newMailFiles += (Join-Path $InboxDir $fileName)
}

# ---------- 触发 headless 处理 ----------
if ($cfg.autoProcess -and $newMailFiles.Count -gt 0) {
    $dshCli = [string]$cfg.dshCli
    if (Test-Path $dshCli) {
        foreach ($file in $newMailFiles) {
            $mail = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
            $fromSafe = [string]$mail.from
            $subjectSafe = ([string]$mail.subject) -replace '[^\p{L}\p{N} ，。！？：；、\-]', '_'
            $prompt = ([string]$cfg.headlessPrompt).Replace('{FILE}', $file).Replace('{FROM}', $fromSafe).Replace('{SUBJECT}', $subjectSafe).Replace('{MAILID}', [string]$mail.message_id)

            Write-Log "触发 headless 处理: $file"
            # 先记录已触发（防止并发/中断导致重复触发），再启动会话
            Add-Content -Path $cfg.triggeredFile -Value ([string]$mail.message_id) -Encoding utf8
            Push-Location 'E:\DeepWork'
            & node $dshCli --profile headless $prompt 2>&1 | Out-File -Append -FilePath (Join-Path $LogDir 'headless.log') -Encoding utf8
            Pop-Location
            Write-Log "headless 处理结束: $file"
        }
    } else {
        Write-Log "dshCli 不存在，跳过自动处理: $dshCli"
    }
}

# ---------- 发送 outbox 回复（headless 只生成内容，这里负责真正发送）----------
$OutboxDir = $cfg.outboxDir
$OutboxSentDir = Join-Path $OutboxDir 'sent'
$OutboxFailDir = Join-Path $OutboxDir 'failed'
New-Item -ItemType Directory -Force -Path $OutboxDir, $OutboxSentDir, $OutboxFailDir | Out-Null

$replies = Get-ChildItem -Path $OutboxDir -Filter '*.json' -File -ErrorAction SilentlyContinue
foreach ($r in $replies) {
    try {
        $reply = Read-TextRobust $r.FullName | ConvertFrom-Json
        $to = [string]$reply.to
        $subject = [string]$reply.subject
        $body = [string]$reply.body
        if (-not $to) { throw '缺少 to 字段' }

        Write-Log "发送 outbox 回复: $($r.Name) -> $to"
        $sendArgs = @('-To', $to)
        if ($subject) { $sendArgs += @('-Subject', $subject) }
        $sendArgs += @('-Body', $body)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'E:\DeepWork\mail-agent\mail-send.ps1' @sendArgs 2>&1 | Out-File -Append -FilePath (Join-Path $LogDir 'outbox-send.log') -Encoding utf8

        if ($LASTEXITCODE -eq 0) {
            Move-Item $r.FullName (Join-Path $OutboxSentDir $r.Name) -Force
            Write-Log "outbox 回复已发送并归档: $($r.Name)"
        } else {
            Move-Item $r.FullName (Join-Path $OutboxFailDir $r.Name) -Force
            Write-Log "outbox 回复发送失败: $($r.Name)"
        }
    } catch {
        Write-Log "outbox 解析失败: $($r.Name) -> $($_.Exception.Message)"
        Move-Item $r.FullName (Join-Path $OutboxFailDir $r.Name) -Force
    }
}

Write-Log "本轮轮询完成（新增 $($newMailFiles.Count) 封白名单邮件）"
