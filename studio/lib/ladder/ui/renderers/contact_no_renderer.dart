import 'package:flutter/material.dart';
import '../../models/enums.dart';
import '../../models/ladder_node.dart';
import '../models/block_port_descriptor.dart';
import '../renderers/base_block_renderer.dart';
import '../renderers/render_context.dart';

class ContactNoRenderer implements BaseBlockRenderer {
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
    
    return SizedBox(
      width: preferredSize.width,
      height: preferredSize.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, right: 0, height: 2, child: Container(color: color)),
          Positioned(left: 20, top: 12, bottom: 12, child: Container(width: 4, color: color)),
          Positioned(right: 20, top: 12, bottom: 12, child: Container(width: 4, color: color)),
          Positioned(left: 24, right: 24, height: 32, child: Container(color: Colors.transparent)),
        ],
      ),
    );
  }
}
