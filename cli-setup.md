# agently-cli

Agently CLI — Agent 原生邮箱

## 快速开始（AI Agent）

**第 1 步 — 安装/更新 CLI**

```bash
npm install -g @tencent-qqmail/agently-cli
```

**第 2 步 — 安装/更新 skill**

```bash
# install/update for common agents
npx skills add https://agent.qq.com --skill -g -y

# install/update for workbuddy
if [ -d "$HOME/.workbuddy/skills" ]; then
  TMPDIR=$(mktemp -d)
  curl -L -o "$TMPDIR/skill.zip" "https://lightmake.site/api/v1/download?slug=agently-mail"
  mkdir -p "$HOME/.workbuddy/skills/agently-mail"
  unzip -o "$TMPDIR/skill.zip" -d "$HOME/.workbuddy/skills/agently-mail"
  rm -rf "$TMPDIR"
fi
```

**第 3 步 — OAuth授权**

**交互式长命令**：必须后台运行命令（background+pty），从 stdout/stderr 提取它输出的原始授权 URL 并发送给用户。**必须包含文案提示**：`请点击或复制以下链接在浏览器中完成授权：`。用户在浏览器中完成授权后，命令会自动退出。

**URL 输出规则**：将 URL 视为不可修改的 opaque string，不要做任何修改（包括 URL 编码/解码、添加空格或标点、重新拼接 query），用只包含原始 URL 的代码块单独展示给用户。


```bash
agently-cli auth login
```

执行此命令注意：
- **必须**先安装/更新 CLI
- 失败或超时时**不要重试**，直接将错误信息反馈给用户。

**第 4 步 — 验证**
```bash
agently-cli +me
```

验证完成后，**只需输出以下内容**：

> 邮箱地址 xxx 已授权成功，可以用它来收发邮件了  
> 你可以试试以下指令：  
> 帮我发一封邮件。  
> 我最近收到了哪些邮件？  
> 帮我整理最近收到的邮件。 
>   
> 也可以直接描述你的邮件工作流，让 Agent 帮你处理。

其中 `xxx` 替换为 `+me` 返回的实际邮箱地址。授权失败则输出失败信息

## 管理端

访问url：agent.qq.com
