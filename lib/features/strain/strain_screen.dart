import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class StrainScreen extends StatefulWidget {
  const StrainScreen({super.key});

  @override
  State<StrainScreen> createState() => _StrainScreenState();
}

class _StrainScreenState extends State<StrainScreen> {
  final _health = HealthConnectService.instance;
  HeartDetail? _heart;
  int? _age;
  ActivityEstimate? _estimate;
  bool _loading = true;
  String? _readError;

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

  Future<void> _load({bool forceRefresh = false}) async {
    final values = await Future.wait<Object?>([
      _health.readHeartDetail(refresh: forceRefresh),
      _health.readFitnessAge(),
    ]);
    final heart = values[0] as HeartDetail?;
    final age = values[1] as int?;
    final estimate = heart == null
        ? null
        : _health.activityEstimateFor(heart, age);
    if (!mounted) return;
    setState(() {
      _heart = heart;
      _age = age;
      _estimate = estimate;
      _readError = heart?.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heart = _heart;
    final estimate = _estimate;
    final zones = estimate?.zoneMinutes ?? const <double>[];
    final zoneTotal = zones.fold<double>(0, (sum, value) => sum + value);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              ScreenHeader(
                onBack: () => Navigator.of(context).maybePop(),
                eyebrow: 'WEEKLY INTENSITY',
                title: 'Heart-rate zones',
                trailing: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.orange,
                        ),
                      )
                    : StatusPill(
                        label: _readError != null
                            ? 'READ ERROR'
                            : estimate == null
                            ? 'NEEDS DATA'
                            : '7-DAY VIEW',
                        color: _readError != null || estimate == null
                            ? AppColors.yellow
                            : AppColors.orange,
                        icon: Icons.monitor_heart_rounded,
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recorded heart-rate intervals classified into estimated intensity bands; they do not confirm exercise.',
                style: AppType.note,
              ),
              const SizedBox(height: 6),
              const Text(
                'HRR bands use (interval midpoint − resting HR) ÷ (predicted max HR − resting HR).',
                style: AppType.caption,
              ),
              const SizedBox(height: 16),
              if (_readError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoNote(
                      text: 'Could not read Health Connect: $_readError',
                      textColor: AppColors.red,
                    ),
                    TextButton.icon(
                      onPressed: () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else if (estimate == null)
                _SetupCard(
                  age: _age,
                  heart: heart,
                  onSettings: () => context.push('/settings'),
                  onData: () => context.go('/data'),
                  onRetry: _load,
                )
              else ...[
                const SectionHeader(
                  title: 'Time by zone',
                  caption: 'HRR ESTIMATE · LAST 7 DAYS',
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: Column(
                    children: [
                      for (var index = 0; index < 5; index++)
                        ZoneBarRow(
                          label: const [
                            'Very light',
                            'Light',
                            'Moderate',
                            'Vigorous',
                            'Near max',
                          ][index],
                          rangeLabel: estimate.zoneRanges[index],
                          minutes: zones[index].round(),
                          fraction: zoneTotal == 0
                              ? 0
                              : zones[index] / zoneTotal,
                          color: const [
                            AppColors.blue,
                            AppColors.teal,
                            AppColors.green,
                            AppColors.yellow,
                            AppColors.red,
                          ][index],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'At least one usable interval on ${estimate.usableDays}/7 local days. This does not measure full-day wear; gaps and unworn time can miss activity.',
                  style: AppType.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  'Inputs: age ${estimate.age}, predicted max ${estimate.estimatedMaxHrBpm} bpm, and resting HR ${estimate.restingHrBpm.round()} bpm from ${formatClock(estimate.restingHrAt)}. The same recent resting value sets zones for all 7 dates.',
                  style: AppType.caption,
                ),
                const SizedBox(height: 13),
                const InfoNote(
                  text: activityMethod,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.orange,
                ),
              ],
              const SizedBox(height: 18),
              SurfaceCard(
                color: AppColors.surface,
                onTap: () => context.go('/fitness'),
                padding: const EdgeInsets.all(14),
                child: const Row(
                  children: [
                    IconChip(
                      icon: Icons.directions_run_rounded,
                      color: AppColors.orange,
                      size: 38,
                      iconSize: 19,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Back to weekly activity',
                        style: AppType.rowTitle,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const TrustFooter(
                text: 'HEART-RATE ESTIMATE · NOT A WORKOUT DETECTOR',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.age,
    required this.heart,
    required this.onSettings,
    required this.onData,
    required this.onRetry,
  });

  final int? age;
  final HeartDetail? heart;
  final VoidCallback onSettings;
  final VoidCallback onData;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 36));
    final hasRecentRestingHr =
        heart?.restingHrSamples.any(
          (sample) =>
              !sample.at.isBefore(recentCutoff) &&
              sample.value >= 30 &&
              sample.value <= 120,
        ) ==
        true;
    final title = age == null
        ? 'Add age for estimated zones'
        : heart == null || !heart!.canReadHeartRate || !heart!.canReadRestingHr
        ? 'Connect heart-rate data'
        : !hasRecentRestingHr
        ? 'Waiting for a recent resting reading'
        : 'No usable intervals yet';
    final body = age == null
        ? 'Becel uses age and a recent resting heart rate to estimate heart-rate reserve. Age stays on this device.'
        : heart == null || !heart!.canReadHeartRate || !heart!.canReadRestingHr
        ? 'Allow Fitbit Air heart-rate and resting heart-rate records in Data Sources.'
        : !hasRecentRestingHr
        ? 'A resting-heart-rate record from the last 36 hours is needed to set your zones.'
        : 'Zones need consecutive heart-rate samples no more than two minutes apart.';
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.rowTitle),
          const SizedBox(height: 5),
          Text(body, style: AppType.note),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: [
              if (age == null)
                TextButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Add age'),
                ),
              if (heart == null ||
                  !heart!.canReadHeartRate ||
                  !heart!.canReadRestingHr)
                TextButton.icon(
                  onPressed: onData,
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('Data sources'),
                ),
              if (age != null && heart != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
