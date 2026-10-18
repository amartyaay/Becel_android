import 'package:flutter/material.dart';

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
    final lastNight = sleep?.lastNight;
    final score = lastNight == null
        ? null
        : sleepScoreEstimate(
            minutes: lastNight.minutes,
            deepMinutes: lastNight.deepMinutes,
            remMinutes: lastNight.remMinutes,
          );
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
                        label: lastNight == null
                            ? 'NO SESSION'
                            : formatDurationMinutes(lastNight.minutes),
                        color: lastNight == null
                            ? AppColors.yellow
                            : AppColors.blue,
                        icon: Icons.nightlight_round,
                      ),
              ),
              const SizedBox(height: 16),
              if (sleep?.error != null)
                InfoNote(text: sleep!.error!)
              else if (sleep != null && !sleep.canReadSleep)
                const InfoNote(
                  text: 'Sleep access is not allowed. Enable it in Data '
                      'sources to see sessions and stages.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                )
              else if (lastNight == null)
                const SurfaceCard(
                  child: Text(
                    'No Fitbit Air-matched sleep sessions in the last '
                    '14 days. Sessions appear here after Google Health '
                    'syncs them.',
                    style: AppType.note,
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
                            lastNight.minutes < 60
                                ? '${lastNight.minutes}m'
                                : formatDurationMinutes(lastNight.minutes),
                            style: AppType.numXl,
                          ),
                          const Spacer(),
                          if (score != null)
                            StatusPill(
                              label: '$score ESTIMATE',
                              color: AppColors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Main session \u00b7 ${formatClock(lastNight.start)} '
                        '\u2013 ${formatClock(lastNight.end)}',
                        style: AppType.caption,
                      ),
                      const SizedBox(height: 14),
                      StageBar(
                        segments: [
                          ChartSegment(
                            label: 'Awake',
                            minutes: lastNight.awakeMinutes,
                            color: AppColors.yellow,
                          ),
                          ChartSegment(
                            label: 'Light',
                            minutes: lastNight.lightMinutes,
                            color: AppColors.blue,
                          ),
                          ChartSegment(
                            label: 'Deep',
                            minutes: lastNight.deepMinutes,
                            color: AppColors.violet,
                          ),
                          ChartSegment(
                            label: 'REM',
                            minutes: lastNight.remMinutes,
                            color: AppColors.teal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const InfoNote(
                  text: sleepScoreFormula,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.blue,
                ),
                const SizedBox(height: 18),
                if (recent.length >= 2) ...[
                  SectionHeader(
                    title: 'Recent nights',
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
                SectionHeader(
                  title: 'Sessions',
                  caption: 'LAST 14 DAYS',
                ),
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
