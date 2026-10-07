import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'fixable.dart';

// Tells what a press landed on from the app itself: the widget under the finger and the line that
// created it, through the widget creation tracking `flutter run` turns on in debug builds. The app
// needs no marks for this; a `Fixable` mark adds a name and a frame.

/// A widget the app's own code created, and the line that created it.
@immutable
class FixLocation {
  const FixLocation({required this.type, required this.file, required this.line, this.column});

  /// The widget's class: `Text`, `TransactionRow`.
  final String type;

  /// The file as the compiler saw it: a `file://` URI on the machine that built the app.
  final String file;
  final int line;
  final int? column;

  String get fileName => file.substring(file.lastIndexOf('/') + 1);

  Map<String, Object?> toJson() => {'type': type, 'file': file, 'line': line, 'column': ?column};
}

/// The `Fixable` mark around what was pressed.
@immutable
class FixMark {
  const FixMark({required this.name, required this.source, required this.frame});

  final String name;

  /// The line that creates the widget the mark wraps.
  final FixLocation? source;

  /// Its frame in the app's coordinates.
  final Rect frame;
}

/// What a long press captured, before the comment is typed. Points and frames are in the app's
/// coordinates as they were at the press.
class FixTarget {
  FixTarget({
    required this.touch,
    this.screen = '',
    this.mark,
    this.chain = const [],
    this.text,
    this.nearby = const [],
    this.frame,
  });

  final Offset touch;

  /// The name of the innermost `FixScreen` around the pressed widget, or empty.
  final String screen;
  final FixMark? mark;

  /// The widgets the app's own code created, from the pressed one outwards.
  final List<FixLocation> chain;

  /// The text under the touch, when there is one.
  final String? text;

  /// The texts beside the pressed widget in the same row, nearest first.
  final List<String> nearby;

  /// What the composer lights and the screenshot outlines; null leaves a ring where the finger was.
  final Rect? frame;

  /// The app as it looked when it was pressed, as PNG, with [frame] outlined.
  Future<Uint8List?> screenshot = Future.value();

  /// How the composer labels the target: the mark and its line, else the widget and its line,
  /// else the screen.
  String? get title {
    if (mark case FixMark(:final name, :final source)) {
      return source == null ? name : '$name  ·  ${source.fileName}:${source.line}';
    }
    if (chain.isNotEmpty) return '${chain.first.type}  ·  ${chain.first.fileName}:${chain.first.line}';
    return screen.isEmpty ? null : '$screen screen';
  }
}

/// What is under [point], in global coordinates, deepest first. A press takes this when the finger
/// goes down: once a scroll view has won the press, it hides its content from hit tests until the
/// finger lifts.
List<RenderObject> hitTestAt(Offset point, int viewId) => _hitTest(point, viewId);

/// Looks up what a press at [point], in global coordinates, landed on inside [app], the element of
/// the boundary that holds the app, from the [targets] [hitTestAt] found there.
FixTarget inspect(Offset point, {required Element app, required List<RenderObject> targets}) {
  final boundary = app.renderObject! as RenderBox;
  final touch = boundary.globalToLocal(point);
  // The tree may have changed since the finger went down.
  targets = [
    for (final target in targets)
      if (target.attached) target,
  ];

  // The deepest render object a widget made. A mark claims the gaps between its children; a press
  // in one is a press on the widget the mark wraps.
  Element? pressed;
  for (final target in targets) {
    if (target.debugCreator case DebugCreator(:final element) when element.mounted) {
      pressed = element;
      break;
    }
  }
  if (pressed != null && pressed.widget is FixableBox) {
    Element? child;
    pressed.visitChildElements((element) => child = element);
    pressed = child ?? pressed;
  }
  if (pressed == null) return FixTarget(touch: touch);

  // From the pressed element out to the app's boundary; a press outside the app is not one.
  final lineage = <Element>[pressed];
  var isInApp = false;
  pressed.visitAncestorElements((ancestor) {
    if (identical(ancestor, app)) {
      isInApp = true;
      return false;
    }
    lineage.add(ancestor);
    return true;
  });
  if (!isInApp) return FixTarget(touch: touch);

  final ownFiles = _ownFiles(app);
  FixMark? mark;
  String? screen;
  final chain = <FixLocation>[];
  Element? first;
  for (final element in lineage) {
    switch (element.widget) {
      case FixableBox(:final name):
        mark ??= _mark(element, name, boundary);
      case FixScreen(:final name):
        screen ??= name;
      case Fixable():
        break;
      default:
        final location = creationLocation(element);
        if (location == null || !_isAppCode(location.file, ownFiles) || chain.length >= 20) break;
        if (chain.lastOrNull case FixLocation(
          :final file,
          :final line,
        ) when file == location.file && line == location.line) {
          break;
        }
        chain.add(location);
        first ??= element;
    }
  }

  String? text;
  Rect? textFrame;
  for (final target in targets) {
    if (target is RenderParagraph) {
      text = _readable(target.text.toPlainText());
      if (text != null) textFrame = _frame(target, boundary);
      break;
    }
  }

  // Without a mark the pressed widget is lit, unless it is most of the screen: a background.
  var frame = mark?.frame;
  final box = first?.findRenderObject();
  if (frame == null && box is RenderBox && box.hasSize) {
    final candidate = _frame(box, boundary);
    final screenArea = boundary.size.width * boundary.size.height;
    if (candidate.width * candidate.height < screenArea * 0.4) frame = candidate;
  }

  return FixTarget(
    touch: touch,
    screen: screen ?? '',
    mark: mark,
    chain: chain,
    text: text,
    nearby: _nearby(
      boundary,
      row: textFrame ?? frame ?? Rect.fromCircle(center: touch, radius: 22),
      touch: touch,
      own: text,
    ),
    frame: frame,
  );
}

/// The `Fixable` mark called [name] that is on screen now, for the director to press.
FixMark? findMark(String name, {required Element app, required int viewId}) {
  final boundary = app.renderObject! as RenderBox;
  FixMark? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget case FixableBox(name: final markName) when markName == name) {
      final mark = _mark(element, name, boundary);
      // Only a mark a press would reach: not one on a hidden tab or a covered route.
      final centre = boundary.localToGlobal(mark.frame.center);
      if (_hitTest(centre, viewId).contains(element.renderObject)) {
        found = mark;
        return;
      }
    }
    element.visitChildElements(visit);
  }

  app.visitChildElements(visit);
  return found;
}

/// The line that created [element]'s widget, when widget creation is tracked: `flutter run` and
/// `flutter test` track it in debug builds.
FixLocation? creationLocation(Element element) {
  final json = element.toDiagnosticsNode().toJsonMap(_serialization);
  final location = json['creationLocation'];
  if (location is! Map<String, Object?>) return null;
  final file = location['file'];
  final line = location['line'];
  if (file is! String || line is! int) return null;
  return FixLocation(
    type: element.widget.runtimeType.toString(),
    file: file,
    line: line,
    column: location['column'] as int?,
  );
}

final _serialization = InspectorSerializationDelegate(service: WidgetInspectorService.instance, subtreeDepth: 0);

List<RenderObject> _hitTest(Offset point, int viewId) {
  final result = HitTestResult();
  RenderFixable.claimsArea = true;
  try {
    WidgetsBinding.instance.hitTestInView(result, point, viewId);
  } finally {
    RenderFixable.claimsArea = false;
  }
  return [
    for (final entry in result.path)
      if (entry.target case final RenderObject target) target,
  ];
}

FixMark _mark(Element element, String name, RenderBox boundary) {
  Element? child;
  element.visitChildElements((inner) => child = inner);
  final box = element.renderObject! as RenderBox;
  return FixMark(
    name: name,
    source: child == null ? null : creationLocation(child!),
    frame: box.hasSize ? _frame(box, boundary) : Rect.zero,
  );
}

Rect _frame(RenderBox box, RenderBox boundary) =>
    MatrixUtils.transformRect(box.getTransformTo(boundary), Offset.zero & box.size);

/// WidgetFix's own folder, from where the app's boundary was created, so WidgetFix's widgets are never
/// what was pressed.
String? _ownFiles(Element app) {
  final file = creationLocation(app)?.file;
  final src = file?.lastIndexOf('/src/') ?? -1;
  return src < 0 ? null : file!.substring(0, src + 1);
}

/// Whether a widget was created by the app's own code: not by Flutter, a package from the pub
/// cache, or WidgetFix. Packages the app depends on by path count as its own.
bool _isAppCode(String file, String? ownFiles) =>
    !file.contains('/packages/flutter/lib/src/') &&
    !file.contains('/.pub-cache/') &&
    !file.contains('/Pub/Cache/') &&
    (ownFiles == null || !file.startsWith(ownFiles));

/// The text as a report quotes it: without icon glyphs, which live in the private use areas.
String? _readable(String text) {
  final readable = String.fromCharCodes(
    text.runes.where((rune) => !(rune >= 0xE000 && rune <= 0xF8FF) && rune < 0xF0000),
  ).trim();
  if (readable.isEmpty) return null;
  return readable.length > 120 ? '${readable.substring(0, 119)}…' : readable;
}

/// The texts on screen that share the pressed widget's row, nearest first, up to six. Hidden tabs,
/// offstage routes and scrolled-out rows are skipped: the walk follows what accessibility reads.
List<String> _nearby(RenderBox boundary, {required Rect row, required Offset touch, String? own}) {
  final screen = Offset.zero & boundary.size;
  final top = row.top - 12;
  final bottom = row.bottom + 12;
  final found = <(String, double)>[];

  void visit(RenderObject object) {
    if (object is RenderParagraph && object.attached && object.hasSize) {
      final frame = _frame(object, boundary);
      final label = _readable(object.text.toPlainText());
      if (label != null && frame.overlaps(screen) && frame.top < bottom && frame.bottom > top) {
        found.add((label, (frame.center - touch).distance));
      }
    }
    object.visitChildrenForSemantics(visit);
  }

  boundary.visitChildrenForSemantics(visit);
  found.sort((a, b) => a.$2.compareTo(b.$2));
  final labels = <String>{for (final (label, _) in found) label}..remove(own);
  return labels.take(math.min(6, labels.length)).toList();
}
