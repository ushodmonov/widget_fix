import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Optional: names an element, so its reports lead with that name and the line of the widget it
/// wraps. Unmarked elements are reported through Flutter's widget creation tracking.
///
/// `Text(card.holder).fixable('card.holderName')` does the same in fewer characters.
class Fixable extends StatelessWidget {
  const Fixable(this.name, {super.key, required this.child});

  /// What the report calls the element. It only has to make sense to you, and may carry data:
  /// `'transaction.amount.${transaction.merchant}'`.
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) => kDebugMode ? FixableBox(name: name, child: child) : child;
}

/// Optional: names the screen the widgets inside it belong to, sent along with each report from
/// one of them. With an `IndexedStack` or a navigator, every screen can carry its own name: a
/// report takes the innermost one around the pressed widget.
class FixScreen extends StatelessWidget {
  const FixScreen(this.name, {super.key, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

extension FixableWidget on Widget {
  /// Names this widget for reports: the same as wrapping it in [Fixable].
  Widget fixable(String name) => kDebugMode ? FixableBox(name: name, child: this) : this;

  /// Names the screen this widget shows: the same as wrapping it in [FixScreen].
  Widget fixScreen(String name) => FixScreen(name, child: this);
}

/// The mark itself, in debug builds only.
class FixableBox extends SingleChildRenderObjectWidget {
  const FixableBox({super.key, required this.name, required super.child});

  final String name;

  @override
  RenderFixable createRenderObject(BuildContext context) => RenderFixable();
}

class RenderFixable extends RenderProxyBox {
  /// While WidgetFix looks up what a press landed on, a mark claims its whole area, the gaps between
  /// its children included, so a press anywhere inside it finds it. Every other hit test is left
  /// as it was.
  static bool claimsArea = false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!claimsArea) return super.hitTest(result, position: position);
    if (!size.contains(position)) return false;
    hitTestChildren(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
