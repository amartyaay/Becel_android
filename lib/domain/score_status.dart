import 'package:flutter/material.dart';

import '../app/theme.dart';

class ScoreStatus {
  const ScoreStatus(this.label, this.color);

  final String label;
  final Color color;

  static ScoreStatus recovery(int value) {
    if (value >= 70) return const ScoreStatus('Primed', AppColors.green);
    if (value >= 50) return const ScoreStatus('Moderate', AppColors.yellow);
    return const ScoreStatus('Take it easy', AppColors.red);
  }

  static ScoreStatus sleepScore(int value) {
    if (value >= 75) return const ScoreStatus('Optimal', AppColors.green);
    if (value >= 60) return const ScoreStatus('Fair', AppColors.yellow);
    return const ScoreStatus('Poor', AppColors.red);
  }

  static ScoreStatus strain(int value, int low, int high) {
    if (value < low) return const ScoreStatus('Under target', AppColors.sleep);
    if (value <= high) return const ScoreStatus('In range', AppColors.green);
    return const ScoreStatus('Above target', AppColors.red);
  }

  static ScoreStatus stress(int value) {
    if (value <= 33) return const ScoreStatus('Calm', AppColors.green);
    if (value <= 66) return const ScoreStatus('Moderate', AppColors.yellow);
    return const ScoreStatus('High', AppColors.red);
  }

  static ScoreStatus energy(int value) {
    if (value >= 70) return const ScoreStatus('Charged', AppColors.green);
    if (value >= 40) return const ScoreStatus('Steady', AppColors.yellow);
    return const ScoreStatus('Running low', AppColors.red);
  }
}
