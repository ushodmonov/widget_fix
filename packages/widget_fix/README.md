# widget_fix

Long press any widget of your Flutter app in a debug build, type what is wrong, and the report lands in the Claude Code session running in your project, with the line of Dart that created the widget and a screenshot. Release and profile builds compile it away.

```dart
MaterialApp(
  builder: WidgetFix.builder,
  home: const HomePage(),
);
```

Optional marks name what a report points at: `Text(card.holder).fixable('card.holderName')`, and `.fixScreen('Home')` names a screen.

The package needs the widget-fix mod for Claude Code to receive the reports. The README at the root of the repository explains both.
