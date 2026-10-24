import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  final _health = HealthConnectService.instance;
  SleepDetail? _sleep;
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
    final sleep = await _health.readSleepDetail();
    if (!mounted) return;
    setState(() {
      _sleep = sleep;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sleep = _sleep;
    final currentSession = sleep?.selectedRecentSession;
    final selectedSession =
        currentSession ??
        (sleep?.sessions.isNotEmpty == true ? sleep!.sessions.first : null);
    final durationProgress = currentSession == null
        ? null
        : sleepDurationProgressPercent(minutes: currentSession.minutes);
    final recent = sleep?.sessions.take(7).toList() ?? const <SleepNight>[];
    final chronological = recent.reversed.toList();

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
                eyebrow: 'REST & REPAIR',
                title: 'Sleep',
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
                        label: selectedSession == null
                            ? 'NO SESSION'
                            : durationProgress == null
                            ? 'OLDER SESSION'
                            : formatDurationMinutes(selectedSession.minutes),
                        color: selectedSession == null
                            ? AppColors.yellow
                            : durationProgress == null
                            ? AppColors.textSecondary
                            : AppColors.blue,
                        icon: Icons.nightlight_round,
                      ),
              ),
              const SizedBox(height: 16),
              if (sleep?.error != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoNote(
                      text: 'Could not read Health Connect: ${sleep!.error}',
                      textColor: AppColors.red,
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else if (sleep != null && !sleep.canReadSleep)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InfoNote(
                      text:
                          'Sleep access is off. Enable it in Data sources to see sessions and stages.',
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.yellow,
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/data'),
                      icon: const Icon(Icons.sensors_rounded),
                      label: const Text('Open data sources'),
                    ),
                  ],
                )
              else if (selectedSession == null)
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sleep has not synced yet',
                        style: AppType.rowTitle,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'When Fitbit Air sleep records arrive through Health Connect, Becel will show duration and stages here.',
                        style: AppType.note,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => context.go('/data'),
                        icon: const Icon(Icons.sensors_rounded),
                        label: const Text('Review data sources'),
                      ),
                    ],
                  ),
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
                            selectedSession.minutes < 60
                                ? '${selectedSession.minutes}m'
                                : formatDurationMinutes(
                                    selectedSession.minutes,
                                  ),
                            style: AppType.numXl,
                          ),
                          const Spacer(),
                          if (durationProgress != null)
                            StatusPill(
                              label: '$durationProgress% OF 7H REFERENCE',
                              color: AppColors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selected session · ${formatClock(selectedSession.start)} '
                        '– ${formatClock(selectedSession.end)}',
                        style: AppType.caption,
                      ),
                      if (durationProgress == null) ...[
                        const SizedBox(height: 5),
                        const Text(
                          'No qualifying session ended in the last 24 hours. Showing the latest record; it is not used for today’s Recovery.',
                          style: AppType.caption,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Duration progress · $durationProgress% of the 7-hour adult reference',
                          style: AppType.caption.copyWith(
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: durationProgress / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceHigher,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.blue,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      StageBar(
                        segments: [
                          ChartSegment(
                            label: 'Awake',
                            minutes: selectedSession.awakeMinutes,
                            color: AppColors.yellow,
                          ),
                          ChartSegment(
                            label: 'Light',
                            minutes: selectedSession.lightMinutes,
                            color: AppColors.blue,
                          ),
                          ChartSegment(
                            label: 'Deep',
                            minutes: selectedSession.deepMinutes,
                            color: AppColors.violet,
                          ),
                          ChartSegment(
                            label: 'REM',
                            minutes: selectedSession.remMinutes,
                            color: AppColors.teal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const InfoNote(
                  text:
                      'Recovery uses the longest synced session of at least 3 hours ending in the past 24 hours. A long nap can be selected; check the session times above.',
                  icon: Icons.schedule_rounded,
                  color: AppColors.blue,
                ),
                const SizedBox(height: 10),
                const InfoNote(
                  text: sleepDurationMethod,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.blue,
                ),
                const SizedBox(height: 18),
                if (recent.length >= 2) ...[
                  SectionHeader(
                    title: 'Recent sessions',
                    caption: 'SESSION LENGTH',
                  ),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    child: TrendBars(
                      values: chronological
                          .map((night) => night.minutes.toDouble())
                          .toList(),
                      labels: chronological
                          .map((night) => formatDayShort(night.end))
                          .toList(),
                      color: AppColors.blue,
                      valueLabelBuilder: (value) =>
                          formatDurationMinutes(value.round()),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                SectionHeader(title: 'Sessions', caption: 'LAST 14 DAYS'),
                const SizedBox(height: 10),
                for (final night in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const IconChip(
                            icon: Icons.bedtime_rounded,
                            color: AppColors.blue,
                            size: 34,
                            iconSize: 17,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dayLabel(night.end),
                                  style: AppType.rowTitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatClock(night.start)} \u2013 '
                                  '${formatClock(night.end)} \u00b7 deep '
                                  '${formatDurationMinutes(night.deepMinutes)}',
                                  style: AppType.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatDurationMinutes(night.minutes),
                            style: AppType.numS,
                          ),
                        ],
                      ),
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

  String _dayLabel(DateTime end) {
    final local = end.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return formatDayShort(local);
  }
}
