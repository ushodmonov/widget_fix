import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color.from(alpha: 1, red: 0.035, green: 0.043, blue: 0.071);
  static const surface = Color.from(alpha: 1, red: 0.082, green: 0.094, blue: 0.141);
  static const surfaceRaised = Color.from(alpha: 1, red: 0.118, green: 0.133, blue: 0.192);
  static final stroke = Colors.white.withValues(alpha: 0.07);
  static const accent = Color.from(alpha: 1, red: 0.38, green: 0.93, blue: 0.69);
  static const positive = Color.from(alpha: 1, red: 0.38, green: 0.93, blue: 0.69);
  static const negative = Color.from(alpha: 1, red: 1.00, green: 0.42, blue: 0.45);
  static const textPrimary = Colors.white;
  static final textSecondary = Colors.white.withValues(alpha: 0.56);

  /// Icons that label rather than act: neutral, so colour is left to mean something.
  static final iconInk = Colors.white.withValues(alpha: 0.78);

  /// Chart marks: a neutral tinted from the background's navy, not a hue per category.
  static const chartMark = Color.from(alpha: 1, red: 0.60, green: 0.66, blue: 0.84);
  static const cornerRadius = 22.0;
}

/// Roboto, the interface font.
TextStyle ui(double size, {FontWeight weight = .w400, Color? color}) {
  final FontWeight face = switch (weight.value) {
    >= 700 => .w700,
    >= 600 => .w600,
    >= 500 => .w500,
    <= 300 => .w300,
    _ => .w400,
  };
  return _style('Roboto', size, face, color);
}

/// iA Writer Mono, for amounts and card numbers.
TextStyle mono(double size, {FontWeight weight = .w400, Color? color}) {
  final FontWeight face = switch (weight.value) {
    >= 700 => .w700,
    >= 500 => .w600,
    _ => .w400,
  };
  return _style('iAWriterMono', size, face, color);
}

/// Both fonts are variable: the weight also goes to the `wght` axis.
TextStyle _style(String family, double size, FontWeight weight, Color? color) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  color: color,
);

abstract final class Money {
  static final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

  /// Amounts are in cents: `string(1248056)` is "€12,480.56".
  static String string(int cents) {
    final euros = (cents.abs() ~/ 100).toString().replaceAll(_thousands, ',');
    return '€$euros.${(cents.abs() % 100).toString().padLeft(2, '0')}';
  }

  /// "+€64.95" for money in, "−€7.40" for money out.
  static String signed(int cents) => (cents > 0 ? '+' : '−') + string(cents);
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: ui(18, weight: .w600, color: Palette.textPrimary),
        ),
        const Spacer(),
        if (action case final action?)
          Text(
            action,
            style: ui(14, weight: .w500, color: Palette.accent),
          ),
      ],
    );
  }
}

/// The `.card(padding:)` modifier: [child] on a rounded surface panel with a stroke.
class TallyCard extends StatelessWidget {
  const TallyCard({super.key, this.padding = 16, required this.child});

  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(Palette.cornerRadius);
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: Palette.surface, borderRadius: shape),
      foregroundDecoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: Palette.stroke),
      ),
      child: child,
    );
  }
}

/// `Divider().overlay(Theme.stroke)`: iOS draws the divider in its separator grey, and the stroke
/// washes over it. Indented past a row's icon.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  static const _separator = Color.from(alpha: 0.6, red: 0.329, green: 0.329, blue: 0.345);

  @override
  Widget build(BuildContext context) {
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Divider(
      height: hairline,
      thickness: hairline,
      indent: 58,
      color: Color.alphaBlend(Palette.stroke, _separator),
    );
  }
}
