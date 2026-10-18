import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';

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
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final inspection = await _health.inspect();
    HealthSummary? summary;
    if (inspection.isAvailable && inspection.hasAnyPermission) {
      summary = await _health.readSummary();
    }
    if (!mounted) return;
    setState(() {
      _inspection = inspection;
      _summary = summary;
      _loading = false;
    });
    _health.notifyDataChanged();
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
    final airSeen = summary?.fitbitAirDetected ?? false;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR INFORMATION',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.05,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Data sources',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green,
                      ),
                    )
                  else
                    _StatusPill(
                      healthStatus,
                      inspection?.hasAnyPermission == true
                          ? AppColors.green
                          : AppColors.yellow,
                    ),
                ],
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
              if (summary?.hasAccess == true) ...[
                const SizedBox(height: 14),
                _HealthSummaryCard(summary: summary!),
              ],
              const SizedBox(height: 25),
              const _SectionLabel('CONNECTIONS'),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.watch_rounded,
                color: AppColors.green,
                title: 'Fitbit Air',
                subtitle: airSeen
                    ? 'Device details found in Health Connect records'
                    : 'Air data has not been identified in readable records',
                status: airSeen ? 'Detected' : 'Unverified',
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
              const SizedBox(height: 25),
              const _SectionLabel('PRIVACY'),
              const SizedBox(height: 10),
              const _PrivacyCard(),
              const SizedBox(height: 17),
              const Center(
                child: Text(
                  'READ ONLY  ·  NO HEALTH DATA IS UPLOADED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2922), Color(0xFF121B17)],
        ),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAccess ? 'Health Connect is ready' : status,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasAccess
                          ? 'Read-only access · on this device'
                          : 'Your permission stays in your control',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.circle,
                size: 8,
                color: hasAccess ? AppColors.green : AppColors.yellow,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            hasAccess
                ? 'Your data, on your terms.'
                : 'Connect once. Keep control.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.55,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasAccess
                ? 'Becel reads only the types you approved. Pull to refresh '
                      'to check for new records.'
                : 'Choose exactly which health data Becel can read. We will '
                      'show the source and freshness for available records.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          if (lastChecked != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last checked ${_formatTime(lastChecked!)}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (hasError) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: AppColors.red, fontSize: 10),
            ),
          ],
          const SizedBox(height: 16),
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
                        color: Color(0xFF18210D),
                      ),
                    )
                  : Icon(
                      isAvailable && hasAccess
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded,
                      size: 17,
                    ),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: const Color(0xFF18210D),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
    final values = <(String, String, String?, Color)>[
      (
        'Steps today',
        summary.stepCount == null ? '—' : _formatNumber(summary.stepCount!),
        summary.stepCount == null
            ? summary.canReadSteps
                  ? 'No step record found today'
                  : 'Step access not allowed'
            : 'Health Connect total',
        AppColors.green,
      ),
      (
        'Latest heart rate',
        summary.heartRateBpm == null ? '—' : '${summary.heartRateBpm} bpm',
        summary.heartRateBpm == null
            ? summary.canReadHeartRate
                  ? 'No reading in the last 24 hours'
                  : 'Heart-rate access not allowed'
            : _sourceLine(summary.heartRateSource, summary.heartRateDevice),
        AppColors.red,
      ),
      (
        'Latest sleep session',
        summary.sleepSessionMinutes == null
            ? '—'
            : _formatDuration(summary.sleepSessionMinutes!),
        summary.sleepSessionMinutes == null
            ? summary.canReadSleep
                  ? 'No session in the last 36 hours'
                  : 'Sleep access not allowed'
            : 'Session span · '
                  '${_sourceLine(summary.sleepSource, summary.sleepDevice)}',
        AppColors.blue,
      ),
      (
        'Latest workout',
        summary.workoutType ?? '—',
        summary.workoutDurationMinutes == null
            ? summary.canReadExercise
                  ? 'No workout found in the last 7 days'
                  : 'Workout access not allowed'
            : '${summary.workoutDurationMinutes} min · '
                  '${_sourceLine(summary.workoutSource, summary.workoutDevice)}',
        AppColors.violet,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available records',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'LIVE READ',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Read from Health Connect · nothing is written back',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 9),
          ),
          const SizedBox(height: 8),
          for (final item in values) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: item.$4,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.$3 != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.$3!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.teal, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Becel requests read-only access. Your records stay in Health '
              'Connect; this app reads them on-device and does not upload them.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
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
