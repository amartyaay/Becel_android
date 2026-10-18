import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/mock_data.dart';
import '../../domain/models.dart';
import '../../domain/score_status.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scores = MockData.todayScores;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _HeroCard(scores: scores),
            const SizedBox(height: 16),
            const _MonitorStrip(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StressCard(value: scores.stress)),
                const SizedBox(width: 12),
                Expanded(child: _EnergyCard(value: scores.energyBank)),
              ],
            ),
            const SizedBox(height: 12),
            _SleepNeededCard(),
            const SizedBox(height: 24),
            const SectionHeader('Timeline'),
            const _Timeline(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDate(MockData.today),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const StatusPill('Active', AppColors.green),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.scores});

  final DailyScores scores;

  @override
  Widget build(BuildContext context) {
    final strain = scores.strain;
    final strainTarget = scores.strainHigh;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _HeroRing(
                value: scores.recovery / 100,
                color: AppColors.recovery,
                label: 'Recovery',
                display: '${scores.recovery}%',
                onTap: () => context.push('/recovery'),
              ),
              _HeroRing(
                value: strain / strainTarget,
                color: AppColors.strain,
                label: 'Strain',
                display: '$strain%',
                onTap: () => context.push('/strain'),
              ),
              _HeroRing(
                value: scores.sleepScore / 100,
                color: AppColors.sleep,
                label: 'Sleep',
                display: '${scores.sleepScore}%',
                onTap: () => context.push('/sleep'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigher.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.yellow,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Good recovery. Your target strain today is '
                    '${scores.strainLow}–${scores.strainHigh}%.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.value,
    required this.color,
    required this.label,
    required this.display,
    required this.onTap,
  });

  final double value;
  final Color color;
  final String label;
  final String display;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(60),
        child: Column(
          children: [
            ScoreRing(
              value: value,
              color: color,
              size: 92,
              stroke: 8,
              center: Text(
                display,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorStrip extends StatelessWidget {
  const _MonitorStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MockData.monitors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final m = MockData.monitors[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      m.value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (m.unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          m.unit,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StressCard extends StatelessWidget {
  const _StressCard({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final status = ScoreStatus.stress(value);
    return AppCard(
      onTap: () => context.push('/stress'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StatusPill(status.label, status.color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SparkLine(data: MockData.stressSeries, color: AppColors.stress),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final status = ScoreStatus.energy(value);
    return AppCard(
      onTap: () => context.push('/energy'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy Bank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$value%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StatusPill(status.label, status.color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BatteryGauge(value: value / 100, color: AppColors.energy, height: 32),
        ],
      ),
    );
  }
}

class _SleepNeededCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/sleep'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sleep.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.dark_mode_outlined,
              size: 20,
              color: AppColors.sleep,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep needed',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  'Based on your goal and 42m sleep debt',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '8h 30m',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < MockData.timeline.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _TimelineTile(event: MockData.timeline[i]),
          ],
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final TimelineEvent event;

  static const _icons = {
    TimelineEventKind.sleep: (Icons.dark_mode_outlined, AppColors.sleep),
    TimelineEventKind.workout: (Icons.directions_run, AppColors.strain),
    TimelineEventKind.meal: (Icons.restaurant, AppColors.nutrition),
    TimelineEventKind.drink: (Icons.local_cafe_outlined, AppColors.stress),
    TimelineEventKind.journal: (Icons.edit_note, AppColors.recovery),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _icons[event.kind]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatTime(event.time),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
