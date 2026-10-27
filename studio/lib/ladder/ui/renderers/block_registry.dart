import '../../models/enums.dart';
import '../models/block_definition.dart';
import '../renderers/base_block_renderer.dart';
import '../definitions/contact_definition.dart';
import '../renderers/contact_no_renderer.dart';
import '../renderers/contact_nc_renderer.dart';
import '../definitions/coil_definition.dart';
import '../renderers/coil_renderer.dart';

class BlockRegistry {
  static final Map<NodeType, BlockDefinition> _definitions = {
    NodeType.contactNO: ContactDefinition(isNormallyClosed: false),
    NodeType.contactNC: ContactDefinition(isNormallyClosed: true),
    NodeType.coil: CoilDefinition(coilType: 'coil'),
    NodeType.coilSet: CoilDefinition(coilType: 'set'),
    NodeType.coilReset: CoilDefinition(coilType: 'reset'),
  };
  
  static final Map<NodeType, BaseBlockRenderer> _renderers = {
    NodeType.contactNO: ContactNoRenderer(),
    NodeType.contactNC: ContactNcRenderer(),
    NodeType.coil: CoilRenderer(),
    NodeType.coilSet: CoilRenderer(),
    NodeType.coilReset: CoilRenderer(),
  };

  static BlockDefinition getDefinition(NodeType type) {
    final def = _definitions[type];
    if (def == null) throw Exception('No definition registered for: $type');
    return def;
  }

  static BaseBlockRenderer getRenderer(NodeType type) {
    final renderer = _renderers[type];
    if (renderer == null) throw Exception('No renderer registered for: $type');
    return renderer;
  }
}
