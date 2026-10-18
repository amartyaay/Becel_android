import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today screen renders core scores', (tester) async {
    await tester.pumpWidget(const BecelApp());
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Recovery'), findsWidgets);
    expect(find.text('Strain'), findsWidgets);
    expect(find.text('Sleep'), findsWidgets);
    expect(find.text('Energy Bank'), findsWidgets);
    expect(find.text('Stress'), findsWidgets);
  });

  testWidgets('Open recovery detail from Today', (tester) async {
    await tester.pumpWidget(const BecelApp());
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.tap(find.text('Recovery').first);
    await tester.pumpAndSettle();

    expect(find.text('Contributors'), findsOneWidget);
    expect(find.text('HRV'), findsOneWidget);
  });

  testWidgets('Switch to Fitness tab', (tester) async {
    await tester.pumpWidget(const BecelApp());
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Cardio Load'), findsOneWidget);
    expect(find.text('This week'), findsWidgets);
  });
}
