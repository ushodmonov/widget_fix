import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Transform.translate(
            offset: const Offset(16, 10),
            child: const QuickActionButton(
              title: 'Send',
              icon: Icons.north_east_rounded,
            ).fixable('home.quickActions.send'),
          ),
        ),
        Expanded(
          child: const QuickActionButton(
            title: 'Request',
            icon: Icons.south_west_rounded,
          ).fixable('home.quickActions.request'),
        ),
        Expanded(
          child: const QuickActionButton(
            title: 'Top up',
            icon: Icons.add_rounded,
            cornerRadius: 2,
          ).fixable('home.quickActions.topUp'),
        ),
        Expanded(
          child: const QuickActionButton(
            title: 'More',
            icon: Icons.more_horiz_rounded,
          ).fixable('home.quickActions.more'),
        ),
      ],
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.cornerRadius = 20,
  });

  final String title;
  final IconData icon;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(cornerRadius);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Column(
          spacing: 8,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: Palette.surfaceRaised, borderRadius: shape),
              foregroundDecoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(color: Palette.stroke),
              ),
              child: Icon(icon, size: 20, color: Palette.accent),
            ),
            Text(
              title,
              style: ui(13, weight: .w500, color: Palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
