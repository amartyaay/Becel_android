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

const _profileJson =
    '{"version":2,"checkIns":[],"strengthDays":[],"strengthSessions":[],'
    '"profile":{"age":34,"sex":"male","heightCm":180.0,"weightKg":82.0,'
    '"bodyFatPercent":15.0}}';

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
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
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

  testWidgets('Today shows the three rings, plan, and calorie reconciliation', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);

    expect(find.text('RECOVERY'), findsOneWidget);
    expect(find.text('STRAIN'), findsWidgets);
    expect(find.text('SLEEP'), findsOneWidget);
    expect(find.text('TODAY’S PLAN'), findsOneWidget);
    expect(find.text('How do you feel this morning?'), findsOneWidget);

    await _scrollTo(tester, find.text('CALORIES · SO FAR'));
    expect(find.text('BY MIDNIGHT'), findsOneWidget);
    await _scrollTo(tester, find.text('TRAINING LOAD'));
    await _scrollTo(tester, find.text('OVERNIGHT VITALS'));
    expect(tester.takeException(), isNull);
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

  testWidgets('An unwell check-in turns the plan into a rest day', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);

    await tester.tap(find.text('How do you feel this morning?'));
    await _settle(tester);
    expect(find.text('Morning check-in'), findsOneWidget);
    await tester.ensureVisible(find.text('Unwell'));
    await tester.tap(find.text('Unwell'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await _settle(tester);

    expect(find.text('Checked in: Unwell'), findsOneWidget);
    expect(find.text('Back off today'), findsOneWidget);
    expect(_localJson, contains('unwell'));
  });

  testWidgets('Training shows strain, load, zones, and workouts', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Training');

    expect(find.text('TIME IN ZONES TODAY'), findsOneWidget);
    await _scrollTo(tester, find.text('TRAINING LOAD'));
    expect(find.textContaining('ACWR'), findsOneWidget);
    await _scrollTo(tester, find.text('HEART-RATE ZONES · 7 DAYS'));
    await _scrollTo(tester, find.text('Workouts'));
    expect(find.text('strain'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logging a lift saves a session and adds strength load', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Training');

    await tester.tap(find.byTooltip('Log a lift'));
    await _settle(tester);
    expect(find.text('Log a strength session'), findsOneWidget);
    await tester.tap(find.text('Save session'));
    await _settle(tester);

    expect(
      find.text('Session logged. Strain and load updated.'),
      findsOneWidget,
    );
    expect(_localJson, contains('strengthSessions'));
    expect(_localJson, contains('"sessionRpe":7.0'));
    expect(LocalStore.instance.log.strengthSessions, hasLength(1));
  });

  testWidgets('Sleep shows performance, tonight’s need, and onset edit', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Sleep');

    expect(find.text('LAST NIGHT'), findsOneWidget);
    expect(find.text('OF NEED'), findsOneWidget);
    await _scrollTo(tester, find.text('I fell asleep later'));
    await _scrollTo(tester, find.text('TONIGHT'));
    expect(find.text('IN BED BY'), findsOneWidget);
    await _scrollTo(tester, find.text('CONSISTENCY · 7 NIGHTS'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trends builds a weekly review with share and CSV', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Trends');

    expect(find.textContaining('WEEK OF'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('NEXT WEEK’S FOCUS'), findsOneWidget);
    await _scrollTo(tester, find.text('YOUR PATTERNS'));
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

  testWidgets('Energy explains the difference from Fitbit', (tester) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    GoRouter.of(tester.element(find.byType(NavigationBar))).push('/energy');
    await _settle(tester);

    expect(find.text('TODAY SO FAR'), findsOneWidget);
    await _scrollTo(tester, find.text('WHY THEY DIFFER'));
    expect(find.textContaining('FLEX-HR'), findsWidgets);
    await _scrollTo(tester, find.text('STEPS · PHANTOM FILTER'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings exposes check-ins, profile, data, and about', (
    tester,
  ) async {
    _setPhone(tester);
    _installAthlete();
    await _boot(tester);
    await _openTab(tester, 'Settings');

    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Morning check-ins'), findsOneWidget);
    expect(find.text('FITNESS PROFILE'), findsOneWidget);
    expect(find.textContaining('15% BF'), findsOneWidget);
    await _scrollTo(tester, find.text('Delete local data'));
    await _scrollTo(tester, find.text('ABOUT'));
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
