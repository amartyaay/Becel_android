import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(const BecelApp());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Today shows the three fitness measures', (tester) async {
    await _boot(tester);

    expect(find.text('Your fitness snapshot'), findsOneWidget);
    expect(find.text('RECOVERY'), findsOneWidget);
    expect(find.text('SLEEP DURATION'), findsOneWidget);
    expect(find.text('WEEKLY ACTIVITY'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('Today’s movement'), findsOneWidget);
  });

  testWidgets('Activity tab shows the estimate and synced workouts', (
    tester,
  ) async {
    await _boot(tester);
    await _openTab(tester, 'Activity');

    expect(find.text('WEEKLY ACTIVITY'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Recent workouts'), findsOneWidget);
    expect(find.text('HR zones'), findsOneWidget);
  });

  testWidgets('Vitals tab lists measured signals and fitness snapshot', (
    tester,
  ) async {
    await _boot(tester);
    await _openTab(tester, 'Vitals');

    expect(find.text('Vitals'), findsWidgets);
    expect(find.text('Fitness snapshot'), findsOneWidget);
    expect(find.text('Recovery'), findsOneWidget);
    expect(find.text('Heart rate'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Body metrics'), findsOneWidget);
  });

  testWidgets('Today heart tile opens the heart detail screen', (tester) async {
    await _boot(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pump();
    await tester.tap(find.text('Heart rate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Heart rate'), findsOneWidget);
  });

  testWidgets('History tab shows the air-matched empty state', (tester) async {
    await _boot(tester);
    await _openTab(tester, 'History');

    expect(find.text('No Fitbit Air-matched history yet'), findsOneWidget);
    expect(find.text('Review data access'), findsOneWidget);
  });

  testWidgets('Sources tab shows connection sections', (tester) async {
    await _boot(tester);
    await _openTab(tester, 'Sources');

    expect(find.text('Data sources'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('CONNECTIONS'), findsOneWidget);
  });

  testWidgets('Settings opens from Today', (tester) async {
    await _boot(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('YOUR DATA'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pump();

    expect(find.text('ABOUT'), findsOneWidget);
  });
}
