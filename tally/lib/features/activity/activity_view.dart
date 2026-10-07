import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';
import '../home/transaction_row.dart';
import 'spending_chart.dart';

class ActivityView extends StatelessWidget {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'Activity',
            style: ui(30, weight: .w700, color: Palette.textPrimary),
          ).fixable('activity.title'),
        ),
        const SizedBox(height: 22),
        const _Totals(),
        const SizedBox(height: 22),
        const SpendingChart(),
        for (final section in SampleData.days) ...[
          const SizedBox(height: 22),
          _DaySectionView(section: section),
        ],
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: _TotalTile(
            title: 'Spent',
            amount: SampleData.totalSpent,
            icon: Icons.north_east_rounded,
            tint: Palette.negative,
          ).fixable('activity.totals.spent'),
        ),
        Expanded(
          child: _TotalTile(
            title: 'Received',
            amount: SampleData.totalIncome,
            icon: Icons.south_west_rounded,
            tint: Palette.positive,
          ).fixable('activity.totals.received'),
        ),
      ],
    );
  }
}

class _DaySectionView extends StatelessWidget {
  const _DaySectionView({required this.section});

  final DaySection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          children: [
            Text(
              _title(section.day),
              style: ui(14, weight: .w600, color: Palette.textSecondary),
            ),
            const Spacer(),
            Text(Money.signed(section.total), style: mono(13, color: Palette.textSecondary)),
          ],
        ).fixable('activity.dayHeader'),
        TallyCard(
          padding: 4,
          child: Column(
            children: [
              for (final transaction in section.transactions)
                TransactionRow(transaction: transaction),
            ],
          ),
        ),
      ],
    );
  }

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', //
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  static String _title(DateTime day) {
    final today = startOfDay(DateTime.now());
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) return 'Yesterday';
    return '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.title,
    required this.amount,
    required this.icon,
    required this.tint,
  });

  final String title;
  final int amount;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return TallyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 11, color: tint),
              Text(
                title,
                style: ui(13, weight: .w500, color: Palette.textSecondary),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.string(amount),
              maxLines: 1,
              style: mono(19, weight: .w700, color: Palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
