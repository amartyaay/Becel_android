import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../shell/shell_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _health = HealthConnectService.instance;
  HealthSummary? _summary;
  HeartDetail? _heart;
  SleepDetail? _sleep;
  RecoveryReadiness? _recoveryStatus;
  ActivityEstimate? _activityEstimate;
  int? _age;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_onHealthDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    _health.dataRevision.removeListener(_onHealthDataChanged);
    super.dispose();
  }

  void _onHealthDataChanged() => _refresh();

  Future<void> _refresh({bool forceRefresh = false}) async {
    final inspection = await _health.inspect();
    HealthSummary? summary;
    HeartDetail? heart;
    SleepDetail? sleep;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      final records = await Future.wait<Object?>([
        _health.readSummary(),
        _health.readHeartDetail(refresh: forceRefresh),
        _health.readSleepDetail(),
      ]);
      summary = records[0] as HealthSummary?;
      heart = records[1] as HeartDetail?;
      sleep = records[2] as SleepDetail?;
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
    final activity = heart == null
        ? null
        : _health.activityEstimateFor(heart, age);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _heart = heart;
      _sleep = sleep;
      _age = age;
      _recoveryStatus = recoveryStatus;
      _activityEstimate = activity;
      _loading = false;
      _error =
          heart?.error ?? sleep?.error ?? summary?.error ?? inspection.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final heart = _heart;
    final sleepDetail = _sleep;
    final night = sleepDetail?.selectedRecentSession;
    final recoveryStatus = _recoveryStatus;
    final recovery = recoveryStatus?.estimate;
    final activity = _activityEstimate;
    final now = DateTime.now();
    final weekday = const [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ][now.weekday - 1];
    final month = const [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ][now.month - 1];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              _TopBar(
                loading: _loading,
                connected: summary?.fitbitAirMetadataMatched == true,
                onData: () => context.go('/data'),
                onSettings: () => openSettings(context),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekday  ·  $month ${now.day}',
                          style: AppType.eyebrow.copyWith(
                            color: AppColors.teal,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Your fitness snapshot',
                          style: AppType.screenTitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh health data',
                    onTap: () => _refresh(forceRefresh: true),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Recovery today · selected sleep session · activity over 7 days',
                style: AppType.body,
              ),
              const SizedBox(height: 20),
              _RecoveryHero(
                score: recovery?.score,
                loading: _loading,
                limitedSamples:
                    recovery != null &&
                    (recoveryStatus?.limitedSamples ?? false),
                subtitle: _recoveryWaitText(recoveryStatus),
                onTap: () => context.push('/health/recovery'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.nightlight_round,
                      title: 'SLEEP DURATION',
                      value: night == null
                          ? '—'
                          : formatDurationMinutes(night.minutes),
                      progress: night == null
                          ? null
                          : (night.minutes / 420).clamp(0, 1).toDouble(),
                      footnote: night == null
                          ? 'Waiting for a qualifying session'
                          : 'Selected session · 7h adult reference',
                      color: AppColors.blue,
                      onTap: () => context.push('/health/sleep'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.directions_run_rounded,
                      title: 'WEEKLY ACTIVITY',
                      value: activity == null
                          ? '—'
                          : '${activity.equivalentMinutes.round()} min',
                      progress: activity == null
                          ? null
                          : activity.progressPercent / 100,
                      footnote: activity == null
                          ? _activityRequirement(heart, _age)
                          : 'of 150 moderate-equiv min · ≥1 interval on ${activity.usableDays}/7 days',
                      color: AppColors.orange,
                      onTap: () => context.go('/fitness'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _TodayFocus(
                recovery: recovery,
                recoveryStatus: recoveryStatus,
                activity: activity,
                heart: heart,
                summary: summary,
                age: _age,
                readError: _error,
                onData: () => context.go('/data'),
                onSettings: () => openSettings(context),
              ),
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Today’s movement',
                action: 'Activity',
                onAction: () => context.go('/fitness'),
              ),
              const SizedBox(height: 10),
              _MovementSummary(
                summary: summary,
                onTap: () => context.go('/fitness'),
              ),
              const SizedBox(height: 22),
              SectionHeader(title: 'Latest signals', caption: 'MEASURED'),
              const SizedBox(height: 10),
              _LatestSignals(
                summary: summary,
                night: night,
                onHeart: () => context.push('/health/heart'),
                onSleep: () => context.push('/health/sleep'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InfoNote(
                  text: 'Could not refresh health data: $_error',
                  textColor: AppColors.red,
                ),
                TextButton.icon(
                  onPressed: () => _refresh(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
              const SizedBox(height: 20),
              const TrustFooter(
                text:
                    'BECEL ESTIMATES ARE WELLNESS CONTEXT, NOT MEDICAL ADVICE',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _activityRequirement(HeartDetail? heart, int? age) {
  if (age == null) return 'Add age for personal HR zones';
  if (heart?.canReadRestingHr != true) return 'Needs resting HR access';
  if (heart?.canReadHeartRate != true) return 'Needs heart-rate access';
  return 'Waiting for consecutive HR samples';
}

String _recoveryWaitText(RecoveryReadiness? readiness) {
  if (readiness == null) return 'Connect sleep and personal health signals';
  if (!readiness.hasSleepSession) {
    return 'Waiting for a qualifying sleep session ending within 24 hours';
  }
  if (readiness.hrvCurrentSampleCount == 0) {
    return 'Waiting for HRV during recorded asleep stages';
  }
  if (readiness.restingHrCurrentSampleCount == 0) {
    return 'Waiting for daily resting HR on the selected session date';
  }
  if (readiness.hrvBaselineNights < recoveryMinimumBaselineNights ||
      readiness.restingHrBaselineNights < recoveryMinimumBaselineNights) {
    return 'Baseline nights · HRV ${readiness.hrvBaselineNights}/$recoveryMinimumBaselineNights · RHR ${readiness.restingHrBaselineNights}/$recoveryMinimumBaselineNights';
  }
  return 'Matching sleep and personal signals';
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.loading,
    required this.connected,
    required this.onData,
    required this.onSettings,
  });

  final bool loading;
  final bool connected;
  final VoidCallback onData;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD9FA83), Color(0xFF91BD49)],
            ),
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: Color(0xFF14200B),
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BECEL',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 2),
            Text('FITNESS COMPANION', style: AppType.eyebrow),
          ],
        ),
        const Spacer(),
        Tooltip(
          message: connected ? 'Fitbit Air data' : 'Connect Fitbit Air data',
          child: InkWell(
            onTap: onData,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.teal,
                      ),
                    )
                  : Icon(
                      connected
                          ? Icons.sensors_rounded
                          : Icons.sensors_off_rounded,
                      size: 19,
                      color: connected ? AppColors.green : AppColors.yellow,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: AppColors.textSecondary),
        ),
      ),
    ),
  );
}

class _RecoveryHero extends StatelessWidget {
  const _RecoveryHero({
    required this.score,
    required this.loading,
    required this.limitedSamples,
    required this.subtitle,
    required this.onTap,
  });

  final int? score;
  final bool loading;
  final bool limitedSamples;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = limitedSamples ? AppColors.yellow : AppColors.teal;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      color: const Color(0xFF14201B),
      borderColor: color.withValues(alpha: 0.20),
      radius: 24,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.energy_savings_leaf_rounded,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'RECOVERY',
                      style: AppType.eyebrow.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  score == null ? 'Recovery unavailable' : 'Recovery trend',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  score == null
                      ? loading
                            ? 'Checking sleep and personal signals…'
                            : subtitle
                      : limitedSamples
                      ? 'Limited data · experimental trend · tap for signals'
                      : 'Experimental personal trend · tap for signals',
                  style: AppType.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (score ?? 0) / 100,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceHigher,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score?.toString() ?? '—',
                      style: AppType.numM.copyWith(fontSize: 29),
                    ),
                    Text(
                      score == null ? 'WAIT' : 'OF 100',
                      style: AppType.eyebrow.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
    required this.footnote,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final double? progress;
  final String footnote;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.eyebrow.copyWith(
                  color: color,
                  fontSize: 11,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [Text(value, style: AppType.numM.copyWith(fontSize: 25))],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceHigher,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          footnote,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(fontSize: 11, height: 1.3),
        ),
      ],
    ),
  );
}

class _TodayFocus extends StatelessWidget {
  const _TodayFocus({
    required this.recovery,
    required this.recoveryStatus,
    required this.activity,
    required this.heart,
    required this.summary,
    required this.age,
    required this.readError,
    required this.onData,
    required this.onSettings,
  });

  final RecoveryEstimate? recovery;
  final RecoveryReadiness? recoveryStatus;
  final ActivityEstimate? activity;
  final HeartDetail? heart;
  final HealthSummary? summary;
  final int? age;
  final String? readError;
  final VoidCallback onData;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final hasSourceAccess = summary?.hasAccess == true;
    final hasFitbitRecords = summary?.fitbitAirMetadataMatched == true;
    final needsAccess =
        heart != null && (!heart!.canReadHrv || !heart!.canReadRestingHr) ||
        summary?.canReadSleep == false;
    final title = readError != null
        ? 'Health data could not load'
        : !hasSourceAccess
        ? 'Connect your health data'
        : summary != null && !hasFitbitRecords && recovery == null
        ? 'Fitbit Air data has not arrived'
        : recovery == null
        ? needsAccess
              ? 'Finish your data setup'
              : 'Let your baseline build'
        : activity == null && age == null
        ? 'Personalize activity zones'
        : 'Keep the full picture in view';
    final body = readError != null
        ? 'Pull to refresh or tap to review your connected data source.'
        : !hasSourceAccess
        ? 'Connect Health Connect and allow Fitbit Air records to see your fitness estimates.'
        : summary != null && !hasFitbitRecords && recovery == null
        ? 'Becel can read Health Connect, but has not found Fitbit Air records yet. Check device sync and the sharing setup in Data sources.'
        : recovery == null
        ? needsAccess
              ? 'Allow sleep, HRV, and resting heart-rate access to calculate recovery.'
              : _recoveryWaitText(recoveryStatus)
        : activity == null && age == null
        ? 'Add your age in Settings to estimate heart-rate-reserve zones.'
        : activity == null
        ? 'Activity is waiting for continuous heart-rate samples and a recent resting reading.'
        : 'HR-estimated moderate-equivalent minutes. Pulse alone does not confirm exercise.';
    final targetSettings = recovery != null && activity == null && age == null;
    return SurfaceCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(15),
      onTap: targetSettings ? onSettings : onData,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: recovery == null
                ? Icons.tune_rounded
                : Icons.insights_rounded,
            color: AppColors.teal,
            size: 40,
            iconSize: 19,
            radius: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.rowTitle),
                const SizedBox(height: 4),
                Text(body, style: AppType.caption),
                const SizedBox(height: 7),
                Text(
                  targetSettings ? 'OPEN SETTINGS' : 'REVIEW DATA SOURCES',
                  style: AppType.footer.copyWith(color: AppColors.teal),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.teal,
            size: 17,
          ),
        ],
      ),
    );
  }
}

class _MovementSummary extends StatelessWidget {
  const _MovementSummary({required this.summary, required this.onTap});

  final HealthSummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    child: Row(
      children: [
        const IconChip(
          icon: Icons.directions_walk_rounded,
          color: AppColors.green,
          size: 42,
          iconSize: 20,
          radius: 14,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary?.stepCount == null
                    ? 'Steps syncing'
                    : _formatNumber(summary!.stepCount!),
                style: summary?.stepCount == null
                    ? AppType.rowTitle
                    : AppType.numM.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 3),
              Text(
                summary?.stepCount == null
                    ? 'Fitbit Air step count is not available yet'
                    : 'steps · Fitbit Air',
                style: AppType.caption,
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.textTertiary,
        ),
      ],
    ),
  );
}

class _LatestSignals extends StatelessWidget {
  const _LatestSignals({
    required this.summary,
    required this.night,
    required this.onHeart,
    required this.onSleep,
  });

  final HealthSummary? summary;
  final SleepNight? night;
  final VoidCallback onHeart;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: AppColors.surface,
    child: Column(
      children: [
        _SignalRow(
          icon: Icons.favorite_rounded,
          color: AppColors.red,
          title: 'Heart rate',
          value: summary?.heartRateBpm == null
              ? '—'
              : '${summary!.heartRateBpm} bpm',
          onTap: onHeart,
        ),
        const Divider(height: 1),
        _SignalRow(
          icon: Icons.bedtime_rounded,
          color: AppColors.blue,
          title: 'Last sleep',
          value: night == null ? '—' : formatDurationMinutes(night!.minutes),
          onTap: onSleep,
        ),
      ],
    ),
  );
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppType.rowTitle)),
          Text(value, style: AppType.numS.copyWith(fontSize: 14)),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}
