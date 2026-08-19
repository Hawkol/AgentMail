# 📧 dsh-tool-mail

DeepSeek Harness 邮件工具插件 —— 基于腾讯 **Agent Mail**（`@tencent-qqmail/agently-cli`）。

给智能体注册 **7 个工具**，运行在 DSH **host 进程**内（有网络，无沙箱限制）：

| 工具 | 功能 |
|---|---|
| `mail_send(to, subject, body)` | 发送邮件（自动两步确认）|
| `mail_list(limit)` | 列出收件箱 |
| `mail_read(id)` | 读取邮件正文（HTML 转纯文本）|
| `mail_reply(id, body)` | 回复邮件（回复原发件人，主题加"回复："）|
| `mail_delete(id, permanent?)` | 删除邮件：默认移入回收站（软删 30 天可恢复）；`permanent=true` 永久删除 |
| `mail_search(q, from?, dir?)` | 关键词搜索（默认搜主题+正文，可按发件人/文件夹过滤）|
| `mail_forward(id, to, body?)` | 转发邮件给新收件人（可附备注，自动两步确认）|

> 所有写操作（send/reply/delete/forward）自动处理 Agent Mail 的两步确认流程（首次调用拿 token → 携带重发）。

## 前置条件

- 已安装并授权 `agently-cli`：`npm install -g @tencent-qqmail/agently-cli` + `agently-cli auth login`
- 使用 DSH（DeepSeek Harness）

## 安装

```bash
# 本地开发（file: 安装后改代码需重启 GUI 生效）
dsh plugin --profile web add ./dsh-tool-mail
# 或从 npm 安装
dsh plugin --profile web add @hawkol/dsh-tool-mail
```

安装后**重启 GUI**，然后在对话中直接说需求即可，例如：
- "发一封邮件给 xxx@qq.com，主题：你好"
- "看看我的收件箱" / "搜索含'报告'的邮件"
- "把邮件 msg_xxx 转发给 xxx@qq.com"

> 若插件未自动激活（profile 未识别 dsh.bundle），手动加入 bundles：
> 编辑 `~/.dsh/profiles/<name>/package.json` 的 `dsh.profile.bundles`，追加 `"@hawkol/dsh-tool-mail"`。

## 配置（可选）

默认自动发现 npm 全局安装的 agently-cli。如需自定义 CLI 入口，在插件自带的 `cordis.patch.yml` 中配置：

```yaml
- insert:
    - id: tool-mail
      name: '@hawkol/dsh-tool-mail'
      config:
        cliRunJs: "C:\\path\\to\\agently-cli\\scripts\\run.js"   # 默认自动发现
```

## 发布到 npm

```bash
# 1. 登录 npm
npm login

# 2. 发布
npm publish

# 之后其他用户安装：
dsh plugin --profile web add @hawkol/dsh-tool-mail
```

> 未发布的替代方案：GitHub Packages（`.npmrc` 配 `@hawkol:registry=https://npm.pkg.github.com/`）。

## 安全说明

- 插件**不硬编码任何邮箱/token**；发送凭据由本机 agently-cli 的授权（Windows 凭据管理器，DPAPI）提供
- 邮件内容会进入模型上下文——发送前请确认内容无误
- 无白名单限制：工具可发给任意地址，使用时应由对话者明确指示
- 永久删除（`permanent=true`）不可恢复，请谨慎使用

## 开发说明

- 纯 ESM JavaScript（`src/`），无需编译
- 导出 `name` / `inject` / `apply`，**无 default 导出**
- CLI 调用走 `node 直调 run.js`（避免 .cmd shim 参数问题）
- 每个工具定义 `output.render`（DSH 要求模型可见渲染函数）
- 工具在 `src/index.js` 注册，CLI 封装在 `src/mail.js`
