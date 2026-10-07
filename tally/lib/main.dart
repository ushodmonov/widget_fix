import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

import 'app/root_view.dart';
import 'app/theme.dart';

void main() {
  runApp(const TallyApp());
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Palette.background,
        colorScheme: const ColorScheme.dark(
          primary: Palette.accent,
          onPrimary: Palette.background,
          surface: Palette.surface,
          error: Palette.negative,
        ),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
      builder: WidgetFix.builder,
      home: const RootView(),
    );
  }
}
