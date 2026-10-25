import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
import '../../domain/estimates.dart';
import '../../domain/performance.dart';
import '../../domain/strain.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/rings.dart';
import '../activity/strength_log_sheet.dart';
import '../shell/shell_screen.dart';
import 'check_in_sheet.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _health = HealthStore.instance;
  final _local = LocalStore.instance;
  late final Listenable _listenable = Listenable.merge([_health, _local]);

  @override
  void initState() {
    super.initState();
    _health.ensureLoaded();
    _local.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _listenable,
          builder: (context, _) {
            final snapshot = _health.snapshot;
            final now = DateTime.now();
            final checkIn = _local.log.checkInFor(now);
            return RefreshIndicator(
              onRefresh: () => _health.refresh(force: true),
              color: AppColors.green,
              backgroundColor: AppColors.surfaceHigh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                children: [
                  _TopBar(
                    now: now,
                    loading: _health.loading,
                    connected: snapshot?.airMatched ?? false,
                    onData: () => context.push('/data'),
                    onSettings: () => openSettings(context),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot == null)
                    _InitialState(
                      loading: _health.loading,
                      error: _health.error,
                      onRetry: () => _health.refresh(force: true),
                      onData: () => context.push('/data'),
                    )
                  else if (!snapshot.hasAccess)
                    StateCard(
                      icon: Icons.link_rounded,
                      color: AppColors.yellow,
                      title: snapshot.isAvailable
                          ? 'Connect your health data'
                          : 'Health Connect is not available',
                      body: snapshot.isAvailable
                          ? 'Allow Fitbit Air records in Health Connect so '
                                'Becel can calculate recovery, strain, and sleep.'
                          : 'This phone does not expose Health Connect. '
                                'Becel needs it to read Fitbit Air records.',
                      actionLabel: 'Open data sources',
                      onAction: () => context.push('/data'),
                    )
                  else if (snapshot.error != null && !snapshot.hasAnyRecord)
                    StateCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.red,
                      title: 'Health data could not load',
                      body: snapshot.error!,
                      actionLabel: 'Retry',
                      onAction: () => _health.refresh(force: true),
                    )
                  else if (!snapshot.hasAnyRecord)
                    StateCard(
                      icon: Icons.sensors_off_rounded,
                      color: AppColors.yellow,
                      title: 'No Fitbit Air records yet',
                      body:
                          'Health Connect is connected, but no records have '
                          'arrived. Check that the Fitbit app is syncing and '
                          'sharing with Health Connect.',
                      actionLabel: 'Open data sources',
                      onAction: () => context.push('/data'),
                    )
                  else
                    ..._dashboard(context, snapshot, checkIn),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _dashboard(
    BuildContext context,
    HealthSnapshot snapshot,
    CheckIn? checkIn,
  ) {
    final p = snapshot.performance;
    final needsProfile = snapshot.profile?.hasEnergyInputs != true;
    return [
      _RingsHero(
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
      _PlanCard(
        plan: p.plan,
        strainNow: p.today?.strain,
        onLog: () => showStrengthLogSheet(context),
      ),
      const SizedBox(height: 12),
      _CheckInCard(checkIn: checkIn, onTap: () => showCheckInSheet(context)),
      if (needsProfile) ...[
        const SizedBox(height: 12),
        StateCard(
          icon: Icons.person_outline_rounded,
          color: AppColors.teal,
          title: 'Finish your profile',
          body:
              'Age, sex, height, and weight unlock calories, strain, and '
              'personal heart-rate zones. Body fat % makes calories more '
              'accurate for muscular builds.',
          actionLabel: 'Add profile',
          onAction: () => openSettings(context),
        ),
      ],
      const SizedBox(height: 12),
      _EnergyCard(performance: p, onTap: () => context.push('/energy')),
      const SizedBox(height: 12),
      _LoadCard(performance: p, onTap: () => context.go('/training')),
      const SizedBox(height: 12),
      _VitalsCard(snapshot: snapshot, onTap: () => context.push('/vitals')),
      if (snapshot.error != null) ...[
        const SizedBox(height: 12),
        InfoNote(
          text: 'Some data could not refresh: ${snapshot.error}',
          textColor: AppColors.yellow,
        ),
      ],
      const SizedBox(height: 16),
      SourceLine(
        text:
            'Fitbit Air via Health Connect · calculated on this phone · '
            'refreshed ${formatAgo(snapshot.loadedAt)}',
        icon: Icons.sync_rounded,
      ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.now,
    required this.loading,
    required this.connected,
    required this.onData,
    required this.onSettings,
  });

  final DateTime now;
  final bool loading;
  final bool connected;
  final VoidCallback onData;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatShortDate(now).toUpperCase(),
                style: AppType.eyebrow.copyWith(color: AppColors.teal),
              ),
              const SizedBox(height: 4),
              Text(greeting, style: AppType.screenTitle),
            ],
          ),
        ),
        _RoundButton(
          icon: loading
              ? Icons.sync_rounded
              : connected
              ? Icons.sensors_rounded
              : Icons.sensors_off_rounded,
          color: connected ? AppColors.green : AppColors.yellow,
          tooltip: connected ? 'Data sources connected' : 'Set up data sources',
          onTap: onData,
        ),
        const SizedBox(width: 8),
        _RoundButton(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    ),
  );
}

class _RingsHero extends StatelessWidget {
  const _RingsHero({
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
    final strain = p.today?.strain;
    final target = p.plan.target;
    final sleepPct = p.sleep.performancePercent;
    final waiting = p.recovery.nightsUntilScore;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 1.4,
          colors: [
            recoveryColor(score).withValues(alpha: 0.13),
            AppColors.surface,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = ((constraints.maxWidth - 12) / 3 - 8).clamp(80.0, 108.0);
          return _rings(
            ring,
            score,
            strain,
            target,
            sleepPct,
            waiting,
            recovery,
          );
        },
      ),
    );
  }

  Widget _rings(
    double ring,
    int? score,
    double? strain,
    StrainTarget target,
    int? sleepPct,
    int waiting,
    RecoveryEstimate? recovery,
  ) {
    final p = performance;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RingButton(
              onTap: onRecovery,
              child: MetricRing(
                size: ring,
                fraction: score == null ? null : score / 100,
                color: recoveryColor(score),
                value: score == null ? '—' : '$score',
                unit: score == null ? null : '%',
                label: 'RECOVERY',
                semanticsLabel: score == null
                    ? 'Recovery calibrating'
                    : 'Recovery $score percent, ${recoveryWord(score)}',
              ),
            ),
            _RingButton(
              onTap: onStrain,
              child: MetricRing(
                size: ring,
                fraction: strain == null ? null : strain / strainMax,
                color: AppColors.strain,
                value: strain == null ? '—' : strain.toStringAsFixed(1),
                label: 'STRAIN',
                bandFrom: target.low / strainMax,
                bandTo: target.high / strainMax,
                semanticsLabel: strain == null
                    ? 'Strain unavailable'
                    : 'Strain ${strain.toStringAsFixed(1)} of 21, target '
                          '${target.low.round()} to ${target.high.round()}',
              ),
            ),
            _RingButton(
              onTap: onSleep,
              child: MetricRing(
                size: ring,
                fraction: sleepPct == null ? null : sleepPct / 100,
                color: AppColors.sleep,
                value: sleepPct == null ? '—' : '$sleepPct',
                unit: sleepPct == null ? null : '%',
                label: 'SLEEP',
                semanticsLabel: sleepPct == null
                    ? 'Sleep performance unavailable'
                    : 'Sleep performance $sleepPct percent of need',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _RingCaption(
                text: score == null
                    ? waiting > 0
                          ? '$waiting more night${waiting == 1 ? '' : 's'}'
                          : 'Needs last night'
                    : recoveryWord(score),
                color: recoveryColor(score),
              ),
            ),
            Expanded(
              child: _RingCaption(
                text: strain == null
                    ? 'Needs HR + age'
                    : 'Target ${target.low.round()}–${target.high.round()}',
                color: AppColors.strain,
              ),
            ),
            Expanded(
              child: _RingCaption(
                text: p.sleep.lastNight == null
                    ? 'No main sleep'
                    : formatDurationMinutes(p.sleep.lastNight!.asleepMinutes),
                color: AppColors.sleep,
              ),
            ),
          ],
        ),
        if (recovery != null && recovery.provisional) ...[
          const SizedBox(height: 10),
          Text(
            'Provisional · ${recovery.hrvBaselineDays} of 10 baseline nights',
            style: AppType.caption.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _RingButton extends StatelessWidget {
  const _RingButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Padding(padding: const EdgeInsets.all(4), child: child),
  );
}

class _RingCaption extends StatelessWidget {
  const _RingCaption({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppType.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final BodyAlert alert;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bandRed.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.bandRed.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.bandRed,
          size: 20,
        ),
        const SizedBox(width: 10),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.strainNow,
    required this.onLog,
  });

  final DailyPlan plan;
  final double? strainNow;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final color = switch (plan.tone) {
      PlanTone.push => AppColors.bandGreen,
      PlanTone.train => AppColors.bandYellow,
      PlanTone.recover => AppColors.bandRed,
      PlanTone.rest => AppColors.bandRed,
    };
    final target = plan.target;
    final now = strainNow ?? 0;
    final remaining = (target.low - now).clamp(0, strainMax);
    return PanelCard(
      title: 'TODAY’S PLAN',
      icon: Icons.flag_rounded,
      accent: color,
      trailing: Tag(target.label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.headline,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(plan.session, style: AppType.body),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Text(
                  'STRAIN ${now.toStringAsFixed(1)}',
                  overflow: TextOverflow.ellipsis,
                  style: AppType.eyebrow.copyWith(color: AppColors.strain),
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
                  style: AppType.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearMeter(
            value: now,
            max: strainMax,
            color: AppColors.strain,
            bandFrom: target.low,
            bandTo: target.high,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('0', style: AppType.caption.copyWith(fontSize: 10)),
              const Spacer(),
              Text(
                'target ${target.low.round()}–${target.high.round()}',
                style: AppType.caption.copyWith(fontSize: 10),
              ),
              const Spacer(),
              Text('21', style: AppType.caption.copyWith(fontSize: 10)),
            ],
          ),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final note in plan.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(note, style: AppType.note)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.fitness_center_rounded, size: 17),
              label: const Text('Log a lift'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkIn, required this.onTap});

  final CheckIn? checkIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final existing = checkIn;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Icon(
            existing == null
                ? Icons.wb_sunny_outlined
                : Icons.check_circle_rounded,
            color: existing == null ? AppColors.yellow : AppColors.green,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              existing == null
                  ? 'How do you feel this morning?'
                  : 'Checked in: ${existing.label}',
              style: AppType.rowTitle,
            ),
          ),
          Icon(
            existing == null ? Icons.add_rounded : Icons.edit_outlined,
            color: AppColors.teal,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.performance, required this.onTap});

  final Performance performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final energy = performance.energy;
    if (energy == null) {
      return PanelCard(
        title: 'CALORIES',
        icon: Icons.local_fire_department_rounded,
        accent: AppColors.energy,
        onTap: onTap,
        child: const Text(
          'Needs your body profile and today’s heart rate.',
          style: AppType.note,
        ),
      );
    }
    final today = energy.today;
    final delta = energy.deviceDelta;
    return PanelCard(
      title: 'CALORIES · SO FAR',
      icon: Icons.local_fire_department_rounded,
      accent: AppColors.energy,
      onTap: onTap,
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
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatNumber(today.totalKcal.round()),
                        style: AppType.numXl.copyWith(fontSize: 40),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 6),
                        child: Text('kcal', style: AppType.unit),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: StatBlock(
                    label: 'BY MIDNIGHT',
                    value: '~${formatNumber(energy.projectedToday.round())}',
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'ACTIVE',
                  value: formatNumber(today.activeKcal.round()),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'RESTING',
                  value: formatNumber(today.restingKcal.round()),
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'MAINTENANCE',
                  value: energy.maintenanceKcal == null
                      ? '—'
                      : formatNumber(energy.maintenanceKcal!.round()),
                  delta: energy.maintenanceKcal == null
                      ? 'needs 3 full days'
                      : 'avg of ${energy.history.length} days',
                ),
              ),
            ],
          ),
          if (delta != null && delta.abs() >= 50) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigher.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                delta > 0
                    ? 'Fitbit says ${formatNumber(energy.deviceTotalToday!)} '
                          '(+${formatNumber(delta.round())}). Becel ignores HR '
                          'below ${today.flexBpm} bpm and '
                          '${formatNumber(today.filteredSteps)} incidental steps.'
                    : 'Fitbit says ${formatNumber(energy.deviceTotalToday!)} '
                          '(${formatNumber(delta.round())}).',
                style: AppType.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.performance, required this.onTap});

  final Performance performance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final load = performance.load;
    final days = performance.strainDays;
    final week = days.length <= 7 ? days : days.sublist(days.length - 7);
    final status = load?.status ?? LoadStatus.calibrating;
    final color = switch (status) {
      LoadStatus.productive => AppColors.bandGreen,
      LoadStatus.maintaining => AppColors.teal,
      LoadStatus.detraining => AppColors.blue,
      LoadStatus.overreaching => AppColors.bandYellow,
      LoadStatus.spike => AppColors.bandRed,
      LoadStatus.calibrating => AppColors.textTertiary,
    };
    return PanelCard(
      title: 'TRAINING LOAD',
      icon: Icons.stacked_line_chart_rounded,
      accent: AppColors.strain,
      onTap: onTap,
      trailing: Tag(status.label, color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: '7-DAY (FATIGUE)',
                  value: load == null
                      ? '—'
                      : load.acuteStrain.toStringAsFixed(1),
                  delta: 'avg daily strain',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: '28-DAY (FITNESS)',
                  value: load == null
                      ? '—'
                      : load.chronicStrain.toStringAsFixed(1),
                  delta: 'avg daily strain',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'RATIO',
                  value: load?.acwr == null
                      ? '—'
                      : load!.acwr!.toStringAsFixed(2),
                  delta: 'sweet spot 0.8–1.3',
                ),
              ),
            ],
          ),
          if (week.isNotEmpty) ...[
            const SizedBox(height: 14),
            DayBars(
              values: [for (final d in week) d.hasData ? d.strain : null],
              labels: [for (final d in week) formatDayShort(d.date)[0]],
              maxValue: strainMax,
              height: 54,
              valueLabel: (v) => v.toStringAsFixed(0),
              colorFor: (i, v) => AppColors.strain.withValues(
                alpha: i == week.length - 1 ? 1 : 0.45,
              ),
              semanticsLabel: 'Daily strain, last 7 days',
            ),
          ],
          const SizedBox(height: 8),
          Text(status.advice, style: AppType.caption),
        ],
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.snapshot, required this.onTap});

  final HealthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = snapshot.performance;
    final r = p.recoveryEstimate;
    String signed(double v, {int digits = 0}) =>
        '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(digits)}';
    Color tone(double v, {bool higherIsBetter = true, double tolerance = 0}) {
      if (v.abs() <= tolerance) return AppColors.textTertiary;
      final good = higherIsBetter ? v > 0 : v < 0;
      return good ? AppColors.bandGreen : AppColors.bandYellow;
    }

    final rhr = r?.restingHrCurrent ?? snapshot.heart?.restingHrBpm?.toDouble();
    final hrv = r?.hrvCurrent;
    final resp = snapshot.body?.respiratoryRate;
    final skin = p.skinTempDelta;
    return PanelCard(
      title: 'OVERNIGHT VITALS',
      icon: Icons.monitor_heart_rounded,
      accent: AppColors.teal,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: StatBlock(
              label: 'RHR',
              value: rhr == null ? '—' : rhr.round().toString(),
              unit: 'bpm',
              delta: r == null ? null : '${signed(r.restingHrChange)} vs base',
              deltaColor: r == null
                  ? null
                  : tone(
                      r.restingHrChange,
                      higherIsBetter: false,
                      tolerance: 1,
                    ),
            ),
          ),
          Expanded(
            child: StatBlock(
              label: 'HRV',
              value: hrv == null ? '—' : hrv.round().toString(),
              unit: 'ms',
              delta: r == null
                  ? 'night median'
                  : '${signed(r.hrvChangePercent)}% vs base',
              deltaColor: r == null
                  ? null
                  : tone(r.hrvChangePercent, tolerance: 4),
            ),
          ),
          Expanded(
            child: StatBlock(
              label: 'RESP',
              value: resp == null ? '—' : resp.toStringAsFixed(1),
              unit: '/min',
              delta: p.respiratoryDelta == null
                  ? null
                  : '${signed(p.respiratoryDelta!, digits: 1)} vs base',
              deltaColor: p.respiratoryDelta == null
                  ? null
                  : tone(
                      p.respiratoryDelta!,
                      higherIsBetter: false,
                      tolerance: 0.5,
                    ),
            ),
          ),
          Expanded(
            child: StatBlock(
              label: 'SKIN',
              value: skin == null ? '—' : signed(skin, digits: 1),
              unit: '°C',
              delta: skin == null ? null : 'vs baseline',
              deltaColor: skin == null
                  ? null
                  : tone(skin, higherIsBetter: false, tolerance: 0.3),
            ),
          ),
        ],
      ),
    );
  }
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
        icon: Icons.error_outline_rounded,
        color: AppColors.red,
        title: 'Health data could not load',
        body: error!,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return StateCard(
      icon: Icons.link_rounded,
      color: AppColors.yellow,
      title: 'Set up Health Connect',
      body:
          'Becel reads Fitbit Air records from Health Connect. Nothing is '
          'uploaded.',
      actionLabel: 'Open data sources',
      onAction: onData,
    );
  }
}
