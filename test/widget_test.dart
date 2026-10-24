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

Map<String, Object?> _heartFixture() {
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
