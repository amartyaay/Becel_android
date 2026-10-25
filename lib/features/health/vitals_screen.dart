import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../domain/estimates.dart';
import '../../domain/heart_signal.dart';
import '../../domain/metrics.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';
import '../training/training_screen.dart' show zoneColors;

/// Heart rate, zones, overnight signals, and cardio fitness in one place.
class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key});

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
                    eyebrow: 'Heart · breath · temperature',
                    title: 'Vitals',
                    trailing: const GuideButton(section: 'vitals'),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: 'Reading vitals',
                      body: store.error ?? 'Loading Fitbit Air signals.',
                      icon: Icons.sync_rounded,
                      loading: store.loading,
                    )
                  else ...[
                    _HeartTodayCard(snapshot: snapshot),
                    const SizedBox(height: 12),
                    _ZonesCard(snapshot: snapshot),
                    const SizedBox(height: 12),
                    _OvernightCard(snapshot: snapshot),
                    const SizedBox(height: 12),
                    _FitnessCard(fitness: snapshot.cardioFitness),
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

class _HeartTodayCard extends StatelessWidget {
  const _HeartTodayCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final heart = snapshot.heart;
    final values = <double>[
      for (final s in heart?.series ?? const <HeartSample>[]) s.bpm.toDouble(),
    ];
    return PanelCard(
      title: 'Heart rate today',
      icon: Icons.favorite_rounded,
      accent: AppColors.bandRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Latest',
                  value: heart?.latestBpm?.toString() ?? '—',
                  unit: 'bpm',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Min',
                  value: heart?.minBpm?.toString() ?? '—',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Avg',
                  value: heart?.avgBpm?.toString() ?? '—',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Max',
                  value: heart?.maxBpm?.toString() ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SparkArea(
            values: values,
            color: AppColors.bandRed,
            height: 110,
            emptyLabel: 'No heart rate today yet',
          ),
        ],
      ),
    );
  }
}

class _ZonesCard extends StatelessWidget {
  const _ZonesCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.performance;
    final zones = p.zones;
    final max = p.maxHr;
    return PanelCard(
      title: 'YOUR ZONES (KARVONEN)',
      icon: Icons.speed_rounded,
      accent: AppColors.orange,
      child: zones == null || max == null
          ? StateCard(
              icon: Icons.person_outline_rounded,
              title: 'Needs age and resting HR',
              body:
                  'Add your age in Settings; resting HR comes from Fitbit Air.',
              actionLabel: 'Open profile',
              onAction: () => openSettings(context),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var z = 4; z >= 0; z--)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
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
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            HeartZones.names[z],
                            style: AppType.rowTitle.copyWith(fontSize: 13.5),
                          ),
                        ),
                        Text(
                          '${(HeartZones.lowerBounds[z] * 100).round()}%+',
                          style: AppType.caption,
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 92,
                          child: Text(
                            zones.rangeLabel(z),
                            textAlign: TextAlign.right,
                            style: AppType.numS.copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 18),
                Text(
                  'Max ${max.bpm} bpm from ${max.sourceLabel}'
                  '${max.observedBpm != null && max.source != MaxHrSource.observed ? ' (highest sustained seen: ${max.observedBpm})' : ''}. '
                  'Age prediction: ${max.predictedBpm}. Resting ${zones.restingBpm.round()} bpm.',
                  style: AppType.caption,
                ),
                if (max.source != MaxHrSource.tested) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tested max HR? Add it in Settings.',
                    style: AppType.caption.copyWith(color: AppColors.teal),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OvernightCard extends StatelessWidget {
  const _OvernightCard({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final heart = snapshot.heart;
    final cutoff = snapshot.loadedAt.subtract(const Duration(days: 28));
    List<double> recent(List<TimedValue> samples) => [
      for (final s in [...samples]..sort((a, b) => a.at.compareTo(b.at)))
        if (s.at.isAfter(cutoff)) s.value,
    ];
    final rhr = recent(heart?.restingHrSamples ?? const []);
    final hrvByDay = <String, List<double>>{};
    for (final s in heart?.hrvSamples ?? const <TimedValue>[]) {
      if (!s.at.isAfter(cutoff)) continue;
      (hrvByDay['${s.at.year}-${s.at.month.toString().padLeft(2, '0')}-${s.at.day.toString().padLeft(2, '0')}'] ??=
              [])
          .add(s.value);
    }
    final keys = hrvByDay.keys.toList()..sort();
    final hrv = [for (final k in keys) medianOf(hrvByDay[k]!)];
    final r = snapshot.recovery;
    final body = snapshot.body;
    final p = snapshot.performance;
    return PanelCard(
      title: 'Overnight signals · 28 days',
      icon: Icons.nightlight_round,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrendRow(
            label: 'Resting HR',
            value: r == null
                ? heart?.restingHrBpm?.toString() ?? '—'
                : r.restingHrCurrent.round().toString(),
            unit: 'bpm',
            note: r == null
                ? 'latest record'
                : 'baseline ${r.restingHrBaseline.round()}',
            values: rhr,
            color: AppColors.bandRed,
          ),
          _TrendRow(
            label: 'HRV (RMSSD)',
            value: r == null ? '—' : r.hrvCurrent.round().toString(),
            unit: 'ms',
            note: r == null
                ? 'needs last night'
                : 'night median · baseline ${r.hrvBaseline.round()}',
            values: hrv,
            color: AppColors.teal,
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Respiratory',
                  value: body?.respiratoryRate?.toStringAsFixed(1) ?? '—',
                  unit: '/min',
                  delta: p.respiratoryDelta == null
                      ? null
                      : '${p.respiratoryDelta! >= 0 ? '+' : ''}${p.respiratoryDelta!.toStringAsFixed(1)} vs 28-day median',
                  deltaColor: (p.respiratoryDelta ?? 0) >= 1
                      ? AppColors.bandYellow
                      : null,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Skin temp',
                  value: p.skinTempDelta == null
                      ? '—'
                      : '${p.skinTempDelta! >= 0 ? '+' : ''}${p.skinTempDelta!.toStringAsFixed(1)}',
                  unit: '°C',
                  delta: body?.skinTempBaselineC == null
                      ? null
                      : 'vs ${body!.skinTempBaselineC!.toStringAsFixed(1)} °C baseline',
                  deltaColor: (p.skinTempDelta ?? 0) >= 0.5
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

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
    required this.values,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final String note;
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: StatBlock(
            label: label.toUpperCase(),
            value: value,
            unit: unit,
            delta: note,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SparkArea(
            values: values,
            color: color,
            height: 54,
            emptyLabel: 'No history',
          ),
        ),
      ],
    ),
  );
}

class _FitnessCard extends StatelessWidget {
  const _FitnessCard({required this.fitness});

  final CardioFitness? fitness;

  @override
  Widget build(BuildContext context) {
    final f = fitness;
    return PanelCard(
      title: 'Cardio fitness · estimate',
      icon: Icons.directions_run_rounded,
      accent: AppColors.green,
      trailing: f == null
          ? null
          : Tag(
              f.confidence.shortLabel,
              color: f.confidence == MetricConfidence.low
                  ? AppColors.bandYellow
                  : AppColors.green,
            ),
      child: f == null
          ? const Text(
              'Needs age and a resting heart rate.',
              style: AppType.note,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${f.low.round()}–${f.high.round()}',
                      style: AppType.numM,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 3),
                      child: Text('ml/kg/min VO2 max', style: AppType.unit),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  f.category == null
                      ? 'Range too wide to place you in a band yet.'
                      : '${f.category} for your age and sex.',
                  style: AppType.body,
                ),
              ],
            ),
    );
  }
}
