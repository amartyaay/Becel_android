import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final _health = HealthConnectService.instance;
  HealthConnectInspection? _inspection;
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
      _inspection = inspection;
      _summary = summary;
      _error = summary?.error ?? inspection.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final connected = summary?.fitbitAirMetadataMatched == true;
    final statusColor = connected ? AppColors.green : AppColors.yellow;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.green,
          backgroundColor: AppColors.surfaceHigh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOVE WITH CONTEXT',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Activity',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: _loading
                        ? 'CHECKING'
                        : connected
                        ? 'LIVE DATA'
                        : 'NOT CONNECTED',
                    color: _loading ? AppColors.textSecondary : statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _MovementCard(
                stepCount: summary?.stepCount,
                canReadSteps: summary?.canReadSteps ?? false,
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Most recent workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  Text(
                    'LAST 7 DAYS',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _WorkoutCard(
                summary: summary,
                canReadExercise: summary?.canReadExercise ?? false,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.red, fontSize: 10),
                ),
              ],
              const SizedBox(height: 22),
              _DataAccessCard(
                isAvailable: _inspection?.isAvailable ?? false,
                onTap: () => context.go('/data'),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  connected
                      ? 'FITBIT AIR-MATCHED RECORDS · PULL TO REFRESH'
                      : 'NO FITBIT AIR-MATCHED RECORDS',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.65,
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

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.stepCount, required this.canReadSteps});

  final int? stepCount;
  final bool canReadSteps;

  @override
  Widget build(BuildContext context) {
    const goal = 10000;
    final progress = ((stepCount ?? 0) / goal).clamp(0.0, 1.0);
    final count = stepCount == null ? '—' : _formatNumber(stepCount!);
    final status = stepCount != null
        ? 'FITBIT AIR'
        : canReadSteps
        ? 'NO AIR RECORD'
        : 'ACCESS NEEDED';

    return Container(
      padding: const EdgeInsets.fromLTRB(19, 18, 19, 17),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: AppColors.green,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Steps today',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              _StatusPill(label: status, color: AppColors.green),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 7, bottom: 4),
                child: Text(
                  'steps',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                stepCount == null ? '—' : '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigher,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '10,000 reference goal · only Fitbit Air metadata matches are shown',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.summary, required this.canReadExercise});

  final HealthSummary? summary;
  final bool canReadExercise;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final workout = summary?.workoutType;
    final start = summary?.workoutStart;
    final duration = summary?.workoutDurationMinutes;
    final hasWorkout = workout != null;
    final icon = switch (workout) {
      'Run' || 'Treadmill run' => Icons.directions_run_rounded,
      'Walk' => Icons.directions_walk_rounded,
      'Cycling' || 'Indoor cycling' => Icons.directions_bike_rounded,
      'Strength training' => Icons.fitness_center_rounded,
      'Pool swim' || 'Open-water swim' => Icons.pool_rounded,
      'Yoga' => Icons.self_improvement_rounded,
      _ => Icons.sports_gymnastics_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (hasWorkout ? AppColors.red : AppColors.textTertiary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              hasWorkout ? icon : Icons.event_busy_rounded,
              color: hasWorkout ? AppColors.red : AppColors.textTertiary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout ?? 'No workout found',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !canReadExercise
                      ? 'Allow workout access in Data Sources'
                      : hasWorkout
                      ? '${duration ?? '—'} min · Fitbit Air'
                      : 'No Fitbit Air-matched exercise session found in the last 7 days',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
                if (start != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDateAndTime(start),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasWorkout)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 17,
              ),
            ),
        ],
      ),
    );
  }
}

class _DataAccessCard extends StatelessWidget {
  const _DataAccessCard({required this.isAvailable, required this.onTap});

  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.teal,
                size: 20,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isAvailable
                      ? 'Review Health Connect permissions and data'
                      : 'Set up Health Connect on this device',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.teal,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
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
      ? 'Today'
      : '${date.month}/${date.day}';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$dateLabel · $hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
