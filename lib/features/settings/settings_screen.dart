import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.yellow,
                  size: 19,
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Health Connect read access is available in Data Sources. '
                    'Other features are being built.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 18),
            const _AirHapticsTester(),
          ],
          const SizedBox(height: 24),
          const _GroupTitle('YOUR DATA'),
          const SizedBox(height: 9),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.sensors_rounded,
                color: AppColors.teal,
                title: 'Data sources',
                subtitle: 'Connection status and permissions',
                onTap: () => context.go('/data'),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.ios_share_rounded,
                color: AppColors.yellow,
                title: 'Export data',
                subtitle: 'CSV and JSON',
                onTap: () => _showComingSoon(context, 'Data export'),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.delete_outline_rounded,
                color: AppColors.red,
                title: 'Delete local data',
                subtitle: 'Remove records stored by Becel',
                onTap: () => _showComingSoon(context, 'Local data controls'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupTitle('APP'),
          const SizedBox(height: 9),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.straighten_rounded,
                color: AppColors.green,
                title: 'Units',
                subtitle: 'Metric',
                onTap: () => _showComingSoon(context, 'Unit settings'),
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.notifications_none_rounded,
                color: AppColors.blue,
                title: 'Notifications',
                subtitle: 'Choose reminders and alert behavior',
                onTap: () => _showComingSoon(context, 'Notification settings'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _GroupTitle('ABOUT'),
          const SizedBox(height: 9),
          _SettingsCard(
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    _BrandMark(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Becel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'An independent wellness companion',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          const Text(
            'Wellness insights only · Not a medical device',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature will be added in a later milestone.')),
      );
  }

}

class _AirHapticsTester extends StatefulWidget {
  const _AirHapticsTester();

  @override
  State<_AirHapticsTester> createState() => _AirHapticsTesterState();
}

class _AirHapticsTesterState extends State<_AirHapticsTester> {
  static const _channel = MethodChannel('com.becel/air_haptics');

  Map<String, dynamic>? _selected;
  bool _scanning = false;
  bool _testing = false;
  String? _status;
  bool? _lastTestRestored;

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    try {
      final selected = await _channel.invokeMapMethod<String, dynamic>(
        'air.selected',
      );
      if (mounted) setState(() => _selected = selected);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = _message(error));
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _status = 'Looking for Fitbit devices nearby…';
      _lastTestRestored = null;
    });
    try {
      final scanned = await _channel.invokeListMethod<dynamic>('air.scan');
      if (!mounted) return;
      final devices = (scanned ?? const [])
          .whereType<Map>()
          .map((device) => Map<String, dynamic>.from(device))
          .toList();
      if (devices.isEmpty) {
        setState(() => _status =
            'No compatible Fitbit device found. Keep Air nearby and awake, then scan again.');
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const Text(
                'Choose your Fitbit Air',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only select the Air band you want Becel to test.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final device in devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1F62D7A0),
                    child: Icon(Icons.watch_rounded, color: AppColors.green),
                  ),
                  title: Text(
                    (device['name'] as String?)?.trim().isNotEmpty == true
                        ? device['name'] as String
                        : 'Fitbit device',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Bluetooth signal ${device['rssi'] ?? '—'} dBm'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(device),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final saved = await _channel.invokeMapMethod<String, dynamic>(
        'air.select',
        {'address': selected['address'], 'name': selected['name']},
      );
      if (!mounted) return;
      setState(() {
        _selected = saved;
        _status = 'Device selected. Tap Test pulse when you are wearing it.';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = _message(error));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _testPulse() async {
    setState(() {
      _testing = true;
      _status = 'Connecting to Fitbit Air…';
      _lastTestRestored = null;
    });
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('air.test');
      if (!mounted) return;
      final restored = result?['restored'] == true;
      setState(() {
        _lastTestRestored = restored;
        _status = restored
            ? 'Haptic command sent. Original setting restored and verified.'
            : 'The band did not confirm its original haptics setting.';
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _lastTestRestored = false;
          _status = _message(error);
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _message(PlatformException error) {
    final message = error.message?.trim();
    return message == null || message.isEmpty
        ? 'Fitbit Air could not complete the haptic test.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final busy = _scanning || _testing;
    final statusColor = _lastTestRestored == true
        ? AppColors.green
        : _lastTestRestored == false
            ? AppColors.red
            : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.vibration_rounded,
                  color: AppColors.green,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitbit Air haptic test',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'EXPERIMENTAL · DEBUG BUILD',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _selected == null
                ? 'Select the band first, then send a short pulse directly over Bluetooth.'
                : 'Selected: ${_selected!['name'] ?? 'Fitbit Air'}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'Unofficial Bluetooth control may briefly interrupt Google Health sync. The test changes haptics for less than a second and checks that the previous setting is restored.',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ] else if (_lastTestRestored != null) ...[
                  Icon(
                    _lastTestRestored! ? Icons.check_circle : Icons.error_outline,
                    color: statusColor,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    _status!,
                    style: TextStyle(fontSize: 10, color: statusColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _scan,
                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 17),
                  label: Text(_selected == null ? 'Select Air' : 'Change band'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 9),
                    side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || _selected == null ? null : _testPulse,
                  icon: const Icon(Icons.waves_rounded, size: 17),
                  label: const Text('Test pulse'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: const Color(0xFF14200B),
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.95,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => const Divider(indent: 45, height: 1);
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.monitor_heart_rounded,
        color: Color(0xFF14200B),
        size: 22,
      ),
    );
  }
}
