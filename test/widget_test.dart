import 'package:becel/data/health_connect_service.dart';
import 'package:becel/data/health_store.dart';
import 'package:becel/data/local_store.dart';
import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/athlete_fixture.dart';

String? _localJson;

const _profileJson = '{"version":3,"profile":{"age":34,"sex":"male"}}';

Future<void> _boot(WidgetTester tester) async {
  HealthConnectService.instance.notifyDataChanged();
  HealthStore.instance.resetForTest();
  LocalStore.instance.resetForTest();
  await tester.pumpWidget(const BecelApp());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byTooltip(label),
    ),
  );
  await _settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void _setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _installAthlete() => AthleteFixture().install();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _localJson = _profileJson;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(localChannel, (call) async {
      switch (call.method) {
        case 'read':
          return _localJson;
        case 'write':
          _localJson = (call.arguments as Map)['json'] as String;
          return true;
        case 'clear':
          _localJson = null;
          return true;
        default:
          return true;
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(localChannel, null);
    messenger.setMockMethodCallHandler(healthConnectChannel, null);
    HealthConnectService.instance.notifyDataChanged();
    HealthStore.instance.resetForTest();
    LocalStore.instance.resetForTest();
  });

  testWidgets('Today leads with recovery, calories in and out, and steps', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);

    expect(find.text('Recovery'), findsOneWidget);
    expect(find.text('Strain'), findsOneWidget);
    expect(find.text('Sleep'), findsWidgets);

    await _scrollTo(tester, find.text('Eaten'));
    expect(find.text('Burned'), findsOneWidget);
    expect(find.text('1,840'), findsOneWidget);
    await _scrollTo(tester, find.text('Protein'));
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('142'), findsOneWidget);
    await _scrollTo(tester, find.text('Today’s plan'));
    await _scrollTo(tester, find.text('Vitals'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today has no logging controls (read-only app)', (tester) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);

    expect(find.textContaining('Log a'), findsNothing);
    expect(find.text('How do you feel this morning?'), findsNothing);
  });

  testWidgets('Today explains when permission is missing', (tester) async {
    _setPhone(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(healthConnectChannel, (call) async {
      if (call.method == 'inspect') {
        return {
          'availability': 'available',
          'granted': const <String>[],
          'requested': const <String>[],
        };
      }
      if (call.method == 'readFitnessAge') return null;
      return <String, Object?>{};
    });
    await _boot(tester);

    expect(find.text('Connect your health data'), findsOneWidget);
    expect(find.text('Open data sources'), findsOneWidget);
  });

  testWidgets('Today distinguishes no records from no permission', (
    tester,
  ) async {
    _setPhone(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(healthConnectChannel, (call) async {
      return switch (call.method) {
        'inspect' => {
          'availability': 'available',
          'granted': AthleteFixture.granted,
          'requested': AthleteFixture.granted,
        },
        'readFitnessAge' => null,
        _ => {'status': 'ready', 'granted': AthleteFixture.granted},
      };
    });
    await _boot(tester);

    expect(find.text('No Fitbit Air records yet'), findsOneWidget);
    expect(find.text('Connect your health data'), findsNothing);
  });

  testWidgets('Training shows strain, load, zones, and synced workouts', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Training');

    expect(find.text('TIME IN ZONES TODAY'), findsOneWidget);
    await _scrollTo(tester, find.text('Training load'));
    expect(find.textContaining('ACWR'), findsOneWidget);
    await _scrollTo(tester, find.text('Heart-rate zones · 7 days'));
    await _scrollTo(tester, find.text('Workouts'));
    expect(find.text('strain'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sleep shows performance, tonight’s need, and consistency', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Sleep');

    expect(find.text('Last night'), findsOneWidget);
    expect(find.text('I fell asleep later'), findsNothing);
    await _scrollTo(tester, find.text('Tonight'));
    expect(find.text('IN BED BY'), findsOneWidget);
    await _scrollTo(tester, find.text('Consistency · 7 nights'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trends builds a weekly review with share and CSV', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Trends');

    expect(find.textContaining('Week of'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Next week’s focus'), findsOneWidget);
    await _scrollTo(tester, find.text('Your patterns'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trends reports a failed read instead of an empty week', (
    tester,
  ) async {
    _setPhone(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(healthConnectChannel, (call) async {
      if (call.method == 'inspect') {
        return {
          'availability': 'available',
          'granted': AthleteFixture.granted,
          'requested': AthleteFixture.granted,
        };
      }
      if (call.method == 'readHeartDetail' ||
          call.method == 'readSleepDetail') {
        throw PlatformException(code: 'test_read_error', message: 'Fixture');
      }
      if (call.method == 'readFitnessAge') return null;
      return <String, Object?>{};
    });
    await _boot(tester);
    await _openTab(tester, 'Trends');

    expect(find.text('History could not load'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Calories shows intake, 7-day balance, and the Fitbit gap', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    GoRouter.of(tester.element(find.byType(NavigationBar))).push('/energy');
    await _settle(tester);

    expect(find.text('Today so far'), findsOneWidget);
    await _scrollTo(tester, find.text('Eaten today'));
    expect(find.textContaining('g/kg'), findsWidgets);
    await _scrollTo(tester, find.text('Eaten vs burned · 7 days'));
    await _scrollTo(tester, find.text('WHY THEY DIFFER'));
    expect(find.textContaining('FLEX-HR'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings reads weight from Health Connect, not the user', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Settings');

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Age, sex & settings'), findsOneWidget);
    expect(find.text('82.4 kg · Fitbit'), findsOneWidget);
    await _scrollTo(tester, find.text('Reset profile'));
    expect(find.text('Morning check-ins'), findsNothing);
  });

  testWidgets('All tabs survive 360 px and large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    _installAthlete();
    await _boot(tester);

    expect(tester.takeException(), isNull);
    for (final tab in ['Training', 'Sleep', 'Trends', 'Settings']) {
      await _openTab(tester, tab);
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab fits at 360 px with 1.3x text.',
      );
    }
  });
}
