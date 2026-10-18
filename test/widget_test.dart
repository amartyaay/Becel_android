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
  testWidgets('Today shows companion header and movement hero', (
    tester,
  ) async {
    await _boot(tester);

    expect(find.text('Your day, in focus.'), findsOneWidget);
    expect(find.text('DAILY MOVEMENT'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('Activity tab shows steps hero and workout section', (
    tester,
  ) async {
    await _boot(tester);
    await _openTab(tester, 'Activity');

    expect(find.text('MOVE WITH CONTEXT'), findsOneWidget);
    expect(find.text('STEPS TODAY'), findsOneWidget);
    expect(find.text('Most recent workout'), findsOneWidget);
  });

  testWidgets('Trends tab shows the air-matched history empty state', (
    tester,
  ) async {
    await _boot(tester);
    await _openTab(tester, 'Trends');

    expect(find.text('No Fitbit Air-matched history yet'), findsOneWidget);
    expect(find.text('Review data access'), findsOneWidget);
  });

  testWidgets('Data tab shows connection sections', (tester) async {
    await _boot(tester);
    await _openTab(tester, 'Data');

    expect(find.text('Data sources'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('CONNECTIONS'), findsOneWidget);
  });

  testWidgets('Settings opens from Today', (tester) async {
    await _boot(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('YOUR DATA'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pump();

    expect(find.text('ABOUT'), findsOneWidget);
  });
}
