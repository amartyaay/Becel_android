import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../domain/sleep_coach.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final _health = HealthStore.instance;

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _health,
          builder: (context, _) {
            final snapshot = _health.snapshot;
            final coach = snapshot?.performance.sleep;
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, navClearanceOf(context)),
                children: [
                  const ScreenHeader(
                    eyebrow: 'Need · debt · timing',
                    title: 'Sleep',
                    trailing: GuideButton(section: 'sleep'),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null || coach == null)
                    StateCard(
                      title: _health.loading
                          ? 'Reading sleep'
                          : 'Sleep could not load',
                      body: _health.error ?? 'Loading the last 30 nights.',
                      icon: Icons.sync_rounded,
                      loading: _health.loading,
                      actionLabel: _health.loading ? null : 'Retry',
                      onAction: () => _health.refresh(force: true),
                    )
                  else if (snapshot.sleep?.canReadSleep == false)
                    const StateCard(
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.yellow,
                      title: 'Sleep access is off',
                      body:
                          'Allow sleep in Health Connect to see need and debt.',
                    )
                  else ...[
                    if (coach.lastNight == null)
                      const StateCard(
                        icon: Icons.bedtime_off_rounded,
                        color: AppColors.sleep,
                        title: 'No main sleep in the last 20 hours',
                        body:
                            'Sessions of 3 hours or more appear after Fitbit Air '
                            'syncs in the morning.',
                      )
                    else
                      _LastNightCard(coach: coach),
                    const SizedBox(height: 12),
                    _TonightCard(coach: coach),
                    const SizedBox(height: 12),
                    _ConsistencyCard(coach: coach),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Nights', caption: 'LAST 7'),
                    const SizedBox(height: 8),
                    for (final night in coach.nights.reversed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NightRow(night: night),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LastNightCard extends StatelessWidget {
  const _LastNightCard({required this.coach});

  final SleepCoach coach;

  @override
  Widget build(BuildContext context) {
    final night = coach.lastNight!;
    final pct = coach.performancePercent ?? 0;
    final n = night.night;
    final stages = [
      ChartSegment(
        label: 'Awake',
        minutes: n.awakeMinutes,
        color: const Color(0xFFE6A15A),
      ),
      ChartSegment(
        label: 'Light',
        minutes: n.lightMinutes,
        color: const Color(0xFF7D8CFF),
      ),
      ChartSegment(
        label: 'Deep',
        minutes: n.deepMinutes,
        color: const Color(0xFF4B4FD6),
      ),
      ChartSegment(
        label: 'REM',
        minutes: n.remMinutes,
        color: const Color(0xFF59C3FF),
      ),
      if (n.unstagedMinutes > 0)
        ChartSegment(
          label: 'Unstaged',
          minutes: n.unstagedMinutes,
          color: AppColors.textTertiary,
        ),
    ];
    final onsetNote = switch (night.onsetSource) {
      OnsetSource.device => null,
      OnsetSource.heartRate =>
        'Start moved ${night.trimmedMinutes} min later (heart rate was awake)',
      OnsetSource.user =>
        'Onset set by you (${night.trimmedMinutes} min trimmed).',
    };
    return PanelCard(
      title: 'Last night',
      icon: Icons.bedtime_rounded,
      accent: AppColors.sleep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetricRing(
                fraction: pct / 100,
                color: AppColors.sleep,
                value: '$pct',
                unit: '%',
                label: 'Of need',
                size: 116,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDurationMinutes(night.asleepMinutes),
                      style: AppType.numM,
                    ),
                    Text(
                      'asleep of ${formatDurationMinutes(coach.needLastNight)} needed',
                      style: AppType.caption,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            label: 'Efficiency',
                            value: '${night.efficiencyPercent}%',
                            delta: night.efficiencyPercent >= 85
                                ? 'good'
                                : 'restless',
                            deltaColor: night.efficiencyPercent >= 85
                                ? AppColors.bandGreen
                                : AppColors.bandYellow,
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            label: 'In bed',
                            value: formatDurationMinutes(night.inBedMinutes),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${formatClock(night.onset)} – ${formatClock(n.end)}',
            style: AppType.rowTitle,
          ),
          if (onsetNote != null) ...[
            const SizedBox(height: 4),
            Text(
              onsetNote,
              style: AppType.caption.copyWith(color: AppColors.teal),
            ),
          ],
          const SizedBox(height: 12),
          Semantics(
            label: stages
                .map((s) => '${s.label} ${formatDurationMinutes(s.minutes)}')
                .join('. '),
            child: ExcludeSemantics(
              child: StageBar(segments: stages, height: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TonightCard extends StatelessWidget {
  const _TonightCard({required this.coach});

  final SleepCoach coach;

  @override
  Widget build(BuildContext context) {
    final bedtime = coach.recommendedBedtime;
    return PanelCard(
      title: 'Tonight',
      icon: Icons.nights_stay_rounded,
      accent: AppColors.sleep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Sleep need',
                  value: formatDurationMinutes(coach.needTonight),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'In bed by',
                  value: bedtime == null ? '—' : formatClock(bedtime),
                  delta: coach.typicalWake == null
                      ? 'needs 3 nights'
                      : 'to wake ${formatClock(coach.typicalWake!)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NeedRow(
            label: 'Baseline',
            minutes: coach.baselineNeed,
            color: AppColors.sleep,
          ),
          _NeedRow(
            label: 'From yesterday’s strain',
            minutes: coach.strainNeed,
            color: AppColors.strain,
          ),
          _NeedRow(
            label: 'Sleep debt (a third repaid)',
            minutes: coach.debtNeed,
            color: AppColors.bandYellow,
          ),
        ],
      ),
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({
    required this.label,
    required this.minutes,
    required this.color,
  });

  final String label;
  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppType.note)),
        Text(
          minutes == 0 ? '—' : '+${formatDurationMinutes(minutes)}',
          style: AppType.numS.copyWith(fontSize: 14),
        ),
      ],
    ),
  );
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.coach});

  final SleepCoach coach;

  @override
  Widget build(BuildContext context) {
    final nights = coach.nights;
    final need = coach.baselineNeed;
    return PanelCard(
      title: 'Consistency · 7 nights',
      icon: Icons.schedule_rounded,
      accent: AppColors.sleep,
      trailing: coach.consistencyPercent == null
          ? null
          : Tag(
              '${coach.consistencyPercent}%',
              color: coach.consistencyPercent! >= 75
                  ? AppColors.bandGreen
                  : AppColors.bandYellow,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nights.isNotEmpty)
            DayBars(
              values: [for (final n in nights) n.asleepMinutes.toDouble()],
              labels: [for (final n in nights) formatDayShort(n.night.end)[0]],
              maxValue: 600,
              height: 70,
              referenceLine: need.toDouble(),
              valueLabel: (v) => (v / 60).toStringAsFixed(1),
              colorFor: (i, v) => v >= need * 0.9
                  ? AppColors.sleep
                  : AppColors.sleep.withValues(alpha: 0.45),
              semanticsLabel: 'Hours asleep, last 7 nights',
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Average',
                  value: coach.averageAsleep == null
                      ? '—'
                      : formatDurationMinutes(coach.averageAsleep!),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Midpoint spread',
                  value: coach.midpointSdMinutes == null
                      ? '—'
                      : '±${coach.midpointSdMinutes}m',
                  delta: coach.midpointSdMinutes == null
                      ? null
                      : coach.midpointSdMinutes! <= 45
                      ? 'regular'
                      : 'irregular',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NightRow extends StatelessWidget {
  const _NightRow({required this.night});

  final AdjustedNight night;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    color: AppColors.surface,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const IconChip(
          icon: Icons.bedtime_rounded,
          color: AppColors.sleep,
          size: 36,
          iconSize: 17,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatShortDate(night.night.end), style: AppType.rowTitle),
              Text(
                '${formatClock(night.onset)} – ${formatClock(night.night.end)} · '
                '${night.efficiencyPercent}% efficient'
                '${night.onsetSource == OnsetSource.device ? '' : ' · onset corrected'}',
                style: AppType.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        Text(
          formatDurationMinutes(night.asleepMinutes),
          style: AppType.numS.copyWith(fontSize: 15),
        ),
      ],
    ),
  );
}
