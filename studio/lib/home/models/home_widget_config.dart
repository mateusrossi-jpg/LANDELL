import '../../ladder/models/ladder_project.dart';

enum WidgetTemplateType {
  numeric('VALOR NUMÉRICO', 'Display digital de valor e unidade', 'numeric'),
  sparkline('TENDÊNCIA / SPARKLINE', 'Valor numérico com curva gráfica temporal', 'sparkline'),
  gauge('MANÔMETRO RADIAL', 'Medidor circular em arco de 240°', 'gauge'),
  digital('INDICADOR DIGITAL', 'Status ON/OFF com LED industrial', 'digital'),
  actuator('ATUADOR OPERACIONAL', 'Seletor AUTO/MANUAL com comando PULSE', 'actuator'),
  metric('MÉTRICA COMPACTA', 'Tile compacto com ícone e métrica', 'metric'),
  ioMatrix('MATRIZ DE I/O DIGITAL', 'Grade de canais digitais consolidados', 'ioMatrix');

  final String label;
  final String description;
  final String code;

  const WidgetTemplateType(this.label, this.description, this.code);

  static WidgetTemplateType fromCode(String code) {
    return WidgetTemplateType.values.firstWhere(
      (e) => e.code.toLowerCase() == code.toLowerCase() || e.name.toLowerCase() == code.toLowerCase(),
      orElse: () => WidgetTemplateType.numeric,
    );
  }
}

enum WidgetSizePreset {
  compact('Compacto', 1),
  standard('Padrão', 2),
  wide('Largo (Linha Inteira)', 3);

  final String label;
  final int flex;

  const WidgetSizePreset(this.label, this.flex);

  static WidgetSizePreset fromName(String name) {
    return WidgetSizePreset.values.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => WidgetSizePreset.standard,
    );
  }
}

class HomeWidgetConfig {
  final String id;
  String? tagId;
  WidgetTemplateType templateType;
  String title;
  String? unit;
  double? minValue;
  double? maxValue;
  double? warningMin;
  double? warningMax;
  double? criticalMin;
  double? criticalMax;
  int decimalPlaces;
  String onText;
  String offText;
  int order;
  WidgetSizePreset sizePreset;
  bool visible;
  Map<String, dynamic> customConfig;

  HomeWidgetConfig({
    required this.id,
    this.tagId,
    required this.templateType,
    required this.title,
    this.unit,
    this.minValue,
    this.maxValue,
    this.warningMin,
    this.warningMax,
    this.criticalMin,
    this.criticalMax,
    this.decimalPlaces = 1,
    this.onText = 'ON',
    this.offText = 'OFF',
    this.order = 0,
    this.sizePreset = WidgetSizePreset.standard,
    this.visible = true,
    Map<String, dynamic>? customConfig,
  }) : customConfig = customConfig ?? {};

  HomeWidgetConfig clone() {
    return HomeWidgetConfig(
      id: id,
      tagId: tagId,
      templateType: templateType,
      title: title,
      unit: unit,
      minValue: minValue,
      maxValue: maxValue,
      warningMin: warningMin,
      warningMax: warningMax,
      criticalMin: criticalMin,
      criticalMax: criticalMax,
      decimalPlaces: decimalPlaces,
      onText: onText,
      offText: offText,
      order: order,
      sizePreset: sizePreset,
      visible: visible,
      customConfig: Map<String, dynamic>.from(customConfig),
    );
  }

  HomeWidgetConfig copyWith({
    String? id,
    String? tagId,
    WidgetTemplateType? templateType,
    String? title,
    String? unit,
    double? minValue,
    double? maxValue,
    double? warningMin,
    double? warningMax,
    double? criticalMin,
    double? criticalMax,
    int? decimalPlaces,
    String? onText,
    String? offText,
    int? order,
    WidgetSizePreset? sizePreset,
    bool? visible,
    Map<String, dynamic>? customConfig,
  }) {
    return HomeWidgetConfig(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      templateType: templateType ?? this.templateType,
      title: title ?? this.title,
      unit: unit ?? this.unit,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      warningMin: warningMin ?? this.warningMin,
      warningMax: warningMax ?? this.warningMax,
      criticalMin: criticalMin ?? this.criticalMin,
      criticalMax: criticalMax ?? this.criticalMax,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      onText: onText ?? this.onText,
      offText: offText ?? this.offText,
      order: order ?? this.order,
      sizePreset: sizePreset ?? this.sizePreset,
      visible: visible ?? this.visible,
      customConfig: customConfig ?? Map<String, dynamic>.from(this.customConfig),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (tagId != null) 'tagId': tagId,
        'templateType': templateType.code,
        'title': title,
        if (unit != null) 'unit': unit,
        if (minValue != null) 'minValue': minValue,
        if (maxValue != null) 'maxValue': maxValue,
        if (warningMin != null) 'warningMin': warningMin,
        if (warningMax != null) 'warningMax': warningMax,
        if (criticalMin != null) 'criticalMin': criticalMin,
        if (criticalMax != null) 'criticalMax': criticalMax,
        'decimalPlaces': decimalPlaces,
        'onText': onText,
        'offText': offText,
        'order': order,
        'sizePreset': sizePreset.name,
        'visible': visible,
        'customConfig': customConfig,
      };

  factory HomeWidgetConfig.fromJson(Map<String, dynamic> json) {
    return HomeWidgetConfig(
      id: json['id'] as String? ?? 'widget_${DateTime.now().millisecondsSinceEpoch}',
      tagId: json['tagId'] as String?,
      templateType: WidgetTemplateType.fromCode(json['templateType'] as String? ?? 'numeric'),
      title: json['title'] as String? ?? 'Widget',
      unit: json['unit'] as String?,
      minValue: (json['minValue'] as num?)?.toDouble(),
      maxValue: (json['maxValue'] as num?)?.toDouble(),
      warningMin: (json['warningMin'] as num?)?.toDouble(),
      warningMax: (json['warningMax'] as num?)?.toDouble(),
      criticalMin: (json['criticalMin'] as num?)?.toDouble(),
      criticalMax: (json['criticalMax'] as num?)?.toDouble(),
      decimalPlaces: json['decimalPlaces'] as int? ?? 1,
      onText: json['onText'] as String? ?? 'ON',
      offText: json['offText'] as String? ?? 'OFF',
      order: json['order'] as int? ?? 0,
      sizePreset: WidgetSizePreset.fromName(json['sizePreset'] as String? ?? 'standard'),
      visible: json['visible'] as bool? ?? true,
      customConfig: (json['customConfig'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Gera a composição padrão inicial caso o projeto não possua widgets configurados.
  static List<HomeWidgetConfig> createDefaultWidgets(LadderProject project) {
    final hasTags = project.tags.isNotEmpty;
    final tempTag = hasTags ? project.tags.keys.firstWhere((k) => k.contains('TEMP') || k.contains('ANALOG') || k.contains('AI'), orElse: () => '') : '';
    final pressTag = hasTags ? project.tags.keys.firstWhere((k) => k.contains('PRESS') || k.contains('BAR') || k.contains('PSI'), orElse: () => '') : '';
    final valveTag = hasTags ? project.tags.keys.firstWhere((k) => k.contains('VALV') || k.contains('MOTOR') || k.contains('OUT') || k.contains('Q'), orElse: () => '') : '';

    return [
      HomeWidgetConfig(
        id: 'w_actuator_default',
        tagId: valveTag.isNotEmpty ? valveTag : null,
        templateType: WidgetTemplateType.actuator,
        title: 'V-204 VALVE ACTUATOR',
        sizePreset: WidgetSizePreset.wide,
        order: 0,
      ),
      HomeWidgetConfig(
        id: 'w_temp_default',
        tagId: tempTag.isNotEmpty ? tempTag : null,
        templateType: WidgetTemplateType.sparkline,
        title: 'TEMP MOTOR',
        unit: '°C',
        minValue: 0,
        maxValue: 500,
        sizePreset: WidgetSizePreset.standard,
        order: 1,
      ),
      HomeWidgetConfig(
        id: 'w_press_default',
        tagId: pressTag.isNotEmpty ? pressTag : null,
        templateType: WidgetTemplateType.gauge,
        title: 'PRESSÃO',
        unit: 'PSI',
        minValue: 0,
        maxValue: 100,
        sizePreset: WidgetSizePreset.standard,
        order: 2,
      ),
      HomeWidgetConfig(
        id: 'w_iomatrix_default',
        templateType: WidgetTemplateType.ioMatrix,
        title: 'DIGITAL I/O MATRIX',
        sizePreset: WidgetSizePreset.wide,
        order: 3,
      ),
    ];
  }
}
