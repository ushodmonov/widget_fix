import 'package:widget_fix/widget_fix.dart';
import 'package:widget_fix/src/client.dart';
import 'package:widget_fix/src/inspector.dart';
import 'package:widget_fix/src/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A receiver in memory: it takes reports and answers with the statuses the test sets.
class FakeReceiver extends FixClient {
  final reports = <(FixTarget, String)>[];
  final launches = <bool>[];
  final statuses = <String>[];

  @override
  Future<String> send(FixTarget target, String comment) async {
    reports.add((target, comment));
    return 'r${reports.length}';
  }

  @override
  Future<FixStatus> status(String id) async =>
      FixStatus(run: 'test', id: id, status: statuses.isEmpty ? 'queued' : statuses.removeAt(0));

  @override
  Future<FixStatus> launched({required bool reload}) async {
    launches.add(reload);
    return const FixStatus(run: 'test');
  }
}

void main() {
  late FakeReceiver receiver;
  late int taps;
  late List<double> appInsets;

  setUp(() {
    receiver = FakeReceiver();
    FixSession.instance.client = receiver;
    taps = 0;
    appInsets = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: WidgetFix.builder,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appInsets.add(MediaQuery.viewInsetsOf(context).bottom);
              return Center(
                child: ElevatedButton(onPressed: () => taps++, child: const Text('Send')).fixable('send'),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> longPress(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
  }

  testWidgets('a long press opens the composer, and the button under it does not fire', (tester) async {
    await pumpApp(tester);
    expect(receiver.launches, [false]);

    await longPress(tester, find.text('Send'));
    expect(taps, 0);
    expect(find.text('What should Claude fix here?'), findsOneWidget);
    expect(find.textContaining('send  ·  host_test.dart:'), findsOneWidget);
    // The field has the keyboard, though the route had the focus.
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'widget_fix composer');
    expect(tester.testTextInput.isVisible, isTrue);

    // A tap on the dimmed screen closes it; a tap on the button works again.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('What should Claude fix here?'), findsNothing);
    await tester.tap(find.text('Send'));
    expect(taps, 1);
  });

  testWidgets('a text in a scroll view is found, though the scroll view takes the press', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: WidgetFix.builder,
        home: Scaffold(
          body: SingleChildScrollView(child: Column(children: [for (var row = 0; row < 40; row++) Text('Row $row')])),
        ),
      ),
    );

    await longPress(tester, find.text('Row 3'));
    await tester.enterText(find.byType(EditableText), 'Too small');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    final (target, _) = receiver.reports.single;
    expect(target.text, 'Row 3');
    expect(target.chain.first.type, 'Text');

    // The report goes live; the banner says so and goes.
    receiver.statuses.add('live');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a press that moves is a scroll, not a report', (tester) async {
    await pumpApp(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Send')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(find.text('What should Claude fix here?'), findsNothing);
  });

  testWidgets('Return sends the comment, and the banner follows the report until it is live', (tester) async {
    await pumpApp(tester);
    await longPress(tester, find.text('Send'));

    await tester.enterText(find.byType(EditableText), '  Button is shifted ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(receiver.reports.single.$2, 'Button is shifted');
    expect(receiver.reports.single.$1.mark?.name, 'send');
    expect(find.text('Sent to Claude Code'), findsOneWidget);

    receiver.statuses.addAll(['fixing', 'reloading', 'live']);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Claude is fixing it'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reloading the app'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Fixed by Claude Code'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Fixed by Claude Code'), findsNothing);
  });

  testWidgets('the keyboard the composer brings up does not lay the app out again', (tester) async {
    await pumpApp(tester);
    await longPress(tester, find.text('Send'));

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(appInsets.last, 0);
    expect(
      tester.getBottomLeft(find.text('What should Claude fix here?')).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio - 300),
    );
  });

  testWidgets('a hot reload tells the receiver the code on screen is new', (tester) async {
    await pumpApp(tester);

    // The reload finishes with a frame, which only a pump draws.
    final reloaded = tester.binding.reassembleApplication();
    await tester.pump();
    await reloaded;

    expect(receiver.launches, [false, true]);
  });
}
