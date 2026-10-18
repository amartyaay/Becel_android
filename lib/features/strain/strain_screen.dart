import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/charts_kit.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class StrainScreen extends StatefulWidget {
  const StrainScreen({super.key});

  @override
  State<StrainScreen> createState() => _StrainScreenState();
}

class _StrainScreenState extends State<StrainScreen> {
  final _health = HealthConnectService.instance;
  HeartDetail? _heart;
  ActivityDetail? _activity;
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
    final results = await Future.wait<Object>([
      _health.readHeartDetail(),
      _health.readActivityDetail(),
    ]);
    if (!mounted) return;
    setState(() {
      _heart = results[0] as HeartDetail;
      _activity = results[1] as ActivityDetail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heart = _heart;
    final activity = _activity;
    final zoneMinutes = heart?.zoneMinutes ?? const [0, 0, 0, 0, 0];
    final zoneTotal = zoneMinutes.fold<int>(0, (sum, value) => sum + value);
    final strain = heart?.canReadHeartRate == true
        ? strainEstimateFromZones(zoneMinutes)
        : null;
    final workouts = activity?.workouts ?? const <WorkoutEntry>[];

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
                eyebrow: 'CARDIOVASCULAR LOAD',
                title: 'Strain',
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
                        label: strain == null ? 'NO HR ACCESS' : 'ESTIMATE',
                        color: strain == null
                            ? AppColors.yellow
                            : AppColors.red,
                        icon: Icons.bolt_rounded,
                      ),
              ),
              const SizedBox(height: 16),
              if (heart != null && !heart.canReadHeartRate)
                const InfoNote(
                  text: 'Strain is calculated from heart-rate zones and needs '
                      'heart-rate access. Enable it in Data sources.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
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
                            strain?.toString() ?? '\u2014',
                            style: AppType.numXl,
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('of 100 today', style: AppType.unit),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strain == 0
                            ? 'No active zone time recorded yet today.'
                            : 'From $zoneTotal min in heart-rate zones today.',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const InfoNote(
                  text: strainFormula,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.red,
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: 'Time in zones',
                  caption: 'TODAY \u00b7 FIXED BANDS',
                ),
                const SizedBox(height: 10),
                SurfaceCard(
                  child: zoneTotal == 0
                      ? Text(
                          'Not enough heart-rate samples today to map zones.',
                          style: AppType.caption,
                        )
                      : Column(
                          children: [
                            for (var index = 0; index < 5; index++)
                              ZoneBarRow(
                                label: heartZoneLabels[index],
                                bpmRange: heartZoneRanges[index],
                                minutes: zoneMinutes[index],
                                fraction: zoneMinutes[index] / zoneTotal,
                                color: heartZoneColors[index],
                              ),
                          ],
                        ),
                ),
              ],
              const SizedBox(height: 18),
              SectionHeader(
                title: 'Workouts',
                caption: 'LAST 7 DAYS',
              ),
              const SizedBox(height: 10),
              if (activity != null && !activity.canReadExercise)
                const SurfaceCard(
                  child: Text(
                    'Workout access is not allowed. Enable exercise access in '
                    'Data sources to list sessions here.',
                    style: AppType.note,
                  ),
                )
              else if (workouts.isEmpty)
                const SurfaceCard(
                  child: Text(
                    'No Fitbit Air-matched workouts in the last 7 days.',
                    style: AppType.note,
                  ),
                )
              else
                for (final workout in workouts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const IconChip(
                            icon: Icons.fitness_center_rounded,
                            color: AppColors.violet,
                            size: 34,
                            iconSize: 17,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(workout.type, style: AppType.rowTitle),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatDayShort(workout.start)} \u00b7 '
                                  '${formatClock(workout.start)}',
                                  style: AppType.caption,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatDurationMinutes(workout.minutes),
                            style: AppType.numS,
                          ),
                        ],
                      ),
                    ),
                  ),
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
}
