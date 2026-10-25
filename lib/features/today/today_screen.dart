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

/// Protein reference for people who train: 1.6 g/kg/day captures most of
/// the hypertrophy benefit (Morton et al., BJSM 2018).
const proteinPerKg = 1.6;

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
      _FuelCard(snapshot: snapshot, onTap: () => context.push('/energy')),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _StepsTile(snapshot: snapshot)),
            const SizedBox(width: 12),
            Expanded(child: _ProteinTile(snapshot: snapshot)),
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
    final color = recoveryColor(score);
    final strain = p.today?.strain;
    final target = p.plan.target;
    final sleepPct = p.sleep.performancePercent;
    final waiting = p.recovery.nightsUntilScore;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.hairline),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              color.withValues(alpha: 0.10),
              AppColors.surfaceHigh,
            ),
            AppColors.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        children: [
          InkWell(
            onTap: onRecovery,
            customBorder: const CircleBorder(),
            child: Glow(
              color: color,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MetricRing(
                  fraction: score == null ? null : score / 100,
                  color: color,
                  value: score == null ? '—' : '$score',
                  unit: score == null ? null : '%',
                  label: 'Recovery',
                  size: 176,
                  stroke: 14,
                  semanticsLabel: score == null
                      ? 'Recovery calibrating'
                      : 'Recovery $score percent, ${recoveryWord(score)}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Tag(
            score == null
                ? waiting > 0
                      ? 'Calibrating · $waiting more night${waiting == 1 ? '' : 's'}'
                      : 'Needs last night’s sleep'
                : recovery!.provisional
                ? '${recoveryWord(score)} · provisional'
                : recoveryWord(score),
            color: color,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  color: AppColors.strain,
                  label: 'Strain',
                  value: strain == null ? '—' : strain.toStringAsFixed(1),
                  suffix: '/21',
                  fraction: strain == null ? null : strain / strainMax,
                  detail: 'target ${target.low.round()}–${target.high.round()}',
                  onTap: onStrain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  color: AppColors.sleep,
                  label: 'Sleep',
                  value: sleepPct == null ? '—' : '$sleepPct',
                  suffix: '%',
                  fraction: sleepPct == null ? null : sleepPct / 100,
                  detail: p.sleep.lastNight == null
                      ? 'no main sleep'
                      : '${formatDurationMinutes(p.sleep.lastNight!.asleepMinutes)} of '
                            '${formatDurationMinutes(p.sleep.baselineNeed + p.sleep.debtNeed)}',
                  onTap: onSleep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.color,
    required this.label,
    required this.value,
    required this.suffix,
    required this.fraction,
    required this.detail,
    required this.onTap,
  });

  final Color color;
  final String label;
  final String value;
  final String suffix;
  final double? fraction;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bg.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: (fraction ?? 0).clamp(0.0, 1.0),
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppColors.surfaceHigher,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(value, style: AppType.numS.copyWith(fontSize: 20)),
                        Text(
                          suffix,
                          style: AppType.unit.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// Calories eaten (Health Connect) against calories burned (Becel).
class _FuelCard extends StatelessWidget {
  const _FuelCard({required this.snapshot, required this.onTap});

  final HealthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final energy = snapshot.performance.energy;
    final activity = snapshot.activity;
    final eaten = activity?.intakeKcalToday;
    final burned = energy?.today.totalKcal;
    final projected = energy?.projectedToday;
    final balance = eaten == null || projected == null
        ? null
        : eaten - projected;
    final scale = math.max(1.0, [eaten ?? 0, projected ?? 0].reduce(math.max));
    return PanelCard(
      title: 'Calories',
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.burned,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FuelNumber(
                  label: 'Burned',
                  value: burned,
                  sub: projected == null
                      ? 'needs profile'
                      : '~${formatNumber(projected.round())} by midnight',
                  color: AppColors.burned,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FuelNumber(
                  label: 'Eaten',
                  value: eaten,
                  sub: eaten == null
                      ? activity?.canReadNutrition == true
                            ? 'nothing logged yet'
                            : 'allow nutrition access'
                      : '${activity!.mealsToday} entr${activity.mealsToday == 1 ? 'y' : 'ies'}'
                            '${activity.intakeSources.isEmpty ? '' : ' · ${activity.intakeSources.first}'}',
                  color: AppColors.intake,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FuelBar(
            label: 'Burn',
            value: projected ?? 0,
            done: burned ?? 0,
            max: scale,
            color: AppColors.burned,
          ),
          const SizedBox(height: 8),
          _FuelBar(
            label: 'Food',
            value: eaten ?? 0,
            done: eaten ?? 0,
            max: scale,
            color: AppColors.intake,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  balance == null
                      ? 'Balance shows once food is logged in Google Health.'
                      : balance < 0
                      ? '${formatNumber(balance.abs().round())} kcal deficit if you eat nothing more'
                      : '${formatNumber(balance.round())} kcal surplus vs projected burn',
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (energy?.deviceDelta != null &&
                  energy!.deviceDelta!.abs() >= 50)
                Tag(
                  'Fitbit ${energy.deviceDelta! > 0 ? '+' : '−'}${formatNumber(energy.deviceDelta!.abs().round())}',
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelNumber extends StatelessWidget {
  const _FuelNumber({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final double? value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value == null ? '—' : formatNumber(value!.round()),
              style: AppType.numM.copyWith(fontSize: 32),
            ),
            const SizedBox(width: 4),
            const Text('kcal', style: AppType.unit),
          ],
        ),
      ),
      const SizedBox(height: 2),
      Text(
        sub,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption.copyWith(fontSize: 11.5),
      ),
    ],
  );
}

class _FuelBar extends StatelessWidget {
  const _FuelBar({
    required this.label,
    required this.value,
    required this.done,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double done;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 36,
        child: Text(label, style: AppType.caption.copyWith(fontSize: 11)),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigher,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Projected remainder, faint.
                Container(
                  width: width * (value / max).clamp(0.0, 1.0),
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(
                  width: width * (done / max).clamp(0.0, 1.0),
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
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
                      : '${formatNumber(walking)} real walking',
                  maxLines: 1,
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

class _ProteinTile extends StatelessWidget {
  const _ProteinTile({required this.snapshot});

  final HealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final protein = snapshot.activity?.proteinGToday;
    final weight = snapshot.profile?.weightKg;
    final target = weight == null ? null : (weight * proteinPerKg).round();
    return PanelCard(
      title: 'Protein',
      icon: Icons.egg_alt_rounded,
      accent: AppColors.intake,
      onTap: () => context.push('/energy'),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: protein == null || target == null
                  ? 0
                  : (protein / target).clamp(0.0, 1.0),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: AppColors.intake,
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
                        protein == null ? '—' : protein.round().toString(),
                        style: AppType.numM.copyWith(fontSize: 24),
                      ),
                      const SizedBox(width: 2),
                      const Text('g', style: AppType.unit),
                    ],
                  ),
                ),
                Text(
                  target == null ? 'needs weight' : 'of ${target}g (1.6 g/kg)',
                  maxLines: 1,
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
                ? 'needs 14 days'
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
