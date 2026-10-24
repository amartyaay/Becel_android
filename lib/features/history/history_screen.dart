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

class _RecoveryTrend extends StatefulWidget {
  const _RecoveryTrend({required this.points});

  final List<RecoveryHistoryPoint> points;

  @override
  State<_RecoveryTrend> createState() => _RecoveryTrendState();
}

class _RecoveryTrendState extends State<_RecoveryTrend> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant _RecoveryTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selectedIndex = null;
  }

  int _defaultSelection(List<RecoveryHistoryPoint> points) {
    for (var index = points.length - 1; index >= 0; index--) {
      if (points[index].readiness?.estimate != null) return index;
    }
    for (var index = points.length - 1; index >= 0; index--) {
      if (points[index].session != null) return index;
    }
    return points.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _selectedIndex ?? _defaultSelection(points);
    final selected = points[selectedIndex];
    final scored = points
        .where((point) => point.readiness?.estimate != null)
        .toList();
    final limited = scored
        .where((point) => point.readiness?.limitedSamples == true)
        .length;

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
              StatusPill(label: 'EXPERIMENTAL', color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${scored.length}/${points.length} dates scored'
            '${limited == 0 ? '' : ' | $limited with limited data'}',
            style: AppType.rowTitle.copyWith(color: AppColors.teal),
          ),
          const SizedBox(height: 3),
          Text(
            'Fixed 0-100 scale | tap a date to inspect its session and signals',
            style: AppType.caption,
          ),
          const SizedBox(height: 12),
          _RecoveryBars(points: points, selectedIndex: selectedIndex),
          const SizedBox(height: 10),
          Row(
            children: [
              _RecoveryLegend(color: AppColors.teal, label: 'Full inputs'),
              const SizedBox(width: 12),
              _RecoveryLegend(color: AppColors.yellow, label: 'Limited score'),
              const SizedBox(width: 12),
              _RecoveryLegend(color: AppColors.border, label: 'No score'),
            ],
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < points.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(
                      '${points[index].date.month}/${points[index].date.day} '
                      '${points[index].readiness?.estimate?.score ?? "—"}',
                    ),
                    selected: index == selectedIndex,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    selectedColor: AppColors.teal.withValues(alpha: 0.24),
                    onSelected: (_) => setState(() => _selectedIndex = index),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          _SelectedRecoveryPoint(point: selected),
          const SizedBox(height: 7),
          const Text(
            'Blank bars mean no qualifying session or missing inputs/baseline. This experimental personal trend is not a medical or training-clearance measure.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _RecoveryBars extends StatelessWidget {
  const _RecoveryBars({required this.points, required this.selectedIndex});

  final List<RecoveryHistoryPoint> points;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 98,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < points.length; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    points[index].readiness?.estimate?.score.toString() ?? '—',
                    style: AppType.caption.copyWith(
                      fontSize: 8,
                      color: index == selectedIndex
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 68,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        height: _barHeight(points[index]),
                        decoration: BoxDecoration(
                          color: _barColor(
                            points[index],
                            index == selectedIndex,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${points[index].date.day}',
                    style: AppType.caption.copyWith(
                      fontSize: 8,
                      color: index == selectedIndex
                          ? AppColors.teal
                          : AppColors.textTertiary,
                      fontWeight: index == selectedIndex
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  double _barHeight(RecoveryHistoryPoint point) {
    final score = point.readiness?.estimate?.score;
    if (score != null) return (68 * score / 100).clamp(2, 68).toDouble();
    return point.session == null ? 2 : 4;
  }

  Color _barColor(RecoveryHistoryPoint point, bool selected) {
    final estimate = point.readiness?.estimate;
    if (estimate == null) {
      return AppColors.border.withValues(alpha: selected ? 1 : 0.55);
    }
    if (point.readiness?.limitedSamples == true) {
      return AppColors.yellow.withValues(alpha: selected ? 1 : 0.62);
    }
    return AppColors.teal.withValues(alpha: selected ? 1 : 0.55);
  }
}

class _RecoveryLegend extends StatelessWidget {
  const _RecoveryLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

class _SelectedRecoveryPoint extends StatelessWidget {
  const _SelectedRecoveryPoint({required this.point});

  final RecoveryHistoryPoint point;

  @override
  Widget build(BuildContext context) {
    final session = point.session;
    if (session == null) {
      return Text(
        'Selected date: ${_formatRecoveryDate(point.date)} | no qualifying session ended on this date.',
        style: AppType.caption,
      );
    }

    final readiness = point.readiness;
    if (readiness == null) {
      return Text(
        'Session on ${_formatRecoveryDate(point.date)} | Recovery inputs unavailable.',
        style: AppType.caption,
      );
    }
    final estimate = readiness.estimate;
    return SurfaceCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESSION | ${_formatRecoveryDate(point.date)} | ${formatDurationMinutes(session.sleepMinutes)}',
            style: AppType.eyebrow.copyWith(color: AppColors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatClock(session.start)} - ${formatClock(session.end)}',
            style: AppType.caption,
          ),
          const SizedBox(height: 8),
          if (estimate == null) ...[
            const Text(
              'No Recovery score for this date',
              style: AppType.rowTitle,
            ),
            const SizedBox(height: 4),
            Text(_missingRecoveryInputs(readiness), style: AppType.caption),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recovery ${estimate.score}/100',
                    style: AppType.rowTitle.copyWith(color: AppColors.teal),
                  ),
                ),
                StatusPill(
                  label: readiness.limitedSamples
                      ? 'LIMITED DATA'
                      : 'FULL INPUTS',
                  color: readiness.limitedSamples
                      ? AppColors.yellow
                      : AppColors.teal,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Sleep ${estimate.sleepComponent} | HRV ${estimate.hrvComponent} | resting HR ${estimate.restingHrComponent}',
              style: AppType.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${readiness.hrvCurrentSampleCount} HRV samples | '
              '${readiness.restingHrCurrentSampleCount} RHR readings | '
              'baselines ${estimate.hrvBaselineDays}/14 HRV nights and '
              '${estimate.restingHrBaselineDays}/14 RHR dates',
              style: AppType.caption,
            ),
            if (readiness.limitedSamples) ...[
              const SizedBox(height: 4),
              const Text(
                'Limited data reflects sparse current readings or incomplete personal baselines.',
                style: AppType.caption,
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _missingRecoveryInputs(RecoveryReadiness readiness) {
    final reasons = <String>[];
    if (readiness.hrvCurrentSampleCount == 0) {
      reasons.add('No HRV inside asleep stages');
    }
    if (readiness.restingHrCurrentSampleCount == 0) {
      reasons.add('No resting HR on this session date');
    }
    if (readiness.hrvBaselineNights < recoveryMinimumBaselineNights) {
      reasons.add('HRV baseline ${readiness.hrvBaselineNights}/10 nights');
    }
    if (readiness.restingHrBaselineNights < recoveryMinimumBaselineNights) {
      reasons.add('RHR baseline ${readiness.restingHrBaselineNights}/10 dates');
    }
    return reasons.isEmpty
        ? 'Required inputs are incomplete.'
        : 'Missing: ${reasons.join(' | ')}.';
  }
}

String _formatRecoveryDate(DateTime date) =>
    '${formatShortDate(date)}, ${date.year}';

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
