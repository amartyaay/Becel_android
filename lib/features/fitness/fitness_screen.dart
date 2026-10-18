import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../widgets/kit.dart';

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
              ScreenHeader(
                eyebrow: 'MOVE WITH CONTEXT',
                title: 'Activity',
                trailing: StatusPill(
                  label: _loading
                      ? 'CHECKING'
                      : connected
                      ? 'LIVE DATA'
                      : 'NOT CONNECTED',
                  color: _loading ? AppColors.textSecondary : statusColor,
                  loading: _loading,
                  icon: connected
                      ? Icons.check_circle_rounded
                      : Icons.link_off_rounded,
                ),
              ),
              const SizedBox(height: 22),
              MovementHero(
                stepCount: summary?.stepCount,
                label: 'STEPS TODAY',
                caption: 'steps',
                statusLabel: summary?.stepCount != null
                    ? 'FITBIT AIR'
                    : (summary?.canReadSteps ?? false)
                    ? 'NO AIR RECORD'
                    : 'ACCESS NEEDED',
                attention:
                    summary?.stepCount == null &&
                    !(summary?.canReadSteps ?? false),
                footerNote:
                    '10,000 reference goal · only Fitbit Air records are shown',
              ),
              const SizedBox(height: 26),
              const SectionHeader(
                title: 'Most recent workout',
                caption: 'LAST 7 DAYS',
              ),
              const SizedBox(height: 12),
              _WorkoutCard(
                summary: summary,
                canReadExercise: summary?.canReadExercise ?? false,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                InfoNote(text: _error!, textColor: AppColors.red),
              ],
              const SizedBox(height: 22),
              _DataAccessCard(
                isAvailable: _inspection?.isAvailable ?? false,
                onTap: () => context.go('/data'),
              ),
              const SizedBox(height: 22),
              TrustFooter(
                text: connected
                    ? 'FITBIT AIR-MATCHED RECORDS · PULL TO REFRESH'
                    : 'NO FITBIT AIR-MATCHED RECORDS',
              ),
            ],
          ),
        ),
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

    return SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          IconChip(
            icon: hasWorkout ? icon : Icons.event_busy_rounded,
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
                  workout ?? 'No workout found',
                  style: AppType.rowTitle,
                ),
                const SizedBox(height: 5),
                Text(
                  !canReadExercise
                      ? 'Allow workout access in Data Sources'
                      : hasWorkout
                      ? '${duration ?? '—'} min · Fitbit Air'
                      : 'No Fitbit Air-matched exercise session found in the last 7 days',
                  style: AppType.caption,
                ),
                if (start != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDateAndTime(start),
                    style: AppType.caption,
                  ),
                ],
              ],
            ),
          ),
          if (hasWorkout) ...[
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.green,
                size: 20,
              ),
            ),
          ],
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
    return SurfaceCard(
      color: AppColors.surface,
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const IconChip(
            icon: Icons.health_and_safety_outlined,
            color: AppColors.teal,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAvailable
                  ? 'Review Health Connect permissions and data'
                  : 'Set up Health Connect on this device',
              style: AppType.rowTitle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.teal,
            size: 18,
          ),
        ],
      ),
    );
  }
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
