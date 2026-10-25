import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
import '../../domain/performance.dart';
import '../../domain/strain.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _health = HealthStore.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
  }

  Future<void> _share(Performance p) async {
    setState(() => _busy = true);
    final ok = await LocalStore.instance.shareText(weeklySummaryText(p.weekly));
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Summary ready to share.' : 'Sharing is not available.',
        ),
      ),
    );
  }

  Future<void> _csv(Performance p) async {
    setState(() => _busy = true);
    final path = await LocalStore.instance.exportCsv(
      weeklyCsv(
        review: p.weekly,
        recoveryHistory: p.recoveryHistory,
        energyDays: p.energyDays,
        now: p.now,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Could not save the CSV.'
              : 'CSV saved to Downloads/Becel.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _health,
          builder: (context, _) {
            final snapshot = _health.snapshot;
            final p = snapshot?.performance;
            final failed =
                snapshot != null &&
                snapshot.error != null &&
                (snapshot.heart?.error != null ||
                    snapshot.sleep?.error != null);
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, navClearance),
                children: [
                  ScreenHeader(
                    eyebrow: p == null
                        ? 'Weekly review'
                        : 'Week of ${formatShortDate(p.weekly.start)}',
                    title: 'Trends',
                  ),
                  const SizedBox(height: 12),
                  if (snapshot == null || failed)
                    StateCard(
                      icon: failed
                          ? Icons.error_outline_rounded
                          : Icons.sync_rounded,
                      color: failed ? AppColors.red : AppColors.teal,
                      title: failed
                          ? 'History could not load'
                          : 'Reading history',
                      body:
                          _health.error ??
                          snapshot?.error ??
                          'Loading 28 days.',
                      loading: _health.loading && !failed,
                      actionLabel: failed ? 'Retry' : null,
                      onAction: () => _health.refresh(force: true),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _share(p!),
                            icon: const Icon(Icons.ios_share_rounded, size: 17),
                            label: const Text('Share'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _csv(p!),
                            icon: const Icon(Icons.download_rounded, size: 17),
                            label: const Text('CSV'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FocusCard(focus: p!.weekly.focus),
                    const SizedBox(height: 12),
                    _WeekGrid(review: p.weekly),
                    const SizedBox(height: 12),
                    _ChartsCard(performance: p),
                    const SizedBox(height: 12),
                    _PatternsCard(performance: p),
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

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.focus});

  final WeeklyFocus focus;

  @override
  Widget build(BuildContext context) => PanelCard(
    title: 'NEXT WEEK’S FOCUS',
    icon: Icons.flag_rounded,
    accent: AppColors.green,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(focus.title, style: AppType.cardTitle.copyWith(fontSize: 19)),
        const SizedBox(height: 6),
        Text(focus.body, style: AppType.body),
      ],
    ),
  );
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.review});

  final WeeklyReview review;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, String, String?, Color)>[
      (
        'RECOVERY',
        review.averageRecovery == null ? '—' : '${review.averageRecovery}%',
        '${review.recoveryDays} days scored',
        recoveryColor(review.averageRecovery),
      ),
      (
        'STRAIN',
        review.averageStrain.toStringAsFixed(1),
        review.load?.status.label,
        AppColors.strain,
      ),
      (
        'SLEEP',
        review.averageSleep == null
            ? '—'
            : formatDurationMinutes(review.averageSleep!),
        review.sleepConsistency == null
            ? null
            : '${review.sleepConsistency}% consistent',
        AppColors.sleep,
      ),
      (
        'STRENGTH',
        '${review.strengthSessions}',
        '${review.hardSets} hard sets',
        AppColors.orange,
      ),
      (
        'CALORIES',
        review.averageKcal == null ? '—' : formatNumber(review.averageKcal!),
        'avg / full day',
        AppColors.energy,
      ),
      (
        'STEPS',
        review.adjustedSteps == null
            ? '—'
            : formatNumber(review.adjustedSteps!),
        review.filteredSteps == null
            ? null
            : '${formatNumber(review.filteredSteps!)} filtered',
        AppColors.green,
      ),
    ];
    return PanelCard(
      title: 'THIS WEEK',
      icon: Icons.grid_view_rounded,
      accent: AppColors.teal,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 14,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 18, height: 3, color: tile.$4),
                      const SizedBox(height: 6),
                      StatBlock(label: tile.$1, value: tile.$2, delta: tile.$3),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChartsCard extends StatelessWidget {
  const _ChartsCard({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final history = performance.recoveryHistory;
    final strain = performance.strainDays.length <= 14
        ? performance.strainDays
        : performance.strainDays.sublist(performance.strainDays.length - 14);
    List<String> labels(List<DateTime> dates) => [
      for (var i = 0; i < dates.length; i++)
        i.isEven || i == dates.length - 1 ? formatDayShort(dates[i])[0] : '',
    ];
    return PanelCard(
      title: 'LAST 14 DAYS',
      icon: Icons.show_chart_rounded,
      accent: AppColors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartLabel('Recovery', AppColors.recovery),
          DayBars(
            values: [
              for (final h in history) h.readiness?.estimate?.score.toDouble(),
            ],
            labels: labels([for (final h in history) h.date]),
            maxValue: 100,
            height: 56,
            colorFor: (i, v) => recoveryColor(v.round()),
            semanticsLabel: 'Recovery, last 14 days',
          ),
          const SizedBox(height: 14),
          _ChartLabel('Strain', AppColors.strain),
          DayBars(
            values: [for (final d in strain) d.hasData ? d.strain : null],
            labels: labels([for (final d in strain) d.date]),
            maxValue: strainMax,
            height: 56,
            colorFor: (i, v) =>
                AppColors.strain.withValues(alpha: 0.4 + v / strainMax * 0.6),
            semanticsLabel: 'Strain, last 14 days',
          ),
          const SizedBox(height: 14),
          _ChartLabel('Sleep (h)', AppColors.sleep),
          DayBars(
            values: [for (final h in history) h.sleepMinutes?.toDouble()],
            labels: labels([for (final h in history) h.date]),
            maxValue: 600,
            height: 56,
            referenceLine: performance.sleep.baselineNeed.toDouble(),
            colorFor: (i, v) => AppColors.sleep.withValues(alpha: 0.75),
            semanticsLabel: 'Sleep, last 14 nights',
          ),
        ],
      ),
    );
  }
}

class _ChartLabel extends StatelessWidget {
  const _ChartLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: AppType.eyebrow.copyWith(color: color, fontSize: 10),
    ),
  );
}

/// Personal cause-and-effect from the user's own 14 days. Shown only when
/// both groups have at least 3 days, and framed as association.
class _PatternsCard extends StatelessWidget {
  const _PatternsCard({required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final strainByDate = {
      for (final d in performance.strainDays) _key(d.date): d,
    };
    final afterHard = <int>[];
    final afterEasy = <int>[];
    final afterShort = <int>[];
    final afterLong = <int>[];
    final need = performance.sleep.baselineNeed;
    for (final point in performance.recoveryHistory) {
      final score = point.readiness?.estimate?.score;
      if (score == null) continue;
      final prior =
          strainByDate[_key(point.date.subtract(const Duration(days: 1)))];
      if (prior != null && prior.hasData) {
        (prior.strain >= 14 ? afterHard : afterEasy).add(score);
      }
      final sleep = point.sleepMinutes;
      if (sleep != null) {
        (sleep < need - 60 ? afterShort : afterLong).add(score);
      }
    }
    final rows = <Widget>[];
    void add(
      String label,
      List<int> a,
      String aLabel,
      List<int> b,
      String bLabel,
    ) {
      if (a.length < 3 || b.length < 3) return;
      final avgA = a.reduce((x, y) => x + y) / a.length;
      final avgB = b.reduce((x, y) => x + y) / b.length;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.rowTitle),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      label: aLabel,
                      value: '${avgA.round()}%',
                      delta: '${a.length} days',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      label: bLabel,
                      value: '${avgB.round()}%',
                      delta: '${b.length} days',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      label: 'DIFFERENCE',
                      value:
                          '${(avgA - avgB) >= 0 ? '+' : ''}${(avgA - avgB).round()}',
                      deltaColor: AppColors.textSecondary,
                      delta: 'points',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    add(
      'Recovery after hard days',
      afterHard,
      'STRAIN ≥ 14',
      afterEasy,
      'EASIER',
    );
    add(
      'Recovery after short sleep',
      afterShort,
      'SHORT NIGHT',
      afterLong,
      'FULL NIGHT',
    );
    return PanelCard(
      title: 'YOUR PATTERNS',
      icon: Icons.auto_graph_rounded,
      accent: AppColors.violet,
      child: rows.isEmpty
          ? const Text(
              'Patterns appear once you have at least 3 days on each side of a '
              'comparison (for example, after hard and after easy days).',
              style: AppType.note,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...rows,
                Text(
                  'Next-morning recovery averages from your last 14 days. '
                  'Associations, not proof of cause.',
                  style: AppType.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
    );
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
