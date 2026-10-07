// Receives fix reports from a Flutter app's WidgetFix debug build and hands them to the widget-fix mod:
// one JSON line on stdout per event. Started by the mod with $.process.spawn and killed with it.
// One receiver owns the port at a time, and the first session to take it keeps it: a receiver from
// another session stands by unless it was started with WIDGET_FIX_TAKE=1 (/fix-take). No dependencies:
// the app itself tells which widget was pressed and the line that created it.
import { createServer } from 'node:http'
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const PORT = Number(process.env.WIDGET_FIX_PORT ?? 4747)
// The loopback interface serves an iOS simulator, a desktop app, a web page, an Android emulator
// (as 10.0.2.2) and a phone after `adb reverse`. WIDGET_FIX_HOST=0.0.0.0 lets a phone on the network in.
const HOST = process.env.WIDGET_FIX_HOST ?? '127.0.0.1'
const dir = join(process.cwd(), '.widget_fix')
const reportsDir = join(dir, 'reports')
const statusFile = join(dir, 'status.json')
// A report's screenshot is a few hundred kilobytes; nothing an app sends comes near this.
const MAX_BODY = 32 * 1024 * 1024
// Tells this run's report ids apart from an earlier run's.
const run = Date.now().toString(36)
// Set by /fix-take: this session takes the port from whichever session holds it.
const TAKE = process.env.WIDGET_FIX_TAKE === '1'
let count = 0
// The reports the app has been told are live, so it says "Fixed" once for each, across restarts.
const announced = new Set()

const emit = event => process.stdout.write(JSON.stringify(event) + '\n')
// A pipe on macOS is written asynchronously: exit once the last event is out.
const leave = (event, code) => process.stdout.write(JSON.stringify(event) + '\n', () => process.exit(code))
const ACTIVE = new Set(['queued', 'fixing', 'reloading'])

// The session that started this receiver is gone when its pipe breaks or the
// process is handed to launchd. Without this the receiver would keep the port
// and swallow every report meant for the next session. The parent's pid also
// names the session: a reload of the mod starts its new receiver from the same one.
const parent = process.ppid
process.stdout.on('error', () => process.exit(0))
setInterval(() => {
  if (process.ppid !== parent) process.exit(0)
}, 1000).unref()

// The mod writes every status change to this file; the app polls it through us.
const statuses = () => {
  try {
    return JSON.parse(readFileSync(statusFile, 'utf8'))
  } catch {
    return {}
  }
}

/** A report's status for the app, marking a live one as announced once the app has heard it. */
function answer(id, all = statuses()) {
  const status = id ? (all[id] ?? 'queued') : null
  const told = announced.has(id)
  if (status === 'live') announced.add(id)
  return { run, id, status, announced: told }
}

/**
 * Whether a request may come from where it says it does. A native app sends no Origin; a Flutter
 * web app in debug runs on localhost. A page from anywhere else in the browser is refused, so it
 * cannot type prompts into the session.
 */
function isAllowedOrigin(origin) {
  if (origin === undefined) return true
  try {
    const { hostname, protocol } = new URL(origin)
    return (protocol === 'http:' || protocol === 'https:') && ['localhost', '127.0.0.1', '[::1]'].includes(hostname)
  } catch {
    return false
  }
}

const reply = (req, res, code, body) => {
  res.writeHead(code, {
    'Content-Type': 'application/json',
    ...(req.headers.origin ? { 'Access-Control-Allow-Origin': req.headers.origin, Vary: 'Origin' } : {}),
  })
  res.end(JSON.stringify(body))
}

/** The request's JSON body, or {} when it has none. */
function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    let size = 0
    req.on('data', chunk => {
      size += chunk.length
      if (size > MAX_BODY) {
        reject(new Error('the body is too large'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      try {
        const text = Buffer.concat(chunks).toString('utf8')
        resolve(text.trim() === '' ? {} : JSON.parse(text))
      } catch (error) {
        reject(error)
      }
    })
    req.on('error', reject)
  })
}

async function handle(req, res) {
  const url = new URL(req.url, 'http://receiver')
  const origin = req.headers.origin

  if (!isAllowedOrigin(origin)) return reply(req, res, 403, { error: 'origin not allowed' })
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': origin ?? '*',
      'Access-Control-Allow-Methods': 'GET, POST',
      'Access-Control-Allow-Headers': 'Content-Type',
      Vary: 'Origin',
    })
    return res.end()
  }
  // A POST must say it is JSON: a browser cannot send that across origins without asking first.
  if (req.method === 'POST' && !String(req.headers['content-type'] ?? '').startsWith('application/json')) {
    return reply(req, res, 415, { error: 'send application/json' })
  }

  if (req.method === 'GET' && url.pathname === '/status') {
    return reply(req, res, 200, answer(url.searchParams.get('id')))
  }

  // Another session's receiver asks who holds the port before it takes it.
  if (req.method === 'GET' && url.pathname === '/owner') {
    return reply(req, res, 200, { app: 'widget-fix', run, session: parent, cwd: process.cwd() })
  }

  // The app has launched or hot reloaded: during a fix that means the fix is on screen, however it
  // got there. The answer is the report Claude is working on (reports are worked through in
  // order), else the newest one, for the app to follow or announce.
  if (req.method === 'POST' && url.pathname === '/launched') {
    const { reason } = await readJson(req).catch(() => ({}))
    emit({ type: 'launched', reason: reason === 'reload' ? 'reload' : 'launch' })
    const all = statuses()
    const id = Object.keys(all).find(key => ACTIVE.has(all[key])) ?? (count > 0 ? `r${count}` : null)
    return reply(req, res, 200, answer(id, all))
  }

  if (req.method === 'POST' && url.pathname === '/report') {
    let body
    try {
      body = await readJson(req)
    } catch (error) {
      return reply(req, res, 400, { error: String(error) })
    }
    const { screenshotPNG, ...report } = body
    if (typeof report.comment !== 'string' || report.comment.trim() === '') {
      return reply(req, res, 400, { error: 'a report needs a comment' })
    }

    const id = `r${++count}`
    let screenshot = null
    if (typeof screenshotPNG === 'string' && screenshotPNG !== '') {
      screenshot = join('.widget_fix', 'reports', `${id}.png`)
      writeFileSync(join(process.cwd(), screenshot), Buffer.from(screenshotPNG, 'base64'))
    }
    // Everything the app sent but the picture, the whole chain of widgets included.
    writeFileSync(join(reportsDir, `${id}.json`), JSON.stringify({ id, ...report }, null, 2))

    reply(req, res, 200, { id })
    emit({ type: 'report', report: { ...report, id, screenshot } })
    return
  }

  // A receiver of this session after a reload, or of another session after /fix-take, asks for the port.
  if (req.method === 'POST' && url.pathname === '/shutdown') {
    const { session, cwd } = await readJson(req).catch(() => ({}))
    reply(req, res, 200, { run })
    server.close()
    server.closeAllConnections()
    // This session's mod hears where the reports went; a reload's old receiver has no one to tell.
    if (session !== parent) leave({ type: 'taken', cwd: typeof cwd === 'string' ? cwd : '' }, 0)
    else process.exit(0)
    return
  }

  reply(req, res, 404, { error: 'not found' })
}

const server = createServer((req, res) => {
  handle(req, res).catch(error => {
    if (!res.headersSent) reply(req, res, 500, { error: String(error) })
  })
})

/**
 * Who holds the port: a receiver's `{ session, cwd }`, `'other'` for a program that answers but is no
 * receiver of ours, or null when nothing answers any more.
 */
async function holder() {
  try {
    const response = await fetch(`http://127.0.0.1:${PORT}/owner`)
    const body = await response.json().catch(() => null)
    return body?.app === 'widget-fix' ? body : 'other'
  } catch {
    return null
  }
}

// The port is taken. A receiver of another session keeps it, and so does any other program, unless
// this receiver was started to take it (/fix-take). This session's own receiver, the one a reload of
// the mod is replacing, is asked to leave. Then we try again: an old receiver killed with the mod
// it belonged to frees the port by itself.
let attempts = 0
server.on('error', error => {
  if (error.code === 'EADDRINUSE' && ++attempts <= 10) {
    void (async () => {
      const found = await holder()
      if (found !== null && found !== 'other' && found.session !== parent && !TAKE) {
        leave({ type: 'busy', cwd: found.cwd }, 0)
        return
      }
      if (found !== null && (found !== 'other' || TAKE)) {
        await fetch(`http://127.0.0.1:${PORT}/shutdown`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ session: parent, cwd: process.cwd() }),
        }).catch(() => {})
      }
      setTimeout(() => server.listen(PORT, HOST), 300)
    })()
    return
  }
  const message =
    error.code === 'EADDRINUSE'
      ? `port ${PORT} is in use by another program; /fix-take asks it to leave, WIDGET_FIX_PORT picks another`
      : String(error)
  leave({ type: 'error', message }, 1)
})

server.listen(PORT, HOST, () => {
  // Only the receiver that holds the port may clear the previous run's reports. The rest of
  // .widget_fix stays: flutter run's pid file lives there.
  rmSync(reportsDir, { recursive: true, force: true })
  rmSync(statusFile, { force: true })
  mkdirSync(reportsDir, { recursive: true })
  emit({ type: 'ready', port: PORT })
})
