import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
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
  List<RecoveryHistoryPoint> _recoveryHistory = const [];
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

  Future<void> _load({bool forceRefresh = false}) async {
    final inspection = await _health.inspect();
    Trends7d? trends;
    HeartDetail? heart;
    SleepDetail? sleep;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      final records = await Future.wait<Object>([
        _health.readTrends7d(),
        _health.readHeartDetail(refresh: forceRefresh),
        _health.readSleepDetail(),
      ]);
      trends = records[0] as Trends7d;
      heart = records[1] as HeartDetail;
      sleep = records[2] as SleepDetail;
    }
    final recovery = heart == null || sleep == null
        ? const <RecoveryHistoryPoint>[]
        : recoveryHistory(
            hrvSamples: heart.hrvSamples,
            restingHrSamples: heart.restingHrSamples,
            sleepWindows: sleep.sleepWindows,
            now: DateTime.now(),
          );
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _trends = trends;
      _recoveryHistory = recovery;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trends = _trends;
    final chartTrends =
        trends ?? const Trends7d(status: 'unavailable', granted: []);
    final hasAnyData =
        trends != null &&
            (trends.steps.any((value) => value != null) ||
                trends.hrAvg.any((value) => value != null) ||
                trends.sleepMinutes.any((value) => value != null)) ||
        _recoveryHistory.any(
          (point) => point.readiness?.hasSleepSession == true,
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
            children: [
              ScreenHeader(
                eyebrow: '7-DAY SIGNALS / 14-DAY RECOVERY',
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
                  'Steps, heart rate and sleep show 7 local days. Recovery shows 14 date-specific estimates; blank dates mean a session or required input was missing.',
                  style: AppType.note,
                ),
                const SizedBox(height: 16),
                if (_recoveryHistory.any(
                  (point) => point.readiness?.hasSleepSession == true,
                )) ...[
                  _RecoveryTrend(points: _recoveryHistory),
                  const SizedBox(height: 14),
                ],
                _TrendCard(
                  title: 'Steps',
                  icon: Icons.directions_walk_rounded,
                  color: AppColors.green,
                  values: chartTrends.steps
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: chartTrends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) =>
                      '${(value / 1000).toStringAsFixed(1)}k',
                  summary: _stepsSummary(chartTrends),
                ),
                const SizedBox(height: 14),
                _TrendCard(
                  title: 'Heart rate',
                  icon: Icons.favorite_rounded,
                  color: AppColors.red,
                  values: chartTrends.hrAvg
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: chartTrends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) => '${value.round()}',
                  summary: _heartSummary(chartTrends),
                ),
                const SizedBox(height: 14),
                _TrendCard(
                  title: 'Longest asleep session',
                  icon: Icons.nightlight_round,
                  color: AppColors.blue,
                  values: chartTrends.sleepMinutes
                      .map((value) => value?.toDouble())
                      .toList(),
                  labels: chartTrends.dates.map(formatDayLabel).toList(),
                  valueLabelBuilder: (value) =>
                      formatDurationMinutes(value.round()),
                  summary: _sleepSummary(chartTrends),
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

class _RecoveryTrend extends StatelessWidget {
  const _RecoveryTrend({required this.points});

  final List<RecoveryHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final scored = points
        .where((point) => point.readiness?.estimate != null)
        .toList();
    final limited = scored
        .where((point) => point.readiness?.limitedSamples == true)
        .length;
    final latest = scored.isEmpty ? null : scored.last;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.battery_charging_full_rounded,
                color: AppColors.teal,
                size: 34,
                iconSize: 17,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Recovery', style: AppType.cardTitle)),
              StatusPill(label: '14 DAYS', color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 14),
          TrendBars(
            values: points
                .map((point) => point.readiness?.estimate?.score.toDouble())
                .toList(),
            labels: points.map((point) => '${point.date.day}').toList(),
            color: AppColors.teal,
            barAreaHeight: 74,
            highlightLast: true,
            valueLabelBuilder: (score) => '${score.round()}',
          ),
          const SizedBox(height: 12),
          Text(
            '${scored.length}/${points.length} dates scored'
            '${limited == 0 ? '' : ' · $limited with limited current samples'}',
            style: AppType.rowTitle.copyWith(color: AppColors.teal),
          ),
          const SizedBox(height: 5),
          if (latest == null)
            const Text(
              'No date has enough data yet. Scoring needs a qualifying sleep session, current HRV and resting HR, plus at least 10 earlier nights for each personal baseline.',
              style: AppType.caption,
            )
          else
            Text(
              'Latest scored session: ${formatShortDate(latest.date)} · '
              '${formatDurationMinutes(latest.sleepMinutes ?? 0)} · '
              'Each bar uses the longest qualifying session ending on that date.',
              style: AppType.caption,
            ),
          const SizedBox(height: 5),
          const Text(
            'Blank days mean no qualifying session or missing inputs/baseline. A score is an experimental personal trend, not a medical measure.',
            style: AppType.caption,
          ),
        ],
      ),
    );
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
