import 'package:flutter_test/flutter_test.dart';
import 'package:tally/main.dart';

void main() {
  testWidgets('opens on Home and switches tabs', (tester) async {
    await tester.pumpWidget(const TallyApp());

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('€12,480.56'), findsOneWidget);

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    // The screen title and the tab's own label.
    expect(find.text('Activity'), findsNWidgets(2));
    expect(find.text('Spending by category'), findsOneWidget);
    expect(find.text('Total balance'), findsNothing);

    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Cards'), findsNWidgets(2));
    expect(find.text('Monthly limit'), findsOneWidget);
    expect(find.text('DE89 3704 0044 0532 0130 00'), findsOneWidget);
  });
}
