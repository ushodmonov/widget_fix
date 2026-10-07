import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';

class BalanceSummary extends StatelessWidget {
  const BalanceSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('Total balance', style: ui(14, color: Palette.textSecondary)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.string(SampleData.balance),
            maxLines: 1,
            style: mono(40, weight: .w700, color: Palette.textPrimary),
          ).fixable('home.balance.amount'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: ShapeDecoration(
            color: Palette.positive.withValues(alpha: 0.14),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              const Icon(Icons.north_east_rounded, size: 11, color: Palette.positive),
              Text(
                '${Money.string(SampleData.monthDelta)} this month',
                style: ui(13, weight: .w500, color: Palette.positive),
              ),
            ],
          ),
        ).fixable('home.balance.monthDelta'),
      ],
    );
  }
}
