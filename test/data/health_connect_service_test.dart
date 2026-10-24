import 'package:becel/data/health_connect_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sleep sessions within a period include its boundary and sort newest first',
    () {
      final now = DateTime(2026, 10, 24, 12);
      final cutoff = now.subtract(const Duration(days: 14));
      final detail = SleepDetail(
        status: 'ok',
        granted: const [],
        sessions: [
          _sleepNight(cutoff.subtract(const Duration(milliseconds: 1)), 1),
          _sleepNight(cutoff, 2),
          _sleepNight(now.subtract(const Duration(days: 1)), 3),
          _sleepNight(now, 4),
          _sleepNight(now.add(const Duration(milliseconds: 1)), 5),
        ],
      );

      final result = detail.sessionsEndingWithin(
        const Duration(days: 14),
        endingAt: now,
      );

      expect(result.map((session) => session.minutes), [4, 3, 2]);
    },
  );
}

SleepNight _sleepNight(DateTime end, int minutes) => SleepNight(
  start: end.subtract(const Duration(hours: 8)),
  end: end,
  minutes: minutes,
  awakeMinutes: 0,
  lightMinutes: minutes,
  deepMinutes: 0,
  remMinutes: 0,
  asleepIntervals: const [],
);
