// Accessibility pass: every tab at 360 px with 1.3× text.
// Run: flutter test test_shots/narrow_test.dart --update-goldens
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:becel/data/health_connect_service.dart';
import 'package:becel/data/health_store.dart';
import 'package:becel/data/local_store.dart';
import 'package:becel/features/shell/shell_screen.dart';
import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/athlete_fixture.dart';
import 'screens_test.dart' show loadFonts;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  for (final tab in ['Today', 'Training', 'Sleep', 'Trends', 'Settings']) {
    testWidgets('narrow $tab', (tester) async {
      final fixture = AthleteFixture()..install();
      var local = fixture.localJson();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.becel/air_haptics'),
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(localChannel, (call) async {
        if (call.method == 'read') return local;
        if (call.method == 'write') {
          local = (call.arguments as Map)['json'] as String;
        }
        return true;
      });
      tester.view.physicalSize = const Size(360 * 1.5, 2600 * 1.5);
      tester.view.devicePixelRatio = 1.5;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      HealthConnectService.instance.notifyDataChanged();
      HealthStore.instance.resetForTest();
      LocalStore.instance.resetForTest();
      await tester.pumpWidget(const BecelApp());
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (tab != 'Today') {
        await tester.tap(
          find.descendant(
            of: find.byType(BecelNavBar),
            matching: find.byTooltip(tab),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/narrow_${tab.toLowerCase()}.png'),
      );
    });
  }
}
