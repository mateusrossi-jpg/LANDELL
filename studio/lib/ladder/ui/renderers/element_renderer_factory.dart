import '../../models/enums.dart';
import 'base_block_renderer.dart';
import 'contact_no_renderer.dart';
import 'contact_nc_renderer.dart';
import 'coil_renderer.dart';

// Placeholder/Registry for renderers
class ElementRendererFactory {
  static final Map<NodeType, BaseBlockRenderer> _renderers = {
    NodeType.contactNO: ContactNoRenderer(),
    NodeType.contactNC: ContactNcRenderer(),
    NodeType.coil: CoilRenderer(),
    NodeType.coilSet: CoilRenderer(),
    NodeType.coilReset: CoilRenderer(),
  };

  static BaseBlockRenderer getRenderer(NodeType type) {
    final renderer = _renderers[type];
    if (renderer == null) {
      throw Exception('No renderer registered for type: $type');
    }
    return renderer;
  }
}
