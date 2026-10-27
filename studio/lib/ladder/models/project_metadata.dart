/// Estrutura rigidamente os metadados do projeto.
class ProjectMetadata {
  final String version;
  final String author;
  final String targetPlatform; // Ex: "EndapRuntime", "ESP32", "SimulatorOnly"

  ProjectMetadata({
    this.version = '1.0.0',
    this.author = '',
    this.targetPlatform = 'SimulatorOnly',
  });

  ProjectMetadata clone() {
    return ProjectMetadata(
      version: version,
      author: author,
      targetPlatform: targetPlatform,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'author': author,
        'targetPlatform': targetPlatform,
      };

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) => ProjectMetadata(
        version: json['version'] as String? ?? '1.0.0',
        author: json['author'] as String? ?? '',
        targetPlatform: json['targetPlatform'] as String? ?? 'SimulatorOnly',
      );
}
