import 'dart:math' as math;

import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';

class SpendingChart extends StatelessWidget {
  const SpendingChart({super.key});

  @override
  Widget build(BuildContext context) {
    return TallyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const SectionHeader('Spending by category', action: '30 days'),
          SizedBox(
            height: 180,
            child: CustomPaint(painter: _BarChart(SampleData.spendingByCategory)),
          ),
        ],
      ),
    ).fixable('activity.spendingChart');
  }
}

/// One bar per category on a zero-based euro scale, value labels on the leading side.
class _BarChart extends CustomPainter {
  const _BarChart(this.totals);

  final List<CategoryTotal> totals;

  static const _barWidth = 0.7;
  static const _barRadius = 7.0;
  static const _labelGap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final highest = totals.fold(0, (highest, item) => math.max(highest, item.total)) / 100;
    final step = _niceStep(math.max(highest, 1), 4);
    final tickCount = (highest / step).ceil();
    final top = tickCount * step;

    final valueLabels = [
      for (var tick = 0; tick <= tickCount; tick++)
        _label('€${(tick * step).round()}', mono(10, color: Palette.textSecondary)),
    ];
    final categoryLabels = [
      for (final item in totals)
        _label(item.category.shortName, ui(10, weight: .w500, color: Palette.textSecondary)),
    ];
    final labelWidth = valueLabels.map((label) => label.width).reduce(math.max);
    final plot = Rect.fromLTRB(
      labelWidth + _labelGap,
      valueLabels.first.height / 2,
      size.width,
      size.height - categoryLabels.first.height - _labelGap,
    );
    double y(double euros) => plot.bottom - plot.height * euros / top;

    final grid = Paint()..color = Palette.stroke;
    for (final (tick, label) in valueLabels.indexed) {
      final lineY = y(tick * step);
      canvas.drawLine(Offset(plot.left, lineY), Offset(plot.right, lineY), grid);
      label.paint(canvas, Offset(plot.left - _labelGap - label.width, lineY - label.height / 2));
    }

    final band = plot.width / totals.length;
    final bar = Paint()..color = Palette.chartMark;
    for (final (index, item) in totals.indexed) {
      final centerX = plot.left + band * (index + 0.5);
      final rect = Rect.fromLTRB(
        centerX - band * _barWidth / 2,
        y(item.total / 100),
        centerX + band * _barWidth / 2,
        plot.bottom,
      );
      final radius = math.min(_barRadius, rect.shortestSide / 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), bar);
      final label = categoryLabels[index];
      label.paint(canvas, Offset(centerX - label.width / 2, plot.bottom + _labelGap));
    }

    for (final label in [...valueLabels, ...categoryLabels]) {
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(_BarChart oldDelegate) => oldDelegate.totals != totals;

  static TextPainter _label(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A round step (1, 2 or 5 times a power of ten) that splits [highest] into about [count] parts.
  static double _niceStep(double highest, int count) {
    final raw = highest / count;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final fraction = raw / magnitude;
    final nice = fraction <= 1 ? 1 : (fraction <= 2 ? 2 : (fraction <= 5 ? 5 : 10));
    return nice * magnitude;
  }
}
