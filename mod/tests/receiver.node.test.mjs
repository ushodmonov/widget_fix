// node --test mod/tests/*.node.test.mjs: the receiver over HTTP, as the app and the mod use it.
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createInterface } from 'node:readline'
import { after, before, test } from 'node:test'

const PORT = 47470 + Math.floor(Math.random() * 20)
const base = `http://127.0.0.1:${PORT}`
const project = mkdtempSync(join(tmpdir(), 'widget-fix-'))
const events = []
let receiver

/** Waits for the receiver to print an event of this type. */
async function nextEvent(type) {
  for (let waited = 0; waited < 3000; waited += 10) {
    const index = events.findIndex(event => event.type === type)
    if (index >= 0) return events.splice(index, 1)[0]
    await new Promise(resolve => setTimeout(resolve, 10))
  }
  throw new Error(`no ${type} event`)
}

const post = (path, body, headers = {}) =>
  fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) })

before(async () => {
  // flutter run's pid file outlives a new session; an old run's reports do not.
  mkdirSync(join(project, '.widget_fix', 'reports'), { recursive: true })
  writeFileSync(join(project, '.widget_fix', 'flutter.pid'), '123')
  writeFileSync(join(project, '.widget_fix', 'reports', 'r9.png'), 'old')

  receiver = spawn(process.execPath, [new URL('../server/receiver.mjs', import.meta.url).pathname], {
    cwd: project,
    env: { ...process.env, WIDGET_FIX_PORT: String(PORT) },
    stdio: ['ignore', 'pipe', 'inherit'],
  })
  createInterface({ input: receiver.stdout }).on('line', line => events.push(JSON.parse(line)))
  await nextEvent('ready')
})

after(() => {
  receiver.kill()
  rmSync(project, { recursive: true, force: true })
})

test('a new run keeps the pid file and clears the old reports', () => {
  assert.equal(readFileSync(join(project, '.widget_fix', 'flutter.pid'), 'utf8'), '123')
  assert.equal(existsSync(join(project, '.widget_fix', 'reports', 'r9.png')), false)
})

test('a report is saved with its screenshot and its chain, and handed to the mod', async () => {
  const chain = [{ type: 'Text', file: 'file:///p/lib/a.dart', line: 3 }]
  const response = await post('/report', {
    comment: 'Too dark',
    screen: 'Home',
    chain,
    screenshotPNG: Buffer.from('png').toString('base64'),
  })

  assert.deepEqual(await response.json(), { id: 'r1' })
  const { report } = await nextEvent('report')
  assert.equal(report.screenshot, join('.widget_fix', 'reports', 'r1.png'))
  assert.equal(report.screenshotPNG, undefined)
  assert.equal(readFileSync(join(project, report.screenshot), 'utf8'), 'png')
  assert.deepEqual(JSON.parse(readFileSync(join(project, '.widget_fix', 'reports', 'r1.json'), 'utf8')).chain, chain)
})

test('a launch names the report being worked on, and a live one is announced once', async () => {
  writeFileSync(join(project, '.widget_fix', 'status.json'), JSON.stringify({ r1: 'reloading' }))
  const launched = await (await post('/launched', { reason: 'reload' })).json()
  assert.deepEqual([launched.id, launched.status, launched.announced], ['r1', 'reloading', false])
  assert.deepEqual(await nextEvent('launched'), { type: 'launched', reason: 'reload' })

  writeFileSync(join(project, '.widget_fix', 'status.json'), JSON.stringify({ r1: 'live' }))
  const first = await (await fetch(`${base}/status?id=r1`)).json()
  const again = await (await post('/launched', {})).json()
  assert.deepEqual([first.status, first.announced], ['live', false])
  assert.deepEqual([again.id, again.status, again.announced], ['r1', 'live', true])
})

test('a page from another site cannot send a report', async () => {
  const fromSite = await post('/report', { comment: 'rm -rf' }, { Origin: 'https://example.com' })
  assert.equal(fromSite.status, 403)

  // Without a JSON content type a browser would not ask first; the receiver refuses it.
  const plain = await fetch(base + '/report', { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: '{"comment":"x"}' })
  assert.equal(plain.status, 415)
  assert.equal(events.some(event => event.type === 'report'), false)
})

test('a Flutter web app on localhost may send one', async () => {
  const origin = 'http://localhost:61234'
  const preflight = await fetch(base + '/report', {
    method: 'OPTIONS',
    headers: { Origin: origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type' },
  })
  assert.equal(preflight.status, 204)
  assert.equal(preflight.headers.get('access-control-allow-origin'), origin)

  const response = await post('/report', { comment: 'Bigger', screen: '' }, { Origin: origin })
  assert.equal(response.headers.get('access-control-allow-origin'), origin)
  assert.deepEqual(await response.json(), { id: 'r2' })
  await nextEvent('report')
})
