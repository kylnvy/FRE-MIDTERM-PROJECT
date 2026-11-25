import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:straysafe_analytics/main.dart';

Future<void> _pumpDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const StraySafeApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard shows KPI cards, charts and records', (tester) async {
    await _pumpDashboard(tester);

    expect(find.text('SUBDIVISION ANALYTICS'), findsOneWidget);
    expect(find.text('TOTAL REPORTS'), findsOneWidget);
    expect(find.text('RESOLUTION RATE'), findsOneWidget);
    expect(find.text('AVG RESPONSE'), findsOneWidget);
    expect(find.text('CASE STATUS DISTRIBUTION'), findsOneWidget);
    expect(find.text('REPORTS BY SUBDIVISION'), findsOneWidget);
    expect(find.text('INCIDENT REPORT TREND'), findsOneWidget);
    expect(find.text('CASE RECORDS (8)'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('search narrows the records, KPIs and pagination text',
      (tester) async {
    await _pumpDashboard(tester);
    expect(find.text('Showing 1–5 of 8 records'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Subdivision C');
    await tester.pumpAndSettle();

    expect(find.text('CASE RECORDS (2)'), findsOneWidget);
    expect(find.text('Showing 1–2 of 2 records'), findsOneWidget);
    expect(find.text('R-004'), findsOneWidget);
    expect(find.text('R-006'), findsOneWidget);
    expect(find.text('R-001'), findsNothing);
  });

  testWidgets('pagination moves to the next page', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.widgetWithText(InkWell, '2'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 6–8 of 8 records'), findsOneWidget);
  });

  testWidgets('priority filter and clear filters work', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('High (4)'));
    await tester.pumpAndSettle();
    expect(find.text('CASE RECORDS (4)'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('CASE RECORDS (8)'), findsOneWidget);
  });

  testWidgets('sorting by a column header reorders the records',
      (tester) async {
    await _pumpDashboard(tester);

    // Default: newest first, so R-008 is the first row.
    DataTable table() => tester.widget<DataTable>(find.byType(DataTable));
    expect(((table().rows.first.cells.first.child) as Text).data, 'R-008');

    await tester.tap(find.text('ID'));
    await tester.pumpAndSettle();
    expect(((table().rows.first.cells.first.child) as Text).data, 'R-001');
  });
}
