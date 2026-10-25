import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../domain/heart_signal.dart';
import '../../domain/performance.dart';
import '../../domain/strain.dart';
import '../../domain/strength.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

const zoneColors = [
  Color(0xFF7FA7C9),
  AppColors.teal,
  AppColors.bandGreen,
  AppColors.orange,
  AppColors.bandRed,
];

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
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
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, navClearance),
                children: [
                  const ScreenHeader(
                    eyebrow: 'Strain · load · zones',
                    title: 'Training',
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: _health.loading
                          ? 'Reading training data'
                          : 'Training data could not load',
                      body: _health.error ?? 'Loading 28 days of heart rate.',
                      icon: Icons.sync_rounded,
                      loading: _health.loading,
                      actionLabel: _health.loading ? null : 'Retry',
                      onAction: () => _health.refresh(force: true),
                    )
                  else if (snapshot.performance.zones == null)
                    StateCard(
                      icon: Icons.person_outline_rounded,
                      color: AppColors.teal,
                      title: snapshot.age == null
                          ? 'Add your age to calculate strain'
                          : 'Waiting for heart rate',
                      body: snapshot.age == null
                          ? 'Age sets your heart-rate reserve. Add a tested '
                                'max HR for the most accurate zones.'
                          : 'Strain needs Fitbit Air heart rate and a resting '
                                'heart-rate record.',
                      actionLabel: snapshot.age == null
                          ? 'Open profile'
                          : 'Data sources',
                      onAction: () => snapshot.age == null
                          ? openSettings(context)
                          : context.push('/data'),
                    )
                  else
                    ..._content(context, snapshot),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, HealthSnapshot snapshot) {
    final p = snapshot.performance;
    return [
      _TodayStrainCard(performance: p),
      const SizedBox(height: 12),
      _LoadTrendCard(performance: p),
      const SizedBox(height: 12),
      _WeekZonesCard(performance: p, onOpen: () => context.push('/vitals')),
      const SizedBox(height: 20),
      const SectionHeader(title: 'Workouts', caption: 'LAST 7 DAYS'),
      const SizedBox(height: 8),
      _WorkoutList(snapshot: snapshot),
      const SizedBox(height: 16),
      SourceLine(
        text:
            'Strain = Banister TRIMP on cleaned minute HR, mapped to 0–21. '
            '${p.clean.corrected} artifact minute${p.clean.corrected == 1 ? '' : 's'} '
            'removed in 28 days.',
        icon: Icons.functions_rounded,
      ),
    ];
  }
}

class _TodayStrainCard extends StatelessWidget {
  const _TodayStrainCard({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final today = performance.today;
    final target = performance.plan.target;
    final zones = performance.zones!;
    final strain = today?.strain ?? 0;
    final zoneTotal = today?.zoneMinutes.fold<double>(0, (s, v) => s + v) ?? 0;
    return PanelCard(
      title: 'TODAY',
      icon: Icons.bolt_rounded,
      accent: AppColors.strain,
      trailing: Tag(target.label, color: AppColors.strain),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetricRing(
                fraction: strain / strainMax,
                color: AppColors.strain,
                value: strain.toStringAsFixed(1),
                label: 'STRAIN',
                size: 112,
                bandFrom: target.low / strainMax,
                bandTo: target.high / strainMax,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target ${target.low.round()}–${target.high.round()}',
                      style: AppType.cardTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(target.reason, style: AppType.caption),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            label: 'PEAK',
                            value: today?.peakBpm?.toString() ?? '—',
                            unit: 'bpm',
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            label: 'TRIMP',
                            value: (today?.trimp ?? 0).round().toString(),
                            delta: (today?.strengthTrimp ?? 0) > 0
                                ? '+${today!.strengthTrimp.round()} lifting'
                                : null,
                            deltaColor: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'TIME IN ZONES TODAY',
            style: AppType.eyebrow.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 8),
          _ZoneStrip(minutes: today?.zoneMinutes ?? List.filled(5, 0)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (var z = 0; z < 5; z++)
                Text(
                  'Z${z + 1} ${(today?.zoneMinutes[z] ?? 0).round()}m',
                  style: AppType.caption.copyWith(
                    color: zoneColors[z],
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (zoneTotal == 0) ...[
            const SizedBox(height: 6),
            Text(
              'No time above ${zones.bpmAt(0.5)} bpm (Z1) yet today.',
              style: AppType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneStrip extends StatelessWidget {
  const _ZoneStrip({required this.minutes});

  final List<double> minutes;

  @override
  Widget build(BuildContext context) {
    final total = minutes.fold<double>(0, (s, v) => s + v);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: total <= 0
            ? Container(color: AppColors.surfaceHigher)
            : Row(
                children: [
                  for (var z = 0; z < 5; z++)
                    if (minutes[z] > 0)
                      Expanded(
                        flex: math.max(1, (minutes[z] * 10).round()),
                        child: Container(color: zoneColors[z]),
                      ),
                ],
              ),
      ),
    );
  }
}

class _LoadTrendCard extends StatelessWidget {
  const _LoadTrendCard({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final load = performance.load;
    final days = performance.strainDays;
    final last14 = days.length <= 14 ? days : days.sublist(days.length - 14);
    final status = load?.status ?? LoadStatus.calibrating;
    final color = switch (status) {
      LoadStatus.productive => AppColors.bandGreen,
      LoadStatus.maintaining => AppColors.teal,
      LoadStatus.detraining => AppColors.blue,
      LoadStatus.overreaching => AppColors.bandYellow,
      LoadStatus.spike => AppColors.bandRed,
      LoadStatus.calibrating => AppColors.textTertiary,
    };
    final weekAerobic = days.length < 7
        ? 0.0
        : days
              .sublist(days.length - 7)
              .fold<double>(0, (s, d) => s + d.aerobicEquivalentMinutes);
    return PanelCard(
      title: 'TRAINING LOAD',
      icon: Icons.stacked_line_chart_rounded,
      accent: AppColors.strain,
      trailing: Tag(status.label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status.advice, style: AppType.body),
          const SizedBox(height: 14),
          _AcwrGauge(ratio: load?.acwr),
          const SizedBox(height: 14),
          DayBars(
            values: [for (final d in last14) d.hasData ? d.strain : null],
            labels: [
              for (var i = 0; i < last14.length; i++)
                i.isEven || i == last14.length - 1
                    ? formatDayShort(last14[i].date)[0]
                    : '',
            ],
            maxValue: strainMax,
            height: 70,
            referenceLine: load?.chronicStrain,
            colorFor: (i, v) => v >= 14
                ? AppColors.strain
                : AppColors.strain.withValues(alpha: v >= 10 ? 0.7 : 0.4),
            semanticsLabel: 'Daily strain, last 14 days',
          ),
          const SizedBox(height: 4),
          Text(
            'Line = your 28-day average strain '
            '(${load?.chronicStrain.toStringAsFixed(1) ?? '—'}).',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'FORM',
                  value: load == null
                      ? '—'
                      : '${load.form >= 0 ? '+' : ''}${load.form.round()}',
                  delta: load == null
                      ? null
                      : load.form >= 0
                      ? 'fresh'
                      : 'carrying fatigue',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'MONOTONY',
                  value: load?.monotony?.toStringAsFixed(1) ?? '—',
                  delta: load?.monotony == null
                      ? null
                      : load!.monotony! > 2
                      ? 'too uniform'
                      : 'varied',
                  deltaColor: (load?.monotony ?? 0) > 2
                      ? AppColors.bandYellow
                      : null,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'AEROBIC MIN',
                  value: weekAerobic.round().toString(),
                  delta: 'mod-equiv / 7d',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcwrGauge extends StatelessWidget {
  const _AcwrGauge({required this.ratio});

  final double? ratio;

  @override
  Widget build(BuildContext context) {
    const min = 0.4;
    const max = 2.0;
    return Semantics(
      label: ratio == null
          ? 'Acute to chronic ratio calibrating'
          : 'Acute to chronic ratio ${ratio!.toStringAsFixed(2)}',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            double x(double v) =>
                ((v - min) / (max - min)).clamp(0.0, 1.0) * width;
            Widget band(double from, double to, Color color) => Positioned(
              left: x(from),
              width: x(to) - x(from),
              top: 8,
              child: Container(
                height: 10,
                color: color.withValues(alpha: 0.55),
              ),
            );
            return SizedBox(
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  band(min, 0.8, AppColors.blue),
                  band(0.8, 1.3, AppColors.bandGreen),
                  band(1.3, 1.5, AppColors.bandYellow),
                  band(1.5, max, AppColors.bandRed),
                  if (ratio != null)
                    Positioned(
                      left: (x(ratio!) - 7).clamp(0.0, width - 14),
                      top: 0,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          Container(
                            width: 3,
                            height: 12,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 24,
                    child: Row(
                      children: [
                        Text(
                          'Detraining',
                          style: AppType.caption.copyWith(fontSize: 10),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              ratio == null
                                  ? 'ACWR calibrating (21 days)'
                                  : 'ACWR ${ratio!.toStringAsFixed(2)}',
                              style: AppType.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Spike',
                          style: AppType.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
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

class _WeekZonesCard extends StatelessWidget {
  const _WeekZonesCard({required this.performance, required this.onOpen});

  final Performance performance;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final zones = performance.zones!;
    final max = performance.maxHr!;
    final days = performance.strainDays;
    final week = days.length <= 7 ? days : days.sublist(days.length - 7);
    final totals = List<double>.filled(5, 0);
    for (final day in week) {
      for (var z = 0; z < 5; z++) {
        totals[z] += day.zoneMinutes[z];
      }
    }
    final top = totals.fold<double>(1, math.max);
    return PanelCard(
      title: 'HEART-RATE ZONES · 7 DAYS',
      icon: Icons.favorite_rounded,
      accent: AppColors.bandRed,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var z = 4; z >= 0; z--)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(
                      HeartZones.names[z],
                      style: AppType.caption.copyWith(
                        color: zoneColors[z],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearMeter(
                      value: totals[z],
                      max: top,
                      color: zoneColors[z],
                      height: 7,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${totals[z].round()}m',
                      textAlign: TextAlign.right,
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Max ${max.bpm} bpm (${max.sourceLabel}) · resting '
            '${zones.restingBpm.round()} bpm · Z2 ${zones.rangeLabel(1)}',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.performance;
    final zones = p.zones!;
    final synced = [
      for (final w in snapshot.activity?.workouts ?? const <WorkoutEntry>[])
        if (p.now.difference(w.start).inDays < 7) w,
    ]..sort((a, b) => b.start.compareTo(a.start));
    final items = <({DateTime at, Widget row})>[
      for (final workout in synced)
        (
          at: workout.start,
          row: _WorkoutRow(
            icon: _iconFor(workout.type),
            color: isStrengthWorkout(workout.type)
                ? AppColors.textSecondary
                : AppColors.strain,
            title: workout.type,
            subtitle:
                '${formatShortDate(workout.start)} · ${formatClock(workout.start)} · '
                '${formatDurationMinutes(workout.minutes)}',
            strain: sessionStrain(
              cleanedMinutes: p.clean.samples,
              start: workout.start,
              end: workout.start.add(Duration(minutes: workout.minutes)),
              restingBpm: zones.restingBpm,
              maxBpm: zones.maxBpm,
              sex: snapshot.profile?.sex,
            ),
          ),
        ),
    ];
    if (items.isEmpty) {
      return const StateCard(
        icon: Icons.fitness_center_rounded,
        color: AppColors.textSecondary,
        title: 'No workouts this week',
        body:
            'Workouts recorded by Fitbit Air or logged in Google Health appear '
            'here with their strain.',
      );
    }
    return Column(
      children: [
        for (final item in items.take(10))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: item.row),
      ],
    );
  }

  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('run')) return Icons.directions_run_rounded;
    if (t.contains('walk')) return Icons.directions_walk_rounded;
    if (t.contains('cycl') || t.contains('bik'))
      return Icons.directions_bike_rounded;
    if (t.contains('swim')) return Icons.pool_rounded;
    if (t.contains('strength') || t.contains('weight'))
      return Icons.fitness_center_rounded;
    if (t.contains('yoga')) return Icons.self_improvement_rounded;
    return Icons.sports_rounded;
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.strain,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final SessionStrain? strain;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(12),
    color: AppColors.surface,
    child: Row(
      children: [
        IconChip(icon: icon, color: color, size: 38, iconSize: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.rowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: AppType.caption.copyWith(fontSize: 11.5)),
              if (strain?.averageBpm != null)
                Text(
                  'avg ${strain!.averageBpm} · peak ${strain!.peakBpm} bpm',
                  style: AppType.caption.copyWith(fontSize: 11.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (strain != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                strain!.strain.toStringAsFixed(1),
                style: AppType.numS.copyWith(color: AppColors.strain),
              ),
              Text('strain', style: AppType.caption.copyWith(fontSize: 10)),
            ],
          ),
      ],
    ),
  );
}
