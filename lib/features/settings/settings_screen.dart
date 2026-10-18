import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _morningSummary = true;
  bool _smartAlarm = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SectionHeader('Data sources'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                InfoRow(
                  title: 'Fitbit Air',
                  subtitle: 'Connected · synced 12m ago',
                  icon: Icons.watch_outlined,
                  iconColor: AppColors.green,
                  value: '',
                  trailing: const _StatusDot(AppColors.green),
                  onTap: () => showSoonSnack(context, 'Device settings'),
                ),
                InfoRow(
                  title: 'Google Health',
                  subtitle: 'Google Health API',
                  icon: Icons.cloud_outlined,
                  iconColor: AppColors.sleep,
                  value: '',
                  trailing: const _StatusDot(AppColors.yellow),
                  onTap: () => showSoonSnack(context, 'Google Health OAuth'),
                ),
                InfoRow(
                  title: 'Health Connect',
                  subtitle: 'On-device sync',
                  icon: Icons.link,
                  iconColor: AppColors.energy,
                  value: '',
                  trailing: const _StatusDot(AppColors.green),
                  onTap: () => showSoonSnack(context, 'Health Connect'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Goals'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                InfoRow(
                  title: 'Sleep goal',
                  value: '8h 00m',
                  icon: Icons.dark_mode_outlined,
                  iconColor: AppColors.sleep,
                  onTap: () => showSoonSnack(context, 'Sleep goal'),
                ),
                InfoRow(
                  title: 'Activity level',
                  value: 'Active',
                  icon: Icons.directions_run,
                  iconColor: AppColors.strain,
                  onTap: () => showSoonSnack(context, 'Activity level'),
                ),
                InfoRow(
                  title: 'Units',
                  value: 'Metric',
                  icon: Icons.straighten,
                  iconColor: AppColors.recovery,
                  onTap: () => showSoonSnack(context, 'Units'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Calculations'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                InfoRow(
                  title: 'HRV method',
                  subtitle: 'Used for Recovery and Stress',
                  value: 'RMSSD',
                  onTap: () => showSoonSnack(context, 'HRV method'),
                ),
                InfoRow(
                  title: 'Resting HRV source',
                  subtitle: 'HRV used for baselines',
                  value: 'During sleep',
                  onTap: () => showSoonSnack(context, 'Resting HRV source'),
                ),
                InfoRow(
                  title: 'Heart rate zones',
                  subtitle: 'Zone calculation method',
                  value: 'HR reserve',
                  onTap: () => showSoonSnack(context, 'Heart rate zones'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Notifications'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Morning summary',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Recovery and sleep when you wake up',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _morningSummary,
                  activeThumbColor: AppColors.green,
                  onChanged: (value) => setState(() => _morningSummary = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Phone smart alarm',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Wrist alarms are not supported by Fitbit Air',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _smartAlarm,
                  activeThumbColor: AppColors.green,
                  onChanged: (value) => setState(() => _smartAlarm = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader('Privacy'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                InfoRow(
                  title: 'Export data',
                  subtitle: 'JSON / CSV',
                  icon: Icons.ios_share,
                  iconColor: AppColors.energy,
                  value: '',
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onTap: () => showSoonSnack(context, 'Data export'),
                ),
                InfoRow(
                  title: 'Delete data',
                  icon: Icons.delete_outline,
                  iconColor: AppColors.red,
                  value: '',
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onTap: () => showSoonSnack(context, 'Data deletion'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Becel 0.1.0 · Not a medical device',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
