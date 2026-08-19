# 📖 Agent Mail 使用说明

## 一、Web 控制台（推荐入口）

浏览器打开 **http://127.0.0.1:3180**

### 首次使用
1. 打开 `E:\AgentMail\config.json`，复制 `webToken` 字段的值（首次启动服务时自动生成）
2. 在控制台顶部"控制台令牌"输入框粘贴 → 点「保存令牌」（浏览器会记住，下次免输）
3. 页面显示状态卡片即连接成功

### 功能区
| 区域 | 功能 |
|---|---|
| 状态卡片 | 轮询间隔 / 上次轮询时间 / 收件箱待处理数 / 待发送回复数 / headless 状态 |
| 配置 | 收件人（任务通知发往哪）、白名单、轮询间隔、自动处理开关 → 保存即生效 |
| 测试发送 | 填收件人/主题/正文 → 一键发信（验证发件链路）|
| 日志 | poll / send / headless 日志实时滚动（每 15 秒刷新）|

## 二、配置说明（config.json）

```jsonc
{
  "targetEmail": "you@example.com",        // 任务完成通知的收件人
  "allowedSenders": ["you@example.com", "your-agent@agent.qq.com"],  // 白名单：只有这些邮箱能驱动 AI 处理
  "pollIntervalMin": 2,                     // 收件轮询间隔（分钟）
  "autoProcess": true,                      // 收到白名单邮件后自动触发 AI 处理回复
  "webToken": "xxxx...",                // 控制台访问令牌（首次启动自动生成，勿泄露）
  "inboxDir": "E:\\AgentMail\\inbox",
  "outboxDir": "E:\\AgentMail\\outbox",
  "seenFile": "E:\\AgentMail\\seen.log",
  "triggeredFile": "E:\\AgentMail\\triggered.log",
  "logDir": "E:\\AgentMail\\logs",
  "cli": "agently-cli",
  "dshCli": "E:\\DeepSeekHarness\\deepseek-harness\\apps\\cli\\lib\\bin.js",
  "headlessPrompt": "AI 处理邮件的指令模板（{FILE}/{FROM}/{SUBJECT}/{MAILID} 占位符）"
}
```

> 改完 config.json 无需重启：在控制台点「保存配置」或重启服务即可生效。

## 三、邮件处理闭环（发邮件给 AI）

1. 用白名单邮箱（如 `you@example.com`）发邮件到 **your-agent@agent.qq.com**
2. 服务每 2 分钟检查一次 → 过滤 → 触发 AI 会话处理
3. AI 理解邮件内容，能执行的执行（生成内容/查状态等），然后生成回复
4. **≤5 分钟**后你收到回复邮件

### 示例
- 发给 AI：*"把 adou 游戏项目最近 5 条 git 提交概括发我"* → 收到概括邮件
- 发给 AI：*"帮我写一封感谢邮件发给 xxx@qq.com"* → AI 生成内容并回复你确认

> 安全提示：邮件内容会被 AI 处理，请勿发送密码等敏感信息；白名单外的邮件会被忽略。

## 四、任务完成通知（AI 侧约定）

我（AI 助手）完成一个任务/里程碑后，会往 `E:\AgentMail\notifications\` 写入通知文件：

```json
{ "title": "M4 完成", "content": "已添加音效与打包配置，详情见 git 提交" }
```

服务自动检测 → 发送邮件到 `targetEmail` → 文件移入 `notifications\sent\`。
文件格式要求：JSON，含 `title`（主题）和 `content`（正文）字段，UTF-8 编码。

## 五、常用操作

| 目的 | 操作 |
|---|---|
| 重新授权（换设备/失效）| 运行 `setup.ps1` 重新执行 OAuth |
| 手动触发一次轮询 | 控制台「立即轮询」按钮 |
| 发一封测试邮件 | 控制台「测试发送」 |
| 查看 AI 处理过程 | `E:\AgentMail\logs\headless.log` |
| 让某封邮件重新处理 | 从 `seen.log` 删除该邮件 ID |
| 完全停止服务 | 任务计划程序 → 禁用 `DSH-Mail-Server` |

## 六、常见问题

**Q: 控制台显示 401？**
A: 令牌没填或过期——复制 config.json 的 webToken 粘贴保存。

**Q: 邮件发了但 AI 没回？**
A: 检查：① 发件人是否在白名单（allowedSenders）② `logs/poll.log` 是否显示"新邮件(白名单)" ③ `logs/headless.log` 是否处理了。

**Q: 回信发不出去？**
A: 看 `outbox/failed/` 和 `logs/send.log`；常见原因：CLI 授权过期（重跑 setup.ps1）、每日发送配额（50 封）用完。

**Q: 怎么换收件通知的邮箱？**
A: 控制台配置区改「收件人」→ 保存。

**Q: 可以让 AI 用我的 163/QQ 邮箱发信吗？**
A: 当前 AI 用 `your-agent@agent.qq.com` 发信（可发到任意地址）。如需以你个人邮箱身份发信，需扩展 SMTP 渠道（方案 A，另行开发）。
