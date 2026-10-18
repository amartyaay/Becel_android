import 'package:flutter/material.dart';

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
  HealthSummary? _summary;
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

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      _health.readHeartDetail(),
      _health.readSummary(),
    ]);
    if (!mounted) return;
    setState(() {
      _heart = results[0] as HeartDetail;
      _summary = results[1] as HealthSummary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heart = _heart;
    final summary = _summary;
    final score = recoveryEstimate(
      restingHr: heart?.restingHrBpm,
      restingHrBaseline: heart?.restingHrBaseline,
      hrv: heart?.hrvRmssd,
      hrvBaseline: heart?.hrvBaseline,
    );
    final needingAccess = heart != null &&
        (!heart.canReadHrv || !heart.canReadRestingHr);
    final strain = heart?.canReadHeartRate == true
        ? strainEstimateFromZones(heart!.zoneMinutes)
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              ScreenHeader(
                onBack: () => Navigator.of(context).maybePop(),
                eyebrow: 'HOW READY YOU ARE',
                title: 'Recovery',
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.green,
                        ),
                      )
                    : StatusPill(
                        label: score == null ? 'NOT ENOUGH DATA' : 'ESTIMATE',
                        color: score == null
                            ? AppColors.yellow
                            : AppColors.green,
                        icon: Icons.energy_savings_leaf_rounded,
                      ),
              ),
              const SizedBox(height: 16),
              if (needingAccess)
                const InfoNote(
                  text: 'Recovery needs HRV and resting heart rate access. '
                      'Enable them in Data sources; the estimate appears '
                      'once Health Connect has records.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                )
              else if (score == null)
                const InfoNote(
                  text: 'No HRV or resting heart-rate records yet. Fitbit '
                      'Air data appears after Google Health syncs it.',
                  icon: Icons.hourglass_empty_rounded,
                  color: AppColors.yellow,
                )
              else ...[
                SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$score', style: AppType.numXl),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('of 100', style: AppType.unit),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _recoveryWord(score).toUpperCase(),
                          style: AppType.pill.copyWith(
                            color: _recoveryColor(score),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const InfoNote(
                  text: recoveryScoreFormula,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.green,
                ),
                const SizedBox(height: 18),
                SectionHeader(title: 'Signals', caption: 'VS 14-DAY BASELINE'),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: Column(
                    children: [
                      _SignalRow(
                        label: 'HRV (RMSSD)',
                        value: heart?.hrvRmssd != null
                            ? '${heart!.hrvRmssd!.round()} ms'
                            : '\u2014',
                        baseline: heart?.hrvBaseline != null
                            ? 'Baseline ${heart!.hrvBaseline!.round()} ms'
                            : 'No baseline',
                        better: _higherIsBetter(
                          heart?.hrvRmssd,
                          heart?.hrvBaseline,
                        ),
                        color: AppColors.violet,
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _SignalRow(
                        label: 'Resting HR',
                        value: heart?.restingHrBpm != null
                            ? '${heart!.restingHrBpm} bpm'
                            : '\u2014',
                        baseline: heart?.restingHrBaseline != null
                            ? 'Baseline ${heart!.restingHrBaseline} bpm'
                            : 'No baseline',
                        better: _lowerIsBetter(
                          heart?.restingHrBpm,
                          heart?.restingHrBaseline,
                        ),
                        color: AppColors.red,
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _SignalRow(
                        label: 'Main sleep',
                        value: summary?.sleepSessionMinutes != null
                            ? formatDurationMinutes(
                                summary!.sleepSessionMinutes!,
                              )
                            : '\u2014',
                        baseline: summary?.sleepEnd != null
                            ? 'Ended ${formatClock(DateTime.parse(summary!.sleepEnd!))}'
                            : 'No session',
                        better: null,
                        color: AppColors.blue,
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _SignalRow(
                        label: 'Today\u2019s strain',
                        value: strain != null ? '$strain' : '\u2014',
                        baseline: 'From heart-rate zones',
                        better: null,
                        color: AppColors.yellow,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const TrustFooter(
                text: 'READ ONLY \u00b7 NO HEALTH DATA IS UPLOADED',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recoveryWord(int score) {
    if (score >= 75) return 'Primed';
    if (score >= 55) return 'Balanced';
    if (score >= 35) return 'Take it easy';
    return 'Rest up';
  }

  Color _recoveryColor(int score) {
    if (score >= 75) return AppColors.green;
    if (score >= 55) return AppColors.teal;
    if (score >= 35) return AppColors.yellow;
    return AppColors.red;
  }

  bool? _higherIsBetter(double? current, double? baseline) {
    if (current == null || baseline == null || baseline == 0) return null;
    return current >= baseline;
  }

  bool? _lowerIsBetter(int? current, int? baseline) {
    if (current == null || baseline == null) return null;
    return current <= baseline;
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.value,
    required this.baseline,
    required this.color,
    required this.better,
  });

  final String label;
  final String value;
  final String baseline;
  final Color color;
  final bool? better;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppType.rowTitle)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: AppType.numS),
            const SizedBox(height: 2),
            Text(
              baseline,
              style: AppType.caption.copyWith(
                color: better == null
                    ? AppColors.textTertiary
                    : better!
                    ? AppColors.green
                    : AppColors.yellow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
