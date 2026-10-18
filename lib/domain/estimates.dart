import 'dart:math' as math;

class BecelEstimate {
  const BecelEstimate({required this.value, required this.formula});

  final int value;
  final String formula;
}

const sleepScoreFormula =
    'Becel estimate: 65% duration vs an 8-hour target plus 35% deep+REM '
    'share vs a 35% reference. This is not a Fitbit Sleep Score.';

const recoveryScoreFormula =
    'Becel estimate: 60% HRV vs your 14-day average plus 40% resting heart '
    'rate vs your 14-day average. This is not a Fitbit readiness score.';

const strainFormula =
    'Becel estimate: time in heart-rate zones weighted by intensity '
    '(Z2\u00d71, Z3\u00d72, Z4\u00d74, Z5\u00d77) with diminishing returns. '
    'This is not a Fitbit Daily Readiness or strain score.';

int? sleepScoreEstimate({
  required int minutes,
  required int deepMinutes,
  required int remMinutes,
}) {
  if (minutes <= 0) return null;
  final durationComponent = (minutes / 480).clamp(0.0, 1.0) * 100;
  final stageShare = (deepMinutes + remMinutes) / minutes;
  final stageComponent = (stageShare / 0.35).clamp(0.0, 1.0) * 100;
  return (0.65 * durationComponent + 0.35 * stageComponent).round();
}

double strainLoadFromZones(List<int> zoneMinutes) {
  const weights = [0.0, 1.0, 2.0, 4.0, 7.0];
  var load = 0.0;
  for (var index = 0; index < weights.length && index < zoneMinutes.length; index++) {
    load += zoneMinutes[index] * weights[index];
  }
  return load;
}

int strainEstimateFromZones(List<int> zoneMinutes) {
  final load = strainLoadFromZones(zoneMinutes);
  if (load <= 0) return 0;
  return (100 * (1 - math.exp(-load / 300))).round().clamp(0, 100);
}

int? recoveryEstimate({
  required int? restingHr,
  required int? restingHrBaseline,
  required double? hrv,
  required double? hrvBaseline,
}) {
  if (restingHr == null ||
      restingHrBaseline == null ||
      hrv == null ||
      hrvBaseline == null ||
      hrvBaseline <= 0) {
    return null;
  }
  final hrvRatio = (hrv / hrvBaseline).clamp(0.5, 1.5);
  final hrvComponent = (hrvRatio - 0.5) * 100;
  final rhrComponent =
      (0.5 + (restingHrBaseline - restingHr) / 20).clamp(0.0, 1.0) * 100;
  return (0.6 * hrvComponent + 0.4 * rhrComponent).round().clamp(0, 100);
}
