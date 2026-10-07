import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/activity/activity_view.dart';
import '../features/cards/cards_view.dart';
import '../features/home/home_view.dart';
import 'theme.dart';

enum AppTab {
  home('Home', Icons.home_rounded),
  activity('Activity', Icons.bar_chart_rounded),
  cards('Cards', Icons.credit_card_rounded);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  var _selectedTab = AppTab.home;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      // Font sizes are fixed, as `Font.custom(_:fixedSize:)` keeps them on iOS.
      child: MediaQuery.withNoTextScaling(
        child: Scaffold(
          backgroundColor: Palette.background,
          body: Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: switch (_selectedTab) {
                    .home => const HomeView(),
                    .activity => const ActivityView(),
                    .cards => const CardsView(),
                  }.fixScreen(_selectedTab.label),
                ),
              ),
              _TabBar(
                selection: _selectedTab,
                onSelect: (tab) => setState(() => _selectedTab = tab),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selection, required this.onSelect});

  final AppTab selection;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.surface,
      foregroundDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: Palette.stroke)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final tab in AppTab.values)
              Expanded(
                child: _TabButton(
                  tab: tab,
                  isSelected: tab == selection,
                  onTap: () => onSelect(tab),
                ).fixable('tabBar.${tab.name}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.isSelected, required this.onTap});

  final AppTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Palette.accent : Palette.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              Icon(tab.icon, size: 19, color: color),
              Text(
                tab.label,
                style: ui(11, weight: .w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
