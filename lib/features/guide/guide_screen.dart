import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/energy.dart';
import '../../domain/estimates.dart';
import '../../domain/strain.dart';
import '../../widgets/kit.dart';

/// "How Becel works": every metric's meaning and calculation in one place,
/// so the data screens can stay numbers-first.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, this.initialSection});

  /// Section id to open and scroll to (e.g. `calories`).
  final String? initialSection;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _keys = {for (final s in guideSections) s.id: GlobalKey()};

  @override
  void initState() {
    super.initState();
    final target = _keys[widget.initialSection];
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = target.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            alignment: 0.05,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 12,
          16,
          32,
        ),
        children: [
          ScreenHeader(
            onBack: () => Navigator.of(context).maybePop(),
            eyebrow: 'Meanings & maths',
            title: 'How Becel works',
          ),
          const SizedBox(height: 16),
          for (final section in guideSections) ...[
            _SectionCard(
              key: _keys[section.id],
              section: section,
              initiallyOpen: section.id == widget.initialSection,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class GuideSection {
  const GuideSection({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.entries,
  });

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final Color color;

  /// (question, answer) pairs.
  final List<(String, String)> entries;
}

final guideSections = <GuideSection>[
  GuideSection(
    id: 'recovery',
    title: 'Recovery',
    summary: 'How ready your body is today, vs your own normal.',
    icon: Icons.favorite_rounded,
    color: AppColors.bandGreen,
    entries: [
      (
        'What the % means',
        'A typical morning for you reads ${RecoveryModel.typical}%. '
            '${RecoveryModel.green}%+ (green) means clearly better than usual: '
            'a good day to go hard. ${RecoveryModel.red}% or less (red) means '
            'clearly worse: recover. Anything between is yellow: train, but '
            'control intensity. 90%+ is rare by design: it takes a night far '
            'better than your usual.',
      ),
      ('How it is calculated', recoveryMethod),
      (
        'The signal bars',
        'Each bar shows how far HRV, resting heart rate, and sleep moved '
            'the score, in standard deviations from your own baseline. Right '
            'helps, left hurts.',
      ),
      (
        'HRV 7-day trend',
        'Single nights are noisy, so the trend card shows your 7-day '
            'average ln RMSSD against your 28-day baseline ± the smallest '
            'worthwhile change (half a standard deviation, at least ±4%). '
            'A week below the band points to accumulated fatigue, poor sleep, '
            'or illness, and caps the day at controlled training even after a '
            'good night (Plews 2013; Buchheit 2014). Above the band is usually '
            'good adaptation, unless resting HR is up too.',
      ),
    ],
  ),
  GuideSection(
    id: 'strain',
    title: 'Strain & targets',
    summary: 'How hard your heart and legs worked today, 0–21.',
    icon: Icons.bolt_rounded,
    color: AppColors.strain,
    entries: [
      (
        'What it means',
        'Strain is today\'s cardiovascular load on a 0–21 scale. It climbs '
            'slowly: a sitting day stays near 0–3, a long walk or easy session '
            '5–9, a solid workout 10–14, and a hard race or double day 15+.',
      ),
      (
        'How it is calculated',
        'Banister TRIMP on cleaned 1-minute heart rate, counted from '
            '${(strainFloorHrr * 100).round()}% of your heart-rate reserve '
            '(below that is sitting with a slightly raised pulse). Walking '
            'cadence counts too: 100+ steps/min is treated as at least '
            'moderate effort and 130+ as vigorous (Tudor-Locke 2018), so a '
            'brisk walk registers even when wrist HR lags. Load is mapped to '
            '0–21 as 21 × (1 − e^(−TRIMP ÷ ${strainScaleK.round()})).',
      ),
      (
        'Today\'s target',
        'Your target is "everyday strain + a session": Recover 2–7, Train '
            '8–12, Push 13–17, picked from your recovery band and trimmed when '
            'your recent load spikes. It shifts (by at most 2) if your normal '
            'days are more or less active than average, so the session dose '
            'stays the same.',
      ),
    ],
  ),
  GuideSection(
    id: 'load',
    title: 'Training load',
    summary: 'Is this week building you up or wearing you down?',
    icon: Icons.stacked_line_chart_rounded,
    color: AppColors.strain,
    entries: [
      (
        'Acute vs chronic (ACWR)',
        'Exponentially weighted 7-day load divided by 28-day load, through '
            'yesterday. 1.0–1.3 is productive building, 0.8–1.0 maintaining, '
            'below 0.8 detraining. Above 1.5 is a sharp jump; links to injury '
            'risk are debated (Impellizzeri 2020), but it is worth easing off.',
      ),
      (
        'What counts',
        'Only effort at or above ${(trainingFloorHrr * 100).round()}% of heart-rate '
            'reserve (or brisk walking cadence) and lifting. Everyday heart '
            'rate is left out so it cannot pad every day equally. Days worn '
            'under 12 hours carry the previous load forward.',
      ),
      (
        'Monotony',
        'Average daily load ÷ its standard deviation over the week (Foster). '
            'Above 2 means every day looks the same: make hard days harder '
            'and easy days easier.',
      ),
    ],
  ),
  GuideSection(
    id: 'calories',
    title: 'Calories burned',
    summary: 'What you burned today: measured, plus an estimated extra.',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.burned,
    entries: [
      (
        'The headline number',
        'Calories burned is resting energy plus measured movement (steps, '
            'workouts, lifting): the same convention Apple, Fitbit, WHOOP, '
            'and Oura use, so it compares with them. Daily living and '
            'digestion are real but not measured, so they are shown '
            'separately as an estimated extra, and the full estimate '
            '(both together) is used for energy balance and maintenance.',
      ),
      (
        'At rest',
        'What your body burns lying still, just staying alive: heart, '
            'brain, organs. Predicted from your weight, height, age, and sex '
            '(Mifflin–St Jeor, or Katch–McArdle with body fat). It runs every '
            'hour of the day, asleep or awake, and is usually 60–70% of '
            'the total. During sleep it runs '
            '${((1 - sleepingMetabolicFraction) * 100).round()}% lower.',
      ),
      (
        'Everyday (estimated extra)',
        'Resting rate is measured lying down, fasted, and perfectly still. '
            'Real life costs more: sitting upright, standing, fidgeting, and '
            'digesting food. Lab studies put sitting still at +4%, standing '
            'at +13%, and fidgeting at +50–90% over rest (Levine 2000). Becel '
            'adds ${(awakeAllowance * 100).round()}% of resting for awake time '
            'without walking, and digestion as '
            '${(tefFractionOfIntake * 100).round()}% of food logged (or '
            '${(tefFractionOfExpenditure * 100).round()}% of the day). It is '
            'not counted during walking or sleep.',
      ),
      (
        'Movement',
        'Walking is costed from steps at '
            '$walkingNetKcalPerKgKm kcal per kg per km on top of resting '
            '(never instead of it, never twice). An hour of walking shows as '
            'one hour of resting in "At rest" plus the extra cost of walking '
            'in "Movement"; the everyday allowance is not added for those '
            'minutes. Workouts use heart rate (Keytel 2005) above '
            '${(keytelMinHrr * 100).round()}% of heart-rate reserve. Below that, '
            'the larger of step cost and half of Keytel is used (hills, '
            'stairs, cycling). Lifting uses Compendium METs.',
      ),
      ('Full method', energyMethod),
      (
        'Is the full estimate too high?',
        'A whole day of sitting still burns about 1.3–1.4× your resting rate. '
            'Doubly labelled water studies, the gold standard for free-living '
            'energy, find about 1.4–1.6 for sedentary people and 1.7–2.0+ for '
            'active ones (FAO/WHO); devices that count only measured movement '
            'read about 16% below that (Murakami 2019, Chowdhury 2017). A gym '
            'session typically adds 250–550 kcal; heart rate with no steps '
            'or recorded workout is capped at ${capMet.round()} METs, because '
            'lifting and stress raise pulse far more than oxygen use. '
            'Becel shows this ratio as "activity level"; outside 1.35–2.6 '
            'usually means missing wear time or a wrong profile value.',
      ),
      (
        'Why Fitbit differs',
        'Fitbit\'s method is not public; it typically credits more for easy '
            'movement and a raised pulse. Becel uses steps there and drops '
            'incidental steps (5-minute blocks under $ambulatoryBucketSteps '
            'steps, unless heart rate rises '
            '${confirmedBucketHrRise.round()}+ bpm), like typing or arm swings.',
      ),
      (
        'Maintenance and balance',
        'Maintenance is your average full-day burn over days with 12+ hours '
            'of wear: a starting intake to hold weight, adjusted by your '
            'scale trend. About 7,700 kcal is 1 kg of body mass.',
      ),
    ],
  ),
  GuideSection(
    id: 'sleep',
    title: 'Sleep',
    summary: 'How much you slept vs what your body needed.',
    icon: Icons.bedtime_rounded,
    color: AppColors.sleep,
    entries: [
      (
        'Sleep need',
        'Your baseline is learned from your best-rested nights (upper '
            'quartile of the last 28, skipping rebound nights), within 7–9 h, '
            'or set in Settings. Tonight adds up to 45 min after a hard '
            'training day and a third of the last 3 nights\' shortfall (max '
            '60 min) as debt.',
      ),
      (
        'Sleep start correction',
        'Fitbit often starts sleep while you are still awake in bed. When '
            'your heart rate stays at awake levels, Becel moves the start '
            'later (at most 60 min). You can switch this off in Settings.',
      ),
      (
        'Stages',
        'Wrist stage estimates agree with lab sleep studies only moderately; '
            'total sleep and timing are more reliable than the deep/REM split.',
      ),
      (
        'Consistency',
        'The spread (standard deviation) of your sleep midpoint over the '
            'week. Under ±45 min is regular; irregular timing blunts recovery '
            'even when the hours are fine.',
      ),
    ],
  ),
  GuideSection(
    id: 'heart',
    title: 'Heart rate & zones',
    summary: 'Your zones and how noisy wrist data is cleaned.',
    icon: Icons.monitor_heart_rounded,
    color: AppColors.active,
    entries: [
      (
        'Zones',
        'Karvonen zones on heart-rate reserve: Z1 50%, Z2 60%, Z3 70%, Z4 80%, '
            'Z5 90%+. Max HR is your tested value if set, else the highest '
            'heart rate held 3+ minutes in 28 days, else the Tanaka age '
            'prediction.',
      ),
      (
        'Cleaning',
        'Isolated spikes are replaced with the local median (Hampel filter). '
            'Stretches where the optical sensor locked onto your step rhythm '
            '(HR jumps, tracks cadence, then snaps back while you keep moving) '
            'are dropped. Charts show 5-minute averages.',
      ),
    ],
  ),
  GuideSection(
    id: 'vitals',
    title: 'Vitals & fitness',
    summary: 'Breathing, skin temperature, cardio fitness.',
    icon: Icons.air_rounded,
    color: AppColors.steps,
    entries: [
      (
        'Body alert',
        'Breathing up 1+/min or skin temperature +0.5 °C over your baseline '
            'lowers recovery. Two or more signals together, with resting HR '
            'up, raise a body alert: often the first sign of illness.',
      ),
      (
        'Cardio fitness (VO₂max)',
        'Estimated as 15.3 × max HR ÷ resting HR (Uth 2004) and shown as a '
            'range. With an age-predicted max the error roughly doubles; a '
            'tested max HR in Settings narrows it.',
      ),
      (
        'What is missing',
        'Fitbit Air does not share blood oxygen or a measured VO₂max with '
            'Health Connect, so Becel cannot show them.',
      ),
    ],
  ),
  GuideSection(
    id: 'data',
    title: 'Your data',
    summary: 'Read-only, on your phone, never uploaded.',
    icon: Icons.lock_rounded,
    color: AppColors.textSecondary,
    entries: [
      (
        'Where it comes from',
        'Fitbit Air and Google Health records in Health Connect. Becel only '
            'reads; it never writes or logs health data.',
      ),
      (
        'What Becel stores',
        'Your age, sex, and optional settings, plus a copy of the last read '
            'so the app opens instantly. Both stay on this phone; nothing is '
            'uploaded. Reset profile in Settings clears them.',
      ),
      (
        'Not medical advice',
        'Becel\'s numbers are training and wellness guidance.',
      ),
    ],
  ),
];

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.initiallyOpen,
  });

  final GuideSection section;
  final bool initiallyOpen;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconChip(icon: s.icon, color: s.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: AppType.cardTitle),
                        const SizedBox(height: 2),
                        Text(s.summary, style: AppType.caption),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (title, body) in s.entries) ...[
                          const Divider(height: 20, color: AppColors.border),
                          Text(
                            title,
                            style: AppType.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(body, style: AppType.note),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
