import 'home_widget_config.dart';

/// Modelo de Tela de IHM Industrial com controle de acesso baseado em perfil (RBAC)
/// e suporte à exportação para tablets e painéis dedicados.
class HmiScreen {
  final String id;
  String title;
  String iconName; // e.g. 'precision_manufacturing', 'speed', 'tune', 'analytics'
  List<String> allowedRoles; // ['OPERADOR', 'INTEGRADOR', 'MANUTENÇÃO', 'GESTOR']
  List<HomeWidgetConfig> widgets;
  bool isKioskEnabled;
  String? description;

  HmiScreen({
    required this.id,
    required this.title,
    this.iconName = 'dashboard',
    List<String>? allowedRoles,
    List<HomeWidgetConfig>? widgets,
    this.isKioskEnabled = true,
    this.description,
  })  : allowedRoles = allowedRoles ?? ['OPERADOR', 'INTEGRADOR', 'MANUTENÇÃO', 'GESTOR'],
        widgets = widgets ?? [];

  /// Verifica se o perfil atual tem permissão para visualizar e interagir com esta tela
  bool canAccess(String? currentRole) {
    if (currentRole == null || currentRole.isEmpty) return true;
    final role = currentRole.toUpperCase();
    if (role == 'INTEGRADOR' ||
        role == 'ADMIN' ||
        role.contains('TÉCNICO') ||
        role.contains('TECNICO') ||
        role.contains('AUTORIZADO')) {
      return true; // Técnico/Integrador tem acesso total para validação e auditoria
    }
    return allowedRoles.any((r) => r.toUpperCase() == role || role.contains(r.toUpperCase()));
  }

  HmiScreen clone() {
    return HmiScreen(
      id: id,
      title: title,
      iconName: iconName,
      allowedRoles: List.from(allowedRoles),
      widgets: widgets.map((w) => w.clone()).toList(),
      isKioskEnabled: isKioskEnabled,
      description: description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconName': iconName,
        'allowedRoles': allowedRoles,
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'isKioskEnabled': isKioskEnabled,
        if (description != null) 'description': description,
      };

  factory HmiScreen.fromJson(Map<String, dynamic> json) => HmiScreen(
        id: json['id'] as String? ?? 'screen_${DateTime.now().millisecondsSinceEpoch}',
        title: json['title'] as String? ?? 'Tela IHM',
        iconName: json['iconName'] as String? ?? 'dashboard',
        allowedRoles: (json['allowedRoles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            ['OPERADOR', 'INTEGRADOR', 'MANUTENÇÃO', 'GESTOR'],
        widgets: (json['widgets'] as List<dynamic>?)
                ?.map((e) => HomeWidgetConfig.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
        isKioskEnabled: json['isKioskEnabled'] as bool? ?? true,
        description: json['description'] as String?,
      );
}
