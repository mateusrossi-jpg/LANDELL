/// Wrapper fortemente tipado para eliminar o uso de "dynamic".
class TagValue {
  final bool? boolValue;
  final int? intValue;
  final double? realValue;
  final String? stringValue;

  TagValue({
    this.boolValue,
    this.intValue,
    this.realValue,
    this.stringValue,
  });

  // Construtores nomeados para facilitar a criacao e validacao
  factory TagValue.boolean(bool value) => TagValue(boolValue: value);
  factory TagValue.integer(int value) => TagValue(intValue: value);
  factory TagValue.real(double value) => TagValue(realValue: value);
  factory TagValue.string(String value) => TagValue(stringValue: value);

  TagValue clone() {
    return TagValue(
      boolValue: boolValue,
      intValue: intValue,
      realValue: realValue,
      stringValue: stringValue,
    );
  }

  Map<String, dynamic> toJson() => {
        if (boolValue != null) 'boolValue': boolValue,
        if (intValue != null) 'intValue': intValue,
        if (realValue != null) 'realValue': realValue,
        if (stringValue != null) 'stringValue': stringValue,
      };

  factory TagValue.fromJson(Map<String, dynamic> json) => TagValue(
        boolValue: json['boolValue'] as bool?,
        intValue: json['intValue'] as int?,
        realValue: (json['realValue'] as num?)?.toDouble(),
        stringValue: json['stringValue'] as String?,
      );
}
