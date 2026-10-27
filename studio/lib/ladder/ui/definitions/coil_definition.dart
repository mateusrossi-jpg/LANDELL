import '../../models/enums.dart';
import '../models/block_definition.dart';
import '../models/block_port_descriptor.dart';

class CoilDefinition implements BlockDefinition {
  final String coilType; // 'coil', 'set', 'reset'
  
  CoilDefinition({required this.coilType});

  @override
  String get id => 'coil_$coilType';

  @override
  String get displayName => 'Coil ${coilType.toUpperCase()}';

  @override
  List<BlockPortDescriptor> get ports => const [
    BlockPortDescriptor(id: 'in', direction: PortDirection.input, dataType: PortDataType.boolean, verticalSlot: 0),
    BlockPortDescriptor(id: 'out', direction: PortDirection.output, dataType: PortDataType.boolean, verticalSlot: 0),
  ];

  @override
  bool validateProperties(Map<String, dynamic> properties) => true; 
}
