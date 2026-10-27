import '../../models/enums.dart';

class BlockPortDescriptor {
  final String id;
  final PortDirection direction;
  final PortDataType dataType;
  final double verticalSlot; // -1, 0, 1 para alinhamento vertical

  const BlockPortDescriptor({
    required this.id,
    required this.direction,
    required this.dataType,
    required this.verticalSlot,
  });
}
