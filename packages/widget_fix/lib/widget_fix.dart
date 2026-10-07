/// WidgetFix: long press anything in a debug build of a Flutter app, type what is wrong, and the
/// report goes to the Claude Code session listening on this machine through the widget-fix mod.
/// Release and profile builds compile all of it away.
library;

export 'src/fixable.dart' show FixScreen, Fixable, FixableWidget;
export 'src/host.dart' show WidgetFix, WidgetFixHost;
