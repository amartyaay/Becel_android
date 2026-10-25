// Renders every Becel screen with real fonts and a synthetic athlete dataset.
//
// Run:  flutter test test_shots --update-goldens
// Output: test_shots/goldens/*.png (review artifacts, not regression goldens).
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:becel/data/health_connect_service.dart';
import 'package:becel/data/health_store.dart';
import 'package:becel/data/local_store.dart';
import 'package:becel/features/shell/shell_screen.dart';
import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/support/athlete_fixture.dart';

String? _localJson;

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'E:\Flutter\flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final name in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
    'roboto-light.ttf',
  ]) {
    final bytes = File('$dir/$name').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
  final inter = FontLoader('Inter');
  for (final weight in [400, 500, 600, 700, 800]) {
    final bytes = File('assets/fonts/Inter-$weight.ttf').readAsBytesSync();
    inter.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await inter.load();
  final nunito = FontLoader('Nunito');
  for (final weight in [600, 700, 800]) {
    final bytes = File('assets/fonts/Nunito-$weight.ttf').readAsBytesSync();
    nunito.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await nunito.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.view(
          File('$dir/materialicons-regular.otf').readAsBytesSync().buffer,
        ),
      ),
    );
  await icons.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadFonts);

  setUp(() {
    final fixture = AthleteFixture();
    _localJson = fixture.localJson();
    fixture.install();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.becel/air_haptics'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(localChannel, (call) async {
      switch (call.method) {
        case 'read':
          return _localJson;
        case 'write':
          _localJson = (call.arguments as Map)['json'] as String;
          return true;
        default:
          return true;
      }
    });
  });

  Future<void> boot(WidgetTester tester, {double height = 2600}) async {
    tester.view.physicalSize = Size(390 * 1.5, height * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    HealthConnectService.instance.notifyDataChanged();
    HealthStore.instance.resetForTest();
    LocalStore.instance.resetForTest();
    await tester.pumpWidget(const BecelApp());
    await _settle(tester);
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await _settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(BecelNavBar),
        matching: find.byTooltip(label),
      ),
    );
    await _settle(tester);
  }

  final tabs = <String, String>{
    '01_today': 'Today',
    '02_training': 'Training',
    '03_sleep': 'Sleep',
    '04_trends': 'Trends',
    '05_settings': 'Settings',
  };
  for (final entry in tabs.entries) {
    testWidgets('shot ${entry.key}', (tester) async {
      await boot(tester);
      final labels = [for (final item in ShellScreen.items) item.$3];
      if (entry.value != labels.first) {
        if (!labels.contains(entry.value)) return;
        await openTab(tester, entry.value);
      }
      await shoot(tester, entry.key);
    });
  }

  for (final route in const ['/recovery', '/energy', '/vitals', '/data']) {
    testWidgets('shot route $route', (tester) async {
      await boot(tester);
      try {
        router(tester).push(route);
      } catch (_) {
        return;
      }
      await _settle(tester);
      final error = tester.takeException();
      if (error != null) {
        // ignore: avoid_print
        print('ROUTE ERROR $route: $error');
        return;
      }
      await shoot(tester, 'r_${route.substring(1)}');
    });
  }
}
