import { expect, test } from 'claude-code/testing'

import type { WidgetLocation } from '../types'
import { describePressed, isReload, pressedLabel, promptFor, relativePath } from '../hooks/prompt'

const cwd = '/Users/me/tally'
const at = (type: string, path: string, line: number): WidgetLocation => ({ type, file: `file://${cwd}/${path}`, line })

const salaryChain = [
  at('Text', 'lib/features/home/transaction_row.dart', 36),
  at('Column', 'lib/features/home/transaction_row.dart', 26),
  at('Row', 'lib/features/home/transaction_row.dart', 16),
  at('TransactionRow', 'lib/features/activity/activity_view.dart', 93),
  at('ActivityView', 'lib/app/root_view.dart', 40),
]

test('an unmarked widget is named by its line, the widget that places it, its row and the screen', () => {
  const prompt = promptFor(
    {
      id: 'r1',
      comment: 'Income should be green',
      screen: 'Activity',
      screenshot: '.widget_fix/reports/r1.png',
      touch: { x: 321, y: 686 },
      chain: salaryChain,
      text: 'Salary, September',
      nearby: ['Northwind GmbH', '+€4,650.00'],
    },
    cwd,
  )

  expect(prompt).toBe(
    'Income should be green\n\n' +
      '[fix r1] Text "Salary, September" · lib/features/home/transaction_row.dart:36 · ' +
      'in TransactionRow at lib/features/activity/activity_view.dart:93 · near "Northwind GmbH", "+€4,650.00" · ' +
      'Activity screen · .widget_fix/reports/r1.png',
  )
})

test('a marked element leads with its name and line, and adds the pressed widget when it is another line', () => {
  const prompt = promptFor(
    {
      id: 'r2',
      comment: 'This button is out of line',
      screen: 'Home',
      screenshot: '.widget_fix/reports/r2.png',
      element: { name: 'home.quickActions.send', file: `file://${cwd}/lib/features/home/quick_actions.dart`, line: 17 },
      chain: [at('Text', 'lib/features/home/quick_actions.dart', 80), at('Column', 'lib/features/home/quick_actions.dart', 67)],
      text: 'Send',
      nearby: ['Request'],
    },
    cwd,
  )

  expect(prompt).toBe(
    'This button is out of line\n\n' +
      '[fix r2] home.quickActions.send · lib/features/home/quick_actions.dart:17 · ' +
      'Text "Send" at lib/features/home/quick_actions.dart:80 · .widget_fix/reports/r2.png',
  )
})

test('a mark on the pressed widget itself is not repeated', () => {
  const prompt = promptFor(
    {
      id: 'r3',
      comment: 'Name is cut off',
      screen: 'Home',
      screenshot: null,
      element: { name: 'card.holderName', file: `file://${cwd}/lib/features/home/wallet_card_view.dart`, line: 43 },
      chain: [at('Text', 'lib/features/home/wallet_card_view.dart', 43)],
      text: 'Vladimir Berest…',
    },
    cwd,
  )

  expect(prompt).toBe(
    'Name is cut off\n\n[fix r3] card.holderName · lib/features/home/wallet_card_view.dart:43 · Text "Vladimir Berest…"',
  )
})

test('with nothing known, the touch point stands in', () => {
  const prompt = promptFor(
    { id: 'r4', comment: 'Too dark', screen: '', screenshot: null, touch: { x: 120.4, y: 339.6 }, chain: [] },
    cwd,
  )

  expect(prompt).toBe('Too dark\n\n[fix r4] touch at 120,340')
})

test('paths outside the project stay whole, and Windows URIs lose their leading slash', () => {
  expect(relativePath(`file://${cwd}/lib/main.dart`, cwd)).toBe('lib/main.dart')
  expect(relativePath('file:///Users/me/shared/lib/button.dart', cwd)).toBe('/Users/me/shared/lib/button.dart')
  expect(relativePath('file:///Users/me/my%20app/lib/a.dart', '/Users/me/my app')).toBe('lib/a.dart')
  expect(relativePath('file:///C:/src/app/lib/a.dart', 'C:/src/app')).toBe('lib/a.dart')
})

test('the pane names a marked element, else the pressed widget, else the screen', () => {
  expect(describePressed({ chain: [at('Icon', 'lib/a.dart', 3)], text: null })).toBe('Icon')
  expect(describePressed({ chain: [], text: null })).toBe(null)
  expect(pressedLabel({ element: 'home.quickActions.send', pressed: 'Text "Send"', screen: 'Home' })).toBe(
    'home.quickActions.send',
  )
  expect(pressedLabel({ element: null, pressed: 'Text "Send"', screen: 'Home' })).toBe('Text "Send"')
  expect(pressedLabel({ element: null, pressed: null, screen: 'Activity' })).toBe('Activity screen')
  expect(pressedLabel({ element: null, pressed: null, screen: '' })).toBe('unnamed element')
})

test('a signal to flutter run and the Dart MCP server reload the app, whatever its server name', () => {
  expect(isReload('Bash', 'pkill -USR1 -F .widget_fix/flutter.pid')).toBe(true)
  expect(isReload('Bash', 'pkill -USR2 -F .widget_fix/flutter.pid')).toBe(true)
  expect(isReload('Bash', 'kill -USR1 $(cat .widget_fix/flutter.pid)')).toBe(true)
  expect(isReload('Bash', 'kill -s SIGUSR2 "$(cat .widget_fix/flutter.pid)"')).toBe(true)
  expect(isReload('Bash', 'cd tally && flutter run -d "iPhone 18 Pro" --pid-file ../.widget_fix/flutter.pid')).toBe(true)
  expect(isReload('mcp__dart__hot_reload')).toBe(true)
  expect(isReload('mcp__plugin_dart_dart__hot_restart')).toBe(true)
  expect(isReload('Bash', 'kill -9 1234')).toBe(false)
  expect(isReload('Bash', 'pkill -F .widget_fix/flutter.pid')).toBe(false)
  expect(isReload('Bash', 'flutter analyze')).toBe(false)
  expect(isReload('mcp__dart__analyze_files')).toBe(false)
})
