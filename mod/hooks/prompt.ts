import type { FixReport, Incoming, WidgetLocation } from '../types'

/** What a `[fix …]` prompt calls for; sent with the system prompt while the mod is loaded. */
export const INSTRUCTIONS = `# Fix requests from the running app

A prompt that ends with a line like

[fix r1] Text "Salary, September" · lib/features/home/transaction_row.dart:36 · in TransactionRow at lib/features/activity/activity_view.dart:93 · near "Northwind GmbH", "+€4,650.00" · Activity screen · .widget_fix/reports/r1.png
[fix r2] home.quickActions.send · lib/features/home/quick_actions.dart:17 · Text "Send" at lib/features/home/quick_actions.dart:80 · .widget_fix/reports/r2.png

was sent from the Flutter app running in a debug build by the widget-fix mod: someone long-pressed a widget and typed the text above that line. The line holds the report's id and what is known about the widget, found by the app through Flutter's widget creation tracking: the name of the Fixable mark around it and the line that creates the widget the mark wraps, when the app marks it; the widget that was pressed, the text under the finger and the line that creates that widget; the widget from another file that places it ("in … at"); the labels beside it in the same row; the screen's name when the app gives one; and a screenshot with the widget outlined in red, or a red ring where the finger was. .widget_fix/reports/<id>.json holds the whole chain of widgets from the pressed one outwards.

When a prompt carries that line:
- Treat the text above it as the request. It may be a bug ("button is shifted") or a change ("make this green").
- Start at the file and line it names: the cause is in that widget, its arguments, or the widgets just around it. A widget used in many places (a shared row, a button) may need the change where it is placed, the "in … at" line, rather than in its class.
- Without a line, search the Dart sources for the text and the labels beside it; a label made from data (an amount, a date) is found through the widget that formats it, so search the neighbouring fixed labels first.
- Make the smallest change that does what was asked. Do not refactor.
- Open the screenshot only when the text and the code leave the request unclear.
- Then put the change on screen. When .widget_fix/flutter.pid exists the app runs under \`flutter run --pid-file .widget_fix/flutter.pid\`: hot reload it with \`pkill -USR1 -F .widget_fix/flutter.pid\`, or hot restart it with \`pkill -USR2 -F .widget_fix/flutter.pid\` when the change is one a hot reload keeps out (initState, a field's initial value, a static or global initialiser, main(), an enum). When the Dart MCP server is connected, its hot_reload and hot_restart tools do the same. The report counts as fixed once the app has reloaded. When neither is there, say the change needs a hot reload: r in the terminal running flutter run.
- Answer in one or two sentences: what was wrong and what changed.`

/** A `file://` URI or a path, relative to the project when it is inside it. */
export function relativePath(file: string, cwd: string) {
  let path = file
  if (path.startsWith('file://')) {
    try {
      path = decodeURIComponent(new URL(path).pathname)
    } catch {}
    // file:///C:/project/lib/main.dart on Windows.
    if (/^\/[A-Za-z]:\//.test(path)) path = path.slice(1)
  }
  return cwd && path.startsWith(cwd + '/') ? path.slice(cwd.length + 1) : path
}

const lineOf = (location: WidgetLocation, cwd: string) => `${relativePath(location.file, cwd)}:${location.line}`

/** What was pressed, in one phrase: the widget's class and the text under the finger. */
export function describePressed({ chain, text }: Pick<Incoming, 'chain' | 'text'>) {
  const type = chain?.[0]?.type
  const quoted = text ? JSON.stringify(text) : null
  return [type, quoted].filter(Boolean).join(' ') || null
}

/** The widget from another file around the pressed one: where the pressed widget's own widget is placed. */
export function placedBy(chain: WidgetLocation[] = []) {
  const [pressed, ...outer] = chain
  return pressed === undefined ? null : (outer.find(location => location.file !== pressed.file) ?? null)
}

/** The line to start at: the mark's, else the pressed widget's. */
export function sourceOf({ element, chain }: Pick<Incoming, 'element' | 'chain'>, cwd: string) {
  if (element?.file && element.line) return lineOf({ type: '', file: element.file, line: element.line }, cwd)
  return chain?.[0] ? lineOf(chain[0], cwd) : null
}

/**
 * The prompt: the person's comment as they typed it, then one line of context.
 * `INSTRUCTIONS` tells the model what a message carrying a `[fix …]` line calls for.
 */
export function promptFor(incoming: Incoming, cwd: string) {
  const { chain = [], comment, element, id, nearby = [], screen, screenshot, touch } = incoming
  const pressed = chain[0]
  const source = sourceOf(incoming, cwd)
  const description = describePressed(incoming)
  const around = placedBy(chain)

  const context = element
    ? [
        element.name,
        source,
        // A marked element says where it is; the pressed widget is added when it is another line.
        description && pressed && lineOf(pressed, cwd) !== source ? `${description} at ${lineOf(pressed, cwd)}` : description,
      ]
    : [
        description,
        source,
        around ? `in ${around.type} at ${lineOf(around, cwd)}` : null,
        nearby.length > 0 ? `near ${nearby.map(label => JSON.stringify(label)).join(', ')}` : null,
        screen ? `${screen} screen` : null,
        !pressed && touch ? `touch at ${Math.round(touch.x)},${Math.round(touch.y)}` : null,
      ]

  return `${comment}\n\n[fix ${id}] ${[...context, screenshot].filter(Boolean).join(' · ')}`
}

/** How the pane names what was pressed: the `Fixable` name, else the widget, else the screen. */
export function pressedLabel({ element, pressed, screen }: Pick<FixReport, 'element' | 'pressed' | 'screen'>) {
  return element ?? pressed ?? (screen ? `${screen} screen` : 'unnamed element')
}

const RELOAD_TOOL = /(?:^|_)(?:hot_reload|hot_restart|launch_app)$/
const RELOAD_COMMAND = /\bp?kill\b[^;&|\n]*\s-(?:s\s+)?(?:SIG)?USR[12]\b|\bflutter\s+run\b/

/**
 * Whether a tool call reloads the app: a signal to `flutter run`, the Dart MCP server's hot reload,
 * hot restart or launch. During it the pane shows the report as reloading; whether the fix reached
 * the screen comes from the app itself, when it reloads.
 */
export function isReload(tool: string, command?: string) {
  return RELOAD_TOOL.test(tool) || (tool === 'Bash' && command !== undefined && RELOAD_COMMAND.test(command))
}
