import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../models/block_port_descriptor.dart';
import '../renderers/base_block_renderer.dart';
import '../renderers/render_context.dart';

class CoilRenderer implements BaseBlockRenderer {
  @override
  List<BlockPortDescriptor> get ports => const [
    BlockPortDescriptor(id: 'in', direction: PortDirection.input, dataType: PortDataType.boolean, verticalSlot: 0),
    BlockPortDescriptor(id: 'out', direction: PortDirection.output, dataType: PortDataType.boolean, verticalSlot: 0),
  ];

  @override
  Size get preferredSize => const Size(64, 54);

  @override
  Widget render(BuildContext context, LadderNode node, RenderContext renderContext) {
    final color = node.isEnergized ? Colors.greenAccent : Colors.grey[400]!;
    final String label = node.type == NodeType.coil
        ? 'Q0.0'
        : (node.type == NodeType.coilSet ? 'S' : 'R');

    return SizedBox(
      width: preferredSize.width,
      height: preferredSize.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, right: 0, height: 2, child: Container(color: color)),
          Positioned(
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                color: node.isEnergized ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.transparent,
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
