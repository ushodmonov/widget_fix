import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/sample_data.dart';
import 'balance_summary.dart';
import 'quick_actions.dart';
import 'transaction_row.dart';
import 'wallet_card_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          const _Header(),
          const BalanceSummary(),
          WalletCardView(card: SampleData.cards[0]).fixable('home.walletCard'),
          const QuickActions(),
          const _RecentActivity(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Palette.accent, shape: BoxShape.circle),
          child: Text(
            'VB',
            style: ui(15, weight: .w700, color: Palette.background),
          ),
        ).fixable('home.header.avatar'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text('Good morning', style: ui(13, color: Palette.textSecondary)),
            Text(
              SampleData.ownerFirstName,
              style: ui(18, weight: .w600, color: Palette.textPrimary),
            ),
          ],
        ).fixable('home.header.greeting'),
        const Spacer(),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Palette.surface, shape: BoxShape.circle),
          child: const _BellBadge(),
        ).fixable('home.header.notifications'),
      ],
    );
  }
}

/// `bell.badge.fill` in two colours: the bell in the text colour, the badge in red.
class _BellBadge extends StatelessWidget {
  const _BellBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 17,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_rounded, size: 17, color: Palette.textPrimary),
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Palette.negative,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.surface, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final transactions = SampleData.recentTransactions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const SectionHeader(
          'Recent activity',
          action: 'See all',
        ).fixable('home.recentActivity.header'),
        TallyCard(
          padding: 4,
          child: Column(
            children: [
              for (final transaction in transactions) ...[
                TransactionRow(transaction: transaction),
                if (transaction.id != transactions.last.id) const RowDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
