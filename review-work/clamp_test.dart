void main() {
  final v = 7518252;
  final cap = 1 << 62;
  print('cap=$cap');
  print('clamped=${v.clamp(0, cap)}');
  print('cycle0=${0.clamp(0, cap)}');
  final util = 0.5012168;
  print('percent=${(util * 100).round()}');
}
