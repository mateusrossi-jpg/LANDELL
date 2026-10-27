import '../../models/ladder_project.dart';

String generateProjectFilename([DateTime? dt]) => 'projeto_endap.endap';
String formatProjectJson(LadderProject project, {int scanPeriodMs = 100, String mode = 'RUN'}) => '';

Future<String?> exportProject(LadderProject project, {int scanPeriodMs = 100}) async {
  throw UnimplementedError('exportProject is not implemented on this platform');
}

Future<LadderProject?> importProject() async {
  throw UnimplementedError('importProject is not implemented on this platform');
}
