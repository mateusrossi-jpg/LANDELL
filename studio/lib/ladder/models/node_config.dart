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

  // PID industrial (todos opcionais; null = padrão industrial abaixo)
  bool? pidDirect; // false/null = ação reversa (MV sobe quando PV cai); true = direta
  bool? pidDerivativeOnError; // false/null = derivada sobre o PV (sem derivative kick)
  int? pidOutMin; // limite inferior da saída (%), padrão 0
  int? pidOutMax; // limite superior da saída (%), padrão 100
  double? pidDeadband; // banda morta sobre o erro (%), padrão 0
  int? pidEnoThreshold; // ENO conduz quando MV > limiar (%), padrão 0
  int? pidEnoHysteresis; // ENO desliga quando MV <= limiar - histerese (%), padrão 0
  int? pidSafeOut; // saída segura quando EN = 0 (%), padrão 0
  String? pidManualTagId; // tag BOOL: true = modo MANUAL (null = sem chave Auto/Manual)
  String? pidManualOut; // saída manual: número (%) ou tag

  static const bool defaultPidDirect = false;
  static const bool defaultPidDerivativeOnError = false;
  static const int defaultPidOutMin = 0;
  static const int defaultPidOutMax = 100;
  static const double defaultPidDeadband = 0.0;
  static const int defaultPidEnoThreshold = 0;
  static const int defaultPidEnoHysteresis = 0;
  static const int defaultPidSafeOut = 0;

  NodeConfig({
    this.tagId,
    this.presetValue,
    this.resetTagId,
    this.setpointTagId,
    this.outputTagId,
    this.kp,
    this.ki,
    this.kd,
    this.pidDirect,
    this.pidDerivativeOnError,
    this.pidOutMin,
    this.pidOutMax,
    this.pidDeadband,
    this.pidEnoThreshold,
    this.pidEnoHysteresis,
    this.pidSafeOut,
    this.pidManualTagId,
    this.pidManualOut,
  });

  /// Configuração padrão de um PID recém-inserido: reverso (irrigação/aquecimento),
  /// 0..100 %, ENO com limiar 20 % e histerese 5 % (pronto para acionar um relé em série).
  factory NodeConfig.pid() => NodeConfig(
        tagId: 'AI0.0',
        setpointTagId: '50',
        outputTagId: 'MV_PID',
        kp: 2.5,
        ki: 0.5,
        kd: 0.1,
        pidDirect: false,
        pidDerivativeOnError: false,
        pidOutMin: 0,
        pidOutMax: 100,
        pidDeadband: 0.0,
        pidEnoThreshold: 20,
        pidEnoHysteresis: 5,
        pidSafeOut: 0,
      );

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
      pidDirect: pidDirect,
      pidDerivativeOnError: pidDerivativeOnError,
      pidOutMin: pidOutMin,
      pidOutMax: pidOutMax,
      pidDeadband: pidDeadband,
      pidEnoThreshold: pidEnoThreshold,
      pidEnoHysteresis: pidEnoHysteresis,
      pidSafeOut: pidSafeOut,
      pidManualTagId: pidManualTagId,
      pidManualOut: pidManualOut,
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
        if (pidDirect != null) 'pidDirect': pidDirect,
        if (pidDerivativeOnError != null) 'pidDerivativeOnError': pidDerivativeOnError,
        if (pidOutMin != null) 'pidOutMin': pidOutMin,
        if (pidOutMax != null) 'pidOutMax': pidOutMax,
        if (pidDeadband != null) 'pidDeadband': pidDeadband,
        if (pidEnoThreshold != null) 'pidEnoThreshold': pidEnoThreshold,
        if (pidEnoHysteresis != null) 'pidEnoHysteresis': pidEnoHysteresis,
        if (pidSafeOut != null) 'pidSafeOut': pidSafeOut,
        if (pidManualTagId != null) 'pidManualTagId': pidManualTagId,
        if (pidManualOut != null) 'pidManualOut': pidManualOut,
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
        pidDirect: json['pidDirect'] as bool?,
        pidDerivativeOnError: json['pidDerivativeOnError'] as bool?,
        pidOutMin: (json['pidOutMin'] as num?)?.toInt(),
        pidOutMax: (json['pidOutMax'] as num?)?.toInt(),
        pidDeadband: (json['pidDeadband'] as num?)?.toDouble(),
        pidEnoThreshold: (json['pidEnoThreshold'] as num?)?.toInt(),
        pidEnoHysteresis: (json['pidEnoHysteresis'] as num?)?.toInt(),
        pidSafeOut: (json['pidSafeOut'] as num?)?.toInt(),
        pidManualTagId: json['pidManualTagId'] as String?,
        pidManualOut: json['pidManualOut'] as String?,
      );
}
