import 'package:becel/data/local_store.dart';
import 'package:becel/domain/profile.dart';
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
        default:
          return true;
      }
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    LocalStore.instance.resetForTest();
  });

  test('stores only the profile and reloads it', () async {
    final store = LocalStore.instance;
    const profile = BodyProfile(
      age: 35,
      sex: BiologicalSex.female,
      maxHrOverride: 188,
      sleepNeedMinutes: 510,
    );

    expect(await store.saveProfile(profile), isTrue);
    expect(stored, contains('"profile"'));
    expect(stored, isNot(contains('checkIns')));
    expect(stored, isNot(contains('strength')));

    store.resetForTest();
    await store.ensureLoaded();

    expect(store.profile?.age, 35);
    expect(store.profile?.sex, BiologicalSex.female);
    expect(store.profile?.maxHrOverride, 188);
    expect(store.profile?.sleepNeedMinutes, 510);
  });

  test('ignores legacy logs left by older versions', () async {
    stored =
        '{"version":2,"checkIns":[{"date":"2026-03-10","tags":["sore"]}],'
        '"strengthSessions":[],"profile":{"age":40,"sex":"male"}}';
    await LocalStore.instance.ensureLoaded();
    expect(LocalStore.instance.profile?.age, 40);
  });

  test('reset clears the profile', () async {
    final store = LocalStore.instance;
    await store.saveProfile(
      const BodyProfile(age: 30, sex: BiologicalSex.male),
    );
    await store.clearLocalData();
    expect(store.profile, isNull);
    expect(cleared, isTrue);
  });

  test('falls back to session-only data when the channel is missing', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, null);
    final store = LocalStore.instance;

    await store.ensureLoaded();
    final saved = await store.saveProfile(
      const BodyProfile(age: 30, sex: BiologicalSex.male),
    );

    expect(saved, isTrue);
    expect(store.profile?.age, 30);
  });
}
