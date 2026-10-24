import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _health = HealthConnectService.instance;
  HeartDetail? _heart;
  SleepDetail? _sleep;
  RecoveryReadiness? _readiness;
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
    final values = await Future.wait<Object>([
      _health.readHeartDetail(refresh: forceRefresh),
      _health.readSleepDetail(),
    ]);
    final heart = values[0] as HeartDetail;
    final sleep = values[1] as SleepDetail;
    final night = sleep.selectedRecentSession;
    final readiness = recoveryReadiness(
      hrvSamples: heart.hrvSamples,
      restingHrSamples: heart.restingHrSamples,
      sleepMinutes: night?.minutes,
      sleepStart: night?.start,
      sleepEnd: night?.end,
      asleepIntervals: night?.asleepIntervals ?? const <AsleepInterval>[],
      sleepWindows: sleep.sleepWindows,
    );
    if (!mounted) return;
    setState(() {
      _heart = heart;
      _sleep = sleep;
      _readiness = readiness;
      _readError = heart.error ?? sleep.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heart = _heart;
    final night = _sleep?.selectedRecentSession;
    final readiness = _readiness;
    final estimate = readiness?.estimate;
    final accessMissing =
        _readError == null &&
        heart != null &&
        (!heart.canReadHrv ||
            !heart.canReadRestingHr ||
            _sleep?.canReadSleep != true);

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
                onBack: () => Navigator.of(context).maybePop(),
                eyebrow: 'SLEEP + PERSONAL BASELINE',
                title: 'Recovery',
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
                        label: estimate == null
                            ? 'CALIBRATING'
                            : readiness?.limitedSamples == true
                            ? 'LOW DATA'
                            : 'EXPERIMENTAL',
                        color: estimate == null
                            ? AppColors.yellow
                            : readiness?.limitedSamples == true
                            ? AppColors.yellow
                            : AppColors.teal,
                      ),
              ),
              const SizedBox(height: 17),
              _RecoveryCard(
                score: estimate?.score,
                loading: _loading,
                limitedSamples:
                    estimate != null && (readiness?.limitedSamples ?? false),
              ),
              if (estimate != null) ...[
                const SizedBox(height: 10),
                const InfoNote(
                  text:
                      'Experimental personal trend only. This formula is not validated as training readiness or a predictor of performance; use your own symptoms and training context.',
                  icon: Icons.science_outlined,
                  color: AppColors.yellow,
                ),
              ],
              if (night != null) ...[
                const SizedBox(height: 10),
                InfoNote(
                  text:
                      'Selected ${formatShortDate(night.end)} · ${formatClock(night.start)}-${formatClock(night.end)} · ${formatDurationMinutes(night.minutes)} recorded sleep. Becel uses the longest synced session of at least 3 hours ending within 24 hours; a long nap may be selected. Baselines use the longest qualifying session on each prior local date.',
                  icon: Icons.schedule_rounded,
                  color: AppColors.blue,
                ),
              ],
              const SizedBox(height: 12),
              if (_readError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoNote(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      text: 'Could not read Health Connect: $_readError',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else if (estimate == null)
                InfoNote(
                  icon: accessMissing
                      ? Icons.lock_outline_rounded
                      : Icons.hourglass_empty_rounded,
                  color: AppColors.yellow,
                  text: accessMissing
                      ? 'Allow sleep, HRV, and resting heart-rate access. The estimate needs all three signals.'
                      : _recoveryWaitText(readiness),
                )
              else ...[
                const SectionHeader(title: 'Signals behind the estimate'),
                const SizedBox(height: 9),
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
                  child: Column(
                    children: [
                      _ComponentRow(
                        icon: Icons.bedtime_rounded,
                        color: AppColors.blue,
                        label: 'Sleep duration',
                        value: formatDurationMinutes(night!.minutes),
                        detail:
                            '${estimate.sleepComponent}/100 duration progress × 40% · selected session',
                      ),
                      const Divider(height: 1),
                      _ComponentRow(
                        icon: Icons.monitor_heart_rounded,
                        color: AppColors.violet,
                        label: 'RMSSD HRV during asleep stages',
                        value: '${estimate.hrvCurrent.round()} ms',
                        detail:
                            '${estimate.hrvComponent}/100 × 35% · ${estimate.hrvSampleCount} asleep-stage samples · latest ${formatClock(estimate.hrvAt)} · personal median ${estimate.hrvBaseline.round()} ms · ${estimate.hrvBaselineDays} nights / 14 days',
                      ),
                      const Divider(height: 1),
                      _ComponentRow(
                        icon: Icons.favorite_rounded,
                        color: AppColors.red,
                        label: 'Daily resting HR · selected session date',
                        value: '${estimate.restingHrCurrent.round()} bpm',
                        detail:
                            '${estimate.restingHrComponent}/100 × 25% · ${estimate.restingHrSampleCount} daily readings · latest ${formatClock(estimate.restingHrAt)} · personal median ${estimate.restingHrBaseline.round()} bpm · ${estimate.restingHrBaselineDays} dates / 14',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                const InfoNote(
                  text: recoveryMethod,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.teal,
                ),
                const SizedBox(height: 10),
                const InfoNote(
                  text:
                      'Use this as a trend to compare with how you feel and your training plan. It is not a diagnosis or medical clearance to exercise.',
                  icon: Icons.self_improvement_rounded,
                  color: AppColors.blue,
                ),
              ],
              if (estimate == null && accessMissing) ...[
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () => context.go('/data'),
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('Review data access'),
                ),
              ],
              const SizedBox(height: 21),
              const TrustFooter(
                text: 'SLEEP-ALIGNED HEALTH CONNECT RECORDS · STORED ON DEVICE',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _recoveryWaitText(RecoveryReadiness? readiness) {
  if (readiness == null || !readiness.hasSleepSession) {
    return 'Waiting for a qualifying sleep session ending within the last 24 hours.';
  }
  final reasons = <String>[];
  if (readiness.hrvCurrentSampleCount == 0) {
    reasons.add('HRV sample needed during an asleep stage');
  }
  if (readiness.restingHrCurrentSampleCount == 0) {
    reasons.add('Daily resting-HR sample needed on the selected session date');
  }
  if (readiness.hrvBaselineNights < recoveryMinimumBaselineNights ||
      readiness.restingHrBaselineNights < recoveryMinimumBaselineNights) {
    reasons.add(
      '14-day baseline: HRV ${readiness.hrvBaselineNights}/$recoveryMinimumBaselineNights nights, RHR ${readiness.restingHrBaselineNights}/$recoveryMinimumBaselineNights nights',
    );
  }
  return reasons.isEmpty
      ? 'Matching sleep-stage HRV and date-aligned resting HR'
      : reasons.join(' | ');
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.score,
    required this.loading,
    required this.limitedSamples,
  });

  final int? score;
  final bool loading;
  final bool limitedSamples;

  @override
  Widget build(BuildContext context) {
    final color = limitedSamples ? AppColors.yellow : AppColors.teal;
    return SurfaceCard(
      color: const Color(0xFF14201B),
      borderColor: color.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  limitedSamples
                      ? 'LIMITED DATA · EXPERIMENTAL'
                      : 'EXPERIMENTAL TREND',
                  style: AppType.eyebrow.copyWith(color: color),
                ),
                const SizedBox(height: 11),
                Text(
                  score == null ? 'Recovery unavailable' : 'Recovery trend',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  score == null
                      ? loading
                            ? 'Checking your latest records'
                            : 'See which signal is missing below'
                      : limitedSamples
                      ? 'Current readings or personal history are incomplete'
                      : 'Compare the trend with your own signals',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (score ?? 0) / 100,
                    strokeWidth: 8,
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
                      style: AppType.numM.copyWith(fontSize: 30),
                    ),
                    Text(
                      'OF 100',
                      style: AppType.eyebrow.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.rowTitle),
              const SizedBox(height: 3),
              Text(detail, style: AppType.caption),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: AppType.numS.copyWith(fontSize: 14)),
      ],
    ),
  );
}
