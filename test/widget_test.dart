import 'package:becel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:becel/data/health_connect_service.dart';

const _healthConnectChannel = MethodChannel('com.becel/health_connect');

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

  testWidgets(
    'fitness summaries share threshold numbers and disclose HR estimates',
    (tester) async {
      final activityMinutes = _installReadyDataFixture();
      await _boot(tester);

      for (final (raw, displayed) in [
        (149.5, 149),
        (150.5, 150),
        (151.5, 151),
      ]) {
        if (raw != 149.5) {
          await _changeActivityMinutes(tester, activityMinutes, raw);
        }
        expect(find.text('$displayed min'), findsOneWidget);
      }
      expect(find.textContaining('not confirmed exercise'), findsOneWidget);

      await _openTab(tester, 'Vitals');
      await _changeActivityMinutes(tester, activityMinutes, 149.5);
      for (final (raw, displayed) in [
        (149.5, 149),
        (150.5, 150),
        (151.5, 151),
      ]) {
        if (raw != 149.5) {
          await _changeActivityMinutes(tester, activityMinutes, raw);
        }
        expect(find.text('$displayed'), findsOneWidget);
      }
      expect(find.textContaining('not confirmed exercise'), findsOneWidget);

      await _openTab(tester, 'Activity');
      await _changeActivityMinutes(tester, activityMinutes, 149.5);
      for (final (raw, displayed, progress) in [
        (149.5, 149, 99),
        (150.5, 150, 100),
        (151.5, 151, 100),
      ]) {
        if (raw != 149.5) {
          await _changeActivityMinutes(tester, activityMinutes, raw);
        }
        expect(find.text('$displayed'), findsOneWidget);
        expect(
          _semanticsLabels(tester),
          contains('$progress percent of the 150 minute weekly minimum'),
        );
      }
      expect(find.text('no usable HR'), findsOneWidget);
      final labels = _semanticsLabels(tester);
      expect(
        labels.any((label) => label.contains('no usable heart-rate coverage')),
        isTrue,
      );
      expect(
        labels.any(
          (label) => label.contains('0 estimated moderate-equivalent minutes'),
        ),
        isTrue,
      );
    },
  );

  testWidgets('Recovery history date chips show selected session details', (
    tester,
  ) async {
    _installReadyDataFixture();
    await _boot(tester);
    await _openTab(tester, 'History');

    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(14));
    await tester.ensureVisible(chips.last);
    await tester.tap(chips.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final session = find.textContaining('SESSION |');
    await tester.ensureVisible(session);
    await tester.pump();
    expect(session, findsOneWidget);
    expect(find.textContaining('LIMITED DATA'), findsOneWidget);
    expect(find.textContaining('HRV samples |'), findsOneWidget);
    expect(find.textContaining(DateTime.now().year.toString()), findsOneWidget);
  });

  testWidgets('Sleep lists every session in its 14-day window', (tester) async {
    _installReadyDataFixture();
    await _boot(tester);
    final sleepTile = find.text('SLEEP DURATION');
    await tester.ensureVisible(sleepTile);
    await tester.tap(sleepTile);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('REST & REPAIR'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.text('Recent sessions'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump();

    expect(find.text('LAST 14 DAYS'), findsOneWidget);
    final currentEnd = DateTime.now().subtract(const Duration(hours: 2));
    final oldestSessionEnd = DateTime(
      currentEnd.year,
      currentEnd.month,
      currentEnd.day - 10,
      7,
    );
    final oldestSession = find.byKey(
      ValueKey('sleep-session-${oldestSessionEnd.toIso8601String()}'),
    );
    await tester.dragUntilVisible(
      oldestSession,
      find.byType(ListView).first,
      const Offset(0, -320),
    );
    expect(oldestSession, findsOneWidget);
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

  testWidgets('Recovery shows its Health Connect error and retry action', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
      if (call.method == 'readHeartDetail' ||
          call.method == 'readSleepDetail') {
        throw PlatformException(code: 'test_read_error', message: 'Fixture');
      }
      if (call.method == 'inspect') return _inspectionFixture();
      if (call.method == 'readFitnessAge') return null;
      return <String, Object?>{};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_healthConnectChannel, null);
      HealthConnectService.instance.notifyDataChanged();
    });
    HealthConnectService.instance.notifyDataChanged();
    await _boot(tester);

    await tester.tap(find.text('Recovery unavailable'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.textContaining('Could not read Health Connect'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Recovery marks a one-sample signal as limited data', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_healthConnectChannel, (call) async {
      if (call.method == 'inspect') return _inspectionFixture();
      if (call.method == 'readHeartDetail') return _heartFixture();
      if (call.method == 'readSleepDetail') return _sleepFixture();
      if (call.method == 'readFitnessAge') return 40;
      return <String, Object?>{};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(_healthConnectChannel, null);
      HealthConnectService.instance.notifyDataChanged();
    });
    HealthConnectService.instance.notifyDataChanged();
    await _boot(tester);

    expect(
      find.text('Recovery trend'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .join(' | '),
    );
    await tester.tap(find.text('Recovery trend'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('LOW DATA'), findsOneWidget);
    expect(find.textContaining('LIMITED DATA'), findsOneWidget);
    expect(
      find.textContaining('Experimental personal trend only'),
      findsOneWidget,
    );
    expect(find.textContaining('1 asleep-stage samples'), findsOneWidget);
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
  for (var offset = 1; offset <= 10; offset++) {
    final end = DateTime(
      currentEnd.year,
      currentEnd.month,
      currentEnd.day - offset,
      7,
    );
    addSession(end.subtract(const Duration(hours: 8)), end);
  }

  // One current HRV sample is enough to show an estimate, but keeps its
  // confidence label limited. Daily RHR correctly needs only one value.
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
  for (var offset = 1; offset <= 10; offset++) {
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
    HealthConnectService.instance.notifyDataChanged();
    activityMinutes.dispose();
  });
  HealthConnectService.instance.notifyDataChanged();
  return activityMinutes;
}

List<String> _semanticsLabels(WidgetTester tester) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .map((semantics) => semantics.properties.label)
    .whereType<String>()
    .toList();

Future<void> _changeActivityMinutes(
  WidgetTester tester,
  ValueNotifier<double> activityMinutes,
  double value,
) async {
  activityMinutes.value = value;
  HealthConnectService.instance.notifyDataChanged();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
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
    'zoneRanges': const ['<95', '96-107', '108-131', '132-167', '168+'],
  };
}
