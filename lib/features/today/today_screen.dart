import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  _TopBar(
                    loading: _health.loading,
                    connected: snapshot?.airMatched ?? false,
                    onData: () => context.go('/data'),
                    onSettings: () => openSettings(context),
                  ),
                  const SizedBox(height: 20),
                  _Greeting(now: now),
                  const SizedBox(height: 18),
                  _CheckInCard(
                    checkIn: checkIn,
                    onTap: () => showCheckInSheet(context),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot == null)
                    _InitialState(
                      loading: _health.loading,
                      error: _health.error,
                      onRetry: () => _health.refresh(force: true),
                      onData: () => context.go('/data'),
                    )
                  else ...[
                    if (!snapshot.hasAccess)
                      StateCard(
                        icon: Icons.link_rounded,
                        color: AppColors.yellow,
                        title: snapshot.isAvailable
                            ? 'Connect your health data'
                            : 'Health Connect is not available',
                        body: snapshot.isAvailable
                            ? 'Allow Fitbit Air records in Health Connect so '
                                  'Becel can show your sleep, recovery range, '
                                  'and activity.'
                            : 'This phone does not expose Health Connect. '
                                  'Becel needs it to read Fitbit Air records.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
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
                            snapshot.error ??
                            'Health Connect is connected, but no records have '
                                'arrived. Check that the Fitbit app is syncing '
                                'and sharing with Health Connect.',
                        actionLabel: 'Open data sources',
                        onAction: () => context.go('/data'),
                      )
                    else ...[
                      _RecoveryCard(
                        context: snapshot.recoveryContext,
                        loadedAt: snapshot.loadedAt,
                        onTap: () => context.push('/recovery'),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _BriefTile(
                                icon: Icons.bedtime_rounded,
                                color: AppColors.blue,
                                label: 'SLEEP · LAST NIGHT',
                                value: snapshot.selectedNight == null
                                    ? '—'
                                    : formatDurationMinutes(
                                        snapshot.selectedNight!.minutes,
                                      ),
                                detail: _sleepDetail(snapshot),
                                footnote: _sleepFootnote(snapshot),
                                onTap: () => context.go('/sleep'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _BriefTile(
                                icon: Icons.directions_run_rounded,
                                color: AppColors.orange,
                                label: 'AEROBIC · HR ESTIMATE',
                                value: snapshot.activityEstimate == null
                                    ? '—'
                                    : '≈${snapshot.activityEstimate!.displayedEquivalentMinutes} min',
                                detail: _activityDetail(snapshot),
                                footnote: _activityFootnote(snapshot),
                                onTap: () => context.go('/activity'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FocusCard(
                        focus: _focus(snapshot, checkIn),
                        onAction: () => _runFocus(context, snapshot, checkIn),
                      ),
                      const SizedBox(height: 22),
                      SectionHeader(
                        title: 'Today’s movement',
                        action: 'Activity',
                        onAction: () => context.go('/activity'),
                      ),
                      const SizedBox(height: 10),
                      _MovementCard(
                        snapshot: snapshot,
                        onTap: () => context.go('/activity'),
                      ),
                      const SizedBox(height: 22),
                      const SectionHeader(
                        title: 'Latest signals',
                        caption: 'MEASURED',
                      ),
                      const SizedBox(height: 10),
                      _SignalsCard(
                        snapshot: snapshot,
                        onHeart: () => context.push('/heart'),
                        onBody: () => context.push('/biology'),
                      ),
                    ],
                    if (snapshot.error != null && snapshot.hasAnyRecord) ...[
                      const SizedBox(height: 14),
                      InfoNote(
                        text:
                            'Some health data could not refresh: '
                            '${snapshot.error}',
                        textColor: AppColors.yellow,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _health.refresh(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SourceLine(
                      text:
                          'Fitbit Air via Health Connect · refreshed '
                          '${formatAgo(snapshot.loadedAt)}',
                      icon: Icons.sync_rounded,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const TrustFooter(
                    text:
                        'BECEL ESTIMATES ARE WELLNESS CONTEXT, NOT MEDICAL '
                        'ADVICE',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  FocusRecommendation _focus(HealthSnapshot snapshot, CheckIn? checkIn) {
    final strengthDays = strengthDaysInWindow(
      workouts: snapshot.strengthCandidates,
      loggedDays: _local.log.strengthDates,
      now: snapshot.loadedAt,
    );
    return buildFocusRecommendation(
      sleep: snapshot.sleepTrend,
      strengthDays: strengthDays,
      activity: snapshot.activityEstimate,
      checkInTags: checkIn?.tags ?? const <String>{},
    );
  }

  Future<void> _runFocus(
    BuildContext context,
    HealthSnapshot snapshot,
    CheckIn? checkIn,
  ) async {
    final focus = _focus(snapshot, checkIn);
    switch (focus.kind) {
      case FocusKind.strength:
        final logged = await showStrengthLogSheet(context);
        if (logged && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Strength day logged.')));
        }
      case FocusKind.aerobic:
        if (context.mounted) context.go('/activity');
      case FocusKind.maintain:
        if (context.mounted) context.go('/history');
      case FocusKind.sleepDuration:
      case FocusKind.sleepRegularity:
      case FocusKind.recover:
        if (context.mounted) context.go('/sleep');
    }
  }

  String _sleepDetail(HealthSnapshot snapshot) {
    final night = snapshot.selectedNight;
    if (night == null) return 'No qualifying session yet';
    final inBed = night.end.difference(night.start).inMinutes;
    return 'asleep · ${formatDurationMinutes(inBed)} in bed';
  }

  String _sleepFootnote(HealthSnapshot snapshot) {
    final trend = snapshot.sleepTrend;
    if (!trend.hasData) return 'Adult range 7–9h · stages are context only';
    final average = formatDurationMinutes(trend.averageMinutes!);
    return '${trend.nights}-night avg $average · adult range 7–9h';
  }

  String _activityDetail(HealthSnapshot snapshot) {
    final activity = snapshot.activityEstimate;
    if (activity == null) return 'Needs heart-rate coverage';
    if (activity.usableDays >= 7) return 'heart rate on all 7 days';
    return 'lower bound \u00b7 ${activity.usableDays}/7 days with HR';
  }

  String _activityFootnote(HealthSnapshot snapshot) {
    final activity = snapshot.activityEstimate;
    if (activity == null) {
      return 'Add age and allow heart-rate access for a personal estimate';
    }
    if (activity.potentialEquivalentMinutes >
        activity.displayedEquivalentMinutes) {
      return 'Up to ${activity.potentialEquivalentMinutes} min if every day '
          'had coverage';
    }
    return 'Heart-rate coverage was available every day this week.';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.loading,
    required this.connected,
    required this.onData,
    required this.onSettings,
  });

  final bool loading;
  final bool connected;
  final VoidCallback onData;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
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
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BECEL',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 2),
              Text('FITNESS COMPANION', style: AppType.eyebrow),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final weekday = const [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ][now.weekday - 1];
    final month = const [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ][now.month - 1];
    final title = now.hour < 12 ? 'Morning brief' : 'Today’s brief';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$weekday  ·  $month ${now.day}',
          style: AppType.eyebrow.copyWith(
            color: AppColors.teal,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: AppType.screenTitle),
        const SizedBox(height: 6),
        const Text(
          'Your usual range, last night’s sleep, and one thing to try.',
          style: AppType.body,
        ),
      ],
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
      padding: const EdgeInsets.all(14),
      color: AppColors.surface,
      child: Row(
        children: [
          IconChip(
            icon: existing == null
                ? Icons.wb_sunny_outlined
                : Icons.check_circle_outline_rounded,
            color: existing == null ? AppColors.yellow : AppColors.green,
            size: 42,
            iconSize: 20,
            radius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null
                      ? 'How do you feel this morning?'
                      : 'Checked in: ${existing.label}',
                  style: AppType.rowTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  existing == null
                      ? 'One tap adds context to today’s suggestion. Stored '
                            'on this phone.'
                      : existing.note ??
                            'Tap to change how you feel or add a note.',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            existing == null
                ? Icons.add_circle_outline_rounded
                : Icons.edit_outlined,
            color: AppColors.teal,
            size: 20,
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
        body: 'Loading last night’s sleep, heart signals, and activity.',
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

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.context,
    required this.loadedAt,
    required this.onTap,
  });

  final RecoveryContext context;
  final DateTime loadedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext widgetContext) {
    final current = context.current;
    if (current == null) {
      return SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: AppColors.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconChip(
              icon: Icons.energy_savings_leaf_rounded,
              color: AppColors.teal,
              size: 42,
              iconSize: 20,
              radius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recovery is calibrating',
                    style: AppType.rowTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(context.detail, style: AppType.caption),
                  const SizedBox(height: 6),
                  const Text(
                    'Becel needs a few scored mornings before it can show your '
                    'usual range.',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final color = switch (context.band) {
      RecoveryBand.below => AppColors.yellow,
      RecoveryBand.above => AppColors.blue,
      RecoveryBand.within => AppColors.teal,
      RecoveryBand.unknown => AppColors.teal,
    };
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      color: const Color(0xFF14201B),
      borderColor: color.withValues(alpha: 0.22),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.energy_savings_leaf_rounded, color: color, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'RECOVERY · PERSONAL RANGE',
                  style: AppType.eyebrow.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  context.provisional ? 'BUILDING' : 'EXPERIMENTAL',
                  style: AppType.eyebrow.copyWith(
                    color: color,
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(context.detail, style: AppType.caption),
          const SizedBox(height: 12),
          RangeGauge(
            value: current,
            low: context.low,
            high: context.high,
            color: color,
            bandLabel: context.provisional ? 'building baseline' : null,
            semanticsLabel:
                'Recovery ${context.label.toLowerCase()}. Today $current out of '
                '100. Usual range ${context.low} to ${context.high}.',
          ),
          const SizedBox(height: 10),
          Text(
            'Built from overnight HRV, resting heart rate, sleep duration, and '
            'your morning check-in. Each signal is shown in Recovery detail.',
            style: AppType.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          SourceLine(
            text: 'Calculated · Fitbit Air · refreshed ${formatAgo(loadedAt)}',
            icon: Icons.calculate_outlined,
          ),
        ],
      ),
    );
  }
}

class _BriefTile extends StatelessWidget {
  const _BriefTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
    required this.footnote,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;
  final String footnote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.eyebrow.copyWith(
                    color: color,
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: AppType.numM.copyWith(fontSize: 25)),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.focus, required this.onAction});

  final FocusRecommendation focus;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: const Color(0xFF17211A),
      borderColor: AppColors.teal.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, size: 16, color: AppColors.green),
              const SizedBox(width: 7),
              Text(
                'ONE THING THIS WEEK',
                style: AppType.eyebrow.copyWith(color: AppColors.green),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            focus.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(focus.body, style: AppType.body),
          const SizedBox(height: 10),
          Text(
            'WHY · ${focus.why}',
            style: AppType.caption.copyWith(fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: BorderSide(color: AppColors.teal.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(focus.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.snapshot, required this.onTap});

  final HealthSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final steps = summary?.stepCount;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Column(
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.directions_walk_rounded,
                color: AppColors.green,
                size: 42,
                iconSize: 20,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps == null
                          ? 'No steps yet today'
                          : _formatNumber(steps),
                      style: steps == null
                          ? AppType.rowTitle
                          : AppType.numM.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      steps == null
                          ? 'Waiting for the next Fitbit Air sync'
                          : 'steps today · measured by Fitbit Air',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          if (summary?.workoutType != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  size: 16,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary!.workoutType!,
                    style: AppType.rowTitle.copyWith(fontSize: 14),
                  ),
                ),
                Text(
                  '${summary.workoutDurationMinutes ?? 0} min',
                  style: AppType.caption,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalsCard extends StatelessWidget {
  const _SignalsCard({
    required this.snapshot,
    required this.onHeart,
    required this.onBody,
  });

  final HealthSnapshot snapshot;
  final VoidCallback onHeart;
  final VoidCallback onBody;

  @override
  Widget build(BuildContext context) {
    final heart = snapshot.heart;
    final body = snapshot.body;
    final rows = <Widget>[];
    if (heart?.restingHrBpm != null) {
      rows.add(
        _SignalRow(
          icon: Icons.favorite_rounded,
          color: AppColors.red,
          title: 'Resting heart rate',
          value: '${heart!.restingHrBpm} bpm',
          onTap: onHeart,
        ),
      );
    }
    if (heart?.hrvRmssd != null) {
      rows.add(
        _SignalRow(
          icon: Icons.monitor_heart_rounded,
          color: AppColors.teal,
          title: 'HRV (RMSSD)',
          value: '${heart!.hrvRmssd!.round()} ms',
          onTap: onHeart,
        ),
      );
    }
    if (body?.spo2Percent != null) {
      rows.add(
        _SignalRow(
          icon: Icons.bloodtype_rounded,
          color: AppColors.blue,
          title: 'Blood oxygen',
          value: '${body!.spo2Percent!.round()}%',
          onTap: onBody,
        ),
      );
    }
    if (body?.respiratoryRate != null) {
      rows.add(
        _SignalRow(
          icon: Icons.air_rounded,
          color: AppColors.blue,
          title: 'Respiratory rate',
          value: '${body!.respiratoryRate!.toStringAsFixed(1)}/min',
          onTap: onBody,
        ),
      );
    }

    if (rows.isEmpty) {
      return const StateCard(
        title: 'No signals recorded yet',
        body:
            'Heart and body signals appear after Fitbit Air shares them with '
            'Health Connect.',
        icon: Icons.sensors_off_rounded,
        color: AppColors.yellow,
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.surface,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppType.rowTitle)),
            Text(value, style: AppType.numS.copyWith(fontSize: 14)),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
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
