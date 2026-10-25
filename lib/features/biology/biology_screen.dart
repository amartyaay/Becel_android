import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../domain/metrics.dart';
import '../../widgets/kit.dart';

class BiologyScreen extends StatefulWidget {
  const BiologyScreen({super.key});

  @override
  State<BiologyScreen> createState() => _BiologyScreenState();
}

class _BiologyScreenState extends State<BiologyScreen> {
  final _store = HealthStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final snapshot = _store.snapshot;
            final body = snapshot?.body;

            return RefreshIndicator(
              onRefresh: () => _store.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  ScreenHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    eyebrow: 'MEASURED BY YOUR AIR',
                    title: 'Biology',
                    trailing: _store.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.green,
                            ),
                          )
                        : const StatusPill(
                            label: 'READ ONLY',
                            color: AppColors.violet,
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: 'Reading body signals',
                      body:
                          _store.error ??
                          'Loading Fitbit Air oxygen, breathing, and skin '
                              'temperature records.',
                      icon: Icons.sync_rounded,
                      loading: _store.loading,
                      actionLabel: _store.error == null ? null : 'Retry',
                      onAction: () => _store.refresh(force: true),
                    )
                  else if (snapshot.error != null && body == null)
                    StateCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      title: 'Body signals could not load',
                      body: snapshot.error!,
                      actionLabel: 'Retry',
                      onAction: () => _store.refresh(force: true),
                    )
                  else ...[
                    if (snapshot.fitnessAge != null) ...[
                      _FitnessAgeCard(age: snapshot.fitnessAge!),
                      const SizedBox(height: 12),
                    ] else ...[
                      const InfoNote(
                        text:
                            'Add age and sex in Settings to see a fitness age. '
                            'Becel uses Fitbit Air VO₂ max when available and '
                            'otherwise estimates it from resting heart rate.',
                        icon: Icons.info_outline_rounded,
                        color: AppColors.violet,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _BioTile(
                      icon: Icons.bloodtype_rounded,
                      color: AppColors.red,
                      label: 'Blood oxygen',
                      value: body?.spo2Percent != null
                          ? body!.spo2Percent!.round().toString()
                          : '\u2014',
                      unit: '%',
                      note: _baselineNote(body?.spo2Baseline, '%'),
                      hasAccess: body?.canReadSpo2 == true,
                    ),
                    const SizedBox(height: 10),
                    _BioTile(
                      icon: Icons.air_rounded,
                      color: AppColors.teal,
                      label: 'Respiratory rate',
                      value: body?.respiratoryRate != null
                          ? body!.respiratoryRate!.toStringAsFixed(1)
                          : '\u2014',
                      unit: 'br/min',
                      note: _baselineNote(body?.respiratoryBaseline, 'br/min'),
                      hasAccess: body?.canReadRespiratory == true,
                    ),
                    const SizedBox(height: 10),
                    _BioTile(
                      icon: Icons.thermostat_rounded,
                      color: AppColors.yellow,
                      label: 'Skin temperature',
                      value: _skinTempValue(body),
                      unit: '\u00b0C',
                      note: body?.skinTempBaselineC != null
                          ? 'Deviation from '
                                '${body!.skinTempBaselineC!.toStringAsFixed(1)}\u00b0C '
                                'baseline'
                          : null,
                      hasAccess: body?.canReadSkinTemp == true,
                    ),
                    const SizedBox(height: 10),
                    _BioTile(
                      icon: Icons.monitor_heart_outlined,
                      color: AppColors.green,
                      label: 'VO\u2082 max',
                      value: body?.vo2Max != null
                          ? body!.vo2Max!.round().toString()
                          : '\u2014',
                      unit: 'ml/kg/min',
                      note: body?.vo2Max != null
                          ? 'Latest estimate written to Health Connect'
                          : null,
                      hasAccess: body?.canReadVo2Max == true,
                    ),
                    const SizedBox(height: 16),
                    const InfoNote(
                      text:
                          'Biology shows raw Fitbit Air values as written to '
                          'Health Connect. Empty tiles mean either no access or no '
                          'synced records yet \u2014 Becel never fills them with '
                          'estimates.',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.violet,
                    ),
                    const SizedBox(height: 22),
                    const TrustFooter(
                      text: 'READ ONLY \u00b7 NO HEALTH DATA IS UPLOADED',
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

  String _skinTempValue(BodyDetail? body) {
    final deviation = body?.skinTempDeviationC;
    if (deviation == null) return '\u2014';
    final sign = deviation >= 0 ? '+' : '';
    return '$sign${deviation.toStringAsFixed(1)}';
  }

  String? _baselineNote(num? baseline, String unit) {
    if (baseline == null) return null;
    return '7-day average ${baseline.toStringAsFixed(1)} $unit';
  }
}

class _FitnessAgeCard extends StatelessWidget {
  const _FitnessAgeCard({required this.age});

  final FitnessAgeEstimate age;

  @override
  Widget build(BuildContext context) {
    final delta = age.deltaYears;
    final deltaLabel = delta == 0
        ? 'Same as your age'
        : delta < 0
        ? '${delta.abs()} years younger'
        : '$delta years older';
    return SurfaceCard(
      color: const Color(0xFF17151F),
      borderColor: AppColors.violet.withValues(alpha: 0.24),
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.violet,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'FITNESS AGE · REFERENCE',
                  style: AppType.eyebrow.copyWith(
                    color: AppColors.violet,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              StatusPill(
                label: age.confidence.shortLabel,
                color: age.confidence == MetricConfidence.low
                    ? AppColors.yellow
                    : AppColors.violet,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${age.fitnessAge}',
                        style: AppType.numXl.copyWith(fontSize: 52),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 7),
                        child: Text('YEARS', style: AppType.unit),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                deltaLabel,
                style: AppType.caption.copyWith(
                  color: delta <= 0 ? AppColors.green : AppColors.yellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Range ${age.lowAge}–${age.highAge} · VO₂ max '
            '${age.vo2Max.toStringAsFixed(1)} ml/kg/min'
            '${age.vo2MaxEstimated ? ' (estimated)' : ''}',
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(age.method, style: AppType.caption),
        ],
      ),
    );
  }
}

class _BioTile extends StatelessWidget {
  const _BioTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
    required this.hasAccess,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String? note;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.rowTitle),
                const SizedBox(height: 2),
                Text(
                  hasAccess ? (note ?? 'No records yet') : 'Access needed',
                  style: AppType.caption.copyWith(
                    color: hasAccess
                        ? AppColors.textTertiary
                        : AppColors.yellow,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppType.numM),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: AppType.unit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
