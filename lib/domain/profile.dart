enum BiologicalSex { female, male }

class BodyProfile {
  const BodyProfile({this.age, this.sex, this.heightCm, this.weightKg});

  final int? age;
  final BiologicalSex? sex;
  final double? heightCm;
  final double? weightKg;

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

  BodyProfile copyWith({
    int? age,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
  }) => BodyProfile(
    age: age ?? this.age,
    sex: sex ?? this.sex,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
  );

  Map<String, Object?> toJson() => {
    'age': age,
    'sex': sex?.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
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
    );
  }
}
