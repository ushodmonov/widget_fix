export type FixStatus = 'queued' | 'fixing' | 'reloading' | 'live' | 'stopped'

/** A widget the app's own code created, and the line that created it. */
export type WidgetLocation = {
  /** The widget's class: `Text`, `TransactionRow`. */
  type: string
  /** A `file://` URI on the machine that built the app. */
  file: string
  line: number
  column?: number
}

/** A report as the receiver prints it, one JSON line each. */
export type Incoming = {
  id: string
  comment: string
  screen: string
  screenshot: string | null
  platform?: string
  touch?: { x: number; y: number }
  /** The `Fixable` mark around what was pressed, and the line that creates the widget it wraps. */
  element?: {
    name: string
    file?: string
    line?: number
  }
  /** The widgets the app's own code created, from the pressed one outwards. */
  chain?: WidgetLocation[]
  /** The text under the finger. */
  text?: string | null
  /** The texts beside the pressed widget in the same row, nearest first. */
  nearby?: string[]
}

export type FixReport = {
  id: string
  comment: string
  /** The `Fixable` name of what was pressed, when the app marks it. */
  element: string | null
  /** What was pressed in a phrase: its widget class and the text under the finger. */
  pressed: string | null
  /** `path:line` of the line to start at, relative to the project. */
  source: string | null
  screen: string
  screenshot: string | null
  status: FixStatus
  receivedAt: number
  finishedAt: number | null
  /** Names of the files Claude edited for this report. */
  edited: string[]
}

export type Receiver = {
  state: 'starting' | 'listening' | 'failed'
  detail: string
  /** Advice that stays in the pane. */
  notice?: string
}

declare module 'claude-code' {
  interface PluginState {
    'widget-fix': { reports: FixReport[]; receiver: Receiver; now: number }
  }
}
