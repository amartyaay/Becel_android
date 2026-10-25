import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/health_connect_service.dart';
import '../../data/health_store.dart';
import '../../data/local_store.dart';
import '../../domain/coaching.dart';
import '../../domain/profile.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../today/check_in_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _health = HealthStore.instance;
  final _local = LocalStore.instance;
  late final Listenable _listenable = Listenable.merge([_health, _local]);
  bool _busy = false;

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
            final checkIns = _local.log.recentCheckIns(days: 7, now: now);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                const ScreenHeader(eyebrow: 'PREFERENCES', title: 'Settings'),
                const SizedBox(height: 6),
                const Text(
                  'Connection, local context, and the data Becel keeps on this '
                  'phone.',
                  style: AppType.body,
                ),
                const SizedBox(height: 18),
                _ConnectionCard(
                  snapshot: snapshot,
                  loading: _health.loading,
                  onManage: () => context.go('/data'),
                ),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Morning check-ins',
                  caption: 'ON DEVICE',
                  action: 'Check in',
                  onAction: () => showCheckInSheet(context),
                ),
                const SizedBox(height: 10),
                _CheckInList(checkIns: checkIns),
                const SizedBox(height: 22),
                const Text('FITNESS PROFILE', style: AppType.eyebrow),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.monitor_heart_rounded,
                      color: AppColors.green,
                      title: 'Body profile',
                      subtitle: _profileSubtitle(
                        _local.log.profile,
                        snapshot?.age,
                      ),
                      onTap: () =>
                          _editProfile(_local.log.profile, snapshot?.age),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('YOUR DATA', style: AppType.eyebrow),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.sensors_rounded,
                      color: AppColors.teal,
                      title: 'Data sources',
                      subtitle: 'Health Connect status and permissions',
                      onTap: () => context.go('/data'),
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.ios_share_rounded,
                      color: AppColors.violet,
                      title: 'Share weekly summary',
                      subtitle: snapshot == null
                          ? 'Available after health data loads'
                          : 'Plain text · no server',
                      onTap: snapshot == null || _busy
                          ? null
                          : () => _shareWeek(snapshot),
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.download_rounded,
                      color: AppColors.orange,
                      title: 'Export weekly CSV',
                      subtitle: snapshot == null
                          ? 'Available after health data loads'
                          : 'Saved to Downloads/Becel',
                      onTap: snapshot == null || _busy
                          ? null
                          : () => _exportWeek(snapshot),
                    ),
                    const _SettingsDivider(),
                    _SettingsRow(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.red,
                      title: 'Delete local data',
                      subtitle: 'Check-ins, strength logs, and body profile',
                      onTap: _confirmDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('ABOUT', style: AppType.eyebrow),
                const SizedBox(height: 10),
                const _SettingsCard(
                  children: [
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
                const SizedBox(height: 12),
                const Text(
                  'Becel reads Fitbit Air records from Health Connect and keeps '
                  'check-ins and strength logs on this phone. Nothing is '
                  'uploaded. Estimates are wellness context, not a medical '
                  'device or training clearance.',
                  style: AppType.caption,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  const Text('DEVELOPER', style: AppType.eyebrow),
                  const SizedBox(height: 10),
                  const _AirHapticsTester(),
                ],
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Wellness insights only · Not a medical device',
                    textAlign: TextAlign.center,
                    style: AppType.caption,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _shareWeek(HealthSnapshot snapshot) async {
    setState(() => _busy = true);
    final shared = await _local.shareText(
      weeklySummaryText(snapshot.performance.weekly),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shared
              ? 'Summary ready to share.'
              : 'Sharing is not available on this device.',
        ),
      ),
    );
  }

  Future<void> _exportWeek(HealthSnapshot snapshot) async {
    setState(() => _busy = true);
    final p = snapshot.performance;
    final path = await _local.exportCsv(
      weeklyCsv(
        review: p.weekly,
        recoveryHistory: p.recoveryHistory,
        energyDays: p.energyDays,
        now: p.now,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Could not save the CSV.'
              : 'Weekly CSV saved to Downloads/Becel.',
        ),
      ),
    );
  }

  String _profileSubtitle(BodyProfile? profile, int? nativeAge) {
    final age = profile?.age ?? nativeAge;
    if (profile == null || !profile.hasEnergyInputs) {
      return age == null
          ? 'Add age, sex, height, and weight'
          : 'Age $age · add sex, height, and weight';
    }
    final sex = profile.sex == BiologicalSex.female ? 'Female' : 'Male';
    final extras = [
      if (profile.hasValidBodyFat) '${profile.bodyFatPercent!.round()}% BF',
      if (profile.maxHrOverride != null) 'max ${profile.maxHrOverride}',
    ];
    return 'Age ${profile.age} · $sex · ${profile.heightCm!.round()} cm · '
        '${profile.weightKg!.round()} kg'
        '${extras.isEmpty ? '' : ' · ${extras.join(' · ')}'}';
  }

  Future<void> _editProfile(BodyProfile? current, int? nativeAge) async {
    final ageController = TextEditingController(
      text: (current?.age ?? nativeAge)?.toString() ?? '',
    );
    final heightController = TextEditingController(
      text: current?.heightCm?.round().toString() ?? '',
    );
    final weightController = TextEditingController(
      text: current?.weightKg?.round().toString() ?? '',
    );
    final bodyFatController = TextEditingController(
      text: current?.bodyFatPercent?.round().toString() ?? '',
    );
    final maxHrController = TextEditingController(
      text: current?.maxHrOverride?.toString() ?? '',
    );
    final sleepNeedController = TextEditingController(
      text: current?.sleepNeedMinutes == null
          ? ''
          : (current!.sleepNeedMinutes! / 60).toStringAsFixed(1),
    );
    var sex = current?.sex;
    var invalid = false;
    final selected = await showDialog<BodyProfile>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, updateDialog) => AlertDialog(
            title: const Text('Body profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Becel uses age for heart-rate zones, and all four fields '
                    'for energy and fitness-age estimates. Values stay on this '
                    'device.',
                    style: AppType.note,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => updateDialog(() => invalid = false),
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      suffixText: 'years',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in BiologicalSex.values)
                        ChoiceChip(
                          label: Text(
                            option == BiologicalSex.female ? 'Female' : 'Male',
                          ),
                          selected: sex == option,
                          onSelected: (_) => updateDialog(() => sex = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => updateDialog(() => invalid = false),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => updateDialog(() => invalid = false),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OPTIONAL · MORE ACCURATE',
                    style: AppType.eyebrow,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyFatController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Body fat',
                      suffixText: '%',
                      helperText: 'Uses lean mass for resting calories',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxHrController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Tested max heart rate',
                      suffixText: 'bpm',
                      helperText: 'From a field or lab test; sets your zones',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sleepNeedController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Baseline sleep need',
                      suffixText: 'h',
                      helperText: 'Default 8 h',
                    ),
                  ),
                  if (invalid) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Enter age 18–100, height 120–230 cm, and weight '
                      '30–250 kg.',
                      style: TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final age = int.tryParse(ageController.text);
                  final height = double.tryParse(heightController.text);
                  final weight = double.tryParse(weightController.text);
                  final bodyFat = double.tryParse(bodyFatController.text);
                  final maxHr = int.tryParse(maxHrController.text);
                  final sleepHours = double.tryParse(sleepNeedController.text);
                  final profile = BodyProfile(
                    age: age,
                    sex: sex,
                    heightCm: height,
                    weightKg: weight,
                    bodyFatPercent:
                        bodyFat != null && bodyFat >= 3 && bodyFat <= 60
                        ? bodyFat
                        : null,
                    maxHrOverride: maxHr != null && maxHr >= 120 && maxHr <= 230
                        ? maxHr
                        : null,
                    sleepNeedMinutes:
                        sleepHours != null &&
                            sleepHours >= 6 &&
                            sleepHours <= 10
                        ? (sleepHours * 60).round()
                        : null,
                  );
                  if (!profile.hasEnergyInputs) {
                    updateDialog(() => invalid = true);
                    return;
                  }
                  Navigator.of(context).pop(profile);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    bodyFatController.dispose();
    maxHrController.dispose();
    sleepNeedController.dispose();
    if (selected == null || !mounted) return;
    final savedProfile = await _local.saveProfile(selected);
    final savedAge = await HealthConnectService.instance.saveFitnessAge(
      selected.age,
    );
    await _health.refresh(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedProfile && savedAge
              ? 'Body profile saved.'
              : 'Profile saved locally; the activity age could not update.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local data?'),
        content: const Text(
          'This removes morning check-ins, manual strength days, and your body '
          'profile from this phone. Health Connect records are not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final cleared = await _local.clearLocalData();
    await _health.refresh(force: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Local data deleted. Health Connect records are unchanged.'
              : 'Could not delete all local data.',
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.snapshot,
    required this.loading,
    required this.onManage,
  });

  final HealthSnapshot? snapshot;
  final bool loading;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final connected = snapshot?.airMatched == true;
    final available = snapshot?.isAvailable == true;
    final hasAccess = snapshot?.hasAccess == true;
    final color = connected
        ? AppColors.green
        : available && hasAccess
        ? AppColors.yellow
        : AppColors.red;
    final title = loading && snapshot == null
        ? 'Checking Health Connect…'
        : connected
        ? 'Fitbit Air connected'
        : !available
        ? 'Health Connect is not available'
        : !hasAccess
        ? 'Health Connect setup is incomplete'
        : 'Health Connect connected, no Air records yet';
    final body = loading && snapshot == null
        ? 'Reading the connection state from this phone.'
        : connected
        ? 'Records are read from Health Connect. Last refresh '
              '${formatAgo(snapshot!.loadedAt)}.'
        : !available
        ? 'This phone does not expose Health Connect, so Becel cannot read '
              'Fitbit Air records.'
        : !hasAccess
        ? 'Allow sleep, heart rate, and exercise access to see your brief.'
        : 'The connection works, but no Fitbit Air records have arrived. '
              'Check that the Fitbit app is syncing.';
    return SurfaceCard(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: connected ? Icons.sensors_rounded : Icons.sensors_off_rounded,
            color: color,
            size: 44,
            iconSize: 21,
            radius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.rowTitle),
                const SizedBox(height: 4),
                Text(body, style: AppType.caption),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onManage,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(48, 44),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Manage data sources'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInList extends StatelessWidget {
  const _CheckInList({required this.checkIns});

  final List<CheckIn> checkIns;

  @override
  Widget build(BuildContext context) {
    if (checkIns.isEmpty) {
      return const StateCard(
        icon: Icons.wb_sunny_outlined,
        color: AppColors.yellow,
        title: 'No check-ins yet',
        body:
            'A morning check-in adds context Becel cannot measure. It stays '
            'on this phone.',
      );
    }
    return _SettingsCard(
      children: [
        for (var index = 0; index < checkIns.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconChip(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.green,
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
                        checkIns[index].label.isEmpty
                            ? 'Check-in'
                            : checkIns[index].label,
                        style: AppType.rowTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateLabel(checkIns[index].date),
                        style: AppType.caption,
                      ),
                      if (checkIns[index].note != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          checkIns[index].note!,
                          style: AppType.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != checkIns.length - 1) const _SettingsDivider(),
        ],
      ],
    );
  }

  String _dateLabel(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return formatShortDate(parsed);
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              IconChip(
                icon: icon,
                color: enabled ? color : AppColors.textTertiary,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppType.caption),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? AppColors.textTertiary : AppColors.border,
                size: 20,
              ),
            ],
          ),
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
              'Fitbit Air has not advertised yet. Keep it nearby; if Google '
              'Health is syncing, Becel will keep checking while the band '
              'becomes available.',
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
            ? 'Pulse sent and original setting restored. Becel disconnected '
                  'so Google Health can reconnect.'
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
                ? 'Select the band first, then send a short pulse directly over '
                      'Bluetooth.'
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
              'Becel waits for Air to advertise, connects only for this short '
              'test, restores the previous haptics setting, then disconnects '
              'so Google Health can reconnect. If Health is using the band, '
              'the test may wait. Becel cannot force Health to release it.',
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
