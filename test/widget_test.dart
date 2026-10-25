import 'package:becel/data/health_connect_service.dart';
import 'package:becel/data/health_store.dart';
import 'package:becel/data/local_store.dart';
import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _healthConnectChannel = MethodChannel('com.becel/health_connect');
const _localChannel = MethodChannel('com.becel/local');

String? _localJson;

Future<void> _boot(WidgetTester tester) async {
  HealthConnectService.instance.notifyDataChanged();
  HealthStore.instance.resetForTest();
  LocalStore.instance.resetForTest();
  await tester.pumpWidget(const BecelApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  await tester.tap(destination);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
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

List<String> _semanticsLabels(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((semantics) => semantics.properties.label)
    .whereType<String>()
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _localJson = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_localChannel, (call) async {
      switch (call.method) {
        case 'read':
          return _localJson;
        case 'write':
          _localJson = (call.arguments as Map)['json'] as String;
          return true;
        case 'clear':
          _localJson = null;
          return true;
        case 'shareText':
        case 'exportCsv':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_localChannel, null);
    messenger.setMockMethodCallHandler(_healthConnectChannel, null);
    HealthConnectService.instance.notifyDataChanged();
    HealthStore.instance.resetForTest();
    LocalStore.instance.resetForTest();
  });

  testWidgets('Today shows the morning brief, range, and one focus', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);

    expect(find.textContaining('brief'), findsOneWidget);
    expect(find.text('How do you feel this morning?'), findsOneWidget);
    expect(find.text('RECOVERY · PERSONAL RANGE'), findsOneWidget);
    expect(find.text('Within your usual range'), findsOneWidget);
    expect(find.text('SLEEP · LAST NIGHT'), findsOneWidget);
    expect(find.text('AEROBIC · HR ESTIMATE'), findsOneWidget);
    expect(find.text('≈149 min'), findsOneWidget);
    expect(
      _semanticsLabels(tester),
      contains(
        'Recovery within your usual range. Today 61 out of 100. '
        'Usual range 55 to 67.',
      ),
    );

    await _scrollTo(tester, find.text('ONE THING THIS WEEK'));
    expect(find.text('Two strength sessions this week'), findsOneWidget);
    expect(find.text('Log strength'), findsOneWidget);

    await _scrollTo(tester, find.text('Today’s movement'));
    expect(find.text('Latest signals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today explains when permission is missing', (tester) async {
    _setPhone(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
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
    addTearDown(
      () => messenger.setMockMethodCallHandler(_healthConnectChannel, null),
    );
    await _boot(tester);

    expect(find.text('Connect your health data'), findsOneWidget);
    expect(find.text('Open data sources'), findsOneWidget);
  });

  testWidgets('Today distinguishes no records from no permission', (
    tester,
  ) async {
    _setPhone(tester);
    _installEmptyDataFixture();
    await _boot(tester);

    expect(find.text('No Fitbit Air records yet'), findsOneWidget);
    expect(find.text('Connect your health data'), findsNothing);
  });

  testWidgets('Activity shows the observed floor and potential ceiling', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'Activity');

    expect(find.text('AEROBIC · HR ESTIMATE'), findsOneWidget);
    expect(find.text('≈149'), findsOneWidget);
    expect(find.text('observed floor'), findsOneWidget);
    expect(
      find.text('Up to 175 min if every day had heart-rate coverage.'),
      findsOneWidget,
    );
    expect(
      _semanticsLabels(tester),
      contains(
        'Observed aerobic estimate 149 minutes. Potential up to 175 minutes. '
        'Adult guideline floor 150 minutes.',
      ),
    );

    await _scrollTo(tester, find.text('Synced workouts'));
    expect(find.text('Log strength day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity logs a manual strength day', (tester) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'Activity');

    await _scrollTo(tester, find.text('Log strength day'));
    await tester.tap(find.text('Log strength day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Log a strength day'), findsOneWidget);
    await tester.ensureVisible(find.text('I did strength today'));
    await tester.tap(find.text('I did strength today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Strength day logged.'), findsOneWidget);
    expect(find.text('1 / 2 DAYS'), findsOneWidget);
    expect(_localJson, contains('strengthDays'));
  });

  testWidgets('Check-in adds context and changes the focus', (tester) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);

    await tester.tap(find.text('How do you feel this morning?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Morning check-in'), findsOneWidget);
    await tester.ensureVisible(find.text('Unwell'));
    await tester.tap(find.text('Unwell'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Checked in: Unwell'), findsOneWidget);
    await _scrollTo(tester, find.text('ONE THING THIS WEEK'));
    expect(find.text('Make today lighter'), findsOneWidget);
    expect(_localJson, contains('unwell'));
  });

  testWidgets('Sleep shows duration, adult range, stages, and pattern', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'Sleep');

    expect(find.text('REST & REPAIR'), findsOneWidget);
    expect(find.text('7–9H RANGE'), findsOneWidget);
    expect(find.text('STAGES'), findsOneWidget);
    expect(
      find.text('Stages are shown for context. Becel does not grade them.'),
      findsOneWidget,
    );
    expect(
      _semanticsLabels(tester),
      contains('Awake 0m. Light 7h. Deep 0m. REM 0m.'),
    );

    await _scrollTo(tester, find.text('7-NIGHT PATTERN'));
    expect(find.text('Sessions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History builds a weekly review with share and CSV', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'History');

    expect(find.text('WEEKLY REVIEW'), findsOneWidget);
    expect(find.textContaining('WEEK OF'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);

    await _scrollTo(tester, find.text('AEROBIC + STRENGTH'));
    expect(find.text('AEROBIC + STRENGTH'), findsOneWidget);

    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(14));
    await _scrollTo(tester, chips.first);
    await tester.ensureVisible(chips.first);
    await tester.pump();
    await tester.tap(chips.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final selectedBar = find.byKey(const ValueKey('recovery-selected-bar'));
    await tester.ensureVisible(selectedBar);
    expect(selectedBar, findsOneWidget);
    await _scrollTo(tester, find.text('LIMITED'));
    expect(find.text('LIMITED'), findsOneWidget);
    expect(find.textContaining('asleep'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('History reports a failed read instead of an empty week', (
    tester,
  ) async {
    _setPhone(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
      if (call.method == 'inspect') return _inspectionFixture();
      if (call.method == 'readHeartDetail' ||
          call.method == 'readSleepDetail') {
        throw PlatformException(code: 'test_read_error', message: 'Fixture');
      }
      if (call.method == 'readFitnessAge') return null;
      return <String, Object?>{};
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(_healthConnectChannel, null),
    );
    await _boot(tester);
    await _openTab(tester, 'History');

    expect(find.text('History could not load'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No week to review yet'), findsNothing);
  });

  testWidgets('Settings exposes check-ins, data, and about sections', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'Settings');

    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Morning check-ins'), findsOneWidget);
    expect(find.text('FITNESS PROFILE'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsOneWidget);

    await _scrollTo(tester, find.text('Delete local data'));
    expect(find.text('Delete local data'), findsOneWidget);

    await _scrollTo(tester, find.text('ABOUT'));
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets('Today settings button switches to the Settings tab', (
    tester,
  ) async {
    _setPhone(tester);
    _installReadyDataFixture();
    await _boot(tester);

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Morning check-ins'), findsOneWidget);
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
    _installReadyDataFixture();
    await _boot(tester);

    expect(tester.takeException(), isNull);
    for (final tab in ['Activity', 'Sleep', 'History', 'Settings']) {
      await _openTab(tester, tab);
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab fits at 360 px with 1.3x text.',
      );
    }
  });
}

Map<String, Object?> _inspectionFixture() => {
  'availability': 'available',
  'granted': [
    'android.permission.health.READ_HEART_RATE',
    'android.permission.health.READ_RESTING_HEART_RATE',
    'android.permission.health.READ_HEART_RATE_VARIABILITY',
    'android.permission.health.READ_SLEEP',
  ],
  'requested': const <String>[],
};

Map<String, Object?> _heartFixture({Map<String, Object?>? activityEstimate}) {
  final now = DateTime.now();
  final currentEnd = now.subtract(const Duration(hours: 2));
  final currentStart = currentEnd.subtract(const Duration(hours: 8));
  final hrv = <List<int>>[];
  final restingHr = <List<Object>>[];
  final sessions = <Map<String, Object?>>[];

  void addSession(DateTime start, DateTime end) {
    final sampleAt = start.add(const Duration(hours: 2));
    hrv.add([sampleAt.millisecondsSinceEpoch, 50]);
    restingHr.add([
      end.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      60.0,
    ]);
    sessions.add(_sleepSession(start, end));
  }

  addSession(currentStart, currentEnd);
  for (var offset = 1; offset <= 24; offset++) {
    final end = DateTime(
      currentEnd.year,
      currentEnd.month,
      currentEnd.day - offset,
      7,
    );
    addSession(end.subtract(const Duration(hours: 8)), end);
  }

  return {
    'status': 'ready',
    'granted': [
      'android.permission.health.READ_HEART_RATE',
      'android.permission.health.READ_RESTING_HEART_RATE',
      'android.permission.health.READ_HEART_RATE_VARIABILITY',
    ],
    'activityEstimate': activityEstimate,
    'hrvSamples': hrv,
    'restingHrSamples': restingHr,
  };
}

Map<String, Object?> _sleepFixture() {
  final now = DateTime.now();
  final currentEnd = now.subtract(const Duration(hours: 2));
  final sessions = <Map<String, Object?>>[
    _sleepSession(currentEnd.subtract(const Duration(hours: 8)), currentEnd),
  ];
  for (var offset = 1; offset <= 24; offset++) {
    final end = DateTime(
      currentEnd.year,
      currentEnd.month,
      currentEnd.day - offset,
      7,
    );
    sessions.add(_sleepSession(end.subtract(const Duration(hours: 8)), end));
  }
  return {
    'status': 'ready',
    'granted': ['android.permission.health.READ_SLEEP'],
    'sessions': sessions,
  };
}

Map<String, Object?> _sleepSession(DateTime start, DateTime end) => {
  'start': start.toIso8601String(),
  'end': end.toIso8601String(),
  'minutes': 420,
  'awakeMinutes': 0,
  'lightMinutes': 420,
  'deepMinutes': 0,
  'remMinutes': 0,
  'asleepIntervals': [
    [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
  ],
};

ValueNotifier<double> _installReadyDataFixture() {
  final activityMinutes = ValueNotifier<double>(149.5);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
    switch (call.method) {
      case 'inspect':
        return _inspectionFixture();
      case 'readSummary':
        return {
          'status': 'ready',
          'granted': _inspectionFixture()['granted'],
          'fitbitAirMetadataMatched': true,
        };
      case 'readHeartDetail':
        return _heartFixture(
          activityEstimate: _activityEstimateFixture(activityMinutes.value),
        );
      case 'readSleepDetail':
        return _sleepFixture();
      case 'readActivityDetail':
        return {
          'status': 'ready',
          'granted': ['android.permission.health.READ_EXERCISE'],
          'workouts': const <Object?>[],
        };
      case 'readBodyDetail':
        return {'status': 'ready', 'granted': const <String>[]};
      case 'readFitnessAge':
        return 40;
      case 'readTrends7d':
        return {
          'status': 'ready',
          'granted': const <String>[],
          'dates': const <String>[],
          'steps': const <Object?>[],
          'hrAvg': const <Object?>[],
          'sleepMinutes': const <Object?>[],
        };
      default:
        return <String, Object?>{};
    }
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(_healthConnectChannel, null);
    activityMinutes.dispose();
  });
  return activityMinutes;
}

void _installEmptyDataFixture() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
    switch (call.method) {
      case 'inspect':
        return _inspectionFixture();
      case 'readSummary':
        return {
          'status': 'ready',
          'granted': _inspectionFixture()['granted'],
          'fitbitAirMetadataMatched': true,
        };
      case 'readHeartDetail':
        return {
          'status': 'ready',
          'granted': _inspectionFixture()['granted'],
          'hrvSamples': const <Object?>[],
          'restingHrSamples': const <Object?>[],
        };
      case 'readSleepDetail':
        return {
          'status': 'ready',
          'granted': ['android.permission.health.READ_SLEEP'],
          'sessions': const <Object?>[],
        };
      case 'readActivityDetail':
        return {
          'status': 'ready',
          'granted': ['android.permission.health.READ_EXERCISE'],
          'workouts': const <Object?>[],
        };
      case 'readBodyDetail':
        return {'status': 'ready', 'granted': const <String>[]};
      case 'readTrends7d':
        return {
          'status': 'ready',
          'granted': const <String>[],
          'dates': const <String>[],
          'steps': const <Object?>[],
          'hrAvg': const <Object?>[],
          'sleepMinutes': const <Object?>[],
        };
      case 'readFitnessAge':
        return null;
      default:
        return <String, Object?>{};
    }
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(_healthConnectChannel, null),
  );
}

Map<String, Object?> _activityEstimateFixture(double equivalentMinutes) {
  final now = DateTime.now();
  final dailyDates = List.generate(
    7,
    (index) => now
        .subtract(Duration(days: 6 - index))
        .toIso8601String()
        .substring(0, 10),
  );
  return {
    'age': 40,
    'estimatedMaxHrBpm': 180,
    'restingHrBpm': 60.0,
    'restingHrAt': now.millisecondsSinceEpoch,
    'moderateMinutes': equivalentMinutes,
    'vigorousMinutes': 0.0,
    'usableDays': 6,
    'dailyDates': dailyDates,
    'dailyEquivalentMinutes': [
      null,
      0.0,
      10.0,
      20.0,
      30.0,
      40.0,
      equivalentMinutes - 100,
    ],
    'dailyCoverageMinutes': [0.0, 90.0, 60.0, 120.0, 120.0, 90.0, 60.0],
    'zoneMinutes': [0.0, 0.0, equivalentMinutes, 0.0, 0.0],
    'zoneRanges': const ['<30%', '30–<40%', '40–<60%', '60–<90%', '≥90%'],
  };
}
