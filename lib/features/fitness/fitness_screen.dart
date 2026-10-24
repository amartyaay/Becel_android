import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final _health = HealthConnectService.instance;
  HealthConnectInspection? _inspection;
  HealthSummary? _summary;
  HeartDetail? _heart;
  ActivityDetail? _activity;
  int? _age;
  ActivityEstimate? _estimate;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _health.dataRevision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    final inspection = await _health.inspect();
    HealthSummary? summary;
    HeartDetail? heart;
    ActivityDetail? activity;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      final records = await Future.wait<Object>([
        _health.readSummary(),
        _health.readHeartDetail(refresh: forceRefresh),
        _health.readActivityDetail(),
      ]);
      summary = records[0] as HealthSummary;
      heart = records[1] as HeartDetail;
      activity = records[2] as ActivityDetail;
    }
    final age = await _health.readFitnessAge();
    final estimate = heart == null
        ? null
        : _health.activityEstimateFor(heart, age);
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _summary = summary;
      _heart = heart;
      _activity = activity;
      _age = age;
      _estimate = estimate;
      _error =
          heart?.error ?? activity?.error ?? summary?.error ?? inspection.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final heart = _heart;
    final activityDetail = _activity;
    final connected = summary?.fitbitAirMetadataMatched == true;
    final estimate = _estimate;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              ScreenHeader(
                eyebrow: 'WEEKLY ACTIVITY',
                title: 'Activity',
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.green,
                        ),
                      )
                    : StatusPill(
                        label: connected ? 'AIR DATA' : 'SOURCE STATUS',
                        color: connected ? AppColors.green : AppColors.yellow,
                      ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoNote(
                        text: 'Could not load health records: $_error',
                        textColor: AppColors.red,
                      ),
                      TextButton.icon(
                        onPressed: () => _refresh(forceRefresh: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (estimate == null)
                _SetupCard(
                  age: _age,
                  heart: heart,
                  isAvailable: _inspection?.isAvailable ?? false,
                  onSettings: () => context.push('/settings'),
                  onData: () => context.go('/data'),
                )
              else
                _ActivityCard(estimate: estimate),
              const SizedBox(height: 12),
              _StepsCard(
                steps: summary?.stepCount,
                allowed: summary?.canReadSteps ?? false,
              ),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Recent workouts',
                caption: 'LAST 7 DAYS',
                action: 'HR zones',
                onAction: () => context.push('/health/zones'),
              ),
              const SizedBox(height: 10),
              if (activityDetail != null && !activityDetail.canReadExercise)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout access is off',
                        style: AppType.rowTitle,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Allow exercise access to show sessions here.',
                        style: AppType.caption,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go('/data'),
                        child: const Text('Review data sources'),
                      ),
                    ],
                  ),
                )
              else if (activityDetail?.workouts.isNotEmpty != true)
                const SurfaceCard(
                  child: Text(
                    'No Fitbit Air workouts synced this week. Heart-rate activity can still be estimated from continuous samples.',
                    style: AppType.note,
                  ),
                )
              else
                for (final workout in activityDetail!.workouts.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WorkoutRow(workout: workout),
                  ),
              const SizedBox(height: 18),
              SurfaceCard(
                color: AppColors.surface,
                onTap: () => context.go('/history'),
                padding: const EdgeInsets.all(14),
                child: const Row(
                  children: [
                    IconChip(
                      icon: Icons.calendar_month_rounded,
                      color: AppColors.violet,
                      size: 38,
                      iconSize: 19,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Review your weekly history',
                        style: AppType.rowTitle,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.violet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const TrustFooter(
                text: 'FITBIT AIR RECORDS · HEALTH CONNECT · READ ONLY',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.estimate});

  final ActivityEstimate estimate;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    color: const Color(0xFF211A15),
    borderColor: AppColors.orange.withValues(alpha: 0.22),
    radius: 24,
    padding: const EdgeInsets.all(17),
    onTap: () => context.push('/health/zones'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.orange, size: 17),
            const SizedBox(width: 7),
            Text(
              '7-DAY ACTIVITY',
              style: AppType.eyebrow.copyWith(color: AppColors.orange),
            ),
            const Spacer(),
            Text('HR ESTIMATE', style: AppType.eyebrow),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${estimate.equivalentMinutes.round()}',
              style: AppType.numXl.copyWith(fontSize: 54),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 7),
              child: Text('MIN', style: AppType.unit),
            ),
            const Spacer(),
            Text(
              '150 min',
              style: AppType.numM.copyWith(color: AppColors.orange),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'HR-estimated moderate-equivalent minutes',
          style: AppType.caption,
        ),
        const SizedBox(height: 13),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: estimate.progressPercent / 100,
            minHeight: 7,
            backgroundColor: AppColors.surfaceHigher,
            valueColor: const AlwaysStoppedAnimation(AppColors.orange),
          ),
        ),
        const SizedBox(height: 11),
        Text(
          '${estimate.moderateMinutes.round()} moderate min · ${estimate.vigorousMinutes.round()} vigorous min × 2',
          style: AppType.caption,
        ),
        const SizedBox(height: 5),
        Text(
          'At least one usable HR interval on ${estimate.usableDays}/7 local days · gaps and missing wear time can undercount',
          style: AppType.caption.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          'Age ${estimate.age} · predicted max ${estimate.estimatedMaxHrBpm} bpm · resting HR ${estimate.restingHrBpm.round()} bpm at ${formatClock(estimate.restingHrAt)}',
          style: AppType.caption.copyWith(fontSize: 11),
        ),
      ],
    ),
  );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.age,
    required this.heart,
    required this.isAvailable,
    required this.onSettings,
    required this.onData,
  });

  final int? age;
  final HeartDetail? heart;
  final bool isAvailable;
  final VoidCallback onSettings;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 36));
    final hasRecentRestingHr =
        heart?.restingHrSamples.any(
          (sample) =>
              !sample.at.isBefore(recentCutoff) &&
              sample.value >= 30 &&
              sample.value <= 120,
        ) ==
        true;
    final title = age == null
        ? 'Personalize your zones'
        : heart == null || !heart!.canReadHeartRate || !heart!.canReadRestingHr
        ? 'Connect your heart-rate data'
        : !hasRecentRestingHr
        ? 'Waiting for a recent resting reading'
        : 'Waiting for usable samples';
    final body = age == null
        ? 'Add age in Settings to estimate heart-rate-reserve zones. Your age stays on this device.'
        : heart == null || !heart!.canReadHeartRate || !heart!.canReadRestingHr
        ? 'Activity estimates need Fitbit Air heart rate and resting heart rate.'
        : !hasRecentRestingHr
        ? 'A resting-heart-rate record from the last 36 hours is needed to set your zones.'
        : 'Activity appears when consecutive readings are close enough to estimate intensity.';
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
          Text(body, style: AppType.note),
          const SizedBox(height: 13),
          FilledButton.icon(
            onPressed: age == null ? onSettings : onData,
            icon: Icon(
              age == null ? Icons.tune_rounded : Icons.sensors_rounded,
            ),
            label: Text(
              age == null ? 'Set up activity zones' : 'Review data sources',
            ),
          ),
          if (!isAvailable) ...[
            const SizedBox(height: 10),
            const Text(
              'Health Connect is not available on this device yet.',
              style: AppType.caption,
            ),
          ],
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
                steps == null ? 'Steps' : _formatNumber(steps!),
                style: steps == null
                    ? AppType.rowTitle
                    : AppType.numM.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 3),
              Text(
                steps == null
                    ? allowed
                          ? 'No Fitbit Air count synced today'
                          : 'Step access needed'
                    : 'steps today · Fitbit Air',
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

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout});

  final WorkoutEntry workout;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(13),
    color: AppColors.surface,
    child: Row(
      children: [
        const IconChip(
          icon: Icons.fitness_center_rounded,
          color: AppColors.violet,
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
                '${formatDayShort(workout.start)} · ${formatClock(workout.start)}',
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
