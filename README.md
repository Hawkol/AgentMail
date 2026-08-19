# 📬 Agent Mail — AI 专属邮箱服务

基于腾讯 **Agent Mail**（`@tencent-qqmail/agently-cli`）的 AI 邮件服务，独立部署，与游戏项目完全分离。

## 它能做什么

- **收发邮件**：拥有专属地址 `your-agent@agent.qq.com`，可收发任意邮箱的邮件
- **邮件处理闭环**：收到白名单发件人的邮件 → AI 会话（headless）理解并生成回复 → 自动回信（≤5 分钟）
- **任务完成通知**：AI 完成任务后自动发邮件到你邮箱
- **可视化控制台**：浏览器配置/状态/日志/测试，无需命令行

## 目录结构

```
E:\AgentMail\
├─ server.js            # Node 常驻服务（轮询/outbox/通知/Web 控制台，无窗口）
├─ config.json          # 配置（含 webToken 令牌，⚠️ 不入库）
├─ config.example.json  # 配置模板（入库）
├─ setup.ps1            # 一键安装配置（Node/CLI/OAuth 授权）
├─ start-server.vbs     # 隐藏窗口启动器（计划任务登录时调用）
├─ README.md            # 本文件
├─ docs/
│  └─ USAGE.md          # 详细使用说明
├─ cli-setup.md         # 官方 CLI 文档
├─ archive/             # 废弃的 PowerShell 脚本（被 server.js 取代）
└─ 运行数据（不入库）:
   ├─ inbox/            # 收到的邮件（JSON，含纯文本正文）
   ├─ outbox/           # AI 生成的待发送回复（sent/ failed/）
   ├─ logs/             # server/poll/send/headless 日志
   ├─ notifications/    # 任务完成通知队列（sent/ failed/）
   ├─ seen.log          # 已处理邮件 ID（去重）
   └─ triggered.log     # 已触发 AI 处理的邮件 ID
```

## 快速开始（首次部署，一次性）

```powershell
# 1. 安装 Node.js（如未安装）：https://nodejs.org/zh-cn（LTS）
# 2. 运行安装配置脚本（自动装 CLI + OAuth 授权）
powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentMail\setup.ps1
#    - 按提示在浏览器完成 QQ 授权（只此一次）
# 3. 启动服务
schtasks /run /tn "DSH-Mail-Server"
# 4. 打开控制台
#    浏览器访问 http://127.0.0.1:3180
#    令牌：E:\AgentMail\config.json 里的 webToken（首次启动自动生成）
```

## 服务管理

| 操作 | 命令 |
|---|---|
| 启动 | `schtasks /run /tn "DSH-Mail-Server"` |
| 停止 | `schtasks /end /tn "DSH-Mail-Server"` |
| 开机自启 | 已注册（登录时自动启动，任务计划程序可查看/禁用）|
| 查看状态 | 控制台或 `E:\AgentMail\logs\server.log` |

### 启动机制（start-server.vbs 的作用）

计划任务 `DSH-Mail-Server` 在**登录时**调用 `start-server.vbs`，它用 `WScript.Shell.Run(..., 0, False)` 以**隐藏窗口**方式静默启动 `server.js`（轮询 + Web 控制台服务），开机全程无弹窗。

- 该文件仅 5 行，**必须保持纯 ASCII**（VBScript 引擎按 ANSI 读取，含中文注释会导致 `800A0408 无效字符` 弹窗）
- 验证服务是否运行：`Get-NetTCPConnection -LocalPort 3180 -State Listen`

## 邮件处理闭环流程

```
白名单邮箱发信 → your-agent@agent.qq.com
  → 服务每 2 分钟轮询（+list/+read）
  → 白名单过滤 → 落盘 inbox/msg_xxx.json
  → 触发 headless 会话：读信 → 理解 → 生成回复 → 写入 outbox/
  → 服务读取 outbox → 两步确认发送 → 归档 sent/
  → 发件人收到回复（≤5 分钟）
```

## 安全说明

- **OAuth token**：存于 Windows 凭据管理器（DPAPI 加密），无明文
- **Web 控制台**：仅绑定 127.0.0.1 + Bearer token 鉴权（`webToken`）
- **白名单**：仅 `you@example.com`、`your-agent@agent.qq.com` 可驱动 AI 处理
- **数据隔离**：运行数据（邮件内容/日志）不入 git 仓库（见 .gitignore）
- ⚠️ `config.json` 含令牌与邮箱配置，**严禁推送到远程仓库**

## 故障排查

| 现象 | 处理 |
|---|---|
| 控制台打不开 | 服务是否运行？`schtasks /run /tn "DSH-Mail-Server"`；端口 3180 是否被占用 |
| 控制台 401 | 在页面顶部输入 config.json 的 webToken 并保存 |
| 邮件没回复 | 看 `logs/poll.log`（轮询）、`logs/headless.log`（AI 处理）；回复在 `outbox/failed/` 说明发送失败 |
| 收件箱乱了 | `seen.log` 记录已处理 ID，删除某行可让该邮件重新处理 |

## 版本记录

- `af37ab4` 独立部署（从游戏工作区剥离）
- `21eddc4` config.json 移出版本库（含 webToken 凭据）
- `e9c4426` 修复 config.example.json 编码

详细使用说明见 [docs/USAGE.md](docs/USAGE.md)。
