import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../domain/coaching.dart';
import '../../domain/performance.dart';
import '../../domain/strain.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../shell/shell_screen.dart';

/// Daily step reference. 8–10k/day is where mortality benefit plateaus for
/// adults under 60 (Paluch et al., Lancet Public Health 2022).
const stepGoal = 10000;

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _health = HealthStore.instance;

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _health,
        builder: (context, _) {
          final snapshot = _health.snapshot;
          final now = DateTime.now();
          return RefreshIndicator(
            onRefresh: () => _health.refresh(force: true),
            color: AppColors.accent,
            backgroundColor: AppColors.surfaceHigh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    now: now,
                    loading: _health.loading,
                    connected: snapshot?.airMatched ?? false,
                    refreshedAt: snapshot?.loadedAt,
                    onData: () => context.push('/data'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, navClearance),
                  sliver: SliverList.list(
                    children: snapshot == null
                        ? [
                            _InitialState(
                              loading: _health.loading,
                              error: _health.error,
                              onRetry: () => _health.refresh(force: true),
                              onData: () => context.push('/data'),
                            ),
                          ]
                        : _content(context, snapshot),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, HealthSnapshot snapshot) {
    if (!snapshot.hasAccess) {
      return [
        StateCard(
          icon: Icons.link_rounded,
          color: AppColors.accent,
          title: snapshot.isAvailable
              ? 'Connect your health data'
              : 'Health Connect is not available',
          body: snapshot.isAvailable
              ? 'Allow Fitbit Air and Google Health records in Health Connect. '
                    'Becel only reads; it never writes.'
              : 'This phone does not expose Health Connect.',
          actionLabel: 'Open data sources',
          onAction: () => context.push('/data'),
        ),
      ];
    }
    if (!snapshot.hasAnyRecord) {
      return [
        StateCard(
          icon: Icons.sensors_off_rounded,
          color: AppColors.yellow,
          title: 'No Fitbit Air records yet',
          body:
              snapshot.error ??
              'Health Connect is connected, but nothing has synced. Open the '
                  'Fitbit / Google Health app to sync.',
          actionLabel: 'Open data sources',
          onAction: () => context.push('/data'),
        ),
      ];
    }
    final p = snapshot.performance;
    return [
      _RecoveryHero(
        performance: p,
        onRecovery: () => context.push('/recovery'),
        onStrain: () => context.go('/training'),
        onSleep: () => context.go('/sleep'),
      ),
      if (p.alert != null) ...[
        const SizedBox(height: 12),
        _AlertCard(alert: p.alert!),
      ],
      const SizedBox(height: 12),
      _BurnCard(snapshot: snapshot, onTap: () => context.push('/energy')),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StepsTile(snapshot: snapshot)),
            const SizedBox(width: 12),
            Expanded(child: _ActiveTile(snapshot: snapshot)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _PlanCard(plan: p.plan, strainNow: p.today?.strain),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _LoadTile(
                performance: p,
                onTap: () => context.go('/training'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VitalsTile(
                snapshot: snapshot,
                onTap: () => context.push('/vitals'),
              ),
            ),
          ],
        ),
      ),
      if (snapshot.profile?.hasEnergyInputs != true) ...[
        const SizedBox(height: 12),
        StateCard(
          icon: Icons.person_outline_rounded,
          color: AppColors.accent,
          title: 'Add age and sex',
          body:
              'Health Connect has no age or sex. Add them once in Settings to '
              'unlock calories burned and personal zones. Weight and height '
              'are read from Google Health when recorded there.',
          actionLabel: 'Open settings',
          onAction: () => openSettings(context),
        ),
      ],
      if (snapshot.error != null) ...[
        const SizedBox(height: 12),
        InfoNote(
          text: 'Some data could not refresh. Pull down to retry.',
          color: AppColors.yellow,
          icon: Icons.sync_problem_rounded,
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.loading,
    required this.connected,
    required this.refreshedAt,
    required this.onData,
  });

  final DateTime now;
  final bool loading;
  final bool connected;
  final DateTime? refreshedAt;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatShortDate(now), style: AppType.eyebrow),
                const SizedBox(height: 4),
                const Text('Today', style: AppType.screenTitle),
              ],
            ),
          ),
          Material(
            color: AppColors.surfaceHigh,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.hairline),
            ),
            child: InkWell(
              onTap: onData,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.6),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: connected
                              ? AppColors.bandGreen
                              : AppColors.bandYellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      loading
                          ? 'Syncing'
                          : refreshedAt == null
                          ? 'Not synced'
                          : formatAgo(refreshedAt!),
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryHero extends StatelessWidget {
  const _RecoveryHero({
    required this.performance,
    required this.onRecovery,
    required this.onStrain,
    required this.onSleep,
  });

  final Performance performance;
  final VoidCallback onRecovery;
  final VoidCallback onStrain;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    final p = performance;
    final recovery = p.recoveryEstimate;
    final score = recovery?.score;
    final color = estimateColor(recovery);
    final strain = p.today?.strain;
    final target = p.plan.target;
    final sleepPct = p.sleep.performancePercent;
    final waiting = p.recovery.nightsUntilScore;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppColors.cardShadow,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.tint(color, 0.16), AppColors.surface],
          stops: const [0.0, 0.75],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final big = (constraints.maxWidth * 0.38).clamp(110.0, 150.0);
          final small = (constraints.maxWidth * 0.25).clamp(78.0, 100.0);
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _HeroRing(
                      onTap: onStrain,
                      ring: MetricRing(
                        size: small,
                        stroke: 9,
                        fraction: strain == null ? null : strain / strainMax,
                        color: AppColors.strain,
                        value: strain == null ? '—' : strain.toStringAsFixed(1),
                        label: 'Strain',
                        bandFrom: target.low / strainMax,
                        bandTo: target.high / strainMax,
                        semanticsLabel: strain == null
                            ? 'Strain unavailable'
                            : 'Strain ${strain.toStringAsFixed(1)} of 21, '
                                  'target ${target.low.round()} to '
                                  '${target.high.round()}',
                      ),
                      caption: strain == null
                          ? 'needs HR'
                          : 'target ${target.low.round()}–${target.high.round()}',
                    ),
                  ),
                  _HeroRing(
                    onTap: onRecovery,
                    ring: Glow(
                      color: color,
                      radius: 0.7,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: MetricRing(
                          size: big,
                          stroke: 13,
                          fraction: score == null ? null : score / 100,
                          color: color,
                          value: score == null ? '—' : '$score',
                          unit: score == null ? null : '%',
                          label: 'Recovery',
                          semanticsLabel: score == null
                              ? 'Recovery calibrating'
                              : 'Recovery $score percent, '
                                    '${estimateWord(recovery)}',
                        ),
                      ),
                    ),
                    caption: null,
                  ),
                  Expanded(
                    child: _HeroRing(
                      onTap: onSleep,
                      ring: MetricRing(
                        size: small,
                        stroke: 9,
                        fraction: sleepPct == null ? null : sleepPct / 100,
                        color: AppColors.sleep,
                        value: sleepPct == null ? '—' : '$sleepPct',
                        unit: sleepPct == null ? null : '%',
                        label: 'Sleep',
                        semanticsLabel: sleepPct == null
                            ? 'Sleep performance unavailable'
                            : 'Sleep performance $sleepPct percent of need',
                      ),
                      caption: p.sleep.lastNight == null
                          ? 'no main sleep'
                          : formatDurationMinutes(
                              p.sleep.lastNight!.asleepMinutes,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Tag(
                score == null
                    ? waiting > 0
                          ? 'Calibrating · $waiting more night${waiting == 1 ? '' : 's'}'
                          : 'Needs last night’s sleep'
                    : recovery!.provisional
                    ? '${estimateWord(recovery)} · provisional'
                    : estimateWord(recovery),
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.onTap,
    required this.ring,
    required this.caption,
  });

  final VoidCallback onTap;
  final Widget ring;
  final String? caption;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ring,
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final BodyAlert alert;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bandRed.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.bandRed.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.bandRed,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.title, style: AppType.rowTitle),
              const SizedBox(height: 4),
              Text(alert.detail, style: AppType.note),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Calories burned today (Becel's algorithm), shown only when every input
/// is present and calculated up to the band's last sync.
class _BurnCard extends StatelessWidget {
  const _BurnCard({required this.snapshot, required this.onTap});

  final HealthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.performance;
    final energy = p.energy;
    if (energy == null) {
      final missing = p.energyMissing;
      final needsSettings = missing.any(
        (m) => m == 'age' || m == 'sex' || m == 'weight' || m == 'height',
      );
      return PanelCard(
        title: 'Calories burned',
        icon: Icons.local_fire_department_rounded,
        accent: AppColors.burned,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waiting for data', style: AppType.cardTitle),
            const SizedBox(height: 4),
            Text(
              missing.isEmpty
                  ? 'Calculating…'
                  : 'Needs ${missing.join(', ')}. Becel shows calories only '
                        'when every input is available, so the number is never '
                        'a guess.',
              style: AppType.note,
            ),
            if (needsSettings) ...[
              const SizedBox(height: 10),
              Text(
                'Weight and height are read from Google Health when it shares '
                'them; age and sex are set once in Settings.',
                style: AppType.caption,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => openSettings(context),
                child: const Text('Open settings'),
              ),
            ],
          ],
        ),
      );
    }
    final today = energy.today;
    final asOf = p.energyAsOf;
    final delta = energy.deviceDelta;
    final stale = asOf != null && p.now.difference(asOf).inMinutes > 30;
    final projected = math.max(energy.projectedToday, today.totalKcal);
    final remaining = projected - today.totalKcal;
    final perHour = (energy.rmr / 24).round();
    // Resting first and in neutral grey: most of any day's burn is the body
    // at rest, and colouring it like activity made it read as "earned".
    final restingColor = AppColors.textTertiary.withValues(alpha: 0.45);
    final everydayColor = AppColors.burned.withValues(alpha: 0.4);
    final parts = [
      (
        label: 'At rest',
        hint: 'just being alive',
        kcal: today.restingKcal,
        color: restingColor,
      ),
      (
        label: 'Everyday',
        hint: 'sitting, digesting',
        kcal: today.livingKcal,
        color: everydayColor,
      ),
      (
        label: 'Movement',
        hint: 'walks, workouts',
        kcal: today.exerciseKcal,
        color: AppColors.burned,
      ),
    ];
    return PanelCard(
      title: 'Calories burned',
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.burned,
      onTap: onTap,
      trailing: asOf == null
          ? null
          : Tag(
              'as of ${formatClock(asOf)}',
              color: stale ? AppColors.bandYellow : AppColors.textTertiary,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatNumber(today.totalKcal.round()),
                        style: AppType.numXl,
                      ),
                      const SizedBox(width: 6),
                      const Text('kcal so far', style: AppType.unit),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '~${formatNumber(projected.round())}',
                      style: AppType.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text('by midnight', style: AppType.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Burned so far, then the predicted rest of the day as an outline.
          SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final (i, part) in parts.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, part.kcal.round()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: part.color,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(i == 0 ? 6 : 0),
                        ),
                      ),
                    ),
                  ),
                ],
                if (remaining >= 1) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, remaining.round()),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.textTertiary.withValues(alpha: 0.4),
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, part) in parts.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _BurnTile(
                    color: part.color,
                    label: part.label,
                    hint: part.hint,
                    kcal: part.kcal,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your body burns about $perHour kcal an hour at rest, even asleep, '
            'so most of any day’s total is not activity. Moving added '
            '${formatNumber(today.exerciseKcal.round())} today.'
            '${energy.deviceTotalToday == null ? '' : ' Fitbit: ${formatNumber(energy.deviceTotalToday!)}${delta == null || delta.abs() < 50 ? '' : ' (${delta > 0 ? '+' : '−'}${formatNumber(delta.abs().round())})'}.'}',
            style: AppType.caption,
          ),
          if (stale) ...[
            const SizedBox(height: 10),
            Text(
              'Your band last synced at ${formatClock(asOf)}. Open the Fitbit '
              'app to sync, then pull down to refresh.',
              style: AppType.caption.copyWith(color: AppColors.bandYellow),
            ),
          ],
        ],
      ),
    );
  }
}

/// One part of the day's burn: a colour key, the kcal, and what it is.
class _BurnTile extends StatelessWidget {
  const _BurnTile({
    required this.color,
    required this.label,
    required this.hint,
    required this.kcal,
  });

  final Color color;
  final String label;
  final String hint;
  final double kcal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatNumber(kcal.round()), style: AppType.numS),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

class _StepsTile extends StatelessWidget {
  const _StepsTile({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final raw = snapshot.summary?.stepCount;
    final today = snapshot.performance.energy?.today;
    final walking = today?.countedSteps;
    final shown = raw;
    return PanelCard(
      title: 'Steps',
      icon: Icons.directions_walk_rounded,
      accent: AppColors.steps,
      onTap: () => context.push('/energy'),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: ((shown ?? 0) / stepGoal).clamp(0.0, 1.0),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: AppColors.steps,
              backgroundColor: AppColors.surfaceHigher,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    shown == null ? '—' : formatNumber(shown),
                    style: AppType.numM.copyWith(fontSize: 24),
                  ),
                ),
                Text(
                  walking == null || raw == null || raw - walking < 100
                      ? 'of ${formatNumber(stepGoal)}'
                      : '${formatNumber(walking)} walking',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = snapshot.performance.today;
    final minutes = today?.aerobicEquivalentMinutes.round();
    const goal = 30; // ~150 moderate-equivalent minutes per week.
    return PanelCard(
      title: 'Active',
      icon: Icons.favorite_rounded,
      accent: AppColors.strain,
      onTap: () => context.go('/training'),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: ((minutes ?? 0) / goal).clamp(0.0, 1.0),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: AppColors.strain,
              backgroundColor: AppColors.surfaceHigher,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        minutes == null ? '—' : '$minutes',
                        style: AppType.numM.copyWith(fontSize: 24),
                      ),
                      const SizedBox(width: 2),
                      const Text('min', style: AppType.unit),
                    ],
                  ),
                ),
                Text(
                  'of $goal today',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.strainNow});

  final DailyPlan plan;
  final double? strainNow;

  @override
  Widget build(BuildContext context) {
    final color = switch (plan.tone) {
      PlanTone.push => AppColors.bandGreen,
      PlanTone.train => AppColors.bandYellow,
      PlanTone.recover || PlanTone.rest => AppColors.bandRed,
    };
    final target = plan.target;
    final now = strainNow ?? 0;
    final remaining = (target.low - now).clamp(0, strainMax);
    return PanelCard(
      title: 'Today’s plan',
      icon: Icons.flag_rounded,
      accent: AppColors.accent,
      trailing: Tag(target.label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.headline,
            style: AppType.sectionTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(plan.session, style: AppType.body),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Strain ${now.toStringAsFixed(1)}',
                  overflow: TextOverflow.ellipsis,
                  style: AppType.rowTitle.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  remaining > 0
                      ? '${remaining.toStringAsFixed(1)} to target'
                      : now > target.high
                      ? 'Above target'
                      : 'In target',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearMeter(
            value: now,
            max: strainMax,
            color: AppColors.strain,
            bandFrom: target.low,
            bandTo: target.high,
          ),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final note in plan.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: AppType.note)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LoadTile extends StatelessWidget {
  const _LoadTile({required this.performance, required this.onTap});

  final Performance performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final load = performance.load;
    final status = load?.status ?? LoadStatus.calibrating;
    final days = performance.strainDays;
    final week = days.length <= 7 ? days : days.sublist(days.length - 7);
    return PanelCard(
      title: 'Load',
      icon: Icons.stacked_line_chart_rounded,
      accent: AppColors.strain,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status.label, style: AppType.numS),
          Text(
            load?.acwr == null
                ? 'needs 21 days'
                : 'ratio ${load!.acwr!.toStringAsFixed(2)}',
            style: AppType.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          if (week.isNotEmpty)
            DayBars(
              values: [for (final d in week) d.hasData ? d.strain : null],
              labels: [for (final d in week) formatDayShort(d.date)[0]],
              maxValue: strainMax,
              height: 36,
              colorFor: (i, v) => AppColors.strain.withValues(
                alpha: i == week.length - 1 ? 1 : 0.5,
              ),
              semanticsLabel: 'Daily strain, last 7 days',
            ),
        ],
      ),
    );
  }
}

class _VitalsTile extends StatelessWidget {
  const _VitalsTile({required this.snapshot, required this.onTap});

  final HealthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = snapshot.recovery;
    final rhr = r?.restingHrCurrent ?? snapshot.heart?.restingHrBpm?.toDouble();
    final hrv = r?.hrvCurrent;
    String delta(double v, String unit) =>
        '${v >= 0 ? '+' : '−'}${v.abs().round()}$unit';
    return PanelCard(
      title: 'Vitals',
      icon: Icons.favorite_rounded,
      accent: AppColors.bandRed,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VitalRow(
            label: 'Resting HR',
            value: rhr == null ? '—' : '${rhr.round()}',
            delta: r == null ? null : delta(r.restingHrChange, ''),
            good: r == null ? null : r.restingHrChange <= 0,
          ),
          const SizedBox(height: 10),
          _VitalRow(
            label: 'HRV',
            value: hrv == null ? '—' : '${hrv.round()} ms',
            delta: r == null ? null : delta(r.hrvChangePercent, '%'),
            good: r == null ? null : r.hrvChangePercent >= 0,
          ),
          const SizedBox(height: 10),
          _VitalRow(
            label: 'Breathing',
            value: snapshot.body?.respiratoryRate?.toStringAsFixed(1) ?? '—',
            delta: snapshot.performance.respiratoryDelta == null
                ? null
                : '${snapshot.performance.respiratoryDelta! >= 0 ? '+' : '−'}${snapshot.performance.respiratoryDelta!.abs().toStringAsFixed(1)}',
            good: snapshot.performance.respiratoryDelta == null
                ? null
                : snapshot.performance.respiratoryDelta! < 1,
          ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  const _VitalRow({
    required this.label,
    required this.value,
    this.delta,
    this.good,
  });

  final String label;
  final String value;
  final String? delta;
  final bool? good;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption,
        ),
      ),
      Text(value, style: AppType.rowTitle.copyWith(fontSize: 13.5)),
      if (delta != null) ...[
        const SizedBox(width: 6),
        Icon(
          good == true ? Icons.north_east_rounded : Icons.south_east_rounded,
          size: 12,
          color: good == true ? AppColors.bandGreen : AppColors.bandYellow,
        ),
      ],
    ],
  );
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
        title: 'Reading Health Connect',
        body: 'Loading 28 days of heart rate, sleep, and recovery signals.',
        icon: Icons.sync_rounded,
        loading: true,
      );
    }
    if (error != null) {
      return StateCard(
        icon: Icons.sync_problem_rounded,
        color: AppColors.yellow,
        title: 'Couldn’t read Health Connect',
        body: 'Health Connect didn’t respond. This usually clears on retry.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return StateCard(
      icon: Icons.link_rounded,
      color: AppColors.accent,
      title: 'Set up Health Connect',
      body:
          'Becel reads Fitbit Air and Google Health records. It never writes.',
      actionLabel: 'Open data sources',
      onAction: onData,
    );
  }
}
