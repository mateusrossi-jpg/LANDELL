import 'tag_value.dart';

/// Substitui o uso de Map para configuracoes de bloco.
class NodeConfig {
  String? tagId; // ID da tag principal vinculada (ex: Sensor_1 / PV no PID)
  String? resetTagId; // Optional reset tag for counters
  TagValue? presetValue; // Para blocos que exigem um preset hardcoded

  // Configurações do Bloco PID
  String? setpointTagId; // Tag do Setpoint (SP) ou null para usar valor fixo
  String? outputTagId; // Tag de saída (MV)
  double? kp; // Ganho Proporcional (ex: 2.0)
  double? ki; // Ganho Integral (ex: 0.5)
  double? kd; // Ganho Derivativo (ex: 0.1)

  NodeConfig({
    this.tagId,
    this.presetValue,
    this.resetTagId,
    this.setpointTagId,
    this.outputTagId,
    this.kp,
    this.ki,
    this.kd,
  });

  NodeConfig clone() {
    return NodeConfig(
      tagId: tagId,
      presetValue: presetValue?.clone(),
      resetTagId: resetTagId,
      setpointTagId: setpointTagId,
      outputTagId: outputTagId,
      kp: kp,
      ki: ki,
      kd: kd,
    );
  }

  Map<String, dynamic> toJson() => {
        if (tagId != null) 'tagId': tagId,
        if (resetTagId != null) 'resetTagId': resetTagId,
        if (presetValue != null) 'presetValue': presetValue!.toJson(),
        if (setpointTagId != null) 'setpointTagId': setpointTagId,
        if (outputTagId != null) 'outputTagId': outputTagId,
        if (kp != null) 'kp': kp,
        if (ki != null) 'ki': ki,
        if (kd != null) 'kd': kd,
      };

  factory NodeConfig.fromJson(Map<String, dynamic> json) => NodeConfig(
        tagId: json['tagId'] as String?,
        resetTagId: json['resetTagId'] as String?,
        presetValue: json['presetValue'] != null
            ? TagValue.fromJson(json['presetValue'] as Map<String, dynamic>)
            : null,
        setpointTagId: json['setpointTagId'] as String?,
        outputTagId: json['outputTagId'] as String?,
        kp: (json['kp'] as num?)?.toDouble(),
        ki: (json['ki'] as num?)?.toDouble(),
        kd: (json['kd'] as num?)?.toDouble(),
      );
}
