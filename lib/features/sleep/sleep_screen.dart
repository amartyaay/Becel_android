import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../domain/coaching.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final _health = HealthStore.instance;

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
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
            final sleep = snapshot?.sleep;
            final night = snapshot?.selectedNight;
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  ScreenHeader(
                    eyebrow: 'REST & REPAIR',
                    title: 'Sleep',
                    trailing: StatusPill(
                      label: night == null
                          ? 'NO SESSION'
                          : formatDurationMinutes(night.minutes),
                      color: night == null ? AppColors.yellow : AppColors.blue,
                      icon: Icons.nightlight_round,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Asleep time, consistency, and stage context — not a sleep '
                    'score.',
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
                  else ...[
                    if (!snapshot.hasAccess)
                      StateCard(
                        icon: Icons.link_rounded,
                        color: AppColors.yellow,
                        title: 'Connect your health data',
                        body:
                            'Allow Fitbit Air sleep records in Health Connect '
                            'to see duration, timing, and stages.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
                      )
                    else if (sleep != null && !sleep.canReadSleep)
                      StateCard(
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.yellow,
                        title: 'Sleep access is off',
                        body:
                            'Enable sleep access in Health Connect to see '
                            'sessions and stages.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
                      )
                    else if (night == null && sleep?.error != null)
                      StateCard(
                        icon: Icons.error_outline_rounded,
                        color: AppColors.red,
                        title: 'Sleep could not load',
                        body: sleep!.error!,
                        actionLabel: 'Retry',
                        onAction: () => _health.refresh(force: true),
                      )
                    else if (night == null)
                      StateCard(
                        icon: Icons.bedtime_off_rounded,
                        color: AppColors.blue,
                        title: 'Sleep has not synced yet',
                        body:
                            snapshot.error ??
                            'When Fitbit Air sleep records arrive through '
                                'Health Connect, Becel will show duration and '
                                'stages here.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
                      )
                    else ...[
                      _LastNightCard(night: night),
                      const SizedBox(height: 14),
                      _PatternCard(
                        trend: snapshot.sleepTrend,
                        sessions: sleep?.sessions ?? const <SleepNight>[],
                        now: snapshot.loadedAt,
                      ),
                      const SizedBox(height: 14),
                      const InfoNote(
                        text:
                            'Recovery uses the longest synced session of at '
                            'least 3 hours ending in the past 24 hours. A long '
                            'nap can be selected; check the session times.',
                        icon: Icons.schedule_rounded,
                        color: AppColors.blue,
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(
                        title: 'Sessions',
                        caption: 'LAST 14 DAYS',
                      ),
                      const SizedBox(height: 10),
                      for (final session
                          in sleep?.sessionsEndingWithin(
                                const Duration(days: 14),
                                endingAt: snapshot.loadedAt,
                              ) ??
                              const <SleepNight>[])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SessionRow(
                            night: session,
                            now: snapshot.loadedAt,
                          ),
                        ),
                      if (sleep?.error != null) ...[
                        const SizedBox(height: 8),
                        InfoNote(
                          text:
                              'Some sleep data could not load: '
                              '${sleep!.error}',
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
                      const SizedBox(height: 8),
                      SourceLine(
                        text:
                            'Fitbit Air via Health Connect · refreshed '
                            '${formatAgo(snapshot.loadedAt)}',
                        icon: Icons.sync_rounded,
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  const TrustFooter(
                    text:
                        'SLEEP STAGES ARE CONTEXT, NOT A DIAGNOSIS · NO HEALTH '
                        'DATA IS UPLOADED',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
        title: 'Reading sleep data',
        body: 'Loading last night’s session and recent nights.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (error != null) {
      return StateCard(
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        title: 'Sleep data could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return StateCard(
      icon: Icons.link_rounded,
      color: AppColors.yellow,
      title: 'Set up Health Connect',
      body: 'Becel reads Fitbit Air sleep records from Health Connect.',
      actionLabel: 'Open data sources',
      onAction: onData,
    );
  }
}

class _LastNightCard extends StatelessWidget {
  const _LastNightCard({required this.night});

  final SleepNight night;

  @override
  Widget build(BuildContext context) {
    final inBed = night.end.difference(night.start).inMinutes;
    final efficiency = inBed <= 0
        ? null
        : ((night.minutes / inBed) * 100).round().clamp(0, 100);
    final rangeLabel = night.minutes < 420
        ? 'Below the 7–9h adult range'
        : night.minutes > 540
        ? 'Above the 7–9h adult range'
        : 'Inside the 7–9h adult range';
    final shortRangeLabel = night.minutes < 420
        ? 'BELOW 7–9H'
        : night.minutes > 540
        ? 'ABOVE 7–9H'
        : '7–9H RANGE';
    final rangeColor = night.minutes < 420
        ? AppColors.yellow
        : night.minutes > 540
        ? AppColors.blue
        : AppColors.green;
    return SurfaceCard(
      color: const Color(0xFF141B24),
      borderColor: AppColors.blue.withValues(alpha: 0.22),
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                size: 16,
                color: AppColors.blue,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'LAST NIGHT',
                  style: AppType.eyebrow.copyWith(color: AppColors.blue),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: shortRangeLabel, color: rangeColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatDurationMinutes(night.minutes),
                style: AppType.numXl.copyWith(fontSize: 46),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 5, bottom: 7),
                child: Text('ASLEEP', style: AppType.unit),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDurationMinutes(inBed)} in bed'
            '${efficiency == null ? '' : ' · $efficiency% asleep'}',
            style: AppType.rowTitle.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatClock(night.start)} – ${formatClock(night.end)}',
            style: AppType.caption,
          ),
          const SizedBox(height: 14),
          RangeGauge(
            value: night.minutes,
            low: 420,
            high: 540,
            min: 0,
            max: 720,
            color: AppColors.blue,
            minLabel: '0h',
            maxLabel: '12h',
            bandLabel: '7–9h adult range',
            semanticsLabel:
                '${formatDurationMinutes(night.minutes)} asleep. '
                '${formatDurationMinutes(inBed)} in bed. $rangeLabel.',
          ),
          const SizedBox(height: 10),
          Text(
            'The 7–9h band is a population reference, not a personal target. '
            'One night is not a verdict.',
            style: AppType.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          const Text('STAGES', style: AppType.eyebrow),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Awake ${formatDurationMinutes(night.awakeMinutes)}. '
                'Light ${formatDurationMinutes(night.lightMinutes)}. '
                'Deep ${formatDurationMinutes(night.deepMinutes)}. '
                'REM ${formatDurationMinutes(night.remMinutes)}.',
            child: ExcludeSemantics(
              child: StageBar(
                showLabels: false,
                segments: [
                  ChartSegment(
                    label: 'Awake',
                    minutes: night.awakeMinutes,
                    color: AppColors.yellow,
                  ),
                  ChartSegment(
                    label: 'Light',
                    minutes: night.lightMinutes,
                    color: AppColors.blue,
                  ),
                  ChartSegment(
                    label: 'Deep',
                    minutes: night.deepMinutes,
                    color: AppColors.violet,
                  ),
                  ChartSegment(
                    label: 'REM',
                    minutes: night.remMinutes,
                    color: AppColors.teal,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _StageLabel(
                color: AppColors.yellow,
                label: 'Awake',
                minutes: night.awakeMinutes,
              ),
              _StageLabel(
                color: AppColors.blue,
                label: 'Light',
                minutes: night.lightMinutes,
              ),
              _StageLabel(
                color: AppColors.violet,
                label: 'Deep',
                minutes: night.deepMinutes,
              ),
              _StageLabel(
                color: AppColors.teal,
                label: 'REM',
                minutes: night.remMinutes,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Stages are shown for context. Becel does not grade them.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.color,
    required this.label,
    required this.minutes,
  });

  final Color color;
  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        '$label ${formatDurationMinutes(minutes)}',
        style: AppType.caption.copyWith(fontSize: 11),
      ),
    ],
  );
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
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
        icon: Icons.nights_stay_outlined,
        color: AppColors.blue,
        title: 'Building a 7-night pattern',
        body:
            'Sessions of at least 3 hours count. A few more nights will '
            'show your average, timing, and bedtime spread.',
      );
    }
    final cutoff = now.subtract(const Duration(days: 7));
    final recent =
        sessions
            .where(
              (night) =>
                  night.minutes >= 180 &&
                  !night.end.isBefore(cutoff) &&
                  !night.end.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.end.compareTo(b.end));
    final delta = trend.sleepDeltaMinutes;
    final deltaText = delta == null
        ? 'No prior week to compare yet'
        : delta == 0
        ? 'Same as the prior week'
        : '${delta > 0 ? '+' : '−'}${formatDurationMinutes(delta.abs())} vs '
              'the prior week';
    final spread = trend.bedtimeSpreadMinutes;
    final regularity = spread == null
        ? 'Not enough nights'
        : spread <= 30
        ? 'Steady'
        : spread <= 60
        ? 'Fairly steady'
        : 'Variable';
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 16,
                color: AppColors.blue,
              ),
              const SizedBox(width: 7),
              Text(
                '7-NIGHT PATTERN',
                style: AppType.eyebrow.copyWith(color: AppColors.blue),
              ),
              const Spacer(),
              Text('${trend.nights} nights', style: AppType.caption),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PatternStat(
                  label: 'AVG ASLEEP',
                  value: formatDurationMinutes(trend.averageMinutes!),
                  note: deltaText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PatternStat(
                  label: 'AVG IN BED',
                  value: trend.averageInBedMinutes == null
                      ? '—'
                      : formatDurationMinutes(trend.averageInBedMinutes!),
                  note: trend.isWithinAdultRange
                      ? 'Inside 7–9h'
                      : trend.isShort
                      ? 'Below 7h'
                      : 'Above 9h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PatternStat(
                  label: 'BEDTIME SPREAD',
                  value: spread == null ? '—' : formatDurationMinutes(spread),
                  note: regularity,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PatternStat(
                  label: 'AVG BEDTIME',
                  value: trend.averageBedtimeMinutes == null
                      ? '—'
                      : _clockFromMinutes(trend.averageBedtimeMinutes!),
                  note: 'Local time',
                ),
              ),
            ],
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Recent nights: ${recent.map((night) => '${formatDayShort(night.end)} ${formatDurationMinutes(night.minutes)}').join(', ')}.',
              child: ExcludeSemantics(
                child: TrendBars(
                  values: recent
                      .map((night) => night.minutes.toDouble())
                      .toList(),
                  labels: recent
                      .map((night) => formatDayShort(night.end))
                      .toList(),
                  color: AppColors.blue,
                  valueLabelBuilder: (value) =>
                      formatDurationMinutes(value.round()),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Regular timing is a behaviour you can control. Becel shows stages '
            'for context but does not grade them.',
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _PatternStat extends StatelessWidget {
  const _PatternStat({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppType.eyebrow.copyWith(fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: AppType.numM.copyWith(fontSize: 20)),
      const SizedBox(height: 2),
      Text(
        note,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption.copyWith(fontSize: 10.5),
      ),
    ],
  );
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.night, required this.now});

  final SleepNight night;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final inBed = night.end.difference(night.start).inMinutes;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconChip(
            icon: Icons.bedtime_rounded,
            color: AppColors.blue,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dayLabel(night.end, now), style: AppType.rowTitle),
                const SizedBox(height: 2),
                Text(
                  '${formatClock(night.start)} – ${formatClock(night.end)} · '
                  '${formatDurationMinutes(inBed)} in bed',
                  style: AppType.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  'Deep ${formatDurationMinutes(night.deepMinutes)} · '
                  'REM ${formatDurationMinutes(night.remMinutes)}',
                  style: AppType.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatDurationMinutes(night.minutes), style: AppType.numS),
        ],
      ),
    );
  }

  String _dayLabel(DateTime end, DateTime now) {
    final local = end.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return formatShortDate(local);
  }
}

String _clockFromMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}
