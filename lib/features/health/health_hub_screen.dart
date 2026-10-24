import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class HealthHubScreen extends StatefulWidget {
  const HealthHubScreen({super.key});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final _health = HealthConnectService.instance;
  HealthConnectInspection? _inspection;
  HealthSummary? _summary;
  HeartDetail? _heart;
  SleepDetail? _sleep;
  ActivityDetail? _activity;
  BodyDetail? _body;
  int? _age;
  RecoveryReadiness? _recoveryStatus;
  ActivityEstimate? _activityEstimate;
  String? _readError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _health.dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final inspection = await _health.inspect();
    HealthSummary? summary;
    HeartDetail? heart;
    SleepDetail? sleep;
    ActivityDetail? activity;
    BodyDetail? body;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      final values = await Future.wait<Object>([
        _health.readSummary(),
        _health.readHeartDetail(refresh: forceRefresh),
        _health.readActivityDetail(),
        _health.readBodyDetail(),
        _health.readSleepDetail(),
      ]);
      summary = values[0] as HealthSummary;
      heart = values[1] as HeartDetail;
      activity = values[2] as ActivityDetail;
      body = values[3] as BodyDetail;
      sleep = values[4] as SleepDetail;
    }
    final age = await _health.readFitnessAge();
    final night = sleep?.selectedRecentSession;
    final recoveryStatus = heart == null
        ? null
        : recoveryReadiness(
            hrvSamples: heart.hrvSamples,
            restingHrSamples: heart.restingHrSamples,
            sleepMinutes: night?.minutes,
            sleepStart: night?.start,
            sleepEnd: night?.end,
            asleepIntervals: night?.asleepIntervals ?? const <AsleepInterval>[],
            sleepWindows: sleep?.sleepWindows ?? const <SleepWindow>[],
          );
    final activityEstimate = heart == null
        ? null
        : _health.activityEstimateFor(heart, age);
    final error =
        heart?.error ??
        sleep?.error ??
        activity?.error ??
        body?.error ??
        summary?.error ??
        inspection.error;
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _summary = summary;
      _heart = heart;
      _sleep = sleep;
      _activity = activity;
      _body = body;
      _age = age;
      _recoveryStatus = recoveryStatus;
      _activityEstimate = activityEstimate;
      _readError = error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    final summary = _summary;
    final heart = _heart;
    final sleep = _sleep;
    final night = sleep?.selectedRecentSession;
    final activityDetail = _activity;
    final body = _body;
    final recoveryStatus = _recoveryStatus;
    final recovery = recoveryStatus?.estimate;
    final activity = _activityEstimate;
    final partial =
        inspection != null &&
        inspection.isAvailable &&
        !inspection.allPermissionsGranted;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              ScreenHeader(
                eyebrow: 'BODY SIGNALS',
                title: 'Vitals',
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.teal,
                        ),
                      )
                    : StatusPill(
                        label: inspection?.stateLabel ?? 'Check data access',
                        color: inspection?.allPermissionsGranted == true
                            ? AppColors.green
                            : AppColors.yellow,
                      ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Recovery today · selected sleep session · activity over 7 days',
                style: AppType.note,
              ),
              if (_readError != null) ...[
                const SizedBox(height: 10),
                InfoNote(
                  text:
                      'Health Connect could not load some records: $_readError',
                  textColor: AppColors.red,
                ),
                TextButton.icon(
                  onPressed: () => _load(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Fitness snapshot',
                caption: 'ESTIMATES',
              ),
              const SizedBox(height: 10),
              _PerformanceCard(
                icon: Icons.energy_savings_leaf_rounded,
                color: AppColors.teal,
                title: 'Recovery',
                value: recovery == null ? '—' : '${recovery.score}',
                unit: recovery == null ? '' : '/100',
                note: recovery == null
                    ? _recoveryNote(heart, summary, recoveryStatus)
                    : recoveryStatus?.limitedSamples == true
                    ? 'Limited signal or personal-history coverage · see component counts'
                    : 'Sleep stages + date-aligned HRV/RHR · personal baseline',
                onTap: () => context.push('/health/recovery'),
              ),
              const SizedBox(height: 9),
              _PerformanceCard(
                icon: Icons.nightlight_round,
                color: AppColors.blue,
                title: 'Sleep · selected session',
                value: night == null
                    ? '—'
                    : formatDurationMinutes(night.minutes),
                note: night == null
                    ? summary?.canReadSleep == true
                          ? 'No session synced in the last 24 hours'
                          : 'Sleep access is needed'
                    : 'Stage-derived sleep duration · 7h adult reference',
                onTap: () => context.push('/health/sleep'),
              ),
              const SizedBox(height: 9),
              _PerformanceCard(
                icon: Icons.directions_run_rounded,
                color: AppColors.orange,
                title: 'Activity · last 7 days',
                value: activity == null
                    ? '—'
                    : '${activity.equivalentMinutes.round()}',
                unit: activity == null ? '' : ' min',
                note: activity == null
                    ? _activityNote(heart, _age)
                    : 'of 150 moderate-equivalent min · ≥1 interval on ${activity.usableDays}/7 days',
                onTap: () => context.go('/fitness'),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Measured signals'),
              const SizedBox(height: 10),
              _SignalCard(
                icon: Icons.favorite_rounded,
                color: AppColors.red,
                title: 'Heart rate',
                value: summary?.heartRateBpm == null
                    ? '—'
                    : '${summary!.heartRateBpm} bpm',
                note: _heartNote(summary, heart),
                onTap: () => context.push('/health/heart'),
              ),
              const SizedBox(height: 9),
              _SignalCard(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.orange,
                title: 'Energy',
                value: activityDetail?.caloriesTotalToday == null
                    ? '—'
                    : '${activityDetail!.caloriesTotalToday} kcal',
                note: _energyNote(activityDetail),
                onTap: () => context.push('/health/energy'),
              ),
              const SizedBox(height: 9),
              _SignalCard(
                icon: Icons.science_rounded,
                color: AppColors.violet,
                title: 'Body metrics',
                value: body?.spo2Percent != null
                    ? '${body!.spo2Percent!.round()}% SpO₂'
                    : '—',
                note: _biologyNote(body),
                onTap: () => context.push('/health/biology'),
              ),
              if (partial) ...[
                const SizedBox(height: 14),
                InfoNote(
                  text: 'Some readings need additional Health Connect access.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/data'),
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('Review data access'),
                ),
              ],
              const SizedBox(height: 20),
              const TrustFooter(
                text: 'MEASUREMENTS COME FROM HEALTH CONNECT · READ ONLY',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recoveryNote(
    HeartDetail? heart,
    HealthSummary? summary,
    RecoveryReadiness? readiness,
  ) {
    if (heart == null) return 'Connect a source to start your baseline';
    if (summary?.canReadSleep != true) return 'Needs sleep access';
    if (!heart.canReadHrv || !heart.canReadRestingHr) {
      return 'Needs HRV and resting heart-rate access';
    }
    if (readiness == null || !readiness.hasSleepSession) {
      return 'Waiting for a qualifying sleep session ending within 24 hours';
    }
    if (readiness.hrvCurrentSampleCount == 0) {
      return 'Waiting for HRV during recorded asleep stages';
    }
    if (readiness.restingHrCurrentSampleCount == 0) {
      return 'Waiting for daily resting HR on the selected session date';
    }
    return 'Baseline nights · HRV ${readiness.hrvBaselineNights}/$recoveryMinimumBaselineNights · RHR ${readiness.restingHrBaselineNights}/$recoveryMinimumBaselineNights';
  }

  String _activityNote(HeartDetail? heart, int? age) {
    if (age == null) return 'Add your age in Settings for estimated HR zones';
    if (heart == null || !heart.canReadHeartRate) {
      return 'Needs heart-rate access';
    }
    if (!heart.canReadRestingHr) return 'Needs resting heart-rate access';
    return 'Waiting for continuous Fitbit Air heart-rate samples';
  }

  String _heartNote(HealthSummary? summary, HeartDetail? heart) {
    final latest = heart?.latestAt;
    if (latest == null) return 'No recent Fitbit Air sample';
    final at = DateTime.tryParse(latest);
    if (at == null) return 'Sample time unavailable';
    return 'Measured ${formatClock(at)} · ${formatAgo(at)}';
  }

  String _energyNote(ActivityDetail? activity) {
    final total = activity?.caloriesTotalToday;
    final active = activity?.caloriesActiveToday;
    if (total == null) return 'No calorie record available';
    if (active == null) return 'Total burned today · source estimate';
    return 'Active $active · resting ${total - active} kcal';
  }

  String _biologyNote(BodyDetail? body) {
    if (body == null || !body.hasAccess) return 'No recent body signals';
    final parts = <String>[];
    if (body.respiratoryRate != null) {
      parts.add('${body.respiratoryRate!.round()} breaths/min');
    }
    if (body.skinTempDeviationC != null) {
      final value = body.skinTempDeviationC!;
      parts.add('temp ${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}°C');
    }
    if (body.vo2Max != null) parts.add('VO₂ max ${body.vo2Max!.round()}');
    return parts.isEmpty ? 'No recent body signals' : parts.join(' · ');
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.note,
    required this.onTap,
    this.unit = '',
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String unit;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        IconChip(icon: icon, color: color, size: 39, iconSize: 19, radius: 13),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.rowTitle),
              const SizedBox(height: 3),
              Text(note, maxLines: 2, style: AppType.caption),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppType.numM.copyWith(
            color: value == '—' ? AppColors.textTertiary : color,
            fontSize: value.length > 5 ? 18 : 23,
          ),
        ),
        if (unit.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 9),
            child: Text(unit, style: AppType.caption.copyWith(fontSize: 11)),
          ),
        const SizedBox(width: 5),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
          size: 19,
        ),
      ],
    ),
  );
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.note,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    color: AppColors.surface,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.rowTitle),
              const SizedBox(height: 3),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: AppType.numS.copyWith(fontSize: 14)),
        const SizedBox(width: 4),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ],
    ),
  );
}
