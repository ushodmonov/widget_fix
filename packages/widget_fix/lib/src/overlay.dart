import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inspector.dart';
import 'session.dart';

const fixTint = Color.from(alpha: 1, red: 0.85, green: 0.47, blue: 0.34);

/// The height of the comment field; the app slides up when the keyboard would put the field over
/// the pressed element.
const composerHeight = 52.0;

/// WidgetFix's own text, whatever the app's text theme says.
const _baseText = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  decoration: TextDecoration.none,
  letterSpacing: 0,
  height: 1.2,
);

/// The dimmed screen with the pressed element lit, and the comment field above the keyboard.
class FixComposer extends StatefulWidget {
  const FixComposer({super.key, required this.target, required this.session, required this.lift});

  final FixTarget target;
  final FixSession session;

  /// How far the app is slid up, so the light stays on the element.
  final double lift;

  @override
  State<FixComposer> createState() => _FixComposerState();
}

class _FixComposerState extends State<FixComposer> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  final _focus = FocusNode(debugLabel: 'widget_fix composer');

  @override
  void initState() {
    super.initState();
    // Autofocus would give way to the route that has the focus; the composer takes it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() => widget.session.send(widget.session.draft.text.trim());

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final media = MediaQuery.of(context);
    final isMarked = target.frame != null;
    final hole = RRect.fromRectAndRadius(
      (target.frame ?? Rect.fromCenter(center: target.touch, width: 0, height: 0))
          .shift(Offset(0, -widget.lift))
          .inflate(isMarked ? 6 : 28),
      Radius.circular(isMarked ? 12 : 28),
    );
    final title = target.title;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.session.cancel},
      child: DefaultTextStyle(
        style: _baseText,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.session.cancel,
              child: CustomPaint(
                painter: _Spotlight(hole: hole, pulse: _pulse),
              ),
            ),
            if (title != null)
              IgnorePointer(
                child: CustomSingleChildLayout(delegate: _LabelLayout(hole.outerRect), child: _Label(title)),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: math.max(media.viewInsets.bottom, media.padding.bottom) + 10,
              child: _field(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field() {
    final draft = widget.session.draft;
    return Container(
      height: composerHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(composerHeight / 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 36, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(composerHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: const Color(0xB31C1C1E),
              shape: StadiumBorder(side: BorderSide(color: fixTint.withValues(alpha: 0.55))),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 7),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 17, color: fixTint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: draft,
                          builder: (context, value, _) => value.text.isEmpty
                              ? Text(
                                  'What should Claude fix here?',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _baseText.copyWith(fontSize: 16, color: Colors.white54),
                                )
                              : const SizedBox.shrink(),
                        ),
                        EditableText(
                          controller: draft,
                          focusNode: _focus,
                          style: _baseText.copyWith(fontSize: 16),
                          cursorColor: fixTint,
                          backgroundCursorColor: Colors.grey,
                          selectionColor: fixTint.withValues(alpha: 0.35),
                          keyboardAppearance: Brightness.dark,
                          textInputAction: TextInputAction.send,
                          autocorrect: false,
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder(
                    valueListenable: draft,
                    builder: (context, value, _) {
                      final isEmpty = value.text.trim().isEmpty;
                      return GestureDetector(
                        onTap: isEmpty ? null : _submit,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEmpty ? Colors.white.withValues(alpha: 0.14) : fixTint,
                          ),
                          child: const Icon(Icons.keyboard_return_rounded, size: 19, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dim layer with a hole where the element is, and a pulsing ring around the hole.
class _Spotlight extends CustomPainter {
  _Spotlight({required this.hole, required this.pulse}) : super(repaint: pulse);

  final RRect hole;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.62));

    final t = Curves.easeInOut.transform(pulse.value);
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = fixTint.withValues(alpha: 0.35 + 0.6 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, 3 + 5 * t),
    );
    canvas.drawRRect(
      hole.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = fixTint,
    );
  }

  @override
  bool shouldRepaint(_Spotlight old) => old.hole != hole;
}

/// Puts the label above the lit element, or below it near the top of the screen, kept on screen.
class _LabelLayout extends SingleChildLayoutDelegate {
  _LabelLayout(this.frame);

  final Rect frame;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - 24));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (frame.center.dx - childSize.width / 2)
        .clamp(12.0, math.max(12.0, size.width - childSize.width - 12))
        .toDouble();
    final centre = frame.top > 120 ? frame.top - 22 : frame.bottom + 22;
    return Offset(x, centre - childSize.height / 2);
  }

  @override
  bool shouldRelayout(_LabelLayout old) => old.frame != frame;
}

class _Label extends StatelessWidget {
  const _Label(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final isApple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const ShapeDecoration(color: fixTint, shape: StadiumBorder()),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _baseText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: isApple ? 'Menlo' : 'monospace',
        ),
      ),
    );
  }
}

/// The report's progress, at the top of the screen.
class FixBannerView extends StatelessWidget {
  const FixBannerView({super.key, required this.banner});

  final FixBanner banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const ShapeDecoration(
        color: fixTint,
        shape: StadiumBorder(),
        shadows: [BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (banner.isWorking)
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(banner.icon, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Text(banner.text, style: _baseText.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Slides banners in from the top and fades them out.
class FixBanners extends StatelessWidget {
  const FixBanners({super.key, required this.banner});

  final FixBanner? banner;

  @override
  Widget build(BuildContext context) {
    final banner = this.banner;
    return IgnorePointer(
      child: DefaultTextStyle(
        style: _baseText,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                child: banner == null
                    ? const SizedBox.shrink()
                    : FixBannerView(key: ValueKey(banner.text), banner: banner),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
