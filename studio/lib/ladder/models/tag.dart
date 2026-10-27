import 'enums.dart';
import 'plc_tag_contract.dart';
import 'tag_value.dart';

/// Identificador do controlador dono de um tag.
/// `null` (ou vazio) = controlador primário (índice 0).
/// Para tag vinculado a controlador secundário, usa o IP ou id do nó
/// (ex.: '192.168.0.12' ou 'ENDAP-3639181160').
class Tag {
  final String id;
  String name;
  final TagType type;
  TagValue? initialValue;
  final String? address;
  final String? description;
  final String? unit;

  /// Parâmetros de Escalonamento Analógico (ex: 4-20mA -> 0-100 Bar)
  final double? rawMin;
  final double? rawMax;
  final double? scaledMin;
  final double? scaledMax;

  /// Parâmetros de Calibração Universal (Offset/Trim e Ganho/Slope)
  final double? calOffset;
  final double? calGain;

  /// ID do controlador dono deste tag. `null` = controlador primário.
  /// Pode ser IP (ex.: '192.168.0.12'), node-id (ex.: 'ENDAP-3639181160')
  /// ou índice numérico como string (ex.: '1' para o segundo controlador).
  final String? controllerId;

  Tag({
    required this.id,
    required this.name,
    required this.type,
    this.initialValue,
    this.address,
    this.description,
    this.unit,
    this.rawMin,
    this.rawMax,
    this.scaledMin,
    this.scaledMax,
    this.calOffset,
    this.calGain,
    this.controllerId,
  });

  /// Realiza o escalonamento linear e calibração universal de um valor analógico bruto
  double scaleValue(double rawValue) {
    double scaled = rawValue;
    if (rawMin != null && rawMax != null && scaledMin != null && scaledMax != null) {
      final rangeRaw = rawMax! - rawMin!;
      if (rangeRaw.abs() < 1e-9) {
        scaled = scaledMin!;
      } else {
        final minR = rawMin! < rawMax! ? rawMin! : rawMax!;
        final maxR = rawMin! < rawMax! ? rawMax! : rawMin!;
        final clampedRaw = rawValue.clamp(minR, maxR);
        scaled = scaledMin! + (clampedRaw - rawMin!) * (scaledMax! - scaledMin!) / rangeRaw;
      }
    }
    // Fórmula calibrada: (scaled * (calGain ?? 1.0)) + (calOffset ?? 0.0)
    return (scaled * (calGain ?? 1.0)) + (calOffset ?? 0.0);
  }

  /// Índice do controlador derivado de [controllerId] ou, se ausente, do
  /// byte do [address] (I0.x/Q0.x/M0.x = 0, I1.x/Q1.x/M1.x = 1, ...).
  /// 0 = primário (padrão), 1 = secundário, 2+ = expandido.
  int get controllerIndex {
    if (controllerId != null && controllerId!.isNotEmpty) {
      final num = int.tryParse(controllerId!);
      if (num != null && num >= 0 && num <= 254) return num;
    }
    final normalized = PlcTagContract.normalizeAddress(address, allowExtended: true) ?? PlcTagContract.normalizeAddress(address);
    if (normalized != null) {
      final matchBit = RegExp(r'^(I|Q|M|AI|AO)(\d{1,2})\.(\d)$').firstMatch(normalized);
      if (matchBit != null) {
        final byteIdx = int.parse(matchBit.group(2)!);
        return byteIdx;
      }
    }
    return 0;
  }

  Tag clone() {
    return Tag(
      id: id,
      name: name,
      type: type,
      initialValue: initialValue?.clone(),
      address: address,
      description: description,
      unit: unit,
      rawMin: rawMin,
      rawMax: rawMax,
      scaledMin: scaledMin,
      scaledMax: scaledMax,
      calOffset: calOffset,
      calGain: calGain,
      controllerId: controllerId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        if (initialValue != null) 'initialValue': initialValue!.toJson(),
        if (address != null) 'address': address,
        if (description != null) 'description': description,
        if (unit != null) 'unit': unit,
        if (rawMin != null) 'rawMin': rawMin,
        if (rawMax != null) 'rawMax': rawMax,
        if (scaledMin != null) 'scaledMin': scaledMin,
        if (scaledMax != null) 'scaledMax': scaledMax,
        if (calOffset != null) 'calOffset': calOffset,
        if (calGain != null) 'calGain': calGain,
        if (controllerId != null && controllerId!.isNotEmpty) 'controllerId': controllerId,
      };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
        type: TagType.values.byName(json['type'] as String),
        initialValue: json['initialValue'] != null
            ? TagValue.fromJson(json['initialValue'] as Map<String, dynamic>)
            : null,
        address: json['address'] as String?,
        description: json['description'] as String?,
        unit: json['unit'] as String?,
        rawMin: (json['rawMin'] as num?)?.toDouble(),
        rawMax: (json['rawMax'] as num?)?.toDouble(),
        scaledMin: (json['scaledMin'] as num?)?.toDouble(),
        scaledMax: (json['scaledMax'] as num?)?.toDouble(),
        calOffset: (json['calOffset'] as num?)?.toDouble(),
        calGain: (json['calGain'] as num?)?.toDouble(),
        controllerId: json['controllerId'] as String?,
      );
}
