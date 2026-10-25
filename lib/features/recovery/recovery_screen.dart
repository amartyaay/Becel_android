import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';

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
            return RefreshIndicator(
              onRefresh: () => store.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                children: [
                  ScreenHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    eyebrow: 'Readiness to perform',
                    title: 'Recovery',
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: 'Reading recovery signals',
                      body:
                          store.error ?? 'Loading HRV, resting HR, and sleep.',
                      icon: Icons.sync_rounded,
                      loading: store.loading,
                    )
                  else if (estimate == null)
                    _CalibratingCard(readiness: readiness!)
                  else ...[
                    _HeroCard(estimate: estimate),
                    const SizedBox(height: 12),
                    _ContributorsCard(estimate: estimate),
                  ],
                  if (snapshot != null) ...[
                    const SizedBox(height: 12),
                    _HistoryCard(history: snapshot.recoveryHistory),
                  ],
                  const SizedBox(height: 12),
                  const PanelCard(
                    title: 'HOW IT WORKS',
                    icon: Icons.functions_rounded,
                    accent: AppColors.textSecondary,
                    child: Text(recoveryMethod, style: AppType.caption),
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

class _CalibratingCard extends StatelessWidget {
  const _CalibratingCard({required this.readiness});

  final RecoveryReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final nights = [
      readiness.hrvBaselineNights,
      readiness.restingHrBaselineNights,
    ].reduce((a, b) => a < b ? a : b);
    return PanelCard(
      title: 'CALIBRATING',
      icon: Icons.hourglass_top_rounded,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !readiness.hasSleepSession
                ? 'No main sleep in the last 20 hours'
                : readiness.hrvCurrentSampleCount == 0
                ? 'No HRV inside last night’s sleep stages'
                : '${readiness.nightsUntilScore} more night'
                      '${readiness.nightsUntilScore == 1 ? '' : 's'} to your first score',
            style: AppType.cardTitle.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 10),
          LinearMeter(
            value: nights.toDouble(),
            max: recoveryFullBaselineNights.toDouble(),
            color: AppColors.teal,
          ),
          const SizedBox(height: 6),
          Text(
            '$nights of $recoveryFullBaselineNights baseline nights. A '
            'provisional score starts at $recoveryMinimumBaselineNights.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.estimate});

  final RecoveryEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final color = recoveryColor(estimate.score);
    return PanelCard(
      accent: color,
      child: Row(
        children: [
          MetricRing(
            fraction: estimate.score / 100,
            color: color,
            value: '${estimate.score}',
            unit: '%',
            label: 'RECOVERY',
            size: 128,
            stroke: 11,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(recoveryWord(estimate.score), color: color),
                const SizedBox(height: 10),
                Text(switch (estimate.band) {
                  RecoveryBand.green =>
                    'Your system is primed for hard training.',
                  RecoveryBand.yellow =>
                    'Ready for moderate work. Keep max efforts in reserve.',
                  RecoveryBand.red =>
                    'Signals point to fatigue. Prioritise recovery.',
                }, style: AppType.body.copyWith(color: AppColors.textPrimary)),
                if (estimate.provisional) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Provisional: ${estimate.hrvBaselineDays} of '
                    '$recoveryFullBaselineNights baseline nights.',
                    style: AppType.caption.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributorsCard extends StatelessWidget {
  const _ContributorsCard({required this.estimate});

  final RecoveryEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final hrvPct = estimate.hrvChangePercent;
    final rhrDelta = estimate.restingHrChange;
    return PanelCard(
      title: 'WHAT DROVE TODAY',
      icon: Icons.insights_rounded,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Contributor(
            label: 'HRV',
            weight: RecoveryModel.hrvWeight,
            value: '${estimate.hrvCurrent.round()} ms',
            detail:
                '${hrvPct >= 0 ? '+' : ''}${hrvPct.round()}% vs '
                '${estimate.hrvBaseline.round()} ms baseline · median of '
                '${estimate.hrvSampleCount} in-sleep readings',
            contribution: estimate.hrvContribution,
          ),
          _Contributor(
            label: 'Resting HR',
            weight: RecoveryModel.restingHrWeight,
            value: '${estimate.restingHrCurrent.round()} bpm',
            detail:
                '${rhrDelta >= 0 ? '+' : '−'}${rhrDelta.abs().toStringAsFixed(1)} '
                'bpm vs ${estimate.restingHrBaseline.toStringAsFixed(0)} baseline',
            contribution: estimate.restingHrContribution,
          ),
          _Contributor(
            label: 'Sleep vs need',
            weight: RecoveryModel.sleepWeight,
            value: '${estimate.sleepPercentOfNeed}%',
            detail:
                '85% of need is neutral; extra sleep never counts against you',
            contribution: estimate.sleepContribution,
          ),
          if (estimate.contextReasons.isNotEmpty) ...[
            const Divider(height: 22),
            for (final reason in estimate.contextReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      estimate.contextAdjustment < 0
                          ? Icons.south_rounded
                          : Icons.north_rounded,
                      size: 14,
                      color: estimate.contextAdjustment < 0
                          ? AppColors.bandYellow
                          : AppColors.bandGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason, style: AppType.note)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            'Bars show each signal’s push on the score in standard-deviation '
            'units against your 28-day baseline (${RecoveryModel.weightsLabel}).',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Contributor extends StatelessWidget {
  const _Contributor({
    required this.label,
    required this.weight,
    required this.value,
    required this.detail,
    required this.contribution,
  });

  final String label;
  final double weight;
  final String value;
  final String detail;
  final double contribution;

  @override
  Widget build(BuildContext context) {
    final positive = contribution >= 0;
    final color = contribution.abs() < 0.15
        ? AppColors.textTertiary
        : positive
        ? AppColors.bandGreen
        : AppColors.bandYellow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppType.rowTitle),
              const SizedBox(width: 6),
              Text('${(weight * 100).round()}%', style: AppType.caption),
              const Spacer(),
              Text(value, style: AppType.numS.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final half = constraints.maxWidth / 2;
              final width = (contribution.abs() / 1.5).clamp(0.0, 1.0) * half;
              return SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigher,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: positive ? half : half - width,
                      width: width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: half - 1,
                      width: 2,
                      top: 0,
                      bottom: 0,
                      child: Container(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 5),
          Text(detail, style: AppType.caption.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<RecoveryHistoryPoint> history;

  @override
  Widget build(BuildContext context) {
    final scores = [
      for (final point in history) point.readiness?.estimate?.score.toDouble(),
    ];
    final valid = scores.whereType<double>().toList();
    final average = valid.isEmpty
        ? null
        : (valid.reduce((a, b) => a + b) / valid.length).round();
    return PanelCard(
      title: 'LAST 14 DAYS',
      icon: Icons.calendar_view_week_rounded,
      accent: AppColors.recovery,
      trailing: average == null
          ? null
          : Text(
              'avg $average%',
              style: AppType.caption.copyWith(fontWeight: FontWeight.w800),
            ),
      child: history.isEmpty
          ? const Text('No history yet.', style: AppType.note)
          : DayBars(
              values: scores,
              labels: [
                for (var i = 0; i < history.length; i++)
                  i.isEven || i == history.length - 1
                      ? formatDayShort(history[i].date)[0]
                      : '',
              ],
              maxValue: 100,
              height: 80,
              valueLabel: (v) => v.round().toString(),
              colorFor: (i, v) => recoveryColor(v.round()),
              semanticsLabel:
                  'Recovery last 14 days: ${valid.map((v) => v.round()).join(', ')}',
            ),
    );
  }
}
