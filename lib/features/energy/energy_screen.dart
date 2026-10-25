import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../domain/energy.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

class EnergyScreen extends StatelessWidget {
  const EnergyScreen({super.key});

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
            final energy = snapshot?.performance.energy;
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
                    eyebrow: 'Burned today',
                    title: 'Calories',
                    trailing: const GuideButton(section: 'calories'),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: 'Reading energy data',
                      body: store.error ?? 'Loading heart rate and steps.',
                      icon: Icons.sync_rounded,
                      loading: store.loading,
                    )
                  else if (energy == null)
                    StateCard(
                      icon: Icons.person_outline_rounded,
                      color: AppColors.energy,
                      title: 'Waiting for data',
                      body:
                          'Needs '
                          '${snapshot.performance.energyMissing.isEmpty ? 'a moment' : snapshot.performance.energyMissing.join(', ')}.',
                      actionLabel: 'Open settings',
                      onAction: () => openSettings(context),
                    )
                  else ...[
                    _TodayCard(energy: energy),
                    const SizedBox(height: 12),
                    // Food logging is optional: these appear only when some
                    // app has shared meals with Health Connect.
                    if (snapshot.activity?.intakeKcalToday != null) ...[
                      _IntakeCard(snapshot: snapshot),
                      const SizedBox(height: 12),
                    ],
                    if (snapshot.activity?.intakeKcalByDay.any(
                          (v) => v != null && v > 0,
                        ) ??
                        false) ...[
                      _BalanceWeekCard(snapshot: snapshot),
                      const SizedBox(height: 12),
                    ],
                    _DeviceCard(energy: energy),
                    const SizedBox(height: 12),
                    _StepsCard(today: energy.today),
                    const SizedBox(height: 12),
                    _WeekCard(
                      days: snapshot.performance.energyDays,
                      maintenance: energy.maintenanceKcal,
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

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.energy});

  final EnergyBalance energy;

  @override
  Widget build(BuildContext context) {
    final t = energy.today;
    // Same order and colours as the Today card: rest in grey, modelled
    // everyday energy in pale orange, measured movement in full orange.
    final parts = [
      (
        'At rest',
        t.restingKcal,
        AppColors.textTertiary.withValues(alpha: 0.45),
      ),
      ('Daily living', t.awakeKcal, AppColors.burned.withValues(alpha: 0.4)),
      ('Digestion', t.tefKcal, AppColors.burned.withValues(alpha: 0.25)),
      ('Walking', t.stepKcal, AppColors.burned),
      ('Workouts (heart rate)', t.heartKcal, AppColors.strain),
      ('Lifting', t.strengthKcal, AppColors.active),
    ];
    final pal = energy.rmr > 0 ? energy.projectedToday / energy.rmr : null;
    final palPlausible = pal == null || (pal >= 1.35 && pal <= 2.6);
    return PanelCard(
      title: 'Today so far',
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatNumber(t.totalKcal.round()),
                        style: AppType.numXl,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 8),
                        child: Text('kcal', style: AppType.unit),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '±${t.uncertaintyKcal.round()}',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'By midnight',
                  value: '~${formatNumber(energy.projectedToday.round())}',
                ),
              ),
              if (pal != null)
                Expanded(
                  child: StatBlock(
                    label: 'Activity level',
                    value: pal.toStringAsFixed(2),
                    delta: palPlausible ? null : 'check wear time',
                    deltaColor: AppColors.bandYellow,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final part in parts)
                    if (part.$2 > 0.5)
                      Expanded(
                        flex: part.$2.round().clamp(1, 100000),
                        child: Container(color: part.$3),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final part in parts)
            if (part.$2 >= 0.5)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: part.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(part.$1, style: AppType.note)),
                    Text(
                      formatNumber(part.$2.round()),
                      style: AppType.numS.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Food logged in Google Health or any nutrition app (read-only).
class _IntakeCard extends StatelessWidget {
  const _IntakeCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final a = snapshot.activity;
    final kcal = a?.intakeKcalToday;
    final weight = snapshot.profile?.weightKg;
    final macros = [
      ('Protein', a?.proteinGToday, 4.0, AppColors.intake),
      ('Carbs', a?.carbsGToday, 4.0, AppColors.steps),
      ('Fat', a?.fatGToday, 9.0, AppColors.burned),
    ];
    final macroKcal = macros.fold<double>(0, (s, m) => s + (m.$2 ?? 0) * m.$3);
    return PanelCard(
      title: 'Eaten today',
      icon: Icons.restaurant_rounded,
      accent: AppColors.intake,
      child: kcal == null
          ? Text(
              a?.canReadNutrition == true
                  ? 'Nothing logged yet today. Food you log in Google Health, '
                        'Fitbit, or a nutrition app that shares with Health '
                        'Connect shows up here.'
                  : 'Allow nutrition access in Data sources to see calories '
                        'eaten and macros.',
              style: AppType.note,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          formatNumber(kcal.round()),
                          style: AppType.numXl,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('kcal', style: AppType.unit),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${a!.mealsToday} entr${a.mealsToday == 1 ? 'y' : 'ies'}'
                        '${a.intakeSources.isEmpty ? '' : ' · ${a.intakeSources.join(', ')}'}',
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (macroKcal > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          for (final m in macros)
                            if ((m.$2 ?? 0) > 0)
                              Expanded(
                                flex: ((m.$2! * m.$3) / macroKcal * 1000)
                                    .round()
                                    .clamp(1, 1000),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Container(color: m.$4),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    for (final m in macros)
                      Expanded(
                        child: StatBlock(
                          label: m.$1,
                          value: m.$2 == null ? '—' : m.$2!.round().toString(),
                          unit: 'g',
                          delta:
                              m.$1 == 'Protein' &&
                                  weight != null &&
                                  m.$2 != null
                              ? '${(m.$2! / weight).toStringAsFixed(1)} g/kg'
                              : macroKcal > 0 && m.$2 != null
                              ? '${((m.$2! * m.$3) / macroKcal * 100).round()}% kcal'
                              : null,
                        ),
                      ),
                  ],
                ),
                if (weight != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Protein target for training: ${(weight * 1.6).round()}–'
                    '${(weight * 2.2).round()} g (1.6–2.2 g/kg).',
                    style: AppType.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Seven days of calories eaten against Becel's calories burned.
class _BalanceWeekCard extends StatelessWidget {
  const _BalanceWeekCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final a = snapshot.activity;
    final days = snapshot.performance.energyDays;
    if (days.isEmpty) return const SizedBox.shrink();
    final intakeByDate = <String, double?>{
      for (var i = 0; i < (a?.intakeDates.length ?? 0); i++)
        a!.intakeDates[i]: i < a.intakeKcalByDay.length
            ? a.intakeKcalByDay[i]
            : null,
    };
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final rows = [
      for (final d in days)
        (
          date: d.date,
          burned: d.complete
              ? d.totalKcal
              : d.projectedTotalKcal(snapshot.performance.energy?.rmr ?? 0),
          eaten: intakeByDate[key(d.date)],
        ),
    ];
    final max = rows.fold<double>(
      1,
      (m, r) => [m, r.burned, r.eaten ?? 0].reduce((x, y) => x > y ? x : y),
    );
    final logged = rows.where((r) => r.eaten != null && r.eaten! > 0).toList();
    final avgBalance = logged.isEmpty
        ? null
        : logged.fold<double>(0, (s, r) => s + (r.eaten! - r.burned)) /
              logged.length;
    return PanelCard(
      title: 'Eaten vs burned · 7 days',
      icon: Icons.balance_rounded,
      accent: AppColors.intake,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Legend(color: AppColors.burned, label: 'Burned'),
              const SizedBox(width: 14),
              _Legend(color: AppColors.intake, label: 'Eaten'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final r in rows)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: 96 * (r.burned / max).clamp(0.02, 1.0),
                              decoration: const BoxDecoration(
                                color: AppColors.burned,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Container(
                              height: r.eaten == null
                                  ? 3
                                  : 96 * (r.eaten! / max).clamp(0.02, 1.0),
                              decoration: BoxDecoration(
                                color: r.eaten == null
                                    ? AppColors.border
                                    : AppColors.intake,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final r in rows)
                Expanded(
                  child: Text(
                    formatDayShort(r.date)[0],
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            avgBalance == null
                ? 'No meals logged this week.'
                : 'Average ${avgBalance < 0 ? 'deficit' : 'surplus'} '
                      '${formatNumber(avgBalance.abs().round())} kcal/day · '
                      '${logged.length} logged day${logged.length == 1 ? '' : 's'}',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: AppType.caption.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.energy});

  final EnergyBalance energy;

  @override
  Widget build(BuildContext context) {
    final t = energy.today;
    final device = energy.deviceTotalToday;
    final delta = energy.deviceDelta;
    return PanelCard(
      title: 'Becel vs Fitbit',
      icon: Icons.compare_arrows_rounded,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Becel',
                  value: formatNumber(t.totalKcal.round()),
                  unit: 'kcal',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Fitbit',
                  value: device == null ? '—' : formatNumber(device),
                  unit: device == null ? null : 'kcal',
                  delta: device == null ? 'not synced yet' : null,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Difference',
                  value: delta == null
                      ? '—'
                      : '${delta >= 0 ? '+' : '−'}${formatNumber(delta.abs().round())}',
                  delta: delta == null
                      ? null
                      : delta > 0
                      ? 'Fitbit higher'
                      : 'Becel higher',
                  deltaColor: delta != null && delta > 150
                      ? AppColors.bandYellow
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.today});

  final DayEnergy today;

  @override
  Widget build(BuildContext context) {
    final total = today.countedSteps + today.filteredSteps;
    return PanelCard(
      title: 'Steps',
      icon: Icons.directions_walk_rounded,
      accent: AppColors.steps,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Walking',
                  value: formatNumber(today.countedSteps),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Incidental',
                  value: formatNumber(today.filteredSteps),
                  deltaColor: AppColors.textTertiary,
                  delta: total == 0
                      ? null
                      : '${(today.filteredSteps / total * 100).round()}% of raw',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Fitbit total',
                  value: formatNumber(total),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            LinearMeter(
              value: today.countedSteps.toDouble(),
              max: total.toDouble(),
              color: AppColors.steps,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.days, required this.maintenance});

  final List<DayEnergy> days;
  final double? maintenance;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Last 7 days',
      icon: Icons.bar_chart_rounded,
      accent: AppColors.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayBars(
            values: [for (final d in days) d.totalKcal],
            labels: [for (final d in days) formatDayShort(d.date)[0]],
            height: 80,
            referenceLine: maintenance,
            valueLabel: (v) => (v / 1000).toStringAsFixed(1),
            colorFor: (i, v) => AppColors.energy.withValues(
              alpha: days[i].complete ? 0.75 : 0.35,
            ),
            semanticsLabel: 'Daily calories, last 7 days',
          ),
          const SizedBox(height: 10),
          Text(
            maintenance == null
                ? 'Maintenance needs 3 full days of wear.'
                : 'Maintenance ~${formatNumber(maintenance!.round())} kcal/day (line)',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}
