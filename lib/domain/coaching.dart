import 'dart:math' as math;

import '../data/health_connect_service.dart';
import 'estimates.dart';

/// A personal range for the experimental recovery index.
///
/// The range comes from prior scored mornings only. It is deliberately shown
/// as a range instead of a percentage so a single morning is not read as
/// "percent recovered" or as training clearance.
class RecoveryContext {
  const RecoveryContext({
    required this.current,
    required this.low,
    required this.high,
    required this.median,
    required this.morningsScored,
    required this.provisional,
    required this.band,
    required this.label,
    required this.detail,
  });

  const RecoveryContext.calibrating(this.detail)
    : current = null,
      low = null,
      high = null,
      median = null,
      morningsScored = 0,
      provisional = true,
      band = RecoveryBand.unknown,
      label = 'Calibrating';

  final int? current;
  final int? low;
  final int? high;
  final double? median;
  final int morningsScored;
  final bool provisional;
  final RecoveryBand band;
  final String label;
  final String detail;

  bool get hasRange => low != null && high != null;
}

enum RecoveryBand { unknown, below, within, above }

/// Builds the usual range from prior scored mornings.
///
/// [history] is expected to include the current date. The current date is
/// excluded from the baseline so today cannot widen its own comparison band.
RecoveryContext buildRecoveryContext({
  required int? currentScore,
  required List<RecoveryHistoryPoint> history,
  required DateTime now,
}) {
  final today = _localDay(now);
  final priorScores = <int>[];
  for (final point in history) {
    if (!point.date.isBefore(today)) continue;
    final score = point.readiness?.estimate?.score;
    if (score != null) priorScores.add(score);
  }
  final morningsScored = priorScores.length + (currentScore == null ? 0 : 1);

  if (priorScores.length < 3 || currentScore == null) {
    if (currentScore == null) {
      return RecoveryContext.calibrating(
        priorScores.isEmpty
            ? 'No scored mornings yet'
            : '${priorScores.length} prior morning'
                  '${priorScores.length == 1 ? '' : 's'} scored',
      );
    }
    final low = priorScores.isEmpty
        ? math.max(0, currentScore - 10)
        : priorScores.reduce(math.min);
    final high = priorScores.isEmpty
        ? math.min(100, currentScore + 10)
        : priorScores.reduce(math.max);
    return RecoveryContext(
      current: currentScore,
      low: low,
      high: high,
      median: priorScores.isEmpty ? currentScore.toDouble() : _median(priorScores),
      morningsScored: morningsScored,
      provisional: true,
      band: RecoveryBand.unknown,
      label: 'Building your usual range',
      detail: priorScores.length < 3
          ? '${priorScores.length}/3 prior mornings needed'
          : 'Provisional range',
    );
  }

  final sorted = [...priorScores]..sort();
  final median = _median(sorted);
  final mad = _median(sorted.map((value) => (value - median).abs()).toList());
  var low = (median - math.max(6, 1.4826 * mad)).round().clamp(0, 100);
  var high = (median + math.max(6, 1.4826 * mad)).round().clamp(0, 100);
  if (high - low < 10) {
    low = (low - 5).clamp(0, 100);
    high = (high + 5).clamp(0, 100);
  }

  final band = currentScore < low
      ? RecoveryBand.below
      : currentScore > high
      ? RecoveryBand.above
      : RecoveryBand.within;
  final label = switch (band) {
    RecoveryBand.below => 'Below your usual range',
    RecoveryBand.above => 'Above your usual range',
    RecoveryBand.within => 'Within your usual range',
    RecoveryBand.unknown => 'Building your usual range',
  };
  final provisional = morningsScored < 7;

  return RecoveryContext(
    current: currentScore,
    low: low,
    high: high,
    median: median,
    morningsScored: morningsScored,
    provisional: provisional,
    band: band,
    label: label,
    detail:
        'Usual $low–$high · $morningsScored morning'
        '${morningsScored == 1 ? '' : 's'} scored',
  );
}

/// Sleep duration and timing summary over a rolling window.
class SleepTrend {
  const SleepTrend({
    required this.nights,
    required this.averageMinutes,
    required this.averageInBedMinutes,
    required this.averageBedtimeMinutes,
    required this.bedtimeSpreadMinutes,
    required this.previousAverageMinutes,
  });

  const SleepTrend.empty()
    : nights = 0,
      averageMinutes = null,
      averageInBedMinutes = null,
      averageBedtimeMinutes = null,
      bedtimeSpreadMinutes = null,
      previousAverageMinutes = null;

  final int nights;
  final int? averageMinutes;
  final int? averageInBedMinutes;
  final int? averageBedtimeMinutes;
  final int? bedtimeSpreadMinutes;
  final int? previousAverageMinutes;

  bool get hasData => nights > 0 && averageMinutes != null;

  int? get sleepDeltaMinutes {
    final current = averageMinutes;
    final previous = previousAverageMinutes;
    if (current == null || previous == null) return null;
    return current - previous;
  }

  bool get isShort => averageMinutes != null && averageMinutes! < 420;
  bool get isWithinAdultRange =>
      averageMinutes != null &&
      averageMinutes! >= 420 &&
      averageMinutes! <= 540;
  bool get isLong => averageMinutes != null && averageMinutes! > 540;
}

/// Builds a seven-night sleep summary plus the previous week's average.
///
/// Only sessions of at least three hours count, so naps do not distort the
/// weekly average or bedtime spread. The previous-week average is used only
/// for a descriptive delta; it is never graded.
SleepTrend buildSleepTrend(
  List<SleepNight> sessions, {
  DateTime? now,
  int windowDays = 7,
}) {
  final reference = (now ?? DateTime.now()).toLocal();
  final currentStart = reference.subtract(Duration(days: windowDays));
  final previousStart = reference.subtract(Duration(days: windowDays * 2));

  final current = <SleepNight>[];
  final previous = <SleepNight>[];
  for (final session in sessions) {
    if (session.minutes < 180) continue;
    final end = session.end.toLocal();
    if (end.isAfter(reference)) continue;
    if (!end.isBefore(currentStart)) {
      current.add(session);
    } else if (!end.isBefore(previousStart)) {
      previous.add(session);
    }
  }
  if (current.isEmpty) {
    return SleepTrend(
      nights: 0,
      averageMinutes: null,
      averageInBedMinutes: null,
      averageBedtimeMinutes: null,
      bedtimeSpreadMinutes: null,
      previousAverageMinutes: previous.isEmpty
          ? null
          : _average(previous.map((night) => night.minutes)),
    );
  }

  current.sort((a, b) => a.end.compareTo(b.end));
  final bedtimes = current.map((night) => _bedtimeMinute(night.start)).toList();
  final spread = bedtimes.length < 2
      ? null
      : (bedtimes.reduce(math.max) - bedtimes.reduce(math.min)).round();

  return SleepTrend(
    nights: current.length,
    averageMinutes: _average(current.map((night) => night.minutes)),
    averageInBedMinutes: _average(
      current.map((night) => _minutesBetween(night.start, night.end)),
    ),
    averageBedtimeMinutes: _average(bedtimes)?.round(),
    bedtimeSpreadMinutes: spread,
    previousAverageMinutes: previous.isEmpty
        ? null
        : _average(previous.map((night) => night.minutes)),
  );
}

/// A single, rules-based action for the week. No model or cloud service is
/// involved, and every recommendation explains the evidence behind it.
class FocusRecommendation {
  const FocusRecommendation({
    required this.kind,
    required this.title,
    required this.body,
    required this.why,
    required this.actionLabel,
  });

  final FocusKind kind;
  final String title;
  final String body;
  final String why;
  final String actionLabel;
}

enum FocusKind { sleepDuration, strength, sleepRegularity, aerobic, maintain, recover }

FocusRecommendation buildFocusRecommendation({
  required SleepTrend sleep,
  required int strengthDays,
  required ActivityEstimate? activity,
  int aerobicTarget = activityAerobicReferenceMinutes,
  Set<String> checkInTags = const <String>{},
}) {
  final averageSleep = sleep.averageMinutes;
  final aerobic = activity?.displayedEquivalentMinutes;

  if (checkInTags.contains('unwell')) {
    return const FocusRecommendation(
      kind: FocusKind.recover,
      title: 'Make today lighter',
      body:
          'You logged feeling unwell. Keep movement easy and protect your '
          'sleep window today. This is not a diagnosis.',
      why:
          'How you feel is context Becel cannot measure. If symptoms are '
          'severe, worsening, or persistent, seek medical advice instead of '
          'training through them.',
      actionLabel: 'Open sleep',
    );
  }

  if (averageSleep != null && averageSleep < 360) {
    return FocusRecommendation(
      kind: FocusKind.sleepDuration,
      title: 'Protect your sleep window',
      body:
          'You averaged ${_duration(averageSleep)} asleep over '
          '${sleep.nights} night${sleep.nights == 1 ? '' : 's'}. '
          'Try lights out 20 minutes earlier on three nights this week.',
      why:
          'Adults are advised to sleep at least seven hours regularly '
          '(AASM/Sleep Research Society). Seven hours is a population floor, '
          'not a personal target, and one short night is normal.',
      actionLabel: 'Open sleep',
    );
  }

  if (strengthDays < 2) {
    return FocusRecommendation(
      kind: FocusKind.strength,
      title: 'Two strength sessions this week',
      body:
          'You are at $strengthDays of 2 strength days. Two 20-minute '
          'sessions count — bodyweight, bands, or weights.',
      why:
          'Adult guidance pairs 150 aerobic minutes with muscle-strengthening '
          'on at least two days each week. Becel’s heart-rate activity '
          'estimate does not track strength work.',
      actionLabel: 'Log strength',
    );
  }

  if (sleep.bedtimeSpreadMinutes != null &&
      sleep.bedtimeSpreadMinutes! > 90) {
    return FocusRecommendation(
      kind: FocusKind.sleepRegularity,
      title: 'Steady your bedtime',
      body:
          'Your bedtime varied by ${_duration(sleep.bedtimeSpreadMinutes!)} '
          'this week. Pick a 15-minute window for the next three nights.',
      why:
          'Regular sleep timing is a behaviour you can control. Becel shows '
          'stage data for context but does not grade sleep stages.',
      actionLabel: 'Open sleep',
    );
  }

  if (aerobic != null && aerobic < aerobicTarget) {
    final remaining = aerobicTarget - aerobic;
    final walks = math.max(1, (remaining / 25).ceil());
    return FocusRecommendation(
      kind: FocusKind.aerobic,
      title: walks == 1 ? 'Add one 25-minute walk' : 'Add two 25-minute walks',
      body:
          'You are at $aerobic of $aerobicTarget estimated aerobic minutes. '
          '$walks brisk 25-minute walk${walks == 1 ? '' : 's'} would close '
          'the observed gap.',
      why:
          '150 minutes is the adult aerobic guideline floor. The estimate '
          'uses heart rate only, so it can miss strength work, cycling, or '
          'any activity with an atypical heart response.',
      actionLabel: 'Open activity',
    );
  }

  if (averageSleep != null && averageSleep < 420) {
    return FocusRecommendation(
      kind: FocusKind.sleepDuration,
      title: 'Nudge sleep toward seven hours',
      body:
          'You averaged ${_duration(averageSleep)} asleep. A 20-minute '
          'earlier wind-down on three nights is enough to test the change.',
      why:
          'The adult reference is at least seven hours regularly. More than '
          'nine hours is not penalised, and one night is not a verdict.',
      actionLabel: 'Open sleep',
    );
  }

  return const FocusRecommendation(
    kind: FocusKind.maintain,
    title: 'Repeat a week that worked',
    body:
        'Sleep, aerobic activity, and strength are all on track. Keep the '
        'same pattern and review again next week.',
    why:
        'Becel recommends one focus at a time. Maintaining a pattern you '
        'already manage is more useful than adding another target.',
    actionLabel: 'Review the week',
  );
}

/// Counts distinct local dates with a strength session in the rolling window.
///
/// A date counts once even when both a synced workout and a manual log exist.
int strengthDaysInWindow({
  required Iterable<StrengthCandidate> workouts,
  required Iterable<DateTime> loggedDays,
  required DateTime now,
  int days = 7,
}) {
  final reference = now.toLocal();
  final start = reference.subtract(Duration(days: days));
  final dates = <String>{};
  for (final workout in workouts) {
    if (!isStrengthType(workout.type)) continue;
    final at = workout.at.toLocal();
    if (at.isBefore(start) || at.isAfter(reference)) continue;
    dates.add(_dateKey(at));
  }
  for (final day in loggedDays) {
    final local = day.toLocal();
    if (local.isBefore(start) || local.isAfter(reference)) continue;
    dates.add(_dateKey(local));
  }
  return dates.length;
}

class StrengthCandidate {
  const StrengthCandidate({required this.at, required this.type});

  final DateTime at;
  final String type;
}

bool isStrengthType(String type) {
  final value = type.toLowerCase();
  return value.contains('strength') ||
      value.contains('weight') ||
      value.contains('resistance') ||
      value.contains('circuit') ||
      value.contains('crossfit') ||
      value.contains('powerlifting') ||
      value.contains('calisthenics') ||
      value.contains('bodyweight');
}

/// Descriptive weekly review used by Today, History, and the share sheet.
class WeeklyReview {
  const WeeklyReview({
    required this.sleep,
    required this.strengthDays,
    required this.aerobicMinutes,
    required this.aerobicPotentialMinutes,
    required this.recoveryMornings,
    required this.stepsTotal,
    required this.focus,
  });

  final SleepTrend sleep;
  final int strengthDays;
  final int? aerobicMinutes;
  final int? aerobicPotentialMinutes;
  final int recoveryMornings;
  final int? stepsTotal;
  final FocusRecommendation focus;
}

WeeklyReview buildWeeklyReview({
  required List<SleepNight> sleepSessions,
  required Iterable<StrengthCandidate> workouts,
  required Iterable<DateTime> loggedStrengthDays,
  required ActivityEstimate? activity,
  required List<RecoveryHistoryPoint> recoveryHistory,
  required List<int?> steps,
  Set<String> checkInTags = const <String>{},
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final sleep = buildSleepTrend(sleepSessions, now: reference);
  final strengthDays = strengthDaysInWindow(
    workouts: workouts,
    loggedDays: loggedStrengthDays,
    now: reference,
  );
  final recoveryMornings = recoveryHistory
      .where((point) => point.readiness?.estimate != null)
      .length;
  final stepsValues = steps.whereType<int>().toList();
  final focus = buildFocusRecommendation(
    sleep: sleep,
    strengthDays: strengthDays,
    activity: activity,
    checkInTags: checkInTags,
  );
  return WeeklyReview(
    sleep: sleep,
    strengthDays: strengthDays,
    aerobicMinutes: activity?.displayedEquivalentMinutes,
    aerobicPotentialMinutes: activity?.potentialEquivalentMinutes,
    recoveryMornings: recoveryMornings,
    stepsTotal: stepsValues.isEmpty
        ? null
        : stepsValues.fold<int>(0, (sum, value) => sum + value),
    focus: focus,
  );
}

/// Plain-language weekly summary that can be shared without a server.
String weeklySummaryText({
  required WeeklyReview review,
  required DateTime now,
}) {
  final end = now.toLocal();
  final start = end.subtract(const Duration(days: 6));
  final buffer = StringBuffer()
    ..writeln('Becel weekly summary · ${_shortDate(start)}–${_shortDate(end)}')
    ..writeln('Generated on device from Fitbit Air-matched Health Connect records.');
  if (review.sleep.averageMinutes != null) {
    final delta = review.sleep.sleepDeltaMinutes;
    buffer.writeln(
      'Sleep: ${_duration(review.sleep.averageMinutes!)} average over '
      '${review.sleep.nights} nights'
      '${delta == null ? '' : ' (${delta >= 0 ? '+' : '−'}${_duration(delta.abs())} vs prior week)'}.',
    );
  } else {
    buffer.writeln('Sleep: no qualifying sessions this week.');
  }
  if (review.aerobicMinutes != null) {
    buffer.writeln(
      'Aerobic: ${review.aerobicMinutes} of $activityAerobicReferenceMinutes '
      'estimated moderate-equivalent minutes'
      '${review.aerobicPotentialMinutes == null ? '' : ' (up to ${review.aerobicPotentialMinutes} with fuller wear)'}.',
    );
  } else {
    buffer.writeln('Aerobic: estimate unavailable this week.');
  }
  buffer
    ..writeln('Strength: ${review.strengthDays} of 2 days.')
    ..writeln('Recovery: ${review.recoveryMornings} mornings scored (experimental personal index).')
    ..writeln()
    ..writeln('One focus: ${review.focus.title}. ${review.focus.body}')
    ..writeln()
    ..writeln('Wellness context only. Not a diagnosis or training clearance.');
  return buffer.toString();
}

/// CSV export of the values Becel displays, with provenance columns.
String weeklyCsv({
  required WeeklyReview review,
  required DateTime now,
}) {
  final rows = <List<String>>[
    ['metric', 'value', 'unit', 'window', 'source', 'note'],
    [
      'sleep_average',
      review.sleep.averageMinutes?.toString() ?? '',
      'minutes_asleep',
      'last_7_local_days',
      'Health Connect / Fitbit Air',
      'Sessions of at least 3 hours only',
    ],
    [
      'sleep_in_bed_average',
      review.sleep.averageInBedMinutes?.toString() ?? '',
      'minutes_in_bed',
      'last_7_local_days',
      'Health Connect / Fitbit Air',
      'End minus start of selected sessions',
    ],
    [
      'sleep_bedtime_spread',
      review.sleep.bedtimeSpreadMinutes?.toString() ?? '',
      'minutes',
      'last_7_local_days',
      'Becel calculation',
      'Largest minus earliest recorded bedtime',
    ],
    [
      'aerobic_observed',
      review.aerobicMinutes?.toString() ?? '',
      'moderate_equivalent_minutes',
      'last_7_local_days',
      'Becel heart-rate estimate',
      'Lower bound; missing wear can undercount',
    ],
    [
      'aerobic_potential',
      review.aerobicPotentialMinutes?.toString() ?? '',
      'moderate_equivalent_minutes',
      'last_7_local_days',
      'Becel heart-rate estimate',
      'If unmeasured days matched covered days',
    ],
    [
      'strength_days',
      review.strengthDays.toString(),
      'days',
      'last_7_local_days',
      'Health Connect workouts + user log',
      'Manual logs stored on device',
    ],
    [
      'recovery_mornings_scored',
      review.recoveryMornings.toString(),
      'mornings',
      'last_14_local_days',
      'Becel experimental index',
      'Personal trend, not a readiness score',
    ],
    [
      'steps_total',
      review.stepsTotal?.toString() ?? '',
      'steps',
      'last_7_local_days',
      'Health Connect / Fitbit Air',
      'Fitbit Air-matched records only',
    ],
    ['exported_at', now.toIso8601String(), 'ISO 8601', '', 'Becel', ''],
  ];
  return rows.map(_csvRow).join('\n');
}

String _csvRow(List<String> values) => values
    .map((value) => '"${value.replaceAll('"', '""')}"')
    .join(',');

int? _average(Iterable<int> values) {
  var total = 0;
  var count = 0;
  for (final value in values) {
    total += value;
    count++;
  }
  return count == 0 ? null : (total / count).round();
}

int _minutesBetween(DateTime start, DateTime end) =>
    end.difference(start).inMinutes;

int _bedtimeMinute(DateTime time) {
  final local = time.toLocal();
  final minute = local.hour * 60 + local.minute;
  return local.hour < 12 ? minute + 24 * 60 : minute;
}

double _median(List<num> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle].toDouble();
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _duration(int minutes) {
  final value = minutes.abs();
  if (value < 60) return '${value}m';
  final hours = value ~/ 60;
  final remainder = value % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _shortDate(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = time.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}
