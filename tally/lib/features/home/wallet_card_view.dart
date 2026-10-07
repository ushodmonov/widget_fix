import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

class WalletCardView extends StatelessWidget {
  const WalletCardView({super.key, required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final caption = ui(9, weight: .w500, color: Colors.white.withValues(alpha: 0.7));
    return _CardSurface(
      card: card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(card.name, style: ui(15, weight: .w600)),
              const Spacer(),
              const Icon(Icons.contactless_rounded, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            '••••  ••••  ••••  ${card.lastFour}',
            style: mono(20, weight: .w600),
          ).fixable('card.number'),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text('CARD HOLDER', style: caption),
                  SizedBox(
                    width: 110,
                    child: Text(
                      card.holder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui(14, weight: .w500),
                    ).fixable('card.holderName'),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text('EXPIRES', style: caption),
                  Text(card.expiry, style: mono(14, weight: .w600)),
                ],
              ),
              const Spacer(),
              Text(
                card.network,
                style: ui(17, weight: .w700).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White content on the card's gradient, clipped, desaturated while frozen, with a tinted shadow.
class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.card, required this.child});

  final PaymentCard card;
  final Widget child;

  static final _radius = BorderRadius.circular(26);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: card.gradient[0].withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(_saturation(card.isFrozen ? 0.2 : 1)),
        child: ClipRRect(
          borderRadius: _radius,
          child: CustomPaint(
            painter: _CardBackground(card.gradient),
            child: SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme.merge(
                    data: const IconThemeData(color: Colors.white),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gradient with two translucent circles, offset from the card's centre.
class _CardBackground extends CustomPainter {
  const _CardBackground(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas
      ..drawRect(rect, Paint()..shader = gradient.createShader(rect))
      ..drawCircle(
        rect.center + const Offset(130, -90),
        110,
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      )
      ..drawCircle(
        rect.center + const Offset(-150, 110),
        90,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
  }

  @override
  bool shouldRepaint(_CardBackground oldDelegate) => oldDelegate.colors != colors;
}

/// `.saturation(_:)`: moves each colour towards its own luminance.
List<double> _saturation(double amount) {
  const red = 0.2126, green = 0.7152, blue = 0.0722;
  final rest = 1 - amount;
  // dart format off
  return [
    red * rest + amount, green * rest, blue * rest, 0, 0,
    red * rest, green * rest + amount, blue * rest, 0, 0,
    red * rest, green * rest, blue * rest + amount, 0, 0,
    0, 0, 0, 1, 0,
  ];
  // dart format on
}
