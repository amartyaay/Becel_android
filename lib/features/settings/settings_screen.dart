import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../widgets/kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _health = HealthConnectService.instance;
  int? _age;
  bool _loadingAge = true;

  @override
  void initState() {
    super.initState();
    _loadAge();
  }

  Future<void> _loadAge() async {
    final age = await _health.readFitnessAge();
    if (!mounted) return;
    setState(() {
      _age = age;
      _loadingAge = false;
    });
  }

  Future<void> _editFitnessAge() async {
    final controller = TextEditingController(text: _age?.toString() ?? '');
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        var invalid = false;
        return StatefulBuilder(
          builder: (context, updateDialog) => AlertDialog(
            title: const Text('Personalize activity zones'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Age helps Becel estimate your maximum heart rate and heart-rate reserve. The estimate is used only for activity intensity zones.',
                  style: AppType.note,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => updateDialog(() => invalid = false),
                  decoration: InputDecoration(
                    labelText: 'Age',
                    suffixText: 'years',
                    hintText: '18–100',
                    errorText: invalid ? 'Enter an age from 18 to 100.' : null,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(-1),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final age = int.tryParse(controller.text);
                  if (age == null || age < 18 || age > 100) {
                    updateDialog(() => invalid = true);
                    return;
                  }
                  Navigator.of(context).pop(age);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (selected == null || !mounted) return;
    final age = selected < 0 ? null : selected;
    final saved = await _health.saveFitnessAge(age);
    if (!mounted) return;
    if (saved) {
      setState(() => _age = age);
      _health.notifyDataChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the activity profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const InfoNote(
            icon: Icons.info_outline_rounded,
            color: AppColors.yellow,
            text:
                'Health Connect read access is available in Data Sources. '
                'Other features are being built.',
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 18),
            const _AirHapticsTester(),
          ],
          const SizedBox(height: 26),
          const Text('FITNESS PROFILE', style: AppType.eyebrow),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.monitor_heart_rounded,
                color: AppColors.green,
                title: 'Heart-rate zones',
                subtitle: _loadingAge
                    ? 'Loading local profile'
                    : _age == null
                    ? 'Add age to estimate personal zones'
                    : 'Age $_age · stored on this device',
                onTap: _editFitnessAge,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('YOUR DATA', style: AppType.eyebrow),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),
          const Text('APP', style: AppType.eyebrow),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),
          const Text('ABOUT', style: AppType.eyebrow),
          const SizedBox(height: 10),
          _SettingsCard(
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'An independent wellness companion',
                            style: AppType.caption,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    StatusPill(label: 'PREVIEW', color: AppColors.yellow),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Wellness insights only · Not a medical device',
              textAlign: TextAlign.center,
              style: AppType.caption,
            ),
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
      _status = 'Waiting for Fitbit Air to advertise nearby…';
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
        setState(
          () => _status =
              'Fitbit Air has not advertised yet. Keep it nearby; if Google Health is syncing, Becel will keep checking while the band becomes available.',
        );
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only select the Air band you want Becel to test.',
                style: AppType.caption,
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
                  subtitle: Text(
                    'Bluetooth signal ${device['rssi'] ?? '—'} dBm',
                  ),
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
      _status = 'Waiting for Fitbit Air, then connecting briefly…';
      _lastTestRestored = null;
    });
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'air.test',
      );
      if (!mounted) return;
      final restored = result?['restored'] == true;
      setState(() {
        _lastTestRestored = restored;
        _status = restored
            ? 'Pulse sent and original setting restored. Becel disconnected so Google Health can reconnect.'
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconChip(
                icon: Icons.vibration_rounded,
                color: AppColors.green,
                size: 38,
                iconSize: 19,
                radius: 13,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fitbit Air haptic test',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'EXPERIMENTAL · DEBUG BUILD',
                      style: TextStyle(
                        fontSize: 11,
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
            style: AppType.note,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'Becel waits for Air to advertise, connects only for this short test, restores the previous haptics setting, then disconnects so Google Health can reconnect. If Health is using the band, the test may wait. Becel cannot force Health to release it.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ] else if (_lastTestRestored != null) ...[
                  Icon(
                    _lastTestRestored!
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    _status!,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _scan,
                  icon: const Icon(Icons.bluetooth_searching_rounded, size: 17),
                  label: Text(_selected == null ? 'Select Air' : 'Change band'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || _selected == null ? null : _testPulse,
                  icon: const Icon(Icons.waves_rounded, size: 17),
                  label: const Text('Test pulse'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            IconChip(
              icon: icon,
              color: color,
              size: 38,
              iconSize: 19,
              radius: 13,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppType.caption),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
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
  Widget build(BuildContext context) => const Divider(indent: 50, height: 1);
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD9FA83), Color(0xFF91BD49)],
        ),
      ),
      child: const Icon(
        Icons.monitor_heart_rounded,
        color: Color(0xFF14200B),
        size: 22,
      ),
    );
  }
}
