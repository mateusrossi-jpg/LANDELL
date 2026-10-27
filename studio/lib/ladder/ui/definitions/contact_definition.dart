import '../../models/enums.dart';
import '../models/block_definition.dart';
import '../models/block_port_descriptor.dart';

class ContactDefinition implements BlockDefinition {
  final bool isNormallyClosed;
  
  ContactDefinition({this.isNormallyClosed = false});

  @override
  String get id => isNormallyClosed ? 'contactNC' : 'contactNO';

  @override
  String get displayName => isNormallyClosed ? 'Normally Closed' : 'Normally Open';

  @override
  List<BlockPortDescriptor> get ports => const [
    BlockPortDescriptor(id: 'in', direction: PortDirection.input, dataType: PortDataType.boolean, verticalSlot: 0),
    BlockPortDescriptor(id: 'out', direction: PortDirection.output, dataType: PortDataType.boolean, verticalSlot: 0),
  ];

  @override
  bool validateProperties(Map<String, dynamic> properties) => true; // Simple contact, no complex props
}
