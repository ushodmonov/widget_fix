# WidgetFix

**English** | [O'zbekcha](README.uz.md) | [Русский](README.ru.md)

Long press any widget of your Flutter app in a debug build, type what is wrong, press Return. The report lands in the Claude Code session already running in your project: the widget, the line of Dart that created it, a screenshot, your words. Claude fixes the code and hot reloads the app, and a banner in the app follows the fix from queued to live.

![Long presses in the simulator send reports to Claude Code in the terminal: a shifted button, square corners, a cut-off name and a red income amount, each fixed by Claude and hot reloaded](docs/demo.gif)

[Watch the demo in full quality (MP4, 70 s)](docs/demo.mp4). It was recorded live: a Claude Code session with the mod fixed Tally's four seeded bugs from the reports. Only the waits are sped up.

WidgetFix is the Flutter port of [FixKit](https://github.com/ostiums/fixkit), which does the same for SwiftUI apps in the iOS simulator.

The same tool, for each platform:

| Platform | Project | Source |
| --- | --- | --- |
| Flutter | WidgetFix | https://github.com/ushodmonov/widget_fix |
| Android (Jetpack Compose) | ComposableFix | https://github.com/ushodmonov/composable_fix |
| iOS (SwiftUI) | FixKit | https://github.com/ostiums/fixkit |

WidgetFix has two parts:

- **the widget-fix mod** for Claude Code receives the reports;
- **the widget_fix Dart package** sends them from a debug build. Release and profile builds compile it away.

## Requirements

- Claude Code 2.1.287 or later.
- Node.js 18.2 or later; the mod's receiver runs on it.
- Flutter 3.32 or later. WidgetFix works on an iOS simulator, an Android emulator, a desktop app and Flutter web, and on a phone that can reach the receiver (see [Devices](#devices)).
- Nothing else. The iOS version needed AXe to read the simulator's accessibility tree; a Flutter debug build knows which line created every widget, so the app tells the receiver itself.

## Installation

### 1. The mod

```bash
claude plugin marketplace add ushodmonov/widget_fix
claude plugin install widget-fix@widget-fix
```

The mod loads in every Claude Code session from then on, but only a session started in a Flutter project whose `pubspec.yaml` depends on `widget_fix`, or in a folder up to two levels above one, takes reports: it starts its receiver on `127.0.0.1:4747` when the session starts, and stops it when the session ends. Sessions in other folders leave the reports alone.

### 2. The package

```yaml
dependencies:
  widget_fix:
    git:
      url: https://github.com/ushodmonov/widget_fix
      path: packages/widget_fix
```

It is a regular dependency, not a dev dependency: the app imports it. In a release build it is nothing but a few `kDebugMode` checks the compiler removes.

### 3. One line in the app

```dart
import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: WidgetFix.builder,
      home: const HomePage(),
    );
  }
}
```

That is the whole integration. `CupertinoApp` and `WidgetsApp` take the same `builder`. When the app already has a builder, wrap what it returns: `builder: (context, child) => WidgetFixHost(child: MyFrame(child: child!))`. The next section explains what the host does.

### 4. The project folder

The mod writes reports to `.widget_fix/` in the Flutter project's root, the folder with `pubspec.yaml`; add `.widget_fix/` to `.gitignore`. Start `claude` in that folder, or in a folder up to two levels above it, as in a repository with the app in `mobile/`: the mod finds the nearest project below and gives Claude every path from the session's folder (`mobile/.widget_fix/flutter.pid`). In VS Code, the Claude Code extension's session runs in the folder VS Code has open. To let Claude open the screenshots and reload the app without asking each time, allow both in the project's Claude Code settings:

```json
{
  "permissions": {
    "allow": [
      "Read(./.widget_fix/**)",
      "Bash(pkill -USR1 -F .widget_fix/flutter.pid)",
      "Bash(pkill -USR2 -F .widget_fix/flutter.pid)"
    ]
  }
}
```

In a session above the project the paths carry the project's folder: `Read(./mobile/.widget_fix/**)`, `Bash(pkill -USR1 -F mobile/.widget_fix/flutter.pid)`.

### 5. Run the app so Claude can reload it

```bash
flutter run --pid-file .widget_fix/flutter.pid
```

`flutter run` hot reloads on `SIGUSR1` and hot restarts on `SIGUSR2`. With the pid file in `.widget_fix/`, Claude reloads the app itself once the fix is written: `pkill -USR1 -F .widget_fix/flutter.pid`. That is one plain command, so the allow rule above covers it; `kill -USR1 $(cat …)` would ask every time, since Claude Code cannot check a nested command before it runs. If the [Dart MCP server](https://docs.flutter.dev/ai/mcp-server) is connected to the session instead, Claude uses its `hot_reload` tool. Without either, Claude says the change needs a hot reload and you press `r`.

## Upgrading from 0.1

In 0.1 every Claude Code session started a receiver, and the newest session took port 4747 over, so the app's reports went to whichever session was opened last. From 0.2 only a session in a WidgetFix project takes reports, and the first one keeps them (see [Use it](#use-it)). To upgrade:

1. Update the mod:

   ```bash
   claude plugin marketplace update widget-fix
   claude plugin update widget-fix@widget-fix
   ```

2. Close every running `claude` session. A session still on 0.1 takes the port from the new one, as 0.1 always did. Receivers left behind by closed sessions stop by themselves within a second.
3. Start `claude` again in the Flutter project's root, the folder whose `pubspec.yaml` lists `widget_fix`, or in a folder up to two levels above it (see [The project folder](#4-the-project-folder)). 0.1 took reports in any folder; 0.2 leaves them alone anywhere else.

The app side does not change: the package, `WidgetFix.builder`, `flutter run --pid-file .widget_fix/flutter.pid`, `.widget_fix/` and the permissions stay as they are, and the app needs no `flutter pub upgrade` and no restart.

## Why `WidgetFix.builder` goes in the app's builder

The package does nothing until the host runs. `MaterialApp.builder` puts it above the navigator, so it covers every route, dialog and sheet. It does five things:

- **The long press.** It listens to raw pointer events around the app, beside the app's own gestures: buttons, lists and scroll views keep working. Once a press has stayed still for half a second it belongs to WidgetFix, which cancels the pointer for everyone else, so the button under the finger does not also act on it.
- **The lookup.** It hit tests the point and walks up from the widget under the finger. Flutter's widget creation tracking, on in every `flutter run` debug build, says which line of the app's own code created each widget: the `Text` that was pressed, the row it sits in, the widget from another file that placed the row. Widgets from Flutter, from the pub cache and from WidgetFix are skipped.
- **The composer.** It draws the dimmed screen with the pressed widget lit and the comment field above the keyboard. When the keyboard would cover the widget, it slides the app up. While the composer is open the app keeps the screen size it had, so the keyboard does not lay it out again under the light.
- **The banners.** It shows the report's progress at the top of the screen: sent, queued, fixing, reloading, fixed.
- **The reload signal.** At every launch and every hot reload it tells the receiver the app's code is new. A reload while Claude works on a report is how the mod learns the fix is on screen, whether Claude signalled `flutter run`, used the Dart MCP server, or you pressed `r` yourself. A hot reload keeps the app's state, so the screen you reported from stays on display.

In a release or profile build `WidgetFix.builder` returns the app unchanged, and since `kDebugMode` is a constant the compiler drops the rest of WidgetFix with it. `scripts/test.sh` checks that a release build of Tally holds none of it.

## Using `Fixable`

Nothing has to be marked. Without marks, the report names the widget under the finger and the line that created it:

```
Income should be green

[fix r1] Text "+€4,650.00" · lib/features/home/transaction_row.dart:50 · in TransactionRow at lib/features/activity/activity_view.dart:93 · near "Salary, September", "Northwind GmbH" · Activity screen · .widget_fix/reports/r1.png
```

`in … at` is the nearest widget from another file around it: for a shared widget, the place it was used. Mark a widget with `.fixable` when you want its reports to carry a name and to light a container rather than the text under the finger:

```dart
class WalletCardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(card.number).fixable('card.number'),
        Text(card.holder).fixable('card.holderName'),
      ],
    ).fixable('home.walletCard');
  }
}
```

`Fixable('card.number', child: Text(card.number))` is the same mark in a longer form. What a mark changes:

- **The report leads with the name.** Its line is the line that creates the widget the mark wraps, so Claude starts reading there:

  ```
  [fix r2] card.holderName · lib/features/home/wallet_card_view.dart:43 · Text "Vladimir Berest…" · .widget_fix/reports/r2.png
  ```

- **The composer lights the mark's frame**, gaps between its children included, and labels it with the name and the file. The screenshot outlines that frame. Without a mark the pressed widget is lit, unless it covers most of the screen, as a background does; then the finger gets a ring.
- **Nested marks resolve to the innermost one.** A press on the holder name above reports `card.holderName`, a press elsewhere on the card reports `home.walletCard`.

Put the mark on the widget whose code you want Claude to open: the `Text` itself for a typo or a colour, the container for spacing or layout. A name only has to make sense to you; it may carry data, as in `.fixable('transaction.amount.${transaction.merchant}')`. In a release build a mark returns the widget unchanged.

`.fixScreen('Home')`, or `FixScreen('Home', child: ...)`, names the screen. A report takes the innermost screen name around the pressed widget, so with an `IndexedStack` or a navigator every screen can carry its own. Without a mark, the name goes with the report as `Home screen`.

## Use it

1. Start `claude` in the project folder. The Fix queue pane opens in a terminal 144 columns or wider; `/fix-queue` opens it at any width. When another session already receives the project's reports, this one stands by and says so; `/fix-take` moves the reports to it.
2. Run the app in a debug build: `flutter run --pid-file .widget_fix/flutter.pid`.
3. Long press a widget in the app, type what is wrong, press Return. Escape or a tap on the dimmed screen closes the composer.

The pane and the banner in the app move through `queued`, `fixing`, `reloading` and `live`. A report turns live when the app reloads while Claude works on it, and stays live if Claude finishes with an answer. Reports sent while Claude works on one wait in the queue.

## Devices

The app looks for the receiver at `127.0.0.1:4747`, and on Android also at `10.0.2.2:4747`, the emulator's name for the computer it runs on.

| Where the app runs | What it needs |
| --- | --- |
| iOS simulator, Android emulator, Flutter web | nothing |
| macOS app | `com.apple.security.network.client` in `macos/Runner/DebugProfile.entitlements` |
| Android phone on USB | `adb reverse tcp:4747 tcp:4747` |
| any phone on the same network | `WIDGET_FIX_HOST=0.0.0.0` in the environment `claude` starts in, and `flutter run --dart-define=WIDGET_FIX_RECEIVER=http://<computer's address>:4747` |

`WIDGET_FIX_PORT` changes the port on both sides: in the environment for the receiver, as a `--dart-define` for the app.

The composer and the banners use Material icons, which every app created by `flutter create` bundles (`uses-material-design: true`).

## How it works

```
app (WidgetFix) ──POST /report──▶ receiver (node, 127.0.0.1:4747) ──▶ .widget_fix/reports/<id>.png, <id>.json
      ▲                               │ one JSON line per report
      │ POST /launched, GET /status   ▼
      └── .widget_fix/status.json ◀── the mod: prompt, Fix queue pane, statuses
```

When the press fires, the app hit tests the point, reads the creation locations of the widgets from the pressed one out to the host, collects the texts in the same row, and takes a screenshot of everything below the host, the composer left out. It sends the report once the comment is typed. The receiver saves the screenshot and the whole report, the full chain of widgets included, as `.widget_fix/reports/<id>.json`, and hands the report to the mod, which submits the prompt and adds a section to the system prompt that explains the `[fix …]` line. The mod writes every report's status to `.widget_fix/status.json`, which the app polls.

The receiver only takes JSON, and refuses requests from web pages other than ones served from `localhost`, so a site open in your browser cannot type prompts into the session.

One session receives reports at a time, and it keeps them: a session started later finds port 4747 taken and stands by, so a second `claude` in the same project, for a side question, does not catch the app's reports. `/fix-take` in that session moves them to it, and the first session's pane says where they went. A reload of the mod in the session that holds the port keeps it there.

## Example: Tally

`tally/` is the Flutter port of the SwiftUI wallet from the original FixKit, with the same four seeded UI bugs, and it depends on the package in this repository by path.

```bash
git clone https://github.com/ushodmonov/widget_fix && cd widget_fix
./scripts/reset-demo.sh                  # puts the bugs back and runs Tally under flutter run
cd tally && claude --plugin-dir ../mod   # in another terminal: the mod from this checkout
```

| Where | Long press | A comment that works |
| --- | --- | --- |
| Home | the Send button | button is shifted |
| Home | the Top up button | corners don't match the others |
| Home or Cards | the card holder name | name is cut off |
| Home or Activity | a green-category amount such as the salary | income should be green |

Each one is a one-line slip in the code. The reset script restores them from the git tag `demo-start`, the commit they were seeded in. It runs on the iPhone 18 Pro simulator; set `DEVICE` to name another simulator or any device `flutter devices` lists.

## Scripted recordings

For screen recordings WidgetFix can play reports from a script instead of a finger. Build the app with the director on, then serve steps as JSON from `http://127.0.0.1:4748/next`, one per request (204 when there are none):

```bash
flutter run --pid-file .widget_fix/flutter.pid --dart-define=WIDGET_FIX_DIRECTOR=true
```

```json
{"press": "card.holderName", "text": "The name is cut off"}
{"at": [321, 686], "text": "Income should be green"}
{"scroll": 260}
```

A press opens the composer on a `Fixable` widget on screen or at a point, types the text letter by letter and sends it. A scroll moves the vertical scroll view in the middle of the screen. The SwiftUI version's `defaults` step has no counterpart: a hot reload keeps the app's state, so there is no tab to restore.

## Development

`scripts/test.sh` runs every check: `claude plugin validate` on the marketplace and the mod, the mod's tests (`claude plugin test mod`), the receiver's tests (`node --test`), the package's and Tally's `flutter analyze` and `flutter test`, and a release build of Tally that must not contain WidgetFix.

## License

MIT, see [LICENSE](LICENSE).
