import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Palette.surfaceRaised, shape: BoxShape.circle),
            child: Icon(transaction.category.icon, size: 15, color: Palette.iconInk),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  transaction.merchant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ui(15, weight: .w500, color: Palette.textPrimary),
                ),
                Text(
                  transaction.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ui(12, color: Palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 3,
            children: [
              Text(
                Money.signed(transaction.amount),
                style: mono(
                  15,
                  weight: .w600,
                  color: transaction.isIncome ? Palette.negative : Palette.textPrimary,
                ),
              ).fixable('transaction.amount.${transaction.merchant}'),
              Text(_time(transaction.date), style: ui(12, color: Palette.textSecondary)),
            ],
          ),
        ],
      ),
    ).fixable('transaction.row.${transaction.merchant}');
  }

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
