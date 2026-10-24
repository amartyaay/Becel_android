import 'package:becel/data/local_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.becel/local');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? stored;
  var cleared = false;

  setUp(() {
    stored = null;
    cleared = false;
    LocalStore.instance.resetForTest();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'read':
          return stored;
        case 'write':
          stored = (call.arguments as Map)['json'] as String;
          return true;
        case 'clear':
          stored = null;
          cleared = true;
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
    messenger.setMockMethodCallHandler(_channel, null);
    LocalStore.instance.resetForTest();
  });

  test('saves one check-in per local date and reloads it', () async {
    final store = LocalStore.instance;
    final day = DateTime(2026, 3, 10, 8);

    expect(
      await store.saveCheckIn(day: day, tags: {'sore'}, note: '  heavy legs  '),
      isTrue,
    );
    expect(store.log.checkInFor(day)?.tags, {'sore'});
    expect(store.log.checkInFor(day)?.note, 'heavy legs');
    expect(stored, contains('"date":"2026-03-10"'));
    expect(stored, contains('"tags":["sore"]'));

    store.resetForTest();
    await store.ensureLoaded();

    expect(store.log.checkInFor(day)?.tags, {'sore'});
    expect(store.log.checkInFor(day)?.note, 'heavy legs');
  });

  test('replaces an existing check-in for the same day', () async {
    final store = LocalStore.instance;
    final day = DateTime(2026, 3, 10);

    await store.saveCheckIn(day: day, tags: {'fresh'});
    await store.saveCheckIn(day: day, tags: {'stressed'}, note: 'deadline');

    expect(store.log.checkIns.length, 1);
    expect(store.log.checkInFor(day)?.tags, {'stressed'});
    expect(store.log.checkInFor(day)?.note, 'deadline');
  });

  test('manual strength days are distinct, sorted, and clearable', () async {
    final store = LocalStore.instance;

    await store.addStrengthDay(DateTime(2026, 3, 10, 18));
    await store.addStrengthDay(DateTime(2026, 3, 10, 7));
    await store.addStrengthDay(DateTime(2026, 3, 8));

    expect(store.log.strengthDates, hasLength(2));
    expect(store.log.strengthDates.map(localDateKey).toSet(), {
      '2026-03-08',
      '2026-03-10',
    });

    await store.clearLocalData();

    expect(store.log.checkIns, isEmpty);
    expect(store.log.strengthDays, isEmpty);
    expect(cleared, isTrue);
  });

  test('falls back to session-only data when the channel is missing', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    final store = LocalStore.instance;

    await store.ensureLoaded();
    final saved = await store.saveCheckIn(
      day: DateTime(2026, 3, 10),
      tags: {'normal'},
    );

    expect(saved, isTrue);
    expect(store.log.checkInFor(DateTime(2026, 3, 10))?.tags, {'normal'});
  });
}
