extension IntE on int {
  /// test method
  int a(int a) => this;

  void aa() => this;

  /// getA property
  int get getA => this;
}

extension IntE1 on int {
  /// b method
  int b(int a) => this;

  /// getB property
  int get getB => this;

  /// getBB property
  int get getBB => this;
}

extension IntE5 on int? {
  /// b method
  int? c(int a) => this;

  /// getC property
  int? get getC => this;

  /// getCC method
  int? getCC(int? a) => this;
  int? getCCC({int? a}) => this;
}
