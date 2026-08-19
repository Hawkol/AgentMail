// ============================================================
// Agent Mail CLI 封装（node 直调 run.js，host 进程内运行）
// 所有网络请求由 DSH host 进程发出（插件运行在 host，无沙箱限制）
// ============================================================
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

const execFileP = promisify(execFile)

/** 默认 CLI 入口（npm 全局安装的 agently-cli） */
export function defaultRunJs() {
  return process.env.APPDATA
    + '\\npm\\node_modules\\@tencent-qqmail\\agently-cli\\scripts\\run.js'
}

/** 调用 CLI 并解析 JSON 输出 */
export async function cli(runJs, args, signal) {
  const { stdout } = await execFileP(process.execPath, [runJs, ...args], {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    signal,
  })
  return JSON.parse(stdout)
}

/** 发送邮件（含两步确认：首次拿 token → 携带重发） */
export async function sendMail(runJs, to, subject, body, signal) {
  const base = ['message', '+send', '--to', to, '--subject', subject, '--body', body]
  let out
  try {
    out = await cli(runJs, base, signal)
  } catch (e) {
    return { ok: false, error: detail(e) }
  }
  const token = out?.data?.confirmation_token
  if (token) {
    try {
      out = await cli(runJs, [...base, '--confirmation-token', token], signal)
    } catch (e) {
      return { ok: false, error: detail(e) }
    }
    if (out?.data?.queued) return { ok: true, to, subject }
    return { ok: false, error: '确认后仍未入队: ' + JSON.stringify(out).slice(0, 200) }
  }
  if (out?.ok && !out?.data?.confirmation_required) {
    return { ok: true, to, subject }
  }
  return { ok: false, error: JSON.stringify(out).slice(0, 300) }
}

/** 提取 CLI 错误的可读信息（含服务端返回的 JSON 详情） */
function detail(e) {
  const stdout = e?.stdout ? String(e.stdout).trim().slice(0, 400) : ''
  return (stdout || String(e?.message || e)).slice(0, 400)
}

/** 列出收件箱（返回精简文本） */
export async function listMails(runJs, limit, signal) {
  const out = await cli(runJs, ['message', '+list', '--limit', String(limit || 10)], signal)
  const items = out?.data?.data || []
  if (items.length === 0) return '（收件箱为空）'
  return items.map((m) => `- [${m.created_at}] ${m.from?.email || '未知发件人'} | ${m.subject} | ${m.message_id}`).join('\n')
}

/** 读取邮件正文（HTML 转纯文本） */
export async function readMail(runJs, id, signal) {
  const out = await cli(runJs, ['message', '+read', '--id', id], signal)
  const body = stripHtml(out?.data?.body)
  if (body) return body
  return String(out?.data?.snippet || '（无正文）')
}

/** 回复邮件：读取原邮件 → 回复其发件人 */
export async function replyMail(runJs, id, body, signal) {
  const out = await cli(runJs, ['message', '+read', '--id', id], signal)
  const from = out?.data?.from?.email
  if (!from) return { ok: false, error: '无法确定原邮件发件人' }
  const subject = '回复：' + String(out?.data?.subject || '')
  return sendMail(runJs, from, subject, body, signal)
}

/** HTML → 纯文本 */
function stripHtml(html) {
  return String(html || '')
    .replace(/<br\s*\/?>/gi, '\n').replace(/<\/p>/gi, '\n').replace(/<\/div>/gi, '\n').replace(/<\/tr>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/[ \t]+/g, ' ').replace(/(\r?\n){3,}/g, '\n\n').trim()
}
