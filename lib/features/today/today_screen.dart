import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../widgets/kit.dart';
import '../shell/shell_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _health = HealthConnectService.instance;
  HealthSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _health.dataRevision.addListener(_onHealthDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    _health.dataRevision.removeListener(_onHealthDataChanged);
    super.dispose();
  }

  void _onHealthDataChanged() => _refresh();

  Future<void> _refresh() async {
    final inspection = await _health.inspect();
    HealthSummary? summary;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      summary = await _health.readSummary();
    }
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
      _error = summary?.error ?? inspection.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final hasLiveData = summary?.fitbitAirMetadataMatched == true;
    final now = DateTime.now();
    final weekday = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];
    final month = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][now.month - 1];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _TopBar(onSettings: () => openSettings(context)),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekday, $month ${now.day}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your day, in focus.',
                          style: AppType.screenTitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DataStatusPill(
                    loading: _loading,
                    connected: hasLiveData,
                    onTap: () => context.go('/data'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              MovementHero(
                stepCount: summary?.stepCount,
                label: 'DAILY MOVEMENT',
                caption: 'steps today',
                statusLabel: summary?.stepCount != null
                    ? 'FITBIT AIR'
                    : (summary?.canReadSteps ?? false)
                    ? 'NO RECORD'
                    : 'STEP ACCESS NEEDED',
                attention:
                    summary?.stepCount == null &&
                    !(summary?.canReadSteps ?? false),
                footerNote: '10,000 reference goal',
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MetricTile(
                        icon: Icons.favorite_rounded,
                        color: AppColors.red,
                        label: 'HEART RATE',
                        value: summary?.heartRateBpm?.toString() ?? '—',
                        unit: summary?.heartRateBpm == null ? '' : 'bpm',
                        note: _metricNote(
                          summary?.canReadHeartRate ?? false,
                          summary?.heartRateAt,
                          'No Fitbit Air-matched reading in the last 24 hours',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        icon: Icons.nightlight_round,
                        color: AppColors.blue,
                        label: 'SLEEP',
                        value: summary?.sleepSessionMinutes == null
                            ? '—'
                            : _formatDuration(summary!.sleepSessionMinutes!),
                        note: summary?.sleepSessionMinutes == null
                            ? _metricNote(
                                summary?.canReadSleep ?? false,
                                null,
                                'No Fitbit Air-matched session in the last 36 hours',
                              )
                            : 'Session span · ended ${_formatTime(summary!.sleepEnd!)}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: 'Recent activity',
                action: 'See all',
                onAction: () => context.go('/fitness'),
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(summary: summary),
              const SizedBox(height: 22),
              _ConnectionNudge(
                connected: hasLiveData,
                onTap: () => context.go('/data'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InfoNote(text: _error!, textColor: AppColors.red),
              ],
              const SizedBox(height: 22),
              TrustFooter(
                text: hasLiveData
                    ? 'FITBIT AIR-MATCHED DATA · PULL TO REFRESH'
                    : 'NO FITBIT AIR-MATCHED DATA',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _metricNote(bool permitted, String? timestamp, String emptyLabel) {
  if (!permitted) return 'Allow access in Data Sources';
  if (timestamp == null) return emptyLabel;
  return 'Updated ${_formatTime(timestamp)}';
}

String _formatTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'recently';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

String _formatDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '$minutes min';
}

String _formatDateAndTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Recent';
  final today = DateTime.now();
  final dateLabel =
      date.year == today.year &&
          date.month == today.month &&
          date.day == today.day
      ? ''
      : '${date.month}/${date.day} ';
  return '$dateLabel${_formatTime(value)}';
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD9FA83), Color(0xFF91BD49)],
            ),
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: Color(0xFF14200B),
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BECEL',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
              ),
            ),
            Text(
              'AIR COMPANION',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const Spacer(),
        _IconButton(icon: Icons.tune_rounded, onTap: onSettings),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DataStatusPill extends StatelessWidget {
  const _DataStatusPill({
    required this.loading,
    required this.connected,
    required this.onTap,
  });

  final bool loading;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.green : AppColors.yellow;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Icon(
                  connected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 14,
                  color: connected ? AppColors.green : AppColors.textSecondary,
                ),
              const SizedBox(width: 6),
              Text(
                loading
                    ? 'CHECKING'
                    : connected
                    ? 'LIVE DATA'
                    : 'CONNECT',
                style: AppType.pill.copyWith(
                  color: connected ? AppColors.green : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.summary});

  final HealthSummary? summary;

  @override
  Widget build(BuildContext context) {
    final workout = summary?.workoutType;
    final duration = summary?.workoutDurationMinutes;
    final started = summary?.workoutStart;
    final hasWorkout = workout != null;
    return SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          IconChip(
            icon: hasWorkout
                ? Icons.directions_run_rounded
                : Icons.event_busy_rounded,
            color: hasWorkout ? AppColors.violet : AppColors.textTertiary,
            size: 48,
            iconSize: 23,
            radius: 16,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout ?? 'No Fitbit Air-matched workout',
                  style: AppType.rowTitle,
                ),
                const SizedBox(height: 5),
                Text(
                  duration == null
                      ? 'No Fitbit Air-matched workout available'
                      : '$duration min · Fitbit Air',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          if (started != null) ...[
            const SizedBox(width: 10),
            Text(
              _formatDateAndTime(started),
              style: AppType.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionNudge extends StatelessWidget {
  const _ConnectionNudge({required this.connected, required this.onTap});

  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.surface,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const IconChip(icon: Icons.link_rounded, color: AppColors.teal, size: 42, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'Manage Fitbit Air data access'
                      : 'Connect Fitbit Air data',
                  style: AppType.rowTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  connected
                      ? 'Only Fitbit Air records are shown; other devices are hidden.'
                      : 'Records from other devices are excluded.',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.teal,
          ),
        ],
      ),
    );
  }
}
