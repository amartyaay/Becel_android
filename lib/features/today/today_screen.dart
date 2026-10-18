import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _TopBar(onSettings: () => openSettings(context)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekday, $month ${now.day}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Your day, in focus.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 27,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _DataStatusPill(
                    loading: _loading,
                    connected: hasLiveData,
                    onTap: () => context.go('/data'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _MovementCard(
                stepCount: summary?.stepCount,
                hasStepAccess: summary?.canReadSteps ?? false,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickMetricCard(
                      icon: Icons.favorite_rounded,
                      iconColor: AppColors.red,
                      label: 'HEART RATE',
                      value: summary?.heartRateBpm?.toString() ?? '—',
                      unit: summary?.heartRateBpm == null ? '' : 'bpm',
                      note: _metricNote(
                        summary?.canReadHeartRate ?? false,
                        summary?.heartRateAt,
                        'No Fitbit Air-matched reading in the last 24 hours',
                      ),
                      chart: const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _QuickMetricCard(
                      icon: Icons.nightlight_round,
                      iconColor: AppColors.blue,
                      label: 'SLEEP',
                      value: summary?.sleepSessionMinutes == null
                          ? '—'
                          : _formatDuration(summary!.sleepSessionMinutes!),
                      unit: '',
                      note: summary?.sleepSessionMinutes == null
                          ? _metricNote(
                              summary?.canReadSleep ?? false,
                              null,
                              'No Fitbit Air-matched session in the last 36 hours',
                            )
                          : 'Session span · ended ${_formatTime(summary!.sleepEnd!)}',
                      chart: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 27),
              _SectionHeading(
                title: 'Recent activity',
                action: 'See all',
                onTap: () => context.go('/fitness'),
              ),
              const SizedBox(height: 12),
              _RecentActivityCard(summary: summary),
              const SizedBox(height: 24),
              _ConnectionNudge(
                connected: hasLiveData,
                onTap: () => context.go('/data'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 10),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  hasLiveData
                      ? 'FITBIT AIR-MATCHED DATA · PULL TO REFRESH'
                      : 'NO FITBIT AIR-MATCHED DATA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.75,
                  ),
                ),
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

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
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
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BECEL',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              'AIR COMPANION',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.25,
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: AppColors.textSecondary),
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
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 9,
                  height: 9,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Icon(
                  connected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline,
                  size: 12,
                  color: connected ? color : AppColors.textSecondary,
                ),
              const SizedBox(width: 5),
              Text(
                loading
                    ? 'CHECKING'
                    : connected
                    ? 'LIVE DATA'
                    : 'CONNECT',
                style: TextStyle(
                  color: connected ? color : AppColors.textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.stepCount, required this.hasStepAccess});

  final int? stepCount;
  final bool hasStepAccess;

  @override
  Widget build(BuildContext context) {
    const goal = 10000;
    final progress = ((stepCount ?? 0) / goal).clamp(0.0, 1.0);
    final steps = stepCount == null ? '—' : _formatNumber(stepCount!);
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDAF58B), Color(0xFFB9E867)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DarkIcon(icon: Icons.directions_walk_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'DAILY MOVEMENT',
                  style: TextStyle(
                    color: Color(0xFF43532A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  stepCount != null
                      ? 'FITBIT AIR'
                      : hasStepAccess
                      ? 'NO RECORD'
                      : 'STEP ACCESS NEEDED',
                  style: TextStyle(
                    color: Color(0xFF44592B),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps,
                      style: const TextStyle(
                        color: Color(0xFF17200E),
                        fontSize: 43,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.4,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'steps today',
                      style: const TextStyle(
                        color: Color(0xFF4D6033),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: Color(0x3D4E632E),
                        valueColor: AlwaysStoppedAnimation(Color(0xFF263817)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stepCount == null ? '—' : '$percent%',
                          style: const TextStyle(
                            color: Color(0xFF1C2910),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        Text(
                          'of goal',
                          style: TextStyle(
                            color: Color(0xFF52663A),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Color(0x3D4E632E),
              valueColor: AlwaysStoppedAnimation(Color(0xFF263817)),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                steps,
                style: const TextStyle(
                  color: Color(0xFF394A24),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Spacer(),
              Text(
                '10,000 reference goal',
                style: const TextStyle(
                  color: Color(0xFF52663A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkIcon extends StatelessWidget {
  const _DarkIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF27391A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: const Color(0xFF344821), size: 18),
    );
  }
}

class _QuickMetricCard extends StatelessWidget {
  const _QuickMetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    required this.note,
    required this.chart,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final String note;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.65,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(height: 28, child: chart),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.green,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 32),
          ),
          child: Text(
            action,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (hasWorkout ? AppColors.red : AppColors.textTertiary)
                  .withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasWorkout
                  ? Icons.directions_run_rounded
                  : Icons.event_busy_rounded,
              color: hasWorkout ? AppColors.red : AppColors.textTertiary,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout ?? 'No Fitbit Air-matched workout',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  duration == null
                      ? 'No Fitbit Air-matched workout available'
                      : '$duration min · Fitbit Air',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (started != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDateAndTime(started),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? 'Manage Fitbit Air data access'
                          : 'Connect Fitbit Air data',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected
                          ? 'Only exact Air source and device matches are shown.'
                          : 'Records from other devices are excluded.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
