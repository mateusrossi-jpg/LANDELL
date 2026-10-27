import '../models/block_port_descriptor.dart';

abstract class BlockDefinition {
  String get id;
  String get displayName;
  List<BlockPortDescriptor> get ports;
  
  // Security-mandated property validation
  bool validateProperties(Map<String, dynamic> properties);
}
