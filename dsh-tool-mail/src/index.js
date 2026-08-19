// ============================================================
// dsh-tool-mail —— DeepSeek Harness 邮件工具插件
//
// 给智能体注册 4 个工具（host 进程内运行，有网络）：
//   mail_send(to, subject, body)  发送邮件（两步确认）
//   mail_list(limit)              列出收件箱
//   mail_read(id)                 读取邮件正文
//   mail_reply(id, body)          回复邮件
//
// 导出约定：name / inject / apply，无 default 导出（勿添加 export default）
// ============================================================
import { defineTool } from '@deepseek-ai/dsh-tools'
import { defaultRunJs, sendMail, listMails, searchMails, readMail, replyMail, forwardMail, deleteMail } from './mail.js'

export const name = 'tool-mail'
export const inject = ['tools']

export function apply(ctx, config) {
  // CLI 入口路径（默认自动发现 npm 全局安装的 agently-cli，可用配置覆盖）
  const runJs = config?.cliRunJs || defaultRunJs()

  ctx.tools.register(defineTool({
    name: 'mail_send',
    description:
      '通过 Agent Mail 发送一封邮件。host 进程直接联网发送（含两步确认）。'
      + '收件人可为任意邮箱地址。返回发送结果。',
    parameters: {
      to: { type: 'string', required: true, description: '收件人邮箱地址' },
      subject: { type: 'string', description: '邮件主题' },
      body: { type: 'string', description: '邮件正文（纯文本，支持换行）' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      const r = await sendMail(runJs, args.to, args.subject || '（无主题）', args.body || '', exec.signal)
      return r.ok ? `✅ 邮件已发送至 ${r.to}（主题：${r.subject}）` : `❌ 发送失败：${r.error}`
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_list',
    description: '列出 Agent Mail 收件箱中的邮件（时间/发件人/主题/ID）。',
    parameters: {
      limit: { type: 'number', description: '最多列出的邮件数，默认 10' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      try {
        return await listMails(runJs, args.limit || 10, exec.signal)
      } catch (e) {
        return '❌ 获取收件箱失败：' + String(e.message || e).slice(0, 300)
      }
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_read',
    description: '读取指定邮件的完整正文（HTML 已转纯文本）。用 mail_list 获取邮件 ID。',
    parameters: {
      id: { type: 'string', required: true, description: '邮件 ID（message_id）' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      try {
        return await readMail(runJs, args.id, exec.signal)
      } catch (e) {
        return '❌ 读取失败：' + String(e.message || e).slice(0, 300)
      }
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_reply',
    description: '回复指定邮件（自动回复其原发件人，主题加"回复："前缀）。',
    parameters: {
      id: { type: 'string', required: true, description: '要回复的邮件 ID' },
      body: { type: 'string', required: true, description: '回复正文' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      const r = await replyMail(runJs, args.id, args.body, exec.signal)
      return r.ok ? `✅ 回复已发送至 ${r.to}（主题：${r.subject}）` : `❌ 回复失败：${r.error}`
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_delete',
    description:
      '删除邮件：默认移入回收站（软删，30 天内可从回收站恢复）；permanent=true 时永久删除（不可恢复）。'
      + '用 mail_list 获取邮件 ID。清理收件箱时逐封调用即可。',
    parameters: {
      id: { type: 'string', required: true, description: '要删除的邮件 ID' },
      permanent: { type: 'boolean', description: '是否永久删除（默认 false，仅移入回收站）' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      const r = await deleteMail(runJs, args.id, !!args.permanent, exec.signal)
      return r.ok
        ? (r.permanent ? `✅ 已永久删除邮件 ${args.id}` : `✅ 已将邮件 ${args.id} 移入回收站`)
        : `❌ 删除失败：${r.error}`
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_search',
    description:
      '按关键词搜索邮件（默认搜索主题+正文）。可指定发件人（from）或文件夹（dir: inbox/sent/trash/spam）过滤。'
      + '返回匹配邮件列表（时间/发件人/主题/ID）。',
    parameters: {
      q: { type: 'string', required: true, description: '搜索关键词' },
      from: { type: 'string', description: '按发件人邮箱过滤' },
      dir: { type: 'string', description: '文件夹：inbox / sent / trash / spam，默认收件箱' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      try {
        return await searchMails(runJs, args.q, args.from || '', args.dir || '', exec.signal)
      } catch (e) {
        return '❌ 搜索失败：' + String(e.message || e).slice(0, 300)
      }
    },
  }))

  ctx.tools.register(defineTool({
    name: 'mail_forward',
    description:
      '转发指定邮件给新收件人（自动两步确认）。可附备注文字。用 mail_list / mail_search 获取邮件 ID。',
    parameters: {
      id: { type: 'string', required: true, description: '要转发的邮件 ID' },
      to: { type: 'string', required: true, description: '新收件人邮箱地址' },
      body: { type: 'string', description: '可选备注内容' },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: String(value) }],
    },
    async execute(args, exec) {
      const r = await forwardMail(runJs, args.id, args.to, args.body || '', exec.signal)
      return r.ok ? `✅ 已转发邮件 ${args.id} 至 ${r.to}` : `❌ 转发失败：${r.error}`
    },
  }))
}
