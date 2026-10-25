enum BiologicalSex { female, male }

class BodyProfile {
  const BodyProfile({
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.bodyFatPercent,
    this.maxHrOverride,
    this.sleepNeedMinutes,
    this.correctSleepOnset = true,
  });

  /// Whether Becel trims sleep onset logged while heart rate was still at
  /// waking levels. A calculation preference, not health data.
  final bool correctSleepOnset;

  final int? age;
  final BiologicalSex? sex;
  final double? heightCm;
  final double? weightKg;

  /// Optional. When present, resting energy uses Katch–McArdle (lean mass)
  /// instead of Mifflin–St Jeor, which underestimates muscular athletes.
  final double? bodyFatPercent;

  /// Optional lab- or field-tested maximum heart rate. Overrides both the
  /// age prediction and the observed maximum.
  final int? maxHrOverride;

  /// Optional personal baseline sleep need. Defaults to 8 h.
  final int? sleepNeedMinutes;

  bool get isComplete =>
      age != null && sex != null && heightCm != null && weightKg != null;

  bool get hasEnergyInputs =>
      age != null &&
      sex != null &&
      heightCm != null &&
      weightKg != null &&
      age! >= 18 &&
      age! <= 100 &&
      heightCm! >= 120 &&
      heightCm! <= 230 &&
      weightKg! >= 30 &&
      weightKg! <= 250;

  bool get hasValidBodyFat =>
      bodyFatPercent != null && bodyFatPercent! >= 3 && bodyFatPercent! <= 60;

  double? get leanMassKg => hasValidBodyFat && weightKg != null
      ? weightKg! * (1 - bodyFatPercent! / 100)
      : null;

  BodyProfile copyWith({
    int? age,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    double? bodyFatPercent,
    int? maxHrOverride,
    int? sleepNeedMinutes,
    bool? correctSleepOnset,
  }) => BodyProfile(
    age: age ?? this.age,
    sex: sex ?? this.sex,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
    maxHrOverride: maxHrOverride ?? this.maxHrOverride,
    sleepNeedMinutes: sleepNeedMinutes ?? this.sleepNeedMinutes,
    correctSleepOnset: correctSleepOnset ?? this.correctSleepOnset,
  );

  Map<String, Object?> toJson() => {
    'age': age,
    'sex': sex?.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'bodyFatPercent': bodyFatPercent,
    'maxHrOverride': maxHrOverride,
    'sleepNeedMinutes': sleepNeedMinutes,
    'correctSleepOnset': correctSleepOnset,
  };

  factory BodyProfile.fromJson(Map<String, dynamic> json) {
    final rawSex = json['sex'] as String?;
    BiologicalSex? sex;
    for (final value in BiologicalSex.values) {
      if (value.name == rawSex) {
        sex = value;
        break;
      }
    }
    return BodyProfile(
      age: (json['age'] as num?)?.toInt(),
      sex: sex,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      correctSleepOnset: json['correctSleepOnset'] as bool? ?? true,
      maxHrOverride: (json['maxHrOverride'] as num?)?.toInt(),
      sleepNeedMinutes: (json['sleepNeedMinutes'] as num?)?.toInt(),
    );
  }
}
