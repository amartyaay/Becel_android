import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../domain/coaching.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = HealthStore.instance;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final snapshot = store.snapshot;
            final readiness = snapshot?.recoveryStatus;
            final estimate = readiness?.estimate;
            final night = snapshot?.selectedNight;
            final recoveryContext = snapshot?.recoveryContext;
            final accessMissing =
                snapshot != null &&
                snapshot.error == null &&
                (!snapshot.hasAccess ||
                    snapshot.heart?.canReadHrv == false ||
                    snapshot.heart?.canReadRestingHr == false ||
                    snapshot.sleep?.canReadSleep == false);
            return RefreshIndicator(
              onRefresh: () => store.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  ScreenHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    eyebrow: 'OVERNIGHT SIGNALS',
                    title: 'Recovery',
                    trailing: StatusPill(
                      label: recoveryContext?.current == null
                          ? 'CALIBRATING'
                          : recoveryContext?.provisional == true
                          ? 'BUILDING'
                          : 'EXPERIMENTAL',
                      color: recoveryContext?.current == null
                          ? AppColors.yellow
                          : recoveryContext?.provisional == true
                          ? AppColors.yellow
                          : AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A personal range from overnight HRV and resting heart '
                    'rate. Sleep sets the window and is not scored twice.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    _InitialState(
                      loading: store.loading,
                      error: store.error,
                      onRetry: () => store.refresh(force: true),
                      onData: () => context.go('/data'),
                    )
                  else if (!snapshot.hasAccess)
                    StateCard(
                      icon: Icons.link_rounded,
                      color: AppColors.yellow,
                      title: 'Connect your health data',
                      body:
                          'Allow sleep, HRV, and resting heart-rate access in '
                          'Health Connect. Recovery needs all three signals.',
                      actionLabel: 'Open data sources',
                      onAction: () => context.go('/data'),
                    )
                  else if (snapshot.error != null && estimate == null)
                    StateCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      title: 'Recovery could not load',
                      body: snapshot.error!,
                      actionLabel: 'Retry',
                      onAction: () => store.refresh(force: true),
                    )
                  else if (estimate == null || recoveryContext == null)
                    StateCard(
                      icon: accessMissing
                          ? Icons.lock_outline_rounded
                          : Icons.hourglass_empty_rounded,
                      color: AppColors.yellow,
                      title: 'Recovery is calibrating',
                      body: accessMissing
                          ? 'Allow sleep, HRV, and resting heart-rate access. '
                                'The estimate needs all three signals.'
                          : _recoveryWaitText(readiness),
                      actionLabel: accessMissing ? 'Open data sources' : null,
                      onAction: accessMissing
                          ? () => context.go('/data')
                          : null,
                    )
                  else ...[
                    _RangeCard(context: recoveryContext),
                    const SizedBox(height: 10),
                    InfoNote(
                      text:
                          'Experimental personal trend only. This formula is '
                          'not validated as training readiness or a predictor '
                          'of performance; use your own symptoms and training '
                          'context.',
                      icon: Icons.science_outlined,
                      color: AppColors.yellow,
                    ),
                    if (readiness?.limitedSamples == true) ...[
                      const SizedBox(height: 10),
                      const InfoNote(
                        text:
                            'Limited inputs: one HRV reading or a short '
                            'baseline can move the score. Treat today as a weak '
                            'signal, not a verdict.',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.yellow,
                      ),
                    ],
                    if (night != null) ...[
                      const SizedBox(height: 10),
                      InfoNote(
                        text:
                            'Selected ${formatShortDate(night.end)} · '
                            '${formatClock(night.start)}–'
                            '${formatClock(night.end)} · '
                            '${formatDurationMinutes(night.minutes)} recorded '
                            'sleep. Becel uses the longest synced session of at '
                            'least 3 hours ending within 24 hours; a long nap '
                            'may be selected.',
                        icon: Icons.schedule_rounded,
                        color: AppColors.blue,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const SectionHeader(title: 'Signals behind the range'),
                    const SizedBox(height: 9),
                    SurfaceCard(
                      padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
                      child: Column(
                        children: [
                          _ComponentRow(
                            icon: Icons.monitor_heart_rounded,
                            color: AppColors.violet,
                            label: 'HRV during asleep stages',
                            value: '${estimate.hrvCurrent.round()} ms',
                            detail:
                                '${estimate.hrvComponent}/100 × 60% · '
                                '${estimate.hrvSampleCount} asleep-stage '
                                'samples · latest ${formatClock(estimate.hrvAt)} '
                                '· personal median '
                                '${estimate.hrvBaseline.round()} ms · '
                                '${estimate.hrvBaselineDays} nights / 14 days',
                          ),
                          const Divider(height: 1),
                          _ComponentRow(
                            icon: Icons.favorite_rounded,
                            color: AppColors.red,
                            label: 'Daily resting HR',
                            value: '${estimate.restingHrCurrent.round()} bpm',
                            detail:
                                '${estimate.restingHrComponent}/100 × 40% · '
                                '${estimate.restingHrSampleCount} daily readings '
                                '· latest '
                                '${formatClock(estimate.restingHrAt)} · personal '
                                'median ${estimate.restingHrBaseline.round()} bpm '
                                '· ${estimate.restingHrBaselineDays} dates / 14',
                          ),
                          const Divider(height: 1),
                          _ComponentRow(
                            icon: Icons.bedtime_rounded,
                            color: AppColors.blue,
                            label: 'Sleep duration · context only',
                            value: night == null
                                ? '—'
                                : formatDurationMinutes(night.minutes),
                            detail:
                                'Not scored. It anchors the overnight window so '
                                'a short night is not counted twice.',
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
                          'Use this as a trend to compare with how you feel and '
                          'your training plan. It is not a diagnosis or medical '
                          'clearance to exercise.',
                      icon: Icons.self_improvement_rounded,
                      color: AppColors.blue,
                    ),
                    const SizedBox(height: 18),
                    SourceLine(
                      text:
                          'Fitbit Air via Health Connect · refreshed '
                          '${formatAgo(snapshot.loadedAt)}',
                      icon: Icons.sync_rounded,
                    ),
                  ],
                  const SizedBox(height: 21),
                  const TrustFooter(
                    text:
                        'PERSONAL TREND, NOT A DIAGNOSIS OR TRAINING '
                        'CLEARANCE',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
        title: 'Reading recovery signals',
        body: 'Loading overnight HRV, resting heart rate, and sleep windows.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (error != null) {
      return StateCard(
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        title: 'Recovery could not load',
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

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.context});

  final RecoveryContext context;

  @override
  Widget build(BuildContext widgetContext) {
    final color = switch (context.band) {
      RecoveryBand.below => AppColors.yellow,
      RecoveryBand.above => AppColors.blue,
      RecoveryBand.within => AppColors.teal,
      RecoveryBand.unknown => AppColors.teal,
    };
    return SurfaceCard(
      color: const Color(0xFF14201B),
      borderColor: color.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERSONAL RANGE', style: AppType.eyebrow.copyWith(color: color)),
          const SizedBox(height: 10),
          Text(
            context.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(context.detail, style: AppType.caption),
          const SizedBox(height: 14),
          RangeGauge(
            value: context.current,
            low: context.low,
            high: context.high,
            color: color,
            semanticsLabel:
                'Recovery ${context.label.toLowerCase()}. Today '
                '${context.current} out of 100. Usual range ${context.low} to '
                '${context.high}.',
          ),
          const SizedBox(height: 10),
          Text(
            'Overnight HRV is weighted 60% and resting heart rate 40%. Sleep '
            'is shown separately.',
            style: AppType.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

String _recoveryWaitText(RecoveryReadiness? readiness) {
  if (readiness == null || !readiness.hasSleepSession) {
    return 'Waiting for a qualifying sleep session ending within the last 24 '
        'hours.';
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
      '14-day baseline: HRV ${readiness.hrvBaselineNights}/'
      '$recoveryMinimumBaselineNights nights, RHR '
      '${readiness.restingHrBaselineNights}/$recoveryMinimumBaselineNights '
      'nights',
    );
  }
  return reasons.isEmpty
      ? 'Matching sleep-stage HRV and date-aligned resting HR'
      : reasons.join(' · ');
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
