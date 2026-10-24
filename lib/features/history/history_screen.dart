import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
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
  final _health = HealthStore.instance;
  final _local = LocalStore.instance;
  late final Listenable _listenable = Listenable.merge([_health, _local]);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
    _local.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _listenable,
          builder: (context, _) {
            final snapshot = _health.snapshot;
            final checkIn = _local.log.checkInFor(DateTime.now());
            final review = snapshot?.weeklyReview(
              loggedStrengthDays: _local.log.strengthDates,
              checkInTags: checkIn?.tags ?? const <String>{},
            );
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  const ScreenHeader(
                    eyebrow: 'WEEKLY REVIEW',
                    title: 'History',
                    trailing: StatusPill(
                      label: '7 DAYS',
                      color: AppColors.violet,
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'One week at a glance: what changed, what stayed steady, '
                    'and one thing to try next.',
                    style: AppType.body,
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    _InitialState(
                      loading: _health.loading,
                      error: _health.error,
                      onRetry: () => _health.refresh(force: true),
                      onData: () => context.go('/data'),
                    )
                  else if (!snapshot.hasAccess)
                    StateCard(
                      icon: Icons.link_rounded,
                      color: AppColors.yellow,
                      title: 'Connect your health data',
                      body: 'Allow Fitbit Air records in Health Connect to '
                          'build a weekly review.',
                      actionLabel: 'Open data sources',
                      onAction: () => context.go('/data'),
                    )
                  else if (snapshot.error != null &&
                      !snapshot.hasAnyRecord)
                    StateCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      title: 'History could not load',
                      body: snapshot.error!,
                      actionLabel: 'Retry',
                      onAction: () => _health.refresh(force: true),
                    )
                  else if (review == null || !snapshot.hasAnyRecord)
                    StateCard(
                      icon: Icons.query_stats_rounded,
                      color: AppColors.yellow,
                      title: 'No week to review yet',
                      body: snapshot.error ??
                          'Records will appear after Fitbit Air shares them '
                              'with Health Connect. Becel needs at least one '
                              'night or activity day to review.',
                      actionLabel: 'Open data sources',
                      onAction: () => context.go('/data'),
                    )
                  else ...[
                    _WeekCard(
                      review: review,
                      now: snapshot.loadedAt,
                      busy: _busy,
                      onShare: () => _share(review, snapshot),
                      onExport: () => _export(review, snapshot),
                    ),
                    const SizedBox(height: 22),
                    const SectionHeader(
                      title: 'Sleep',
                      caption: 'LAST 7 NIGHTS',
                    ),
                    const SizedBox(height: 10),
                    _SleepWeekCard(
                      trend: review.sleep,
                      sessions: snapshot.sleep?.sessions ?? const [],
                      now: snapshot.loadedAt,
                    ),
                    const SizedBox(height: 22),
                    const SectionHeader(
                      title: 'Activity',
                      caption: 'AEROBIC + STRENGTH',
                    ),
                    const SizedBox(height: 10),
                    _ActivityWeekCard(review: review),
                    const SizedBox(height: 22),
                    const SectionHeader(
                      title: 'Recovery',
                      caption: '14 MORNINGS',
                    ),
                    const SizedBox(height: 10),
                    _RecoveryTrend(points: snapshot.recoveryHistory),
                    const SizedBox(height: 22),
                    const SectionHeader(
                      title: 'Measured trends',
                      caption: 'FITBIT AIR',
                    ),
                    const SizedBox(height: 10),
                    _MetricTrendCard(
                      title: 'Steps',
                      icon: Icons.directions_walk_rounded,
                      color: AppColors.green,
                      values: (snapshot.trends?.steps ?? const [])
                          .map((value) => value?.toDouble())
                          .toList(),
                      labels: (snapshot.trends?.dates ?? const [])
                          .map(formatDayLabel)
                          .toList(),
                      summary: _stepsSummary(snapshot),
                      valueLabelBuilder: (value) =>
                          '${(value / 1000).toStringAsFixed(1)}k',
                    ),
                    const SizedBox(height: 12),
                    _MetricTrendCard(
                      title: 'Heart rate · daily average',
                      icon: Icons.favorite_rounded,
                      color: AppColors.red,
                      values: (snapshot.trends?.hrAvg ?? const [])
                          .map((value) => value?.toDouble())
                          .toList(),
                      labels: (snapshot.trends?.dates ?? const [])
                          .map(formatDayLabel)
                          .toList(),
                      summary: _heartSummary(snapshot),
                      valueLabelBuilder: (value) => '${value.round()}',
                    ),
                    if (snapshot.error != null) ...[
                      const SizedBox(height: 14),
                      InfoNote(
                        text: 'Some history could not load: ${snapshot.error}',
                        textColor: AppColors.yellow,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _health.refresh(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SourceLine(
                      text:
                          'Fitbit Air via Health Connect · refreshed '
                          '${formatAgo(snapshot.loadedAt)}',
                      icon: Icons.sync_rounded,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const TrustFooter(
                    text:
                        'WELLNESS CONTEXT ONLY · NOT A DIAGNOSIS OR TRAINING '
                        'CLEARANCE',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _share(WeeklyReview review, HealthSnapshot snapshot) async {
    setState(() => _busy = true);
    final shared = await _local.shareText(
      weeklySummaryText(review: review, now: snapshot.loadedAt),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shared
              ? 'Summary ready to share.'
              : 'Sharing is not available on this device.',
        ),
      ),
    );
  }

  Future<void> _export(WeeklyReview review, HealthSnapshot snapshot) async {
    setState(() => _busy = true);
    final path = await _local.exportCsv(
      weeklyCsv(review: review, now: snapshot.loadedAt),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Could not save the CSV.'
              : 'Weekly CSV saved to Downloads/Becel.',
        ),
      ),
    );
  }

  String _stepsSummary(HealthSnapshot snapshot) {
    final values = (snapshot.trends?.steps ?? const []).whereType<int>().toList();
    if (values.isEmpty) return 'No step records this week';
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return '${_formatNumber(total)} steps total · '
        '${_formatNumber((total / values.length).round())}/day average';
  }

  String _heartSummary(HealthSnapshot snapshot) {
    final values = (snapshot.trends?.hrAvg ?? const []).whereType<int>().toList();
    if (values.isEmpty) return 'No heart-rate records this week';
    final average = (values.reduce((a, b) => a + b) / values.length).round();
    return 'Daily average $average bpm across ${values.length} day'
        '${values.length == 1 ? '' : 's'}';
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onData,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const StateCard(
        title: 'Building your week',
        body: 'Reading sleep, activity, and recovery history.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (error != null) {
      return StateCard(
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        title: 'History could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return StateCard(
      icon: Icons.link_rounded,
      color: AppColors.yellow,
      title: 'Set up Health Connect',
      body: 'Becel reads Fitbit Air records from Health Connect.',
      actionLabel: 'Open data sources',
      onAction: onData,
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.review,
    required this.now,
    required this.busy,
    required this.onShare,
    required this.onExport,
  });

  final WeeklyReview review;
  final DateTime now;
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final start = now.subtract(const Duration(days: 6));
    return SurfaceCard(
      color: const Color(0xFF1B1824),
      borderColor: AppColors.violet.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: AppColors.violet,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'WEEK OF ${formatShortDate(start).toUpperCase()}',
                  style: AppType.eyebrow.copyWith(color: AppColors.violet),
                ),
              ),
              const StatusPill(label: 'REVIEW', color: AppColors.violet),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.focus.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(review.focus.body, style: AppType.body),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _WeekStat(
                  label: 'SLEEP AVG',
                  value: review.sleep.averageMinutes == null
                      ? '—'
                      : formatDurationMinutes(review.sleep.averageMinutes!),
                  note: _sleepNote(review.sleep),
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekStat(
                  label: 'AEROBIC',
                  value: review.aerobicMinutes == null
                      ? '—'
                      : '≈${review.aerobicMinutes} min',
                  note: review.aerobicPotentialMinutes == null
                      ? 'No HR estimate'
                      : 'up to ${review.aerobicPotentialMinutes} min',
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WeekStat(
                  label: 'STRENGTH',
                  value: '${review.strengthDays} / 2',
                  note: review.strengthDays >= 2
                      ? 'Target met'
                      : 'Days logged',
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekStat(
                  label: 'RECOVERY',
                  value: '${review.recoveryMornings}',
                  note: 'Mornings scored',
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onShare,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.violet,
                      side: BorderSide(
                        color: AppColors.violet.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 17),
                    label: const Text('Share'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onExport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('CSV'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sleepNote(SleepTrend trend) {
    final delta = trend.sleepDeltaMinutes;
    if (delta == null) return 'No prior week';
    if (delta == 0) return 'Same as prior week';
    return '${delta > 0 ? '+' : '−'}${formatDurationMinutes(delta.abs())} vs '
        'prior week';
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.eyebrow.copyWith(color: color, fontSize: 9.5),
        ),
        const SizedBox(height: 4),
        Text(value, style: AppType.numM.copyWith(fontSize: 19)),
        const SizedBox(height: 2),
        Text(
          note,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(fontSize: 10),
        ),
      ],
    ),
  );
}

class _SleepWeekCard extends StatelessWidget {
  const _SleepWeekCard({
    required this.trend,
    required this.sessions,
    required this.now,
  });

  final SleepTrend trend;
  final List<SleepNight> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (!trend.hasData) {
      return const StateCard(
        icon: Icons.bedtime_off_rounded,
        color: AppColors.blue,
        title: 'No qualifying sleep this week',
        body: 'Sessions of at least 3 hours appear here. Naps are excluded '
            'from the weekly average.',
      );
    }
    final cutoff = now.subtract(const Duration(days: 7));
    final recent = sessions
        .where(
          (night) =>
              night.minutes >= 180 &&
              !night.end.isBefore(cutoff) &&
              !night.end.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.end.compareTo(b.end));
    final spread = trend.bedtimeSpreadMinutes;
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.bedtime_rounded,
                color: AppColors.blue,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${trend.nights} nights · '
                  '${formatDurationMinutes(trend.averageMinutes!)} average',
                  style: AppType.rowTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${trend.isWithinAdultRange ? 'Inside' : trend.isShort ? 'Below' : 'Above'} '
            'the 7–9h adult range. '
            '${spread == null ? 'Not enough nights for bedtime spread.' : 'Bedtime varied by ${formatDurationMinutes(spread)}.'}',
            style: AppType.caption,
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Sleep by night: ${recent.map((night) => '${formatDayShort(night.end)} ${formatDurationMinutes(night.minutes)}').join(', ')}.',
              child: ExcludeSemantics(
                child: TrendBars(
                  values: recent.map((night) => night.minutes.toDouble()).toList(),
                  labels: recent.map((night) => formatDayShort(night.end)).toList(),
                  color: AppColors.blue,
                  valueLabelBuilder: (value) =>
                      formatDurationMinutes(value.round()),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Sleep sets the overnight window for recovery but is not scored '
            'inside the recovery index.',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActivityWeekCard extends StatelessWidget {
  const _ActivityWeekCard({required this.review});

  final WeeklyReview review;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconChip(
              icon: Icons.bolt_rounded,
              color: AppColors.orange,
              size: 36,
              iconSize: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                review.aerobicMinutes == null
                    ? 'No aerobic estimate'
                    : '≈${review.aerobicMinutes} min observed',
                style: AppType.rowTitle,
              ),
            ),
            if (review.aerobicPotentialMinutes != null)
              Text(
                'up to ${review.aerobicPotentialMinutes}',
                style: AppType.caption.copyWith(color: AppColors.orange),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          review.aerobicMinutes == null
              ? 'Heart-rate coverage was not sufficient for an estimate. '
                    'Strength days are still counted below.'
              : 'This is a lower bound from heart rate. '
                    '${review.aerobicMinutes! < activityAerobicReferenceMinutes ? '${activityAerobicReferenceMinutes - review.aerobicMinutes!} min below the $activityAerobicReferenceMinutes-min guideline floor.' : 'Above the $activityAerobicReferenceMinutes-min guideline floor.'}',
          style: AppType.caption,
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Icon(
              Icons.fitness_center_rounded,
              size: 16,
              color: AppColors.violet,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Strength · ${review.strengthDays} of 2 days',
                style: AppType.rowTitle.copyWith(fontSize: 14),
              ),
            ),
            Text(
              review.strengthDays >= 2 ? 'Target met' : 'Add ${2 - review.strengthDays}',
              style: AppType.caption.copyWith(color: AppColors.violet),
            ),
          ],
        ),
        if (review.stepsTotal != null) ...[
          const Divider(height: 20),
          Row(
            children: [
              const Icon(
                Icons.directions_walk_rounded,
                size: 16,
                color: AppColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatNumber(review.stepsTotal!)} steps this week',
                  style: AppType.rowTitle.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
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
    if (points.isEmpty) {
      return const StateCard(
        icon: Icons.battery_charging_full_rounded,
        color: AppColors.teal,
        title: 'Recovery history is building',
        body: 'A few mornings of HRV and resting heart rate are needed before '
            'date-specific scores appear.',
      );
    }
    final selectedIndex = _selectedIndex ?? _defaultSelection(points);
    final selected = points[selectedIndex];
    final scored = points
        .where((point) => point.readiness?.estimate != null)
        .toList();
    final limited = scored
        .where((point) => point.readiness?.limitedSamples == true)
        .length;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
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
              const Expanded(
                child: Text('Personal recovery range', style: AppType.cardTitle),
              ),
              const StatusPill(label: 'EXPERIMENTAL', color: AppColors.teal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${scored.length}/${points.length} dates scored'
            '${limited == 0 ? '' : ' · $limited with limited inputs'}',
            style: AppType.rowTitle.copyWith(color: AppColors.teal),
          ),
          const SizedBox(height: 3),
          const Text(
            'Overnight HRV and resting HR only. Sleep sets the window and is '
            'shown as context, not scored. Bars follow dates left to right.',
            style: AppType.caption,
          ),
          const SizedBox(height: 12),
          _RecoveryBars(points: points, selectedIndex: selectedIndex),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _RecoveryLegend(label: 'Full inputs', width: 10),
              _RecoveryLegend(label: 'Limited inputs *', width: 6),
              _RecoveryLegend(label: 'No score', width: 3),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var index = 0; index < points.length; index++)
                ChoiceChip(
                  label: Text(
                    '${points[index].date.month}/${points[index].date.day} · '
                    '${points[index].readiness?.estimate?.score ?? "—"}'
                    '${points[index].readiness?.limitedSamples == true ? " *" : ""}',
                  ),
                  selected: index == selectedIndex,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: AppColors.teal.withValues(alpha: 0.24),
                  onSelected: (_) => setState(() => _selectedIndex = index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _SelectedRecoveryPoint(point: selected),
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
    height: 72,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < points.length; index++)
          Expanded(
            child: Semantics(
              label: _semantics(points[index]),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: _widthFactor(points[index]),
                      child: Container(
                        key: ValueKey(
                          index == selectedIndex
                              ? 'recovery-selected-bar'
                              : 'recovery-bar-$index',
                        ),
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
                ),
              ),
            ),
          ),
      ],
    ),
  );

  double _barHeight(RecoveryHistoryPoint point) {
    final score = point.readiness?.estimate?.score;
    if (score != null) return (60 * score / 100).clamp(2, 60).toDouble();
    return point.session == null ? 2 : 4;
  }

  double _widthFactor(RecoveryHistoryPoint point) {
    if (point.readiness?.estimate == null) return 0.28;
    return point.readiness?.limitedSamples == true ? 0.58 : 1;
  }

  Color _barColor(RecoveryHistoryPoint point, bool selected) {
    if (point.readiness?.estimate == null) {
      return AppColors.border.withValues(alpha: selected ? 1 : 0.55);
    }
    if (point.readiness?.limitedSamples == true) {
      return AppColors.yellow.withValues(alpha: selected ? 1 : 0.62);
    }
    return AppColors.teal.withValues(alpha: selected ? 1 : 0.55);
  }

  String _semantics(RecoveryHistoryPoint point) {
    final score = point.readiness?.estimate?.score;
    if (score == null) {
      return '${formatShortDate(point.date)}, no recovery score';
    }
    final limited = point.readiness?.limitedSamples == true
        ? ', limited inputs'
        : ', full inputs';
    return '${formatShortDate(point.date)}, recovery $score out of 100$limited';
  }
}

class _RecoveryLegend extends StatelessWidget {
  const _RecoveryLegend({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: AppType.caption.copyWith(fontSize: 11)),
    ],
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
        'Selected ${formatShortDate(point.date)}: no qualifying session ended '
        'on this date.',
        style: AppType.caption,
      );
    }

    final readiness = point.readiness;
    if (readiness == null) {
      return Text(
        'Session on ${formatShortDate(point.date)}: recovery inputs '
        'unavailable.',
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
            '${formatShortDate(point.date)} · '
            '${formatDurationMinutes(session.sleepMinutes)} asleep',
            style: AppType.eyebrow.copyWith(color: AppColors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatClock(session.start)} – ${formatClock(session.end)}',
            style: AppType.caption,
          ),
          const SizedBox(height: 8),
          if (estimate == null) ...[
            const Text(
              'No recovery score for this date',
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
                  label: readiness.limitedSamples ? 'LIMITED' : 'FULL INPUTS',
                  color: readiness.limitedSamples
                      ? AppColors.yellow
                      : AppColors.teal,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'HRV ${estimate.hrvComponent} · resting HR '
              '${estimate.restingHrComponent} · sleep context '
              '${estimate.sleepComponent} (not scored)',
              style: AppType.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${readiness.hrvCurrentSampleCount} HRV samples · '
              '${readiness.restingHrCurrentSampleCount} resting HR readings · '
              'baselines ${estimate.hrvBaselineDays}/14 and '
              '${estimate.restingHrBaselineDays}/14',
              style: AppType.caption,
            ),
            if (readiness.limitedSamples) ...[
              const SizedBox(height: 4),
              const Text(
                'Limited means sparse current readings or an incomplete '
                'personal baseline.',
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
      reasons.add('no HRV inside asleep stages');
    }
    if (readiness.restingHrCurrentSampleCount == 0) {
      reasons.add('no resting HR on this date');
    }
    if (readiness.hrvBaselineNights < recoveryMinimumBaselineNights) {
      reasons.add(
        'HRV baseline ${readiness.hrvBaselineNights}/'
        '$recoveryMinimumBaselineNights nights',
      );
    }
    if (readiness.restingHrBaselineNights < recoveryMinimumBaselineNights) {
      reasons.add(
        'resting HR baseline ${readiness.restingHrBaselineNights}/'
        '$recoveryMinimumBaselineNights dates',
      );
    }
    return reasons.isEmpty
        ? 'Required inputs are incomplete.'
        : 'Missing: ${reasons.join(', ')}.';
  }
}

class _MetricTrendCard extends StatelessWidget {
  const _MetricTrendCard({
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: icon, color: color, size: 32, iconSize: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppType.cardTitle)),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData)
            const Text(
              'No records in the last 7 days.',
              style: AppType.caption,
            )
          else
            Semantics(
              label:
                  '$title: ${[
                    for (var index = 0; index < values.length; index++)
                      if (values[index] != null)
                        '${index < labels.length ? labels[index] : 'day ${index + 1}'} ${valueLabelBuilder?.call(values[index]!) ?? values[index]!.round()}',
                  ].join(', ')}.',
              child: ExcludeSemantics(
                child: TrendBars(
                  values: values,
                  labels: labels,
                  color: color,
                  valueLabelBuilder: valueLabelBuilder,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(summary, style: AppType.caption),
        ],
      ),
    );
  }
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
