import 'package:widget_fix/widget_fix.dart';
import 'package:widget_fix/src/inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a boundary and returns a lookup at a point, as the host makes one.
Future<FixTarget Function(Offset)> pumpApp(WidgetTester tester, Widget child) async {
  final app = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: app, child: child),
    ),
  );
  return (point) => inspect(point, app: app.currentContext! as Element, targets: hitTestAt(point, tester.view.viewId));
}

Widget box(double width, double height, {Widget? child}) => SizedBox(width: width, height: height, child: child);

void main() {
  testWidgets('the innermost mark wins, and a gap inside a mark finds it', (tester) async {
    final at = await pumpApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 150),
            const Text('Alex Morgan').fixable('card.name'),
            const SizedBox(height: 50),
          ],
        ).fixable('card'),
      ),
    );

    final name = tester.getCenter(find.text('Alex Morgan'));
    expect(at(name).mark?.name, 'card.name');
    expect(at(const Offset(4, 40)).mark?.name, 'card');
    expect(at(const Offset(4, 600)).mark, isNull);
  });

  testWidgets('a mark points at the line of the widget it wraps', (tester) async {
    final at = await pumpApp(tester, Center(child: const Text('Send').fixable('send')));

    final target = at(tester.getCenter(find.text('Send')));
    expect(target.mark?.source?.type, 'Text');
    expect(target.mark?.source?.file, endsWith('/test/inspector_test.dart'));
    expect(target.mark?.source?.line, target.chain.first.line);
    expect(target.title, 'send  ·  inspector_test.dart:${target.chain.first.line}');
  });

  testWidgets('an unmarked widget is named by the line that created it', (tester) async {
    final at = await pumpApp(tester, const Center(child: _Row()));

    final target = at(tester.getCenter(find.text('+€4,650.00')));
    expect(target.mark, isNull);
    expect(target.text, '+€4,650.00');
    expect(target.chain.first.type, 'Text');
    expect(target.chain.first.file, endsWith('/test/inspector_test.dart'));
    // Outwards: the row's own widgets, then the line that placed the row.
    expect(target.chain.map((location) => location.type), containsAllInOrder(['Text', 'Row', '_Row']));
    expect(target.frame, tester.getRect(find.text('+€4,650.00')));
  });

  testWidgets('the labels beside it are the ones in its row, nearest first', (tester) async {
    final at = await pumpApp(tester, const Center(child: _Row()));

    final target = at(tester.getCenter(find.text('+€4,650.00')));
    expect(target.nearby, ['Salary, September', 'Northwind GmbH']);
    expect(target.nearby, isNot(contains('BVG')));
  });

  testWidgets('the innermost screen name goes with the report', (tester) async {
    final at = await pumpApp(tester, Center(child: const Text('Total').fixScreen('Home')).fixScreen('App'));

    expect(at(tester.getCenter(find.text('Total'))).screen, 'Home');
  });

  testWidgets('a hidden tab is never what was pressed', (tester) async {
    final at = await pumpApp(
      tester,
      IndexedStack(
        index: 1,
        children: [
          Center(child: box(200, 200).fixable('home.card')),
          Center(child: const Text('Activity').fixable('activity.title')),
        ],
      ),
    );

    final centre = tester.getCenter(find.byType(IndexedStack));
    expect(at(centre).mark?.name, 'activity.title');
    expect(at(centre + const Offset(80, 80)).mark, isNull);
  });

  testWidgets('an icon is named by its line, not its glyph', (tester) async {
    final at = await pumpApp(tester, const Center(child: Icon(Icons.add)));

    final target = at(tester.getCenter(find.byType(Icon)));
    expect(target.text, isNull);
    expect(target.chain.first.type, 'Icon');
  });

  testWidgets('a background is not lit: the finger gets a ring', (tester) async {
    final at = await pumpApp(tester, const ColoredBox(color: Colors.black, child: SizedBox.expand()));

    final target = at(const Offset(100, 100));
    expect(target.chain.first.type, 'ColoredBox');
    expect(target.frame, isNull);
    expect(target.title, startsWith('ColoredBox  ·  inspector_test.dart:'));
  });

  testWidgets('the director finds a mark on screen by name', (tester) async {
    final app = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: app,
          child: IndexedStack(
            index: 1,
            children: [
              Center(child: const Text('Hidden').fixable('title')),
              Align(alignment: Alignment.topLeft, child: const Text('Shown').fixable('title')),
            ],
          ),
        ),
      ),
    );

    final mark = findMark('title', app: app.currentContext! as Element, viewId: tester.view.viewId);
    expect(mark?.frame, tester.getRect(find.text('Shown')));
  });
}

class _Row extends StatelessWidget {
  const _Row();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(children: [Text('BVG'), Spacer(), Text('−€3.50')]),
          const SizedBox(height: 20),
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Northwind GmbH'), Text('Salary, September')],
              ),
              const Spacer(),
              Text('+€4,650.00', style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}
