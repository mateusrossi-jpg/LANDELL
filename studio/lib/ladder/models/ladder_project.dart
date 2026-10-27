import 'tag.dart';
import 'plc_tag_contract.dart';
import 'ladder_network.dart';
import 'node_config.dart';
import 'project_metadata.dart';
import 'demo_project.dart';
import '../../home/models/home_widget_config.dart';
import '../../home/models/hmi_screen.dart';

class LadderProject {
  final String id;
  String name;
  Map<String, Tag> tags; // Acesso O(1) pelo ID da Tag
  List<LadderNetwork> networks;
  ProjectMetadata metadata;
  List<HomeWidgetConfig>? dashboardWidgets;
  List<HmiScreen>? hmiScreens;

  LadderProject({
    required this.id,
    required this.name,
    Map<String, Tag>? tags,
    List<LadderNetwork>? networks,
    ProjectMetadata? metadata,
    this.dashboardWidgets,
    this.hmiScreens,
  })  : tags = tags ?? DemoProject.createDefaultTags(),
        networks = networks ?? [],
        metadata = metadata ?? ProjectMetadata();

  /// Projeto novo em branco com a tabela canônica de tags IEC padrão (I0.x, Q0.x, AI0.x, AO0.x).
  LadderProject.blank({String? name})
      : this(
          id: 'blank',
          name: name ?? 'Novo Projeto',
          tags: DemoProject.createDefaultTags(),
          networks: [],
        );

  LadderProject clone() {
    return LadderProject(
      id: id,
      name: name,
      tags: tags.map((k, v) => MapEntry(k, v.clone())),
      networks: networks.map((n) => n.clone()).toList(),
      metadata: metadata.clone(),
      dashboardWidgets: dashboardWidgets?.map((w) => w.clone()).toList(),
      hmiScreens: hmiScreens?.map((s) => s.clone()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tags': tags.map((k, v) => MapEntry(k, v.toJson())),
        'networks': networks.map((n) => n.toJson()).toList(),
        'metadata': metadata.toJson(),
        if (dashboardWidgets != null)
          'dashboardWidgets': dashboardWidgets!.map((n) => n.toJson()).toList(),
        if (hmiScreens != null)
          'hmiScreens': hmiScreens!.map((s) => s.toJson()).toList(),
      };

  factory LadderProject.fromJson(Map<String, dynamic> json) => LadderProject(
        id: json['id'] as String,
        name: json['name'] as String,
        tags: () {
          final parsed = (json['tags'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), Tag.fromJson(Map<String, dynamic>.from(v as Map))),
              ) ?? {};
          parsed.remove('UMID_SOLO');
          final defaults = DemoProject.createDefaultTags();
          for (final entry in defaults.entries) {
            parsed.putIfAbsent(entry.key, () => entry.value);
          }
          // Garante que AI0.0 e AI0.1 usem 0-100% diretamente
          for (final aiKey in ['AI0.0', 'AI0.1']) {
            if (defaults.containsKey(aiKey)) {
              parsed[aiKey] = defaults[aiKey]!;
            }
          }
          return parsed;
        }(),
        networks: ((json['networks'] as List<dynamic>?)
                ?.map((e) => LadderNetwork.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [])
          ..forEach((net) {
            for (final n in net.nodes) {
              if (n.config.tagId == 'UMID_SOLO') {
                n.config = NodeConfig(
                  tagId: 'AI0.0',
                  presetValue: n.config.presetValue,
                  setpointTagId: n.config.setpointTagId,
                  outputTagId: n.config.outputTagId,
                  kp: n.config.kp,
                  ki: n.config.ki,
                  kd: n.config.kd,
                );
              }
            }
          }),
        metadata: json['metadata'] != null
            ? ProjectMetadata.fromJson(Map<String, dynamic>.from(json['metadata'] as Map))
            : ProjectMetadata(),
        dashboardWidgets: json['dashboardWidgets'] != null
            ? (json['dashboardWidgets'] as List<dynamic>)
                .map((e) => HomeWidgetConfig.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : null,
        hmiScreens: json['hmiScreens'] != null
            ? (json['hmiScreens'] as List<dynamic>)
                .map((e) => HmiScreen.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : null,
      );
  // Resolve tag address according to ENDAP ADDRESSING CONTRACT V1.
  // Standardized Memory Map (0..255):
  // 10..25  : Physical Inputs (I0.0..I1.7 / X0..X15)
  // 26..39  : Internal Bit Flags (M0..M13)
  // 40..55  : Timers (T0..T15)
  // 56..71  : Counters (C0..C15)
  // 72..87  : Math / Integer Registers (N0..N15 / IW / QW)
  // 88..99  : Dynamic Custom Internal Tags Fallback
  // 100..115: Physical Outputs (Q0.0..Q1.7 / Y0..Y15)
  /// Mapeia o identificador/endereço de uma TAG para sua identidade numérica de 16-bits.
  int getTagAddress(String tagId) {
    final tag = tags[tagId];
    final rawAddress = tag?.address?.trim();
    String targetStr = (rawAddress != null && rawAddress.isNotEmpty) ? rawAddress : tagId.trim();

    return PlcTagContract.addressToId(targetStr);
  }
}

