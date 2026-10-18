import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../domain/estimates.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';

class HealthHubScreen extends StatefulWidget {
  const HealthHubScreen({super.key});

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final _health = HealthConnectService.instance;

  HealthConnectInspection? _inspection;
  HealthSummary? _summary;
  HeartDetail? _heart;
  ActivityDetail? _activity;
  BodyDetail? _body;
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
    final inspection = await _health.inspect();
    HealthSummary? summary;
    HeartDetail? heart;
    ActivityDetail? activity;
    BodyDetail? body;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      final results = await Future.wait<Object>([
        _health.readSummary(),
        _health.readHeartDetail(),
        _health.readActivityDetail(),
        _health.readBodyDetail(),
      ]);
      summary = results[0] as HealthSummary;
      heart = results[1] as HeartDetail;
      activity = results[2] as ActivityDetail;
      body = results[3] as BodyDetail;
    }
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _summary = summary;
      _heart = heart;
      _activity = activity;
      _body = body;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    final summary = _summary;
    final heart = _heart;
    final activity = _activity;
    final body = _body;
    final partial =
        inspection != null &&
        inspection.isAvailable &&
        !inspection.allPermissionsGranted;

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
                eyebrow: 'EVERY MEASUREMENT',
                title: 'Health',
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
                        label: inspection?.stateLabel ?? 'Check status',
                        color: inspection?.allPermissionsGranted == true
                            ? AppColors.green
                            : AppColors.yellow,
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                'Measured Fitbit Air data, plus calculations Becel labels as '
                'estimates. Tap a card for detail.',
                style: AppType.note,
              ),
              const SizedBox(height: 16),
              _ModuleCard(
                icon: Icons.favorite_rounded,
                color: AppColors.red,
                title: 'Heart',
                value: summary?.heartRateBpm != null
                    ? '${summary!.heartRateBpm} bpm'
                    : '—',
                note: _heartNote(summary, heart),
                needsAccess: heart != null && !heart.canReadHeartRate,
                onTap: () => context.push('/health/heart'),
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.nightlight_round,
                color: AppColors.blue,
                title: 'Sleep',
                value: summary?.sleepSessionMinutes != null
                    ? formatDurationMinutes(summary!.sleepSessionMinutes!)
                    : '—',
                note: _sleepNote(summary),
                needsAccess: summary != null && !summary.canReadSleep,
                onTap: () => context.push('/health/sleep'),
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.energy_savings_leaf_rounded,
                color: AppColors.green,
                title: 'Recovery',
                value: _recoveryValue(heart),
                note: _recoveryNote(heart),
                needsAccess:
                    heart != null &&
                    (!heart.canReadHrv || !heart.canReadRestingHr),
                onTap: () => context.push('/health/recovery'),
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.bolt_rounded,
                color: AppColors.red,
                title: 'Strain',
                value: heart?.canReadHeartRate == true
                    ? '${strainEstimateFromZones(heart!.zoneMinutes)}'
                    : '—',
                note: heart?.canReadHeartRate == true
                    ? 'Today\u2019s load from heart-rate zones'
                    : 'Needs heart-rate access',
                needsAccess: heart != null && !heart.canReadHeartRate,
                onTap: () => context.push('/health/strain'),
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.teal,
                title: 'Energy',
                value: activity?.caloriesTotalToday != null
                    ? '${activity!.caloriesTotalToday} kcal'
                    : '—',
                note: _energyNote(activity),
                needsAccess:
                    activity != null && !activity.canReadCaloriesTotal,
                onTap: () => context.push('/health/energy'),
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.science_rounded,
                color: AppColors.violet,
                title: 'Biology',
                value: body?.spo2Percent != null
                    ? '${body!.spo2Percent!.round()}% SpO\u2082'
                    : '—',
                note: _biologyNote(body),
                needsAccess:
                    body != null &&
                    !body.canReadSpo2 &&
                    !body.canReadRespiratory &&
                    !body.canReadSkinTemp &&
                    !body.canReadVo2Max,
                onTap: () => context.push('/health/biology'),
              ),
              if (partial) ...[
                const SizedBox(height: 16),
                InfoNote(
                  text: 'Some metrics need more Health Connect access. Review '
                      'permissions in Data sources.',
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.yellow,
                ),
              ],
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

  String _heartNote(HealthSummary? summary, HeartDetail? heart) {
    final latest = heart?.latestAt;
    if (latest == null) return 'Waiting for a heart-rate sample';
    final at = DateTime.tryParse(latest);
    if (at == null) return 'Sample time unavailable';
    return 'Updated ${formatClock(at)} \u00b7 ${formatAgo(at)}';
  }

  String _sleepNote(HealthSummary? summary) {
    if (summary?.sleepSessionMinutes == null) {
      return summary?.canReadSleep == true
          ? 'No session in the last 36 hours'
          : 'Needs sleep access';
    }
    final end = summary!.sleepEnd == null
        ? null
        : DateTime.tryParse(summary.sleepEnd!);
    if (end == null) return 'Main session';
    return 'Main session \u00b7 ended ${formatClock(end)}';
  }

  String _recoveryValue(HeartDetail? heart) {
    final estimate = recoveryEstimate(
      restingHr: heart?.restingHrBpm,
      restingHrBaseline: heart?.restingHrBaseline,
      hrv: heart?.hrvRmssd,
      hrvBaseline: heart?.hrvBaseline,
    );
    return estimate == null ? '—' : '$estimate';
  }

  String _recoveryNote(HeartDetail? heart) {
    final hrv = heart?.hrvRmssd;
    final rhr = heart?.restingHrBpm;
    if (hrv == null || rhr == null) {
      return heart?.canReadHrv == true && heart?.canReadRestingHr == true
          ? 'No HRV or resting HR records yet'
          : 'Needs HRV + resting HR access';
    }
    return 'HRV ${hrv.round()} ms \u00b7 Resting $rhr bpm';
  }

  String _energyNote(ActivityDetail? activity) {
    final total = activity?.caloriesTotalToday;
    final active = activity?.caloriesActiveToday;
    if (total == null) return 'Needs calorie access';
    if (active == null) return 'Total burned today';
    return 'Active $active \u00b7 Resting ${total - active} kcal';
  }

  String _biologyNote(BodyDetail? body) {
    if (body == null || !body.hasAccess) return 'Needs Health Connect access';
    final parts = <String>[];
    if (body.respiratoryRate != null) {
      parts.add('${body.respiratoryRate!.round()} br/min');
    }
    if (body.skinTempDeviationC != null) {
      final deviation = body.skinTempDeviationC!;
      final sign = deviation >= 0 ? '+' : '';
      parts.add('temp $sign${deviation.toStringAsFixed(1)}\u00b0C');
    }
    if (body.vo2Max != null) parts.add('VO\u2082 max ${body.vo2Max!.round()}');
    if (parts.isEmpty) return 'No body-metric records yet';
    return parts.join(' \u00b7 ');
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.note,
    required this.onTap,
    this.needsAccess = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String note;
  final VoidCallback onTap;
  final bool needsAccess;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconChip(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.rowTitle),
                const SizedBox(height: 2),
                Text(note, style: AppType.caption, maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppType.numS.copyWith(
                  color: needsAccess ? AppColors.textTertiary : AppColors.textPrimary,
                ),
              ),
              if (needsAccess)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'ACCESS NEEDED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.yellow,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
