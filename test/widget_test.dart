import 'package:flutter_test/flutter_test.dart';
import 'package:straysafe_analytics/main.dart';

void main() {
  testWidgets('analytics dashboard loads report data', (tester) async {
    await tester.pumpWidget(const StraySafeApp());
    await tester.pumpAndSettle();

    expect(find.text('SUBDIVISION ANALYTICS'), findsOneWidget);
    expect(find.text('TOTAL REPORTS'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
  });
}
