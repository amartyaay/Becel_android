import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/strength.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../activity/strength_log_sheet.dart';

class StrengthScreen extends StatelessWidget {
  const StrengthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final health = HealthStore.instance;
    final local = LocalStore.instance;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStrengthLogSheet(context),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log session'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([health, local]),
          builder: (context, _) {
            final p = health.snapshot?.performance;
            final sessions = [...local.log.strengthSessions]
              ..sort((a, b) => b.start.compareTo(a.start));
            final volume =
                p?.muscleVolume ??
                weeklyMuscleVolume(sessions, now: DateTime.now());
            final lifts = p?.lifts ?? liftBests(sessions);
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
              children: [
                ScreenHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                  eyebrow: 'MUSCULAR LOAD',
                  title: 'Strength',
                ),
                const SizedBox(height: 16),
                PanelCard(
                  title: 'WEEKLY HARD SETS PER MUSCLE',
                  icon: Icons.accessibility_new_rounded,
                  accent: AppColors.orange,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final muscle in volume) _VolumeRow(volume: muscle),
                      const SizedBox(height: 6),
                      Text(
                        'Shaded band = 10–20 hard sets/week, the range most '
                        'associated with hypertrophy in trained lifters. '
                        'Synergists count as half a set. Hard = RPE ≥ 6.',
                        style: AppType.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PanelCard(
                  title: 'ESTIMATED 1RM',
                  icon: Icons.emoji_events_rounded,
                  accent: AppColors.yellow,
                  child: lifts.isEmpty
                      ? const Text(
                          'Log weighted sets (≤ 12 reps) to track estimated '
                          'one-rep maxes and personal records.',
                          style: AppType.note,
                        )
                      : Column(
                          children: [
                            for (final lift in lifts.take(8))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lift.exercise.name,
                                            style: AppType.rowTitle,
                                          ),
                                          Text(
                                            formatShortDate(lift.at),
                                            style: AppType.caption.copyWith(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lift.isPersonalRecord)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Tag(
                                          'PR',
                                          color: AppColors.yellow,
                                        ),
                                      )
                                    else if (lift.changeKg != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Text(
                                          '${lift.changeKg! >= 0 ? '+' : ''}${lift.changeKg!.toStringAsFixed(1)} kg',
                                          style: AppType.caption.copyWith(
                                            color: lift.changeKg! >= 0
                                                ? AppColors.bandGreen
                                                : AppColors.textTertiary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      lift.oneRepMaxKg.toStringAsFixed(1),
                                      style: AppType.numS,
                                    ),
                                    const SizedBox(width: 3),
                                    const Text('kg', style: AppType.unit),
                                  ],
                                ),
                              ),
                            Text(
                              'Epley formula, adjusted for reps in reserve when '
                              'RPE is logged. Most accurate from sets of 1–8.',
                              style: AppType.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Sessions',
                  caption: 'ON THIS PHONE',
                ),
                const SizedBox(height: 8),
                if (sessions.isEmpty)
                  const StateCard(
                    icon: Icons.fitness_center_rounded,
                    color: AppColors.orange,
                    title: 'No sessions yet',
                    body:
                        'A quick log is duration + session RPE (10 seconds). '
                        'Add exercises and sets when you want volume and 1RM '
                        'tracking.',
                  )
                else
                  for (final session in sessions.take(20))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionRow(session: session),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.volume});

  final MuscleVolume volume;

  @override
  Widget build(BuildContext context) {
    final color = switch (volume.status) {
      MuscleVolumeStatus.minimal => AppColors.textTertiary,
      MuscleVolumeStatus.maintenance => AppColors.bandYellow,
      MuscleVolumeStatus.growth => AppColors.bandGreen,
      MuscleVolumeStatus.high => AppColors.orange,
    };
    final word = switch (volume.status) {
      MuscleVolumeStatus.minimal => 'minimal',
      MuscleVolumeStatus.maintenance => 'maintain',
      MuscleVolumeStatus.growth => 'growth',
      MuscleVolumeStatus.high => 'high',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              volume.muscle.label,
              style: AppType.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: LinearMeter(
              value: volume.sets,
              max: 24,
              color: color,
              bandFrom: 10,
              bandTo: 20,
              height: 8,
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              '${volume.sets.toStringAsFixed(volume.sets % 1 == 0 ? 0 : 1)} · $word',
              textAlign: TextAlign.right,
              style: AppType.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final StrengthSession session;

  @override
  Widget build(BuildContext context) {
    final names = session.exercises
        .map((e) => e.exercise?.name)
        .whereType<String>()
        .join(' · ');
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.bandRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.bandRed,
        ),
      ),
      confirmDismiss: (_) async =>
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete session?'),
              content: const Text(
                'This removes it from strain, load, and volume.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ??
          false,
      onDismissed: (_) => LocalStore.instance.deleteStrengthSession(session.id),
      child: SurfaceCard(
        onTap: () => showStrengthLogSheet(context, existing: session),
        color: AppColors.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const IconChip(
              icon: Icons.fitness_center_rounded,
              color: AppColors.orange,
              size: 38,
              iconSize: 18,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    names.isEmpty ? 'Strength session' : names,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.rowTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatShortDate(session.start)} · ${session.durationMinutes} min · '
                    'RPE ${session.sessionRpe.round()} · ${session.hardSets} hard sets'
                    '${session.volumeKg > 0 ? ' · ${formatNumber(session.volumeKg.round())} kg' : ''}',
                    style: AppType.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(
              '${session.srpeLoad.round()}',
              style: AppType.numS.copyWith(
                fontSize: 15,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(width: 3),
            const Text('AU', style: AppType.unit),
          ],
        ),
      ),
    );
  }
}
