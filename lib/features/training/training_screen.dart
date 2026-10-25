import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../domain/energy.dart';
import '../../domain/heart_signal.dart';
import '../../domain/performance.dart';
import '../../domain/strain.dart';
import '../../domain/strength.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

/// Heart-rate zones are ordinal, so they use one hue (strain) from light
/// to dark, never the status colours: green must only ever mean "good".
/// Every zone bar also carries its Z1–Z5 label.
const zoneColors = [
  Color(0xFFF4B48A),
  Color(0xFFF7A06B),
  Color(0xFFF2601E),
  Color(0xFFC43F16),
  Color(0xFF85280E),
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  navClearanceOf(context),
                ),
                children: [
                  const ScreenHeader(
                    eyebrow: 'Strain · load · zones',
                    title: 'Training',
                    trailing: GuideButton(section: 'strain'),
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
      title: 'Today',
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
                label: 'Strain',
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            label: 'Peak',
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
          if (zoneTotal == 0)
            Text(
              'No zone time yet · Z1 starts at ${zones.bpmAt(0.5)} bpm',
              style: AppType.caption,
            )
          else ...[
            Text('Time in zones', style: AppType.caption),
            const SizedBox(height: 8),
            _ZoneStrip(minutes: today!.zoneMinutes),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (var z = 0; z < 5; z++)
                  if (today.zoneMinutes[z] >= 1)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: zoneColors[z],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Z${z + 1} ${today.zoneMinutes[z].round()}m',
                          style: AppType.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
              ],
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
    final last28 = [
      for (final d in days.length <= 28 ? days : days.sublist(days.length - 28))
        if (d.hasData) d.strain,
    ];
    final averageStrain = last28.isEmpty
        ? null
        : last28.reduce((a, b) => a + b) / last28.length;
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
      title: 'Training load',
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
            referenceLine: averageStrain,
            colorFor: (i, v) => v >= 14
                ? AppColors.strain
                : AppColors.strain.withValues(alpha: v >= 10 ? 0.7 : 0.4),
            semanticsLabel: 'Daily strain, last 14 days',
          ),
          const SizedBox(height: 4),
          Text(
            'Line: 28-day average (${averageStrain?.toStringAsFixed(1) ?? '—'})',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Form',
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
                  label: 'Monotony',
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
                  label: 'Aerobic min',
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
      title: 'Zones · 7 days',
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
                      // Text stays in ink; the zone colour is on the bar.
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
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
            'Max ${max.bpm} · resting ${zones.restingBpm.round()} bpm',
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
    final synced = [
      for (final w in snapshot.activity?.workouts ?? const <WorkoutEntry>[])
        if (p.now.difference(w.start).inDays < 7) w,
    ]..sort((a, b) => b.start.compareTo(a.start));
    final items = <({DateTime at, Widget row})>[
      for (final workout in synced)
        () {
          final detail = WorkoutDetail.of(workout, snapshot);
          return (
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
              strain: detail.strain,
              zoneMinutes: detail.zoneMinutes,
              onTap: () =>
                  _showWorkout(context, detail, _iconFor(workout.type)),
            ),
          );
        }(),
    ];
    if (items.isEmpty) {
      return const StateCard(
        icon: Icons.fitness_center_rounded,
        color: AppColors.textSecondary,
        title: 'No workouts this week',
        body: 'Workouts from Fitbit Air or Google Health appear here.',
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
    if (t.contains('cycl') || t.contains('bik')) {
      return Icons.directions_bike_rounded;
    }
    if (t.contains('swim')) return Icons.pool_rounded;
    if (t.contains('strength') || t.contains('weight')) {
      return Icons.fitness_center_rounded;
    }
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
    this.zoneMinutes,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final SessionStrain? strain;
  final List<double>? zoneMinutes;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(12),
    color: AppColors.surface,
    onTap: onTap,
    child: Column(
      children: [
        _rowBody(),
        if (zoneMinutes != null &&
            zoneMinutes!.fold<double>(0, (s, v) => s + v) > 0) ...[
          const SizedBox(height: 10),
          _ZoneStrip(minutes: zoneMinutes!),
        ],
      ],
    ),
  );

  Widget _rowBody() => Row(
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
      if (onTap != null) ...[
        const SizedBox(width: 4),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ],
    ],
  );
}

/// Everything about one synced workout, computed from cleaned minute HR.
class WorkoutDetail {
  WorkoutDetail._({
    required this.workout,
    required this.strain,
    required this.zoneMinutes,
    required this.bpm,
    required this.activeKcal,
    required this.rpe,
  });

  factory WorkoutDetail.of(WorkoutEntry workout, HealthSnapshot snapshot) {
    final p = snapshot.performance;
    final zones = p.zones!;
    final end = workout.start.add(Duration(minutes: workout.minutes));
    final samples = [
      for (final s in p.clean.samples)
        if (!s.at.isBefore(workout.start) && s.at.isBefore(end)) s,
    ];
    final zoneMinutes = List<double>.filled(5, 0);
    for (final s in samples) {
      final z = zones.zoneOf(s.value);
      if (z >= 0) zoneMinutes[z] += 1;
    }
    final lift = isStrengthWorkout(workout.type)
        ? p.strengthSessions.where((s) => s.start == workout.start).firstOrNull
        : null;
    final profile = snapshot.profile;
    double? kcal;
    if (profile != null && profile.hasEnergyInputs) {
      final rmrPerMinute = restingMetabolicRate(profile) / 1440;
      if (lift != null) {
        // Corrected Compendium METs, as the calorie model costs lifting.
        kcal = (lift.met - 1) * rmrPerMinute * workout.minutes;
      } else {
        // Keytel net of resting from 50 % HRR; half of it below that.
        kcal = 0;
        for (final s in samples) {
          final net = math.max(
            0.0,
            keytelKcalPerMinute(s.value, profile) - rmrPerMinute,
          );
          final f = zones.fraction(s.value);
          kcal =
              kcal! +
              (f >= keytelMinHrr
                  ? net
                  : f >= 0.3
                  ? net / 2
                  : 0);
        }
      }
    }
    return WorkoutDetail._(
      workout: workout,
      strain: sessionStrain(
        cleanedMinutes: p.clean.samples,
        start: workout.start,
        end: end,
        restingBpm: zones.restingBpm,
        maxBpm: zones.maxBpm,
        sex: profile?.sex,
      ),
      zoneMinutes: zoneMinutes,
      bpm: [for (final s in samples) s.value],
      activeKcal: kcal,
      rpe: lift?.sessionRpe,
    );
  }

  final WorkoutEntry workout;
  final SessionStrain? strain;
  final List<double> zoneMinutes;
  final List<double> bpm;
  final double? activeKcal;

  /// Estimated session RPE for synced lifting (from heart-rate density).
  final double? rpe;
}

void _showWorkout(BuildContext context, WorkoutDetail d, IconData icon) {
  final w = d.workout;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconChip(icon: icon, color: AppColors.strain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.type, style: AppType.cardTitle),
                      Text(
                        '${formatShortDate(w.start)} · ${formatClock(w.start)} · '
                        '${formatDurationMinutes(w.minutes)}',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: 'Strain',
                    value: d.strain?.strain.toStringAsFixed(1) ?? '—',
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Avg',
                    value: d.strain?.averageBpm?.toString() ?? '—',
                    unit: 'bpm',
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Peak',
                    value: d.strain?.peakBpm?.toString() ?? '—',
                    unit: 'bpm',
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Active',
                    value: d.activeKcal == null
                        ? '—'
                        : '~${d.activeKcal!.round()}',
                    unit: 'kcal',
                    delta: d.rpe == null
                        ? null
                        : 'RPE ~${d.rpe!.toStringAsFixed(d.rpe! % 1 == 0 ? 0 : 1)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Heart rate', style: AppType.caption),
            const SizedBox(height: 8),
            SparkArea(
              values: d.bpm,
              color: AppColors.active,
              height: 110,
              emptyLabel: 'No heart rate recorded for this workout',
            ),
            const SizedBox(height: 18),
            const Text('Time in zones', style: AppType.caption),
            const SizedBox(height: 8),
            _ZoneStrip(minutes: d.zoneMinutes),
            const SizedBox(height: 10),
            for (var z = 4; z >= 0; z--)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: zoneColors[z],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(HeartZones.names[z], style: AppType.note),
                    ),
                    Text(
                      formatDurationMinutes(d.zoneMinutes[z].round()),
                      style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
