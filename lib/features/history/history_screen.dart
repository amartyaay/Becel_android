import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _health = HealthConnectService.instance;
  HealthConnectInspection? _inspection;
  Trends7d? _trends;
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
    final inspection = await _health.inspect();
    Trends7d? trends;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      trends = await _health.readTrends7d();
    }
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _trends = trends;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trends = _trends;
    final hasAnyData =
        trends != null &&
        (trends.steps.any((value) => value != null) ||
            trends.hrAvg.any((value) => value != null) ||
            trends.sleepMinutes.any((value) => value != null));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
            children: [
              ScreenHeader(
                eyebrow: 'YOUR LAST 7 DAYS',
                title: 'History',
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
                        label: _inspection?.stateLabel ?? 'Check status',
                        color: _inspection?.allPermissionsGranted == true
                            ? AppColors.green
                            : AppColors.yellow,
                      ),
              ),
              const SizedBox(height: 22),
              if (!hasAnyData)
                _EmptyTrends(onReviewAccess: () => context.go('/data'))
              else ...[
                Text(
                  'Last 7 days from Health Connect, Fitbit Air records only. '
                  'Weekday labels mark each day; the rightmost bar is today.',
                  style: AppType.note,
                ),
                const SizedBox(height: 16),
                _TrendCard(
                  title: 'Steps',
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.green,
                  values: trends.steps
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: trends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) =>
                      '${(value / 1000).toStringAsFixed(1)}k',
                  summary: _stepsSummary(trends),
                ),
                const SizedBox(height: 14),
                _TrendCard(
                  title: 'Heart rate',
                  icon: Icons.favorite_rounded,
                  color: AppColors.red,
                  values: trends.hrAvg
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: trends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) => '${value.round()}',
                  summary: _heartSummary(trends),
                ),
                const SizedBox(height: 14),
                _TrendCard(
                  title: 'Longest asleep session',
                  icon: Icons.nightlight_round,
                  color: AppColors.blue,
                  values: trends.sleepMinutes
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: trends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) =>
                      formatDurationMinutes(value.round()),
                  summary: _sleepSummary(trends),
                ),
              ],
              const SizedBox(height: 20),
              const TrustFooter(
                text: 'SOURCE AND FRESHNESS SHOWN FOR EVERY VALUE',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepsSummary(Trends7d trends) {
    final values = trends.steps.whereType<int>().toList();
    if (values.isEmpty) return 'No step records this week';
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return '${_formatNumber(total)} steps total \u00b7 '
        '${_formatNumber((total / values.length).round())}/day average';
  }

  String _heartSummary(Trends7d trends) {
    final values = trends.hrAvg.whereType<int>().toList();
    if (values.isEmpty) return 'No heart-rate records this week';
    final average = (values.reduce((a, b) => a + b) / values.length).round();
    return 'Daily average $average bpm across ${values.length} day'
        '${values.length == 1 ? '' : 's'}';
  }

  String _sleepSummary(Trends7d trends) {
    final values = trends.sleepMinutes.whereType<int>().toList();
    if (values.isEmpty) return 'No sleep sessions this week';
    final average = (values.reduce((a, b) => a + b) / values.length).round();
    return 'Longest asleep session on ${values.length} day'
        '${values.length == 1 ? '' : 's'} \u00b7 ${formatDurationMinutes(average)}'
        ' average';
  }

  String _formatNumber(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
    required this.labels,
    required this.summary,
    this.valueLabelBuilder,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<double?> values;
  final List<String> labels;
  final String summary;
  final String Function(double value)? valueLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final hasData = values.any((value) => value != null);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: icon, color: color, size: 32, iconSize: 16),
              const SizedBox(width: 10),
              Text(title, style: AppType.cardTitle),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            Text('No records in the last 7 days.', style: AppType.caption)
          else
            TrendBars(
              values: values,
              labels: labels,
              color: color,
              valueLabelBuilder: valueLabelBuilder,
            ),
          const SizedBox(height: 12),
          Text(summary, style: AppType.caption),
        ],
      ),
    );
  }
}

class _EmptyTrends extends StatelessWidget {
  const _EmptyTrends({required this.onReviewAccess});

  final VoidCallback onReviewAccess;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GhostBars(),
              const SizedBox(height: 18),
              const IconChip(
                icon: Icons.query_stats_rounded,
                color: AppColors.teal,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(height: 14),
              const Text(
                'No Fitbit Air-matched history yet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Trend values will appear only after Becel receives records written for your Fitbit Air by the Fitbit app or Google Health. Other devices and sample values are hidden.',
                style: AppType.note,
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onReviewAccess,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Review data access'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'What will appear here'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _MetricPreview(
                icon: Icons.directions_walk_rounded,
                color: AppColors.green,
                label: 'Steps',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricPreview(
                icon: Icons.favorite_rounded,
                color: AppColors.red,
                label: 'Heart rate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _MetricPreview(
                icon: Icons.nightlight_round,
                color: AppColors.blue,
                label: 'Sleep',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricPreview(
                icon: Icons.directions_run_rounded,
                color: AppColors.violet,
                label: 'Workouts',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GhostBars extends StatelessWidget {
  const _GhostBars();

  static const _heights = <double>[26, 46, 34, 60, 42, 68, 50];
  static const _colors = <Color>[
    Color(0x24D0F477),
    Color(0x1F79D6C1),
    Color(0x1AD0F477),
    Color(0x1FB9A4FF),
    Color(0x1A8EA9FF),
    Color(0x24D0F477),
    Color(0x1A79D6C1),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < _heights.length; index++) ...[
            if (index > 0) const SizedBox(width: 7),
            Expanded(
              child: Container(
                height: _heights[index],
                decoration: BoxDecoration(
                  color: _colors[index],
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPreview extends StatelessWidget {
  const _MetricPreview({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          IconChip(icon: icon, color: color, size: 34, iconSize: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
