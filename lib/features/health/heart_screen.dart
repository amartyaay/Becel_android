import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
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
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_load);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(),
    );
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _health.dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final heart = await _health.readHeartDetail();
    if (!mounted) return;
    setState(() {
      _heart = heart;
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
    final zoneMinutes = heart?.zoneMinutes ?? const [0, 0, 0, 0, 0];
    final zoneTotal = zoneMinutes.fold<int>(0, (sum, value) => sum + value);

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
                InfoNote(text: heart!.error!)
              else if (heart != null && !heart.canReadHeartRate)
                const InfoNote(
                  text: 'Heart-rate access is not allowed. Enable it in Data '
                      'sources to see your curve.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                )
              else ...[
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
                  title: 'Heart-rate zones',
                  caption: 'TODAY \u00b7 FIXED BANDS',
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: zoneTotal == 0
                      ? Text(
                          'Not enough samples today to map zones.',
                          style: AppType.caption,
                        )
                      : Column(
                          children: [
                            for (var index = 0; index < 5; index++)
                              ZoneBarRow(
                                label: heartZoneLabels[index],
                                bpmRange: heartZoneRanges[index],
                                minutes: zoneMinutes[index],
                                fraction: zoneTotal == 0
                                    ? 0
                                    : zoneMinutes[index] / zoneTotal,
                                color: heartZoneColors[index],
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
                          heart?.restingHrBaseline,
                          'bpm',
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
                          heart?.hrvBaseline,
                          'ms',
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

  String _baselineNote(num? baseline, String unit, bool hasAccess) {
    if (baseline == null) {
      return hasAccess ? 'No records yet' : 'Access needed';
    }
    return 'Baseline ${baseline.round()} $unit';
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
          Text(
            value?.toString() ?? '\u2014',
            style: AppType.numM,
          ),
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
