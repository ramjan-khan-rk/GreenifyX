class MomentLook {
  final String id;
  final String label;
  final List<double> matrix;

  const MomentLook(this.id, this.label, this.matrix);
}

const _identity = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _contrast(double amount) {
  final t = (1 - amount) * 128;
  return [
    amount, 0, 0, 0, t,
    0, amount, 0, 0, t,
    0, 0, amount, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturate(double amount) {
  const lumR = 0.213;
  const lumG = 0.715;
  const lumB = 0.072;
  final sr = (1 - amount) * lumR;
  final sg = (1 - amount) * lumG;
  final sb = (1 - amount) * lumB;
  return [
    sr + amount, sg, sb, 0, 0,
    sr, sg + amount, sb, 0, 0,
    sr, sg, sb + amount, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

final momentLooks = <MomentLook>[
  MomentLook("natural", "Natural", _identity),
  MomentLook("hd", "HD", _contrast(1.12)),
  MomentLook("vivid", "Vivid", _saturate(1.45)),
  MomentLook(
    "warm",
    "Warm",
    [
      1.12, 0, 0, 0, 8,
      0, 1.02, 0, 0, 4,
      0, 0, 0.9, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  MomentLook(
    "cool",
    "Cool",
    [
      0.92, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1.12, 0, 8,
      0, 0, 0, 1, 0,
    ],
  ),
  MomentLook(
    "mono",
    "Mono",
    [
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ],
  ),
  MomentLook("soft", "Soft", _contrast(0.92)),
];

MomentLook lookById(String id) {
  return momentLooks.firstWhere(
    (look) => look.id == id,
    orElse: () => momentLooks.first,
  );
}
