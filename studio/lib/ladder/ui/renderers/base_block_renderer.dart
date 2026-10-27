import 'package:flutter/material.dart';
import '../../models/ladder_node.dart';
import '../models/block_port_descriptor.dart';
import 'render_context.dart';

abstract class BaseBlockRenderer {
  List<BlockPortDescriptor> get ports;
  Size get preferredSize;
  
  Widget render(BuildContext context, LadderNode node, RenderContext renderContext);
}
