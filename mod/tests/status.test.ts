import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// The test runner has timers; the hooks module's own environment, typed here, does not.
declare function setTimeout(callback: () => void, ms: number): unknown

/** The receiver's stdout as the test writes it, one JSON line per event. */
function receiverLines() {
  const waiting: ((line: string | null) => void)[] = []
  const queued: (string | null)[] = []
  const take = () =>
    new Promise<string | null>(resolve => (queued.length > 0 ? resolve(queued.shift() ?? null) : waiting.push(resolve)))

  const push = (line: string | null) => {
    const next = waiting.shift()
    next ? next(line) : queued.push(line)
  }

  return {
    send(event: object) {
      push(JSON.stringify(event) + '\n')
    },
    /** The receiver exits; the next spawn reads on from here. */
    exit() {
      push(null)
    },
    async *stream() {
      for (let line = await take(); line !== null; line = await take()) {
        yield { stream: 'stdout' as const, text: line }
      }
      return { value: { code: 0, signal: null } }
    },
  }
}

const PUBSPEC = 'name: tally\ndependencies:\n  flutter:\n    sdk: flutter\n  widget_fix:\n    path: ../packages/widget_fix\n'

/** The world beneath the mod: a receiver the test drives, and the statuses the mod publishes. */
function world(on: On, { pubspec = PUBSPEC as string | null } = {}) {
  const receiver = receiverLines()
  const spawns: { env?: Record<string, string> }[] = []
  const commands: string[] = []
  const toasts: string[] = []
  const statuses: Record<string, string>[] = []
  const prompts: string[] = []
  let submitted: () => void = () => {}
  const submission = new Promise<void>(resolve => (submitted = resolve))

  mock.clock(on)
  on('session.start', async (_$, e) => ({ cwd: e.cwd }))
  on('fs.read', async (_$, e) => {
    if (!e.path.endsWith('/pubspec.yaml') || pubspec === null) throw new Error(`ENOENT: ${e.path}`)
    return { value: pubspec }
  })
  on('command.register', async (_$, e) => {
    commands.push(e.name)
    return { value: { command: e.name } }
  })
  on('command.run', async () => ({ text: '' }))
  on('ui.open', async () => ({ value: { isPlaced: true as const } }))
  on('ui.toast', async (_$, e) => {
    toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.log', async () => ({ value: undefined }))
  on('process.spawn', async function* (_$, e) {
    spawns.push({ env: e.env })
    return yield* receiver.stream()
  })
  on('prompt.submit', async (_$, e) => {
    prompts.push(e.text)
    submitted()
    return { text: e.text }
  })
  on('fs.write', async (_$, e) => {
    if (e.path.endsWith('status.json')) statuses.push(JSON.parse(e.text))
    return { value: undefined }
  })
  on('tool.call', async () => ({ result: 'done' }))
  on('turn.complete', async () => ({ text: '' }))

  return { receiver, spawns, commands, toasts, statuses, prompts, submission }
}

/** Waits until the mod has done what a receiver line asked for. */
async function until(done: () => boolean) {
  for (let waited = 0; !done(); waited += 5) {
    if (waited > 2000) throw new Error('the mod never got there')
    await new Promise<void>(resolve => setTimeout(resolve, 5))
  }
}

const turnEnd = { answer: 'Fixed.', durationMs: 1, isAborted: false, turnId: 't1' } as const
const report = {
  type: 'report',
  report: {
    id: 'r1',
    comment: 'Income should be green',
    screen: 'Activity',
    screenshot: null,
    chain: [{ type: 'Text', file: 'file:///project/lib/features/home/transaction_row.dart', line: 50 }],
    text: '+€4,650.00',
  },
}

test('a hot reload during the fix makes the report live, and an answer keeps it live', async ($, on) => {
  const { receiver, statuses, prompts, submission } = world(on)
  await $.session.start({ cwd: '/project', surface: 'terminal', isInteractive: true })
  receiver.send({ type: 'ready', port: 4747 })
  receiver.send(report)
  await submission
  await until(() => statuses.at(-1)?.r1 === 'fixing')
  expect(prompts[0]).toContain('[fix r1] Text "+€4,650.00" · lib/features/home/transaction_row.dart:50')

  await $.tool.call({ tool: 'Bash', command: 'pkill -USR1 -F .widget_fix/flutter.pid' })
  receiver.send({ type: 'launched', reason: 'reload' })
  await until(() => statuses.at(-1)?.r1 === 'live')
  await $.turn.complete({ ...turnEnd, reason: 'answer' })

  expect(statuses.map(all => all.r1)).toEqual(['queued', 'fixing', 'reloading', 'live', 'live'])
})

test("the Dart MCP server's hot restart counts as reloading too", async ($, on) => {
  const { receiver, statuses, submission } = world(on)
  await $.session.start({ cwd: '/project', surface: 'terminal', isInteractive: true })
  receiver.send(report)
  await submission
  await until(() => statuses.at(-1)?.r1 === 'fixing')

  await $.tool.call({ tool: 'mcp__dart__hot_restart' })
  receiver.send({ type: 'launched', reason: 'launch' })
  await until(() => statuses.at(-1)?.r1 === 'live')

  expect(statuses.map(all => all.r1)).toEqual(['queued', 'fixing', 'reloading', 'live'])
})

test('without a reload the fix is not on screen', async ($, on) => {
  const { receiver, statuses, submission } = world(on)
  await $.session.start({ cwd: '/project', surface: 'terminal', isInteractive: true })
  receiver.send(report)
  await submission
  await until(() => statuses.at(-1)?.r1 === 'fixing')

  await $.turn.complete({ ...turnEnd, reason: 'answer' })

  expect(statuses.at(-1)?.r1).toBe('stopped')
})

test('a session outside a WidgetFix project leaves the reports alone', async ($, on) => {
  const { spawns, commands } = world(on, { pubspec: null })
  await $.session.start({ cwd: '/elsewhere', surface: 'terminal', isInteractive: true })

  expect(spawns).toEqual([])
  expect(commands).toEqual([])
})

test('a Flutter project without WidgetFix does not count', async ($, on) => {
  const { spawns } = world(on, { pubspec: 'name: other\ndependencies:\n  flutter:\n    sdk: flutter\n' })
  await $.session.start({ cwd: '/other', surface: 'terminal', isInteractive: true })

  expect(spawns).toEqual([])
})

test('a second session stands by until /fix-take moves the reports to it', async ($, on) => {
  const { receiver, spawns, statuses, submission } = world(on)
  await $.session.start({ cwd: '/project', surface: 'terminal', isInteractive: true })
  receiver.send({ type: 'busy', cwd: '/Users/me/tally' })
  receiver.exit()
  await until(() => spawns.length === 1)

  const { text } = await $.command.run({
    command: 'fix-take',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })
  expect(text).toContain('now come to this session')
  await until(() => spawns.length === 2)
  expect(spawns.map(one => one.env?.WIDGET_FIX_TAKE)).toEqual([undefined, '1'])

  receiver.send({ type: 'ready', port: 4747 })
  receiver.send(report)
  await submission
  await until(() => statuses.at(-1)?.r1 === 'fixing')
})

test('a session whose reports were taken stops publishing their statuses', async ($, on) => {
  const { receiver, toasts, statuses, submission } = world(on)
  await $.session.start({ cwd: '/project', surface: 'terminal', isInteractive: true })
  receiver.send({ type: 'ready', port: 4747 })
  receiver.send(report)
  await submission
  await until(() => statuses.at(-1)?.r1 === 'fixing')

  receiver.send({ type: 'taken', cwd: '/Users/me/tally' })
  await until(() => toasts.some(text => text.includes('~/tally took the reports')))
  await $.turn.complete({ ...turnEnd, reason: 'answer' })

  expect(statuses.map(all => all.r1)).toEqual(['queued', 'fixing'])
})
