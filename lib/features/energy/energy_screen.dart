import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../widgets/kit.dart';

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  final _store = HealthStore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final snapshot = _store.snapshot;
            final activity = snapshot?.activity;
            final total = activity?.caloriesTotalToday;
            final active = activity?.caloriesActiveToday;
            final resting = (total != null && active != null)
                ? total - active
                : null;
            final canReadTotal = activity?.canReadCaloriesTotal == true;
            final canReadActive = activity?.canReadCaloriesActive == true;

            return RefreshIndicator(
              onRefresh: () => _store.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  ScreenHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    eyebrow: 'FUEL & BURN',
                    title: 'Energy',
                    trailing: _store.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.green,
                            ),
                          )
                        : StatusPill(
                            label: total == null ? 'NO DATA' : 'TODAY',
                            color: total == null
                                ? AppColors.yellow
                                : AppColors.teal,
                            icon: Icons.local_fire_department_rounded,
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    StateCard(
                      title: 'Reading energy data',
                      body:
                          _store.error ??
                          'Loading Fitbit Air calorie records for today.',
                      icon: Icons.sync_rounded,
                      loading: _store.loading,
                      actionLabel: _store.error == null ? null : 'Retry',
                      onAction: () => _store.refresh(force: true),
                    )
                  else if (snapshot.error != null && activity == null)
                    StateCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      title: 'Energy data could not load',
                      body: snapshot.error!,
                      actionLabel: 'Retry',
                      onAction: () => _store.refresh(force: true),
                    )
                  else if (!canReadTotal)
                    const InfoNote(
                      text:
                          'Calorie totals need Health Connect access. Enable '
                          'total and active calories in Data sources.',
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.yellow,
                    )
                  else if (total == null)
                    const SurfaceCard(
                      child: Text(
                        'No Fitbit Air-matched calorie records today yet. Values '
                        'appear after Google Health syncs them.',
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
                              Text('$total', style: AppType.numXl),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('kcal total', style: AppType.unit),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resting != null && active != null
                                ? 'Resting $resting \u00b7 Active $active kcal'
                                : 'Burned so far today',
                            style: AppType.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SectionHeader(title: 'Breakdown', caption: 'TODAY'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _EnergyTile(
                            icon: Icons.directions_run_rounded,
                            color: AppColors.green,
                            label: 'Active',
                            value: active,
                            note: canReadActive
                                ? 'Movement above rest'
                                : 'Access needed',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _EnergyTile(
                            icon: Icons.self_improvement_rounded,
                            color: AppColors.teal,
                            label: 'Resting',
                            value: resting,
                            note: resting != null
                                ? 'Total minus active'
                                : 'Needs both totals',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const InfoNote(
                      text:
                          'Becel shows Fitbit Air calorie totals as written to '
                          'Health Connect and does not estimate meals.',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.teal,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const TrustFooter(
                    text: 'READ ONLY \u00b7 NO HEALTH DATA IS UPLOADED',
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

class _EnergyTile extends StatelessWidget {
  const _EnergyTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int? value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, color: color, size: 34, iconSize: 17),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value?.toString() ?? '\u2014', style: AppType.numM),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('kcal', style: AppType.unit),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption),
          const SizedBox(height: 4),
          Text(note, style: AppType.caption),
        ],
      ),
    );
  }
}
