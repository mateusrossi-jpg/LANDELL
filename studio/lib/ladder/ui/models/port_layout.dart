import '../../models/enums.dart';

class PortLayout {
  final String portId;      // Ex: "T4:0_IN" ou "T4:0_PT"
  final double worldX;
  final double worldY;      // Liberado da prisão do centerY!
  final PortDirection direction;
  final PortDataType dataType;
  final String label;       // O texto impresso ao lado do pino: "IN", "PT", "Q", "ET"

  const PortLayout({
    required this.portId,
    required this.worldX,
    required this.worldY,
    required this.direction,
    required this.dataType,
    required this.label,
  });
}
