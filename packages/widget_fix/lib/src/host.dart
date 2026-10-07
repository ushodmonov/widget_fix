import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'director.dart';
import 'inspector.dart';
import 'overlay.dart';
import 'session.dart';

/// Installs the long press, the report composer and the status banners. Apply once, around the
/// app's navigator: `MaterialApp(builder: WidgetFix.builder)`.
class WidgetFixHost extends StatelessWidget {
  const WidgetFixHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => kDebugMode ? WidgetFixScope(child: child) : child;
}

abstract final class WidgetFix {
  /// For `MaterialApp.builder`, `CupertinoApp.builder` or `WidgetsApp.builder`. With a builder of
  /// the app's own, wrap what it returns: `WidgetFixHost(child: ...)`.
  static Widget builder(BuildContext context, Widget? child) {
    final app = child ?? const SizedBox.shrink();
    return kDebugMode ? WidgetFixHost(child: app) : app;
  }
}

/// How long a press lasts before it belongs to WidgetFix.
const _pressDuration = Duration(milliseconds: 500);

@visibleForTesting
class WidgetFixScope extends StatefulWidget {
  const WidgetFixScope({super.key, required this.child});

  final Widget child;

  @override
  State<WidgetFixScope> createState() => _WidgetFixScopeState();
}

class _WidgetFixScopeState extends State<WidgetFixScope> with WidgetsBindingObserver implements FixStage {
  final _app = GlobalKey(debugLabel: 'widget_fix app');

  FixSession get _session => FixSession.instance;

  /// The pointer that may become a long press, where it went down, what was under it then, and the
  /// timer that makes it a long press.
  int? _pointer;
  Offset? _origin;
  List<RenderObject> _targets = const [];
  Timer? _press;

  /// The screen as the app saw it when the composer opened. The keyboard the composer brings up
  /// must not lay the app out again under the light, so until it has gone the app keeps this.
  MediaQueryData? _frozen;
  MediaQueryData? _media;
  Timer? _thaw;

  @override
  void initState() {
    super.initState();
    _session.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_session.announceLaunch());
    if (FixDirector.isEnabled) FixDirector.start(this);
  }

  @override
  void reassemble() {
    super.reassemble();
    // A hot reload. The fix is on screen once the frame the reload causes is drawn.
    SchedulerBinding.instance.addPostFrameCallback((_) => unawaited(_session.announceLaunch(reload: true)));
  }

  @override
  void didChangeMetrics() {
    // Without a MediaQuery above, the keyboard is read from the view.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _forget();
    _thaw?.cancel();
    _session.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    if (_session.target != null) {
      _thaw?.cancel();
      _frozen ??= _media;
    } else if (_frozen != null) {
      // The keyboard slides away on its own clock, a little after the composer.
      _thaw ??= Timer(const Duration(seconds: 1), () {
        _thaw = null;
        if (mounted) setState(() => _frozen = null);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context) ?? MediaQueryData.fromView(View.of(context));
    final target = _session.target;
    if (target == null && _frozen != null && media.viewInsets.bottom <= _frozen!.viewInsets.bottom) {
      _thaw?.cancel();
      _thaw = null;
      _frozen = null;
    }
    _media = media;

    final frozen = _frozen;
    final app = MediaQuery(
      data: frozen == null
          ? media
          : media.copyWith(viewInsets: frozen.viewInsets, padding: frozen.padding, viewPadding: frozen.viewPadding),
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: RepaintBoundary(key: _app, child: widget.child),
      ),
    );

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: MediaQuery(
        data: media,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _lift(target, media)),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: app,
          builder: (context, lift, app) => Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(offset: Offset(0, -lift), child: app),
              if (target != null) FixComposer(key: ObjectKey(target), target: target, session: _session, lift: lift),
              FixBanners(banner: _session.banner),
            ],
          ),
        ),
      ),
    );
  }

  /// How far to slide the app up so the comment field does not cover the pressed element.
  double _lift(FixTarget? target, MediaQueryData media) {
    if (target == null) return 0;
    final field = media.size.height - math.max(media.viewInsets.bottom, media.padding.bottom) - 10 - composerHeight;
    final bottom = (target.frame?.bottom ?? target.touch.dy) + 28;
    return math.max(0, bottom - field);
  }

  // The long press: a pointer that stays down and still for half a second. It is read beside the
  // app's own gestures, which keep working; once it fires the press belongs to WidgetFix.

  void _down(PointerDownEvent event) {
    if (_pointer != null) return _forget(); // A second finger: a pinch, not a press.
    if (_session.target != null || _session.isSending) return;
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryMouseButton) return;

    _pointer = event.pointer;
    _origin = event.position;
    _targets = hitTestAt(event.position, event.viewId);
    _press = Timer(_pressDuration, () => _pressed(event.pointer, event.position, _targets));
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer == _pointer && (event.position - _origin!).distance > kTouchSlop) _forget();
  }

  void _end(PointerEvent event) {
    if (event.pointer == _pointer) _forget();
  }

  void _forget() {
    _press?.cancel();
    _press = null;
    _pointer = null;
    _origin = null;
    _targets = const [];
  }

  void _pressed(int pointer, Offset position, List<RenderObject> targets) {
    _forget();
    // The press is ours now: the button or scroll view under the finger must not also act on it.
    GestureBinding.instance.cancelPointer(pointer);
    _report(position, targets);
  }

  /// Opens the composer for what is at [position], in global coordinates.
  void _report(Offset position, List<RenderObject> targets) {
    final app = _app.currentContext as Element?;
    if (!mounted || app == null || _session.target != null) return;

    final target = inspect(position, app: app, targets: targets);
    target.screenshot = _capture(app.renderObject! as RenderRepaintBoundary, target);
    _session.begin(target);
  }

  /// The app as it looks when pressed, with the reported element outlined in red, or a red ring
  /// where the finger was when nothing is lit. The composer is drawn outside the boundary, so it
  /// is not in the picture.
  Future<Uint8List?> _capture(RenderRepaintBoundary boundary, FixTarget target) async {
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        await SchedulerBinding.instance.endOfFrame;
        if (!boundary.attached) return null;
        if (boundary.debugNeedsPaint) continue;

        final shot = await boundary.toImage();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawImage(shot, Offset.zero, Paint());
        final pen = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFF3B30);
        if (target.frame case final frame?) {
          canvas.drawRRect(RRect.fromRectAndRadius(frame.inflate(4), const Radius.circular(8)), pen);
        } else {
          canvas.drawCircle(target.touch, 22, pen);
        }
        final marked = await recorder.endRecording().toImage(shot.width, shot.height);
        shot.dispose();
        final png = await marked.toByteData(format: ui.ImageByteFormat.png);
        marked.dispose();
        return png?.buffer.asUint8List();
      }
    } catch (error) {
      debugPrint('widget_fix: no screenshot: $error');
    }
    return null;
  }

  // What the director drives.

  @override
  void report(Offset position) {
    if (mounted) _report(position, hitTestAt(position, View.of(context).viewId));
  }

  @override
  Offset? markCentre(String name) {
    final app = _app.currentContext as Element?;
    if (!mounted || app == null) return null;
    final mark = findMark(name, app: app, viewId: View.of(context).viewId);
    return mark == null ? null : (app.renderObject! as RenderBox).localToGlobal(mark.frame.center);
  }

  @override
  void scroll(double distance) {
    final app = _app.currentContext as Element?;
    if (!mounted || app == null) return;
    final box = app.renderObject! as RenderBox;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      box.localToGlobal(box.size.center(Offset.zero)),
      View.of(context).viewId,
    );

    for (final entry in result.path) {
      if (entry.target case RenderObject(debugCreator: DebugCreator(:final element))) {
        var scrollable = element.findAncestorStateOfType<ScrollableState>();
        while (scrollable != null && scrollable.position.axis != Axis.vertical) {
          scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
        }
        if (scrollable == null) return;
        final position = scrollable.position;
        unawaited(
          position.animateTo(
            (position.pixels + distance).clamp(position.minScrollExtent, position.maxScrollExtent),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          ),
        );
        return;
      }
    }
  }
}
