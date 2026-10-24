import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class HeartScreen extends StatefulWidget {
  const HeartScreen({super.key});

  @override
  State<HeartScreen> createState() => _HeartScreenState();
}

class _HeartScreenState extends State<HeartScreen> {
  final _health = HealthConnectService.instance;
  HeartDetail? _heart;
  ActivityEstimate? _activityEstimate;
  int? _age;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_load);
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _health.dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final heart = await _health.readHeartDetail(refresh: forceRefresh);
    final age = await _health.readFitnessAge();
    final activity = _health.activityEstimateFor(heart, age);
    if (!mounted) return;
    setState(() {
      _heart = heart;
      _activityEstimate = activity;
      _age = age;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heart = _heart;
    final latestAt = heart?.latestAt == null
        ? null
        : DateTime.tryParse(heart!.latestAt!);
    final seriesValues = heart == null
        ? const <double>[]
        : heart.series.map((sample) => sample.bpm.toDouble()).toList();
    final activity = _activityEstimate;
    final zoneMinutes = activity?.zoneMinutes ?? const <double>[];
    final zoneTotal = zoneMinutes.fold<double>(0, (sum, value) => sum + value);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              ScreenHeader(
                onBack: () => Navigator.of(context).maybePop(),
                eyebrow: 'TODAY\u2019S SIGNAL',
                title: 'Heart rate',
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
                        label: latestAt == null
                            ? 'NO SAMPLE'
                            : formatAgo(latestAt).toUpperCase(),
                        color: latestAt == null
                            ? AppColors.yellow
                            : AppColors.green,
                        icon: Icons.favorite_rounded,
                      ),
              ),
              const SizedBox(height: 16),
              if (heart?.error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoNote(
                      text: 'Could not read Health Connect: ${heart!.error}',
                      textColor: AppColors.red,
                    ),
                    TextButton.icon(
                      onPressed: () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else if (heart != null && !heart.canReadHeartRate) ...[
                const InfoNote(
                  text:
                      'Heart-rate access is off. Allow it to see your curve and activity zones.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                ),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () => context.go('/data'),
                  icon: const Icon(Icons.sensors_rounded),
                  label: const Text('Review data access'),
                ),
              ] else ...[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            heart?.latestBpm?.toString() ?? '\u2014',
                            style: AppType.numXl,
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('bpm latest', style: AppType.unit),
                          ),
                          const Spacer(),
                          if (latestAt != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Updated ${formatClock(latestAt)}',
                                style: AppType.caption,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SparkArea(
                        values: seriesValues,
                        color: AppColors.red,
                        height: 130,
                        emptyLabel: 'No heart-rate samples today yet',
                      ),
                      if (seriesValues.length >= 2) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              formatClock(heart!.series.first.at),
                              style: AppType.caption,
                            ),
                            const Spacer(),
                            Text(
                              formatClock(heart.series.last.at),
                              style: AppType.caption,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Today\u2019s range',
                  caption: '5-MINUTE AVERAGES',
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: Row(
                    children: [
                      _Stat(label: 'Min', value: heart?.minBpm),
                      _Stat(label: 'Avg', value: heart?.avgBpm),
                      _Stat(label: 'Max', value: heart?.maxBpm),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Activity intensity',
                  caption: '7-DAY HR RESERVE',
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: activity == null
                      ? Text(
                          _age == null
                              ? 'Add your age in Settings to estimate personal heart-rate zones.'
                              : 'No continuous heart-rate samples to estimate zones yet.',
                          style: AppType.caption,
                        )
                      : Column(
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
                                bpmRange: activity.zoneRanges[index],
                                minutes: zoneMinutes[index].round(),
                                fraction: zoneTotal == 0
                                    ? 0
                                    : zoneMinutes[index] / zoneTotal,
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
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Recovery signals',
                  caption: '14-DAY BASELINE',
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SignalTile(
                        icon: Icons.favorite_border_rounded,
                        color: AppColors.red,
                        label: 'Resting HR',
                        value: heart?.restingHrBpm != null
                            ? '${heart!.restingHrBpm}'
                            : '\u2014',
                        unit: 'bpm',
                        note: _baselineNote(
                          heart?.restingHrSamples ?? const <TimedValue>[],
                          heart?.canReadRestingHr == true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SignalTile(
                        icon: Icons.monitor_heart_outlined,
                        color: AppColors.violet,
                        label: 'HRV (RMSSD)',
                        value: heart?.hrvRmssd != null
                            ? '${heart!.hrvRmssd!.round()}'
                            : '\u2014',
                        unit: 'ms',
                        note: _baselineNote(
                          heart?.hrvSamples ?? const <TimedValue>[],
                          heart?.canReadHrv == true,
                        ),
                      ),
                    ),
                  ],
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

  String _baselineNote(List<TimedValue> samples, bool hasAccess) {
    if (!hasAccess) return 'Access needed';
    if (samples.isEmpty) return 'No recent records';
    return '${samples.length} readings · last 14 days';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value?.toString() ?? '\u2014', style: AppType.numM),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppType.caption),
        ],
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color, size: 34, iconSize: 17),
          const SizedBox(height: 10),
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
          const SizedBox(height: 2),
          Text(label, style: AppType.caption),
          const SizedBox(height: 4),
          Text(note, style: AppType.caption),
        ],
      ),
    );
  }
}
