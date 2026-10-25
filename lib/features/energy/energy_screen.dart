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
                    eyebrow: 'BURN · HONEST NUMBERS',
                    title: 'Calories',
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
                      title: 'Calories need your profile',
                      body:
                          'Add age, sex, height, and weight. Body fat % switches '
                          'resting energy to lean-mass Katch–McArdle, which is '
                          'more accurate for muscular athletes.',
                      actionLabel: 'Open profile',
                      onAction: () => openSettings(context),
                    )
                  else ...[
                    _TodayCard(energy: energy),
                    const SizedBox(height: 12),
                    _DeviceCard(energy: energy),
                    const SizedBox(height: 12),
                    _StepsCard(today: energy.today),
                    const SizedBox(height: 12),
                    _WeekCard(
                      days: snapshot.performance.energyDays,
                      maintenance: energy.maintenanceKcal,
                    ),
                    const SizedBox(height: 12),
                    const _MethodCard(),
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
    final parts = [
      ('Resting', t.restingKcal, const Color(0xFF6E7F76)),
      ('Cardio (HR)', t.heartKcal, AppColors.bandRed),
      ('Walking', t.stepKcal, AppColors.green),
      ('Lifting', t.strengthKcal, AppColors.orange),
      ('Daily living', t.awakeKcal, AppColors.yellow),
    ];
    return PanelCard(
      title: 'TODAY SO FAR',
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.energy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatNumber(t.totalKcal.round()), style: AppType.numXl),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 8),
                child: Text('kcal', style: AppType.unit),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '±${t.uncertaintyKcal.round()}',
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          Text(
            '~${formatNumber(energy.projectedToday.round())} kcal projected by '
            'midnight at your current pace.',
            style: AppType.caption,
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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.energy});

  final EnergyBalance energy;

  @override
  Widget build(BuildContext context) {
    final t = energy.today;
    final device = energy.deviceTotalToday;
    final delta = energy.deviceDelta;
    final reasons = <String>[
      'Heart rate only counts above ${t.flexBpm} bpm (your FLEX-HR point). '
          'Below it, pulse reflects posture, caffeine, and stress, not work.',
      if (t.filteredSteps > 0)
        '${formatNumber(t.filteredSteps)} steps looked incidental (arm '
            'movement, fidgeting) and earned no walking energy.',
      if (t.strengthKcal > 0)
        'Lifting is scored with Compendium METs. HR during sets over-reads '
            'oxygen cost.',
      'Resting energy: ${t.rmrMethod}.',
    ];
    return PanelCard(
      title: 'BECEL VS FITBIT',
      icon: Icons.compare_arrows_rounded,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'BECEL',
                  value: formatNumber(t.totalKcal.round()),
                  unit: 'kcal',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'FITBIT',
                  value: device == null ? '—' : formatNumber(device),
                  unit: device == null ? null : 'kcal',
                  delta: device == null ? 'not synced yet' : null,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'DIFFERENCE',
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
          const SizedBox(height: 12),
          const Text('WHY THEY DIFFER', style: AppType.eyebrow),
          const SizedBox(height: 6),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(reason, style: AppType.caption)),
                ],
              ),
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
      title: 'STEPS · PHANTOM FILTER',
      icon: Icons.directions_walk_rounded,
      accent: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'WALKING',
                  value: formatNumber(today.countedSteps),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'INCIDENTAL',
                  value: formatNumber(today.filteredSteps),
                  deltaColor: AppColors.textTertiary,
                  delta: total == 0
                      ? null
                      : '${(today.filteredSteps / total * 100).round()}% of raw',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'RAW (FITBIT)',
                  value: formatNumber(total),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (total > 0)
            LinearMeter(
              value: today.countedSteps.toDouble(),
              max: total.toDouble(),
              color: AppColors.green,
            ),
          const SizedBox(height: 6),
          Text(
            '5-minute blocks under $ambulatoryBucketSteps steps count only when '
            'heart rate rises ≥${confirmedBucketHrRise.round()} bpm above '
            'resting. Desk typing and arm swings rarely do.',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
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
      title: 'LAST 7 DAYS',
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
                ? 'Maintenance appears after 3 full days with 12 h+ of wear.'
                : 'Maintenance ≈ ${formatNumber(maintenance!.round())} kcal/day '
                      '(line). A practical starting intake to hold weight; '
                      'adjust with your scale trend.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard();

  @override
  Widget build(BuildContext context) => const PanelCard(
    title: 'HOW IT’S CALCULATED',
    icon: Icons.functions_rounded,
    accent: AppColors.textSecondary,
    child: Text(
      'Each minute gets exactly one source, so nothing is double counted: '
      'logged lift (MET) → heart rate above FLEX-HR (Keytel 2005, net of '
      'resting) → walking steps (0.5 kcal/kg/km net) → a 15% daily-living '
      'allowance when awake. Sleep adds nothing above resting. HR artifacts '
      'are removed first with a Hampel filter. Wrist devices typically '
      'overestimate exercise energy by 20–40%; this design errs low on '
      'purpose. Thermic effect of food is not included.',
      style: AppType.caption,
    ),
  );
}
