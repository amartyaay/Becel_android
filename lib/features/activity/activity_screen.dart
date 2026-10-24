import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../shell/shell_screen.dart';
import 'strength_log_sheet.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _health = HealthStore.instance;
  final _local = LocalStore.instance;
  late final Listenable _listenable = Listenable.merge([_health, _local]);

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
    _local.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _listenable,
          builder: (context, _) {
            final snapshot = _health.snapshot;
            final strengthDays = snapshot == null
                ? 0
                : strengthDaysInWindow(
                    workouts: snapshot.strengthCandidates,
                    loggedDays: _local.log.strengthDates,
                    now: snapshot.loadedAt,
                  );
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  ScreenHeader(
                    eyebrow: 'WEEKLY AEROBIC',
                    title: 'Activity',
                    trailing: StatusPill(
                      label: snapshot?.airMatched == true
                          ? 'AIR DATA'
                          : 'SOURCE STATUS',
                      color: snapshot?.airMatched == true
                          ? AppColors.green
                          : AppColors.yellow,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A lower-bound aerobic estimate from heart rate, plus the '
                    'strength days heart rate cannot see.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    _InitialState(
                      loading: _health.loading,
                      error: _health.error,
                      onRetry: () => _health.refresh(force: true),
                      onData: () => context.go('/data'),
                    )
                  else ...[
                    if (!snapshot.hasAccess)
                      StateCard(
                        icon: Icons.link_rounded,
                        color: AppColors.yellow,
                        title: 'Connect your health data',
                        body: snapshot.isAvailable
                            ? 'Allow Fitbit Air heart-rate and exercise records '
                                  'in Health Connect to estimate aerobic '
                                  'activity.'
                            : 'Health Connect is not available on this phone.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
                      )
                    else if (snapshot.error != null && !snapshot.hasAnyRecord)
                      StateCard(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.red,
                        title: 'Activity data could not load',
                        body: snapshot.error!,
                        actionLabel: 'Retry',
                        onAction: () => _health.refresh(force: true),
                      )
                    else if (snapshot.activityEstimate == null)
                      _SetupCard(
                        snapshot: snapshot,
                        onSettings: () => openSettings(context),
                        onData: () => context.go('/data'),
                      )
                    else
                      _AerobicCard(
                        estimate: snapshot.activityEstimate!,
                        onZones: () => context.push('/zones'),
                      ),
                    const SizedBox(height: 12),
                    _StrengthCard(
                      snapshot: snapshot,
                      strengthDays: strengthDays,
                      loggedDays: _local.log.strengthDates,
                      onLog: () => _logStrength(context),
                    ),
                    const SizedBox(height: 12),
                    _StepsCard(
                      steps: snapshot.summary?.stepCount,
                      allowed: snapshot.summary?.canReadSteps ?? false,
                    ),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Synced workouts',
                      caption: 'LAST 7 DAYS',
                      action: 'HR zones',
                      onAction: () => context.push('/zones'),
                    ),
                    const SizedBox(height: 10),
                    _WorkoutSection(snapshot: snapshot),
                    if (snapshot.error != null) ...[
                      const SizedBox(height: 14),
                      InfoNote(
                        text:
                            'Some activity data could not load: '
                            '${snapshot.error}',
                        textColor: AppColors.yellow,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _health.refresh(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SourceLine(
                      text:
                          'Fitbit Air via Health Connect · refreshed '
                          '${formatAgo(snapshot.loadedAt)}',
                      icon: Icons.sync_rounded,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const TrustFooter(
                    text:
                        'HEART-RATE ESTIMATES ARE A LOWER BOUND, NOT A '
                        'TRAINING PRESCRIPTION',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logStrength(BuildContext context) async {
    final logged = await showStrengthLogSheet(context);
    if (logged && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Strength day logged.')));
    }
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onData,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const StateCard(
        title: 'Reading activity data',
        body: 'Loading heart-rate coverage and synced workouts.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (error != null) {
      return StateCard(
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        title: 'Activity data could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return StateCard(
      icon: Icons.link_rounded,
      color: AppColors.yellow,
      title: 'Set up Health Connect',
      body: 'Becel reads Fitbit Air records from Health Connect.',
      actionLabel: 'Open data sources',
      onAction: onData,
    );
  }
}

class _AerobicCard extends StatelessWidget {
  const _AerobicCard({required this.estimate, required this.onZones});

  final ActivityEstimate estimate;
  final VoidCallback onZones;

  @override
  Widget build(BuildContext context) {
    final observed = estimate.displayedEquivalentMinutes;
    final potential = estimate.potentialEquivalentMinutes;
    final scale = math.max(
      activityAerobicReferenceMinutes.toDouble(),
      potential.toDouble(),
    );
    final remaining = estimate.minutesToAerobicReference;
    return SurfaceCard(
      color: const Color(0xFF211A15),
      borderColor: AppColors.orange.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.orange, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'AEROBIC · HR ESTIMATE',
                  style: AppType.eyebrow.copyWith(
                    color: AppColors.orange,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton(
                onPressed: onZones,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Zones'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '≈$observed',
                        style: AppType.numXl.copyWith(fontSize: 52),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 7),
                        child: Text('MIN', style: AppType.unit),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'observed floor',
                  textAlign: TextAlign.right,
                  style: AppType.caption.copyWith(color: AppColors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            potential > observed
                ? 'Up to $potential min if every day had heart-rate coverage.'
                : 'Heart-rate coverage was available on every day this week.',
            style: AppType.rowTitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          Semantics(
            label:
                'Observed aerobic estimate $observed minutes. Potential up to '
                '$potential minutes. Adult guideline floor '
                '$activityAerobicReferenceMinutes minutes.',
            child: ExcludeSemantics(
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final observedX =
                          (observed / scale).clamp(0.0, 1.0) * width;
                      final potentialX =
                          (potential / scale).clamp(0.0, 1.0) * width;
                      final guidelineX =
                          (activityAerobicReferenceMinutes / scale).clamp(
                            0.0,
                            1.0,
                          ) *
                          width;
                      return SizedBox(
                        height: 34,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 12,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigher,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            Positioned(
                              left: observedX,
                              width: (potentialX - observedX).clamp(0.0, width),
                              top: 12,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.orange.withValues(
                                    alpha: 0.28,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            Positioned(
                              left: (observedX - 5).clamp(0.0, width - 10),
                              top: 7,
                              child: Container(
                                width: 10,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.bg,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: (guidelineX - 1).clamp(0.0, width - 2),
                              top: 5,
                              child: Container(
                                width: 2,
                                height: 22,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('0', style: AppType.caption.copyWith(fontSize: 10)),
                      const Spacer(),
                      Text(
                        '$activityAerobicReferenceMinutes guideline',
                        style: AppType.caption.copyWith(fontSize: 10),
                      ),
                      const Spacer(),
                      Text(
                        '${scale.round()}',
                        style: AppType.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0
                ? '$remaining min to the $activityAerobicReferenceMinutes-min '
                      'aerobic guideline floor.'
                : 'Above the $activityAerobicReferenceMinutes-min aerobic '
                      'guideline floor by '
                      '${estimate.minutesAboveAerobicReference} min.',
            style: AppType.rowTitle.copyWith(color: AppColors.orange),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaPill(
                label: '${estimate.usableDays}/7 days with HR',
                color: AppColors.orange,
              ),
              _MetaPill(
                label: 'age ${estimate.age}',
                color: AppColors.textSecondary,
              ),
              _MetaPill(
                label: 'resting ${estimate.restingHrBpm.round()} bpm',
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatActivityMinutes(estimate.moderateMinutes)} moderate + '
            '${_formatActivityMinutes(estimate.vigorousMinutes)} vigorous × 2 ≈ '
            '${_formatActivityMinutes(estimate.equivalentMinutes)} min',
            style: AppType.caption,
          ),
          const SizedBox(height: 4),
          const Text(
            'This is a lower bound: pulse alone cannot confirm exercise, and '
            'it misses strength work, atypical heart responses, and time '
            'without the band. Strength is tracked separately.',
            style: AppType.caption,
          ),
          if (estimate.dailyDates.length == 7 &&
              estimate.dailyEquivalentMinutes.length == 7 &&
              estimate.dailyCoverageMinutes.length == 7) ...[
            const SizedBox(height: 14),
            const Text('DAILY ESTIMATE / HR COVERAGE', style: AppType.eyebrow),
            const SizedBox(height: 8),
            _ActivityWeek(estimate: estimate),
            const SizedBox(height: 8),
            const Text(
              '— = no usable HR interval · coverage is valid HR time',
              style: AppType.caption,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Age ${estimate.age} · predicted max ${estimate.estimatedMaxHrBpm} '
            'bpm · resting ${estimate.restingHrBpm.round()} bpm at '
            '${formatClock(estimate.restingHrAt)}. One recent resting reading '
            'is applied to all seven dates.',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      style: AppType.caption.copyWith(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _formatActivityMinutes(double minutes) {
  final value = minutes.toStringAsFixed(1);
  return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
}

class _ActivityWeek extends StatelessWidget {
  const _ActivityWeek({required this.estimate});

  final ActivityEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final daily = estimate.dailyEquivalentMinutes;
    final maximum = daily.whereType<double>().fold<double>(
      0,
      (largest, value) => value > largest ? value : largest,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Semantics(
              label: daily[index] == null
                  ? '${formatDayLabel(estimate.dailyDates[index])}, no usable heart-rate coverage'
                  : '${formatDayLabel(estimate.dailyDates[index])}, '
                        '${daily[index]!.round()} estimated moderate-equivalent minutes, '
                        '${formatDurationMinutes(estimate.dailyCoverageMinutes[index].round())} heart-rate coverage',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        daily[index]?.round().toString() ?? '—',
                        maxLines: 1,
                        style: AppType.caption.copyWith(
                          color: daily[index] == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: daily[index] == null || maximum <= 0
                            ? 4
                            : 4 + 38 * daily[index]! / maximum,
                        decoration: BoxDecoration(
                          color: daily[index] == null
                              ? AppColors.border
                              : AppColors.orange.withValues(
                                  alpha: index == 6 ? 1 : 0.42,
                                ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatDayLabel(estimate.dailyDates[index]),
                        style: AppType.caption.copyWith(
                          fontSize: 11,
                          color: index == 6
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        estimate.dailyCoverageMinutes[index] <= 0
                            ? '—'
                            : estimate.dailyCoverageMinutes[index] < 60
                            ? '${estimate.dailyCoverageMinutes[index].round()}m'
                            : '${(estimate.dailyCoverageMinutes[index] / 60).toStringAsFixed(1)}h',
                        maxLines: 1,
                        style: AppType.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({
    required this.snapshot,
    required this.strengthDays,
    required this.loggedDays,
    required this.onLog,
  });

  final HealthSnapshot snapshot;
  final int strengthDays;
  final List<DateTime> loggedDays;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final met = strengthDays >= 2;
    final color = met ? AppColors.green : AppColors.violet;
    final now = snapshot.loadedAt;
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        now.subtract(Duration(days: offset)),
    ];
    final activeDates = <String>{};
    for (final workout
        in snapshot.activity?.workouts ?? const <WorkoutEntry>[]) {
      if (isStrengthType(workout.type)) {
        activeDates.add(localDateKey(workout.start));
      }
    }
    for (final day in loggedDays) {
      activeDates.add(localDateKey(day));
    }
    return SurfaceCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center_rounded, size: 16, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'STRENGTH · THIS WEEK',
                  style: AppType.eyebrow.copyWith(color: color),
                ),
              ),
              StatusPill(label: '$strengthDays / 2 DAYS', color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            met
                ? 'Strength target met'
                : strengthDays == 0
                ? 'No strength days logged'
                : 'One strength day to go',
            style: AppType.rowTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Two 20-minute sessions count. Bodyweight, bands, or weights all '
            'qualify, and manual logs stay on this phone.',
            style: AppType.caption,
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Strength days this week: $strengthDays of 2. '
                '${days.map((day) => '${formatDayShort(day)} ${activeDates.contains(localDateKey(day)) ? 'done' : 'not done'}').join(', ')}.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (final day in days)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: activeDates.contains(localDateKey(day))
                                  ? color.withValues(alpha: 0.18)
                                  : AppColors.surfaceHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: activeDates.contains(localDateKey(day))
                                    ? color.withValues(alpha: 0.55)
                                    : AppColors.border,
                              ),
                            ),
                            child: activeDates.contains(localDateKey(day))
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: color,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDayShort(day).substring(0, 1),
                            style: AppType.caption.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onLog,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                met ? 'Log another strength day' : 'Log strength day',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.snapshot,
    required this.onSettings,
    required this.onData,
  });

  final HealthSnapshot snapshot;
  final VoidCallback onSettings;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    final heart = snapshot.heart;
    final age = snapshot.age;
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 36));
    final hasRecentRestingHr =
        heart?.restingHrSamples.any(
          (sample) =>
              !sample.at.isBefore(recentCutoff) &&
              sample.value >= 30 &&
              sample.value <= 120,
        ) ==
        true;
    final needsAge = age == null;
    final needsHeart = heart == null || !heart.canReadHeartRate;
    final needsResting = heart == null || !heart.canReadRestingHr;
    final title = needsAge
        ? 'Add your age for personal zones'
        : needsHeart || needsResting
        ? 'Allow heart-rate access'
        : !hasRecentRestingHr
        ? 'Waiting for a recent resting reading'
        : 'Waiting for usable HR samples';
    final body = needsAge
        ? 'Age stays on this device and sets your predicted maximum heart '
              'rate. It is only used for zone estimates.'
        : needsHeart || needsResting
        ? 'Aerobic estimates need Fitbit Air heart rate and resting heart '
              'rate from Health Connect.'
        : !hasRecentRestingHr
        ? 'A resting reading from the last 36 hours is needed. The band may '
              'still be syncing.'
        : 'Activity appears when consecutive readings are close enough to '
              'estimate intensity.';
    return SurfaceCard(
      color: const Color(0xFF211A15),
      borderColor: AppColors.orange.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconChip(
            icon: Icons.directions_run_rounded,
            color: AppColors.orange,
            size: 42,
          ),
          const SizedBox(height: 13),
          Text(title, style: AppType.sectionTitle),
          const SizedBox(height: 5),
          Text(body, style: AppType.body),
          const SizedBox(height: 13),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: needsAge ? onSettings : onData,
              icon: Icon(
                needsAge ? Icons.tune_rounded : Icons.sensors_rounded,
                size: 18,
              ),
              label: Text(
                needsAge ? 'Add age in Settings' : 'Review data sources',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps, required this.allowed});

  final int? steps;
  final bool allowed;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        const IconChip(
          icon: Icons.directions_walk_rounded,
          color: AppColors.green,
          size: 38,
          iconSize: 19,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                steps == null ? 'No steps yet today' : _formatNumber(steps!),
                style: steps == null
                    ? AppType.rowTitle
                    : AppType.numM.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 3),
              Text(
                steps == null
                    ? allowed
                          ? 'Waiting for the next Fitbit Air sync'
                          : 'Step access needed in Health Connect'
                    : 'steps today · measured by Fitbit Air',
                style: AppType.caption,
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 19,
          color: AppColors.textTertiary,
        ),
      ],
    ),
  );
}

class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final detail = snapshot.activity;
    if (detail == null) {
      return const StateCard(
        title: 'Workouts are loading',
        body: 'Synced sessions will appear here.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (!detail.canReadExercise) {
      return StateCard(
        icon: Icons.lock_outline_rounded,
        color: AppColors.yellow,
        title: 'Workout access is off',
        body:
            'Allow exercise access in Health Connect to show synced '
            'sessions. Manual strength logs still count.',
        actionLabel: 'Review data sources',
        onAction: () => context.go('/data'),
      );
    }
    if (detail.workouts.isEmpty) {
      return const StateCard(
        icon: Icons.fitness_center_rounded,
        color: AppColors.textSecondary,
        title: 'No synced workouts this week',
        body:
            'Heart-rate activity is still estimated from continuous '
            'samples. Strength logged manually is counted separately.',
      );
    }
    return Column(
      children: [
        for (final workout in detail.workouts.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WorkoutRow(workout: workout),
          ),
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout});

  final WorkoutEntry workout;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(13),
    color: AppColors.surface,
    child: Row(
      children: [
        IconChip(
          icon: isStrengthType(workout.type)
              ? Icons.fitness_center_rounded
              : Icons.directions_run_rounded,
          color: isStrengthType(workout.type)
              ? AppColors.violet
              : AppColors.orange,
          size: 36,
          iconSize: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.type, style: AppType.rowTitle),
              const SizedBox(height: 3),
              Text(
                '${formatDayShort(workout.start)} · '
                '${formatClock(workout.start)}',
                style: AppType.caption,
              ),
            ],
          ),
        ),
        Text(formatDurationMinutes(workout.minutes), style: AppType.numS),
      ],
    ),
  );
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
