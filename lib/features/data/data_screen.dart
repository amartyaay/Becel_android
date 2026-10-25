import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../widgets/kit.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _health = HealthConnectService.instance;
  HealthConnectInspection? _inspection;
  HealthSummary? _summary;
  bool _loading = true;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    // Refreshing notifies every screen listening to the store, so wait
    // until this route has finished building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await HealthStore.instance.refresh(force: true);
    final snapshot = HealthStore.instance.snapshot;
    final inspection = snapshot?.inspection ?? await _health.inspect();
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _summary = snapshot?.summary;
      _loading = false;
    });
  }

  Future<void> _connect() async {
    final inspection = _inspection;
    if (inspection == null) return;

    setState(() => _connecting = true);
    if (!inspection.isAvailable) {
      final opened = await _health.openProviderStore();
      if (mounted && !opened) {
        _showMessage('Health Connect could not be opened on this device.');
      }
      if (mounted) setState(() => _connecting = false);
      await _refresh();
      return;
    }

    if (inspection.allPermissionsGranted) {
      await _refresh();
      if (mounted) setState(() => _connecting = false);
      return;
    }

    final updated = await _health.requestPermissions();
    if (!mounted) return;
    setState(() {
      _inspection = updated;
      _connecting = false;
    });
    await _refresh();
    if (mounted && updated.hasAnyPermission) {
      _showMessage('Health Connect access is ready.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final inspection = _inspection;
    final summary = _summary;
    final healthStatus = inspection?.stateLabel ?? 'Checking';
    final airSeen = summary?.fitbitAirMetadataMatched ?? false;

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
                onBack: () => Navigator.of(context).maybePop(),
                eyebrow: 'Your information',
                title: 'Data sources',
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
                        label: healthStatus,
                        color: inspection?.hasAnyPermission == true
                            ? AppColors.green
                            : AppColors.yellow,
                      ),
              ),
              const SizedBox(height: 21),
              _ConnectionHero(
                status: healthStatus,
                isAvailable: inspection?.isAvailable ?? false,
                hasAccess: inspection?.hasAnyPermission ?? false,
                allPermissionsGranted:
                    inspection?.allPermissionsGranted ?? false,
                connecting: _connecting || _loading,
                lastChecked: summary?.checkedAt ?? inspection?.checkedAt,
                error: summary?.error ?? inspection?.error,
                onTap: _connect,
              ),
              if (!airSeen) ...[
                const SizedBox(height: 14),
                _FitbitSyncGuide(
                  accessGranted: inspection?.hasAnyPermission == true,
                  allPermissionsGranted:
                      inspection?.allPermissionsGranted == true,
                  onRefresh: _refresh,
                ),
              ],
              if (summary?.fitbitAirMetadataMatched == true) ...[
                const SizedBox(height: 14),
                _HealthSummaryCard(summary: summary!),
              ],
              const SizedBox(height: 26),
              const Text('CONNECTIONS', style: AppType.eyebrow),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.watch_rounded,
                color: AppColors.green,
                title: 'Fitbit Air',
                subtitle: airSeen
                    ? 'Showing Fitbit Air records from the Fitbit app and Google Health; other apps are hidden'
                    : inspection?.allPermissionsGranted == true
                    ? 'All requested access is allowed; no Fitbit Air-matched records were found'
                    : inspection?.hasAnyPermission == true
                    ? 'Some access is allowed, but Fitbit Air-matched records were not found'
                    : 'No Fitbit Air records detected yet; check Health Connect access and Fitbit sync',
                status: airSeen ? 'Air records' : 'No match',
                statusColor: airSeen
                    ? AppColors.green
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 9),
              _SourceTile(
                icon: Icons.health_and_safety_rounded,
                color: AppColors.teal,
                title: 'Health Connect',
                subtitle: inspection?.isAvailable == true
                    ? 'On-device source · ${inspection!.granted.length} of '
                          '${inspection.requested.length} permissions allowed'
                    : 'Not available on this device yet',
                status: healthStatus,
                statusColor: inspection?.hasAnyPermission == true
                    ? AppColors.green
                    : AppColors.yellow,
              ),
              const SizedBox(height: 9),
              const _SourceTile(
                icon: Icons.cloud_outlined,
                color: AppColors.blue,
                title: 'Google Health API',
                subtitle: 'Cloud access is not configured for Becel',
                status: 'Not connected',
                statusColor: AppColors.textSecondary,
              ),
              const SizedBox(height: 26),
              const Text('PRIVACY', style: AppType.eyebrow),
              const SizedBox(height: 10),
              const _PrivacyCard(),
              const SizedBox(height: 20),
              const TrustFooter(
                text: 'READ ONLY  ·  NO HEALTH DATA IS UPLOADED',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FitbitSyncGuide extends StatelessWidget {
  const _FitbitSyncGuide({
    required this.accessGranted,
    required this.allPermissionsGranted,
    required this.onRefresh,
  });

  final bool accessGranted;
  final bool allPermissionsGranted;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconChip(
              icon: Icons.sync_rounded,
              color: AppColors.yellow,
              size: 38,
              iconSize: 19,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                !accessGranted
                    ? 'Finish setup to bring Fitbit data in'
                    : allPermissionsGranted
                    ? 'All access is allowed; Fitbit data has not arrived'
                    : 'Some health permissions are still off',
                style: AppType.rowTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          !accessGranted
              ? 'Becel shows only records matched to Fitbit Air. Allow the requested Health Connect read access above, then check the Fitbit sync.'
              : allPermissionsGranted
              ? 'Permission lets Becel read Health Connect. It does not confirm that Fitbit Air records have synced.'
              : 'Becel shows only records matched to Fitbit Air. Allow the requested Health Connect read access above, then check the Fitbit sync.',
          style: AppType.note,
        ),
        const SizedBox(height: 14),
        _SyncStep(
          number: '1',
          text:
              'Open Google Health with Fitbit Air nearby and pull down to sync. Check Connections > Fitbit Air for the last-synced time.',
        ),
        const SizedBox(height: 10),
        const _SyncStep(
          number: '2',
          text:
              'In Google Health, open Connections > Partner apps > Settings > Manage Health Connect. Check setup and allow Google Health to write the fitness, sleep and vital data you want to share.',
        ),
        const SizedBox(height: 10),
        const _SyncStep(
          number: '3',
          text:
              'Return here and refresh. Fitbit Air records will appear only after the source writes matching data.',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Check again'),
          ),
        ),
      ],
    ),
  );
}

class _SyncStep extends StatelessWidget {
  const _SyncStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StatusPill(label: number, color: AppColors.teal),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: AppType.caption)),
    ],
  );
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({
    required this.status,
    required this.isAvailable,
    required this.hasAccess,
    required this.allPermissionsGranted,
    required this.connecting,
    required this.lastChecked,
    required this.error,
    required this.onTap,
  });

  final String status;
  final bool isAvailable;
  final bool hasAccess;
  final bool allPermissionsGranted;
  final bool connecting;
  final String? lastChecked;
  final String? error;
  final VoidCallback onTap;

  String get buttonLabel {
    if (connecting) return 'Checking Health Connect…';
    if (!isAvailable) return 'Install or update Health Connect';
    if (allPermissionsGranted) return 'Refresh health data';
    if (hasAccess) return 'Review data permissions';
    return 'Choose data to share';
  }

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.tint(
              hasAccess ? AppColors.green : AppColors.accent,
              0.14,
            ),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.sensors_rounded,
                color: AppColors.green,
                size: 42,
                iconSize: 21,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAccess ? 'Health Connect is ready' : status,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasAccess
                          ? 'Read-only access · on this device'
                          : 'Your permission stays in your control',
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: hasAccess ? AppColors.green : AppColors.yellow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (hasAccess ? AppColors.green : AppColors.yellow)
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            hasAccess
                ? 'Your data, on your terms.'
                : 'Connect once. Keep control.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasAccess
                ? 'Becel reads only the types you approved. Pull to refresh '
                      'to check for new records.'
                : 'Choose exactly which health data Becel can read. We will '
                      'show the source and freshness for available records.',
            style: AppType.note,
          ),
          if (lastChecked != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Last checked ${_formatTime(lastChecked!)}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (hasError) ...[
            const SizedBox(height: 10),
            InfoNote(text: error!, textColor: AppColors.red),
          ],
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: connecting ? null : onTap,
              icon: connecting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isAvailable && hasAccess
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSummaryCard extends StatelessWidget {
  const _HealthSummaryCard({required this.summary});

  final HealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = <(String, String, String?, Color, IconData)>[
      (
        'Steps today',
        summary.stepCount == null ? '—' : _formatNumber(summary.stepCount!),
        summary.stepCount == null
            ? summary.canReadSteps
                  ? 'No Fitbit Air-matched step record found today'
                  : 'Step access not allowed'
            : 'Fitbit Air record',
        AppColors.green,
        Icons.directions_walk_rounded,
      ),
      (
        'Latest heart rate',
        summary.heartRateBpm == null ? '—' : '${summary.heartRateBpm} bpm',
        summary.heartRateBpm == null
            ? summary.canReadHeartRate
                  ? 'No Fitbit Air-matched reading in the last 24 hours'
                  : 'Heart-rate access not allowed'
            : _sourceLine(summary.heartRateSource, summary.heartRateDevice),
        AppColors.red,
        Icons.favorite_rounded,
      ),
      (
        'Recent sleep session',
        summary.sleepSessionMinutes == null
            ? '—'
            : _formatDuration(summary.sleepSessionMinutes!),
        summary.sleepSessionMinutes == null
            ? summary.canReadSleep
                  ? 'No Fitbit Air-matched session in the last 36 hours'
                  : 'Sleep access not allowed'
            : 'Session span · '
                  '${_sourceLine(summary.sleepSource, summary.sleepDevice)}',
        AppColors.blue,
        Icons.nightlight_round,
      ),
      (
        'Latest workout',
        summary.workoutType ?? '—',
        summary.workoutDurationMinutes == null
            ? summary.canReadExercise
                  ? 'No Fitbit Air-matched workout in the last 7 days'
                  : 'Workout access not allowed'
            : '${summary.workoutDurationMinutes} min · '
                  '${_sourceLine(summary.workoutSource, summary.workoutDevice)}',
        AppColors.violet,
        Icons.directions_run_rounded,
      ),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Fitbit Air records', style: AppType.cardTitle),
              ),
              StatusPill(label: 'AIR FILTER', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Only records written for Fitbit Air by the Fitbit app or Google Health are shown. Other sources and devices are hidden.',
            style: AppType.caption,
          ),
          const SizedBox(height: 8),
          for (final item in values) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  IconChip(
                    icon: item.$5,
                    color: item.$4,
                    size: 36,
                    iconSize: 18,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (item.$3 != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.$3!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.numS,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconChip(icon: icon, color: color, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(label: status, color: statusColor),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.surface,
      radius: 18,
      padding: const EdgeInsets.all(15),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.teal, size: 19),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Becel requests read-only access. Your records stay in Health '
              'Connect; this app reads them on-device and does not upload them.',
              style: AppType.note,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'recently';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
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

String _formatDuration(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '$minutes min';
}

String? _sourceLine(String? packageName, String? device) {
  if (packageName == null && device == null) return 'Source not provided';
  if (device != null && device.isNotEmpty) {
    return '$device · ${packageName ?? 'Health Connect'}';
  }
  return packageName;
}
