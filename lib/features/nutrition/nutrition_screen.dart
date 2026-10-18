import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/mock_data.dart';
import '../../widgets/components.dart';
import '../../widgets/visuals.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            const Text(
              'Nutrition',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Row(
                children: [
                  ScoreRing(
                    value: 0.78,
                    color: AppColors.nutrition,
                    size: 92,
                    stroke: 8,
                    center: const Text(
                      '78',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrition score',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Good balance today. Sodium is a bit high.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Energy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Goal 2,200',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '1,430',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'kcal eaten',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Net -590',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ProgressBar(
                    value: 1430 / 2200,
                    color: AppColors.nutrition,
                    height: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: const [
                  _MacroRow(
                    label: 'Protein',
                    current: 96,
                    goal: 140,
                    color: AppColors.green,
                  ),
                  SizedBox(height: 14),
                  _MacroRow(
                    label: 'Carbs',
                    current: 158,
                    goal: 240,
                    color: AppColors.yellow,
                  ),
                  SizedBox(height: 14),
                  _MacroRow(
                    label: 'Fat',
                    current: 52,
                    goal: 70,
                    color: AppColors.strain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(
              'Meals',
              trailing: TextButton(
                onPressed: () => showSoonSnack(context, 'Food logging'),
                child: const Text('Add'),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  for (final meal in MockData.meals)
                    InfoRow(
                      title: meal.name,
                      subtitle: formatTime(meal.time),
                      value: '${meal.kcal} kcal',
                      icon: Icons.restaurant_outlined,
                      iconColor: AppColors.nutrition,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  final String label;
  final int current;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$current / ${goal}g',
              style: const TextStyle(
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(value: current / goal, color: color),
      ],
    );
  }
}
