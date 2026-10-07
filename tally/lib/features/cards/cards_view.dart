import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/sample_data.dart';
import '../home/wallet_card_view.dart';

class CardsView extends StatefulWidget {
  const CardsView({super.key});

  @override
  State<CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<CardsView> {
  final _cards = [...SampleData.cards];
  var _selectedIndex = 0;

  PaymentCard get _card => _cards[_selectedIndex];

  void _update(PaymentCard card) => setState(() => _cards[_selectedIndex] = card);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 22,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Cards',
              style: ui(30, weight: .w700, color: Palette.textPrimary),
            ),
          ).fixable('cards.title'),
          _CardCarousel(
            cards: _cards,
            selectedIndex: _selectedIndex,
            onSelect: (index) => setState(() => _selectedIndex = index),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 22,
              children: [
                _MonthlyLimit(card: _card).fixable('cards.monthlyLimit'),
                TallyCard(
                  padding: 4,
                  child: Column(
                    children: [
                      _SettingRow(
                        title: 'Freeze card',
                        subtitle: 'Block all payments instantly',
                        icon: Icons.ac_unit_rounded,
                        isOn: _card.isFrozen,
                        onChanged: (isOn) => _update(_card.copyWith(isFrozen: isOn)),
                      ).fixable('cards.settings.freeze'),
                      const RowDivider(),
                      _SettingRow(
                        title: 'Online payments',
                        subtitle: 'Allow purchases on the web',
                        icon: Icons.public_rounded,
                        isOn: _card.allowsOnlinePayments,
                        onChanged: (isOn) => _update(_card.copyWith(allowsOnlinePayments: isOn)),
                      ).fixable('cards.settings.onlinePayments'),
                    ],
                  ),
                ),
                const _AccountDetails().fixable('cards.accountDetails'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pages through the cards one at a time: each card is as wide as the screen less 20 point margins,
/// 14 points from the next, whose edge peeks in. Shadows are not clipped.
class _CardCarousel extends StatelessWidget {
  const _CardCarousel({required this.cards, required this.selectedIndex, required this.onSelect});

  final List<PaymentCard> cards;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const margin = 20.0;
  static const spacing = 14.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200 + 26,
      child: LayoutBuilder(
        // The page width follows the carousel's, so a new width starts a new pager.
        builder: (context, constraints) => _CardPager(
          key: ValueKey(constraints.maxWidth),
          viewportFraction: (constraints.maxWidth - 2 * margin + spacing) / constraints.maxWidth,
          initialPage: selectedIndex,
          onPageChanged: onSelect,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.fromLTRB(spacing / 2, 0, spacing / 2, 26),
                child: WalletCardView(card: card),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardPager extends StatefulWidget {
  const _CardPager({
    super.key,
    required this.viewportFraction,
    required this.initialPage,
    required this.onPageChanged,
    required this.children,
  });

  final double viewportFraction;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  @override
  State<_CardPager> createState() => _CardPagerState();
}

class _CardPagerState extends State<_CardPager> {
  late final _controller = PageController(
    initialPage: widget.initialPage,
    viewportFraction: widget.viewportFraction,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      clipBehavior: Clip.none,
      onPageChanged: widget.onPageChanged,
      children: widget.children,
    );
  }
}

class _MonthlyLimit extends StatelessWidget {
  const _MonthlyLimit({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final progress = card.spentThisMonth / card.monthlyLimit;
    return TallyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const SectionHeader('Monthly limit'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              Text(
                Money.string(card.spentThisMonth),
                style: mono(22, weight: .w700, color: Palette.textPrimary),
              ),
              Text(
                'of ${Money.string(card.monthlyLimit)}',
                style: ui(13, color: Palette.textSecondary),
              ),
            ],
          ),
          _ProgressBar(value: progress.clamp(0, 1), tint: card.gradient[1]),
        ],
      ),
    );
  }
}

/// A linear `ProgressView`, `.scaleEffect(y: 1.8)`.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.tint});

  final double value;
  final Color tint;

  /// iOS's default track, `systemFill` in the dark appearance.
  static const _track = Color.from(alpha: 0.36, red: 0.471, green: 0.471, blue: 0.502);

  @override
  Widget build(BuildContext context) {
    const capsule = StadiumBorder();
    return Transform.scale(
      scaleX: 1,
      scaleY: 1.8,
      child: Container(
        height: 4,
        decoration: const ShapeDecoration(color: _track, shape: capsule),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: tint, shape: capsule),
          ),
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails();

  @override
  Widget build(BuildContext context) {
    return TallyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const SectionHeader('Account details'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('IBAN', style: ui(12, color: Palette.textSecondary)),
              Text(
                SampleData.iban,
                style: mono(14, weight: .w600, color: Palette.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isOn,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: Palette.surfaceRaised, shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: Palette.iconInk),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    title,
                    style: ui(15, weight: .w500, color: Palette.textPrimary),
                  ),
                  Text(subtitle, style: ui(12, color: Palette.textSecondary)),
                ],
              ),
            ),
            Switch.adaptive(value: isOn, onChanged: onChanged, activeTrackColor: Palette.accent),
          ],
        ),
      ),
    );
  }
}
