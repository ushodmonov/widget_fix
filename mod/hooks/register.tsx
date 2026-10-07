import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { FixReport, FixStatus, Incoming, Receiver } from '../types'
import { describePressed, instructionsFor, isReload, pressedLabel, promptFor, relativePath, sourceOf } from './prompt'

const PANE = 'fix-queue'
const TITLE = 'Fix queue'
// Folders a Flutter project is never found in.
const SKIP = new Set(['build', 'node_modules', 'ios', 'android', 'macos', 'linux', 'windows', 'web', 'Pods'])

const reports = atom({ plugin: 'widget-fix', key: 'reports' } as const, [])
const receiver = atom({ plugin: 'widget-fix', key: 'receiver' } as const, {
  state: 'starting',
  detail: '',
})
const now = atom({ plugin: 'widget-fix', key: 'now' } as const, 0)

type ReceiverEvent =
  | { type: 'ready'; port: number }
  | { type: 'busy'; cwd: string }
  | { type: 'taken'; cwd: string }
  | { type: 'error'; message: string }
  | { type: 'notice'; message: string }
  | { type: 'launched'; reason: 'launch' | 'reload' }
  | { type: 'report'; report: Incoming }

const LOOK: Record<FixStatus, { mark: string; label: string; color: string }> = {
  queued: { mark: '○', label: 'queued', color: 'yellow' },
  fixing: { mark: '◆', label: 'fixing', color: 'cyan' },
  reloading: { mark: '▲', label: 'reloading', color: 'magenta' },
  live: { mark: '✔', label: 'live', color: 'green' },
  stopped: { mark: '✘', label: 'not reloaded', color: 'red' },
}

const isActive = (report: FixReport) => report.status !== 'live' && report.status !== 'stopped'

let cwd = ''
// The Flutter project that depends on widget_fix: the session's folder, or one up to two levels
// below it. Null in any other session, which leaves the reports alone.
let project: string | null = null
// The project's folder from the session's, with a trailing slash; '' when they are the same.
let prefix = ''
// The report whose turn is running; its prompt was submitted by this mod.
let current: string | null = null

/** Whether the project in this folder uses WidgetFix: its pubspec.yaml lists widget_fix. */
async function usesWidgetFix($: EngineInterface, folder: string) {
  try {
    return /^[ \t]+widget_fix[ \t]*:/m.test(await $.fs.read(`${folder}/pubspec.yaml`))
  } catch {
    return false
  }
}

/** The WidgetFix project: this folder, else the nearest one up to two levels below it. */
async function findProject($: EngineInterface, folder: string): Promise<string | null> {
  let level = [folder]
  for (let depth = 0; depth <= 2; depth++) {
    for (const candidate of level) {
      if (await usesWidgetFix($, candidate)) return candidate
    }
    if (depth === 2) break
    const below = await Promise.all(
      level.map(async parent =>
        (await $.fs.list(parent).catch(() => []))
          .filter(entry => entry.kind === 'dir' && !entry.name.startsWith('.') && !SKIP.has(entry.name))
          .map(entry => `${parent}/${entry.name}`)
          .sort(),
      ),
    )
    level = below.flat()
  }
  return null
}

/** A folder as the pane names it: home as ~. */
const shortPath = (path: string) => path.replace(/^\/(?:Users|home)\/[^/]+(?=\/|$)/, '~')

/** Changes one report, then publishes every status for the app to poll. */
async function patch($: EngineInterface, id: string, change: (report: FixReport) => FixReport) {
  const list = await update($, reports, all => all.map(one => (one.id === id ? change(one) : one)))
  // Once another session took the reports, the status file is its own.
  if ((await read($, receiver)).state === 'standby') return
  const statuses = Object.fromEntries(list.map(one => [one.id, one.status]))
  await $.fs.write(`${project}/.widget_fix/status.json`, JSON.stringify(statuses))
}

async function accept($: EngineInterface, received: Incoming) {
  // The receiver names the screenshot from the project's folder; Claude reads it from the session's.
  const incoming = { ...received, screenshot: received.screenshot && prefix + received.screenshot }
  const report: FixReport = {
    id: incoming.id,
    comment: incoming.comment,
    element: incoming.element?.name ?? null,
    pressed: describePressed(incoming),
    source: sourceOf(incoming, cwd),
    screen: incoming.screen,
    screenshot: incoming.screenshot,
    status: 'queued',
    receivedAt: await $.clock.now(),
    finishedAt: null,
    edited: [],
  }
  await update($, reports, all => [...all, report].slice(-50))
  await patch($, report.id, one => one)
  $.ui.toast(`Fix request ${report.id}: ${report.comment}`)

  // Resolves when the report's own turn starts, after any turn already running.
  // As the person's own words: they typed the comment, and the engine adds no frame around it.
  await $.prompt.submit({ text: promptFor(incoming, cwd), asUser: true })
  current = report.id
  await patch($, report.id, one => ({ ...one, status: 'fixing' }))
}

/** The app launched or hot reloaded while Claude works on a report: whatever did it, the fix is on screen. */
async function launched($: EngineInterface) {
  if (current !== null) {
    await patch($, current, one => ({ ...one, status: 'live' }))
  }
}

/** Runs the receiver; `take` moves the port here from the session that holds it. */
async function listen($: EngineInterface, take = false) {
  await update($, receiver, (): Receiver => ({ state: 'starting', detail: '' }))
  const child = $.process.spawn({
    argv: ['node', `${$.plugin.root}/server/receiver.mjs`],
    // The receiver keeps .widget_fix/ in the folder it runs in, where flutter run puts its pid file.
    cwd: project ?? cwd,
    ...(take ? { env: { WIDGET_FIX_TAKE: '1' } } : {}),
  })
  let pending = ''

  try {
    for await (const { stream, text } of child) {
      if (stream === 'stderr') {
        $.ui.log(text, { to: 'debug' })
        continue
      }
      pending += text
      const lines = pending.split('\n')
      pending = lines.pop() ?? ''

      for (const line of lines.filter(Boolean)) {
        const event = JSON.parse(line) as ReceiverEvent
        if (event.type === 'ready') {
          await update($, receiver, (): Receiver => ({ state: 'listening', detail: `127.0.0.1:${event.port}` }))
          void $.ui.open({ id: PANE, title: TITLE })
        } else if (event.type === 'busy' || event.type === 'taken') {
          const where = event.cwd === '' ? 'another session' : `the session in ${shortPath(event.cwd)}`
          await update($, receiver, (): Receiver => ({
            state: 'standby',
            detail: `reports go to ${where}`,
            notice: '/fix-take moves them to this session.',
          }))
          $.ui.toast(
            event.type === 'busy'
              ? `widget-fix: reports go to ${where}; /fix-take moves them here`
              : `widget-fix: ${where} took the reports; /fix-take takes them back`,
          )
        } else if (event.type === 'error') {
          await update($, receiver, (): Receiver => ({ state: 'failed', detail: event.message }))
          $.ui.toast(`widget-fix: ${event.message}`)
        } else if (event.type === 'notice') {
          await update($, receiver, (was): Receiver => ({ ...was, notice: event.message }))
        } else if (event.type === 'launched') {
          void launched($)
        } else {
          void accept($, event.report)
        }
      }
    }
  } catch (error) {
    await update($, receiver, (): Receiver => ({ state: 'failed', detail: String(error) }))
    return
  }

  // The child has exited. Say so, unless it already reported why.
  await update($, receiver, (was): Receiver =>
    was.state === 'failed' || was.state === 'standby'
      ? was
      : { state: 'failed', detail: 'receiver stopped; run /fix-take' },
  )
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    cwd = e.cwd
    project = await findProject($, e.cwd)
    if (project === null) {
      return next(e)
    }
    prefix = project === cwd ? '' : `${relativePath(project, cwd)}/`

    // Another plugin may hold a name; the reports still come without the command.
    for (const command of [
      { name: 'fix-queue', description: 'Show the fix requests sent from the Flutter app' },
      { name: 'fix-take', description: "Receive the Flutter app's fix requests in this session instead of another one" },
    ]) {
      await $.command.register(command).catch((error: unknown) => {
        $.ui.toast(`widget-fix: /${command.name} is unavailable: ${String(error)}`)
      })
    }
    const started = await next(e)

    void listen($)
    // Keeps the elapsed seconds of a running fix ticking in the pane.
    $.clock.every(1000, () => {
      void (async () => {
        if ((await read($, reports)).some(isActive)) {
          await update($, now, () => Date.now())
        }
      })()
    })

    return started
  })

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    if (project === null) {
      return composed
    }

    return {
      sections: [...composed.sections, { id: 'widget-fix:fix-requests', text: instructionsFor(prefix), scope: 'session' }],
    }
  })

  on('command.run', { command: 'fix-queue' }, async $ => {
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'Fix queue opened.' }
  })

  on('command.run', { command: 'fix-take' }, async $ => {
    const { state } = await read($, receiver)
    if (state === 'listening' || state === 'starting') {
      return { text: 'This session already receives the fix requests.' }
    }

    void listen($, true)
    await $.ui.open({ id: PANE, title: TITLE })

    return { text: 'Fix requests from the app now come to this session.' }
  })

  // A status that fails to save must not fail the tool call itself.
  on('tool.call', async ($, e, next) => {
    const id = current
    if (id === null || e.agentId !== undefined) {
      return next(e)
    }

    if (isReload(String(e.tool), e.tool === 'Bash' ? e.command : undefined)) {
      await patch($, id, one => ({ ...one, status: 'reloading' }))
      const ran = await next(e)
      // A reload during the call has marked the report live; a failed call leaves it fixing.
      if (ran.deny !== undefined || ran.isError === true) {
        await patch($, id, one => (one.status === 'reloading' ? { ...one, status: 'fixing' } : one))
      }

      return ran
    }

    if (e.tool === 'Edit' || e.tool === 'Write') {
      const name = e.file_path.split('/').pop() ?? e.file_path
      await patch($, id, one => (one.edited.includes(name) ? one : { ...one, edited: [...one.edited, name] }))
    }

    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const id = current
    if (id !== null && e.agentId === undefined) {
      current = null
      const finishedAt = await $.clock.now()
      // Live only when the app reloaded with the fix and the turn ended with an answer.
      await patch($, id, one => ({
        ...one,
        status: e.reason === 'answer' && one.status === 'live' ? 'live' : 'stopped',
        finishedAt,
      }))
    }

    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const list = await read($, reports)
    const link = await read($, receiver)
    const clock = (await read($, now)) || (await $.clock.now())
    const width = Math.max(20, e.props.bodyColumns)
    // Each report takes five rows; the newest ones are kept in view.
    const room = Math.max(1, Math.floor(((e.viewport?.rows ?? 30) - 6) / 5))

    return (
      <Box flexDirection="column" width={width}>
        <Text color={link.state === 'failed' ? 'red' : link.state === 'listening' ? 'green' : 'yellow'}>
          {link.state === 'listening' ? '●' : '○'} {link.state} <Text dimColor>{link.detail}</Text>
        </Text>
        {link.notice !== undefined && (
          <Text dimColor wrap="wrap">
            {link.notice}
          </Text>
        )}

        {list.length === 0 && (
          <Box flexDirection="column" marginTop={1}>
            <Text>No fix requests yet.</Text>
            <Text dimColor wrap="wrap">
              Long press any widget in the app, type what is wrong and press Return.
            </Text>
          </Box>
        )}

        {list.slice(-room).map(report => {
          const look = LOOK[report.status]
          const seconds = Math.max(0, Math.round(((report.finishedAt ?? clock) - report.receivedAt) / 1000))

          return (
            <Box flexDirection="column" marginTop={1}>
              <Box justifyContent="space-between">
                <Text color={look.color} bold>
                  {look.mark} {report.id} {look.label}
                </Text>
                <Text dimColor>{seconds}s</Text>
              </Box>
              <Text bold wrap="truncate-end">
                “{report.comment}”
              </Text>
              <Text wrap="truncate-middle">{pressedLabel(report)}</Text>
              {report.source !== null && (
                <Text dimColor wrap="truncate-start">
                  {report.source}
                </Text>
              )}
              {report.edited.length > 0 && (
                <Text color="cyan" wrap="truncate-end">
                  edited {report.edited.join(', ')}
                </Text>
              )}
            </Box>
          )
        })}
      </Box>
    )
  })
}
