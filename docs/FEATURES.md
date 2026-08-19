# 📋 Agent Mail 项目功能清单

> 覆盖：常驻服务（server.js）+ Web 控制台 + DSH 插件（dsh-tool-mail）+ 配套工具。
> 更新时间：2026-08

---

## 一、邮件收发能力（核心）

| 功能 | 说明 | 入口 |
|---|---|---|
| 发送邮件 | 任意收件人，自动两步确认（token → 重发）| 插件 `mail_send` / 控制台"测试发送" |
| 收件轮询 | 每 N 分钟自动拉取收件箱（可配置间隔）| 服务自动 |
| 读取邮件 | 完整正文，HTML 自动转纯文本 | 插件 `mail_read` |
| 列收件箱 | 时间/发件人/主题/ID | 插件 `mail_list` |
| 回复邮件 | 自动回复原发件人，主题加"回复：" | 插件 `mail_reply` |
| 转发邮件 | 转发给新收件人，可附备注 | 插件 `mail_forward` |
| 搜索邮件 | 关键词搜主题+正文，可按发件人/文件夹过滤 | 插件 `mail_search` |
| 删除邮件 | 默认软删（回收站 30 天可恢复）；可永久删除 | 插件 `mail_delete` |

> 所有写操作均自动处理 Agent Mail 的**两步确认**流程。

## 二、邮件处理闭环（无人值守）

```
白名单邮箱发信 → agent 邮箱
  → 服务轮询（每 2 分钟）→ 白名单过滤 → 落盘 inbox/
  → 触发 headless AI 会话：读信 → 理解 → 生成回复 → 写入 outbox/
  → 服务读取 outbox → 发送回复 → 归档 sent/
  → 发件人收到回复（≤5 分钟）
```

| 环节 | 功能点 |
|---|---|
| 白名单 | 仅 `allowedSenders` 中的邮箱能驱动 AI 处理，其余忽略 |
| 收件归档 | 每封邮件存为 JSON（含纯文本正文）到 `inbox/` |
| AI 处理 | headless 会话理解邮件内容，可执行指令、生成内容 |
| 回复队列 | outbox 机制：AI 只生成内容，服务负责发送（绕开 AI 沙箱限制）|
| 去重 | `seen.log` 记录已处理邮件 ID，避免重复 |

## 三、任务完成通知

| 功能 | 说明 |
|---|---|
| 通知队列 | 往 `notifications/` 写 JSON（title/content），服务自动发送到收件人 |
| 自动发送 | 邮件送达 `targetEmail`，文件归档 `notifications/sent/` |
| 失败处理 | 发送失败移入 `notifications/failed/` 并记录日志 |

## 四、Web 控制台（http://127.0.0.1:3180）

| 功能 | 说明 |
|---|---|
| 可视化配置 | 收件人 / 白名单 / 轮询间隔 / 自动处理开关，保存即生效 |
| 状态卡片 | 上次轮询时间 / 收件箱待处理数 / 待发送回复数 / headless 状态 |
| 测试发送 | 填收件人/主题/正文一键发信 |
| 实时日志 | poll / send / headless 日志滚动显示（15 秒刷新）|
| 安全鉴权 | Bearer token（webToken，首次启动自动生成）|

## 五、DSH 插件（dsh-tool-mail，7 个工具）

运行在 DSH **host 进程**（有网络，无沙箱限制），对话中直接调用：

| 工具 | 功能 |
|---|---|
| `mail_send` | 发送邮件 |
| `mail_list` | 列收件箱 |
| `mail_read` | 读正文 |
| `mail_reply` | 回复 |
| `mail_delete` | 软删 / 永久删 |
| `mail_search` | 关键词搜索 |
| `mail_forward` | 转发 |

## 六、配套与运维

| 功能 | 说明 |
|---|---|
| 一键安装配置 | `setup.ps1`：Node 检测（含 winget 自动装）、CLI 安装、OAuth 浏览器授权、验证 |
| 隐藏窗口自启 | `start-server.vbs` + 计划任务 `DSH-Mail-Server`，登录时静默启动服务 |
| 多邮箱切换 | `agently-cli auth logout` + `auth login` 重新授权（服务/插件自动跟随）|
| 服务管理 | 计划任务启停 / 日志查看 / 配置热更新（控制台保存即生效）|

## 七、安全机制

| 机制 | 说明 |
|---|---|
| 凭据存储 | OAuth token 存 Windows 凭据管理器（DPAPI 加密），无明文 |
| 控制台鉴权 | 仅 127.0.0.1 监听 + Bearer token |
| 白名单 | 只有授权邮箱能驱动 AI 处理 |
| 数据隔离 | 运行数据（邮件/日志/队列）全部 gitignore，不入库 |
| 配置隔离 | config.json（含 webToken）不入库，只提供 config.example.json 模板 |
| 插件纯净 | 插件不硬编码邮箱/token，凭据由本机授权提供 |

## 八、技术特性

- **纯 ESM JavaScript**，免编译，跨平台（Node ≥ 18）
- CLI 调用走 **node 直调 run.js**（避免 .cmd shim 参数缺陷）
- `dsh.bundle` 声明 + `cordis.patch.yml`（insert 语法）→ profile 自动加载
- 编码健壮性：脚本强制 UTF-8 / 纯 ASCII（避免 GBK/BOM 坑）
- 错误可读：CLI 失败信息包含服务端 JSON 详情（如配额 429）

---

## 扩展方向（未实现，可后续开发）

- 定时邮件（`mail_schedule`）
- 多邮箱并存（当前 CLI 单账号）
- 163/QQ 个人邮箱 SMTP 渠道
- 邮件附件收发
- 微信通知渠道（Server酱）
