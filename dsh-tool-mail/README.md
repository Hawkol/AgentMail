# 📧 dsh-tool-mail

DeepSeek Harness 邮件工具插件 —— 基于腾讯 **Agent Mail**（`@tencent-qqmail/agently-cli`）。

给智能体注册 4 个工具，运行在 DSH **host 进程**内（有网络，无沙箱限制）：

| 工具 | 功能 |
|---|---|
| `mail_send(to, subject, body)` | 发送邮件（自动两步确认）|
| `mail_list(limit)` | 列出收件箱 |
| `mail_read(id)` | 读取邮件正文（HTML 转纯文本）|
| `mail_reply(id, body)` | 回复邮件（回复原发件人）|

## 前置条件

- 已安装并授权 `agently-cli`（`npm install -g @tencent-qqmail/agently-cli` + `agently-cli auth login`）
- 使用 DSH（DeepSeek Harness）

## 安装（本地开发）

```bash
dsh plugin --profile web add ./dsh-tool-mail
# 或
dsh plugin --profile web add @hawkol/dsh-tool-mail
```

安装后重启 GUI（或等待 HMR），然后在对话中直接说"发一封邮件给 xxx"即可。

> 若插件未自动激活，在 profile 的 `cordis.patch.yml` 中追加：
> ```yaml
> - type: include
>   name: tool-mail
> ```

## 配置（可选）

默认自动发现 npm 全局安装的 agently-cli。如需自定义 CLI 入口：

```yaml
# cordis.patch.yml
- type: config
  id: tool-mail
  config:
    cliRunJs: "C:\\path\\to\\agently-cli\\scripts\\run.js"
```

## 发布到 npm

```bash
# 1. 登录 npm
npm login

# 2. 发布（package.json 已配置 access: public 相关字段）
npm publish

# 之后其他用户安装：
dsh plugin --profile web add @hawkol/dsh-tool-mail
```

> 未发布的替代方案：GitHub Packages（`.npmrc` 配 `@hawkol:registry=https://npm.pkg.github.com/`）。

## 安全说明

- 插件**不硬编码任何邮箱/token**；发送凭据由本机 agently-cli 的授权（Windows 凭据管理器）提供
- 邮件内容会进入模型上下文——发送前请确认内容无误
- 无白名单限制：工具可发给任意地址，使用时应由对话者明确指示

## 开发说明

- 纯 ESM JavaScript（`src/`），无需编译
- 导出 `name` / `inject` / `apply`，**无 default 导出**
- CLI 调用走 `node 直调 run.js`（避免 .cmd shim 参数问题），发送含两步确认
