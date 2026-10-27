import 'package:flutter/material.dart';
import '../../../models/enums.dart';

class LadderToolbox extends StatelessWidget {
  final bool isDraggingNode;
  final Function(int, int) onNodeDeleted;
  final Function(NodeType) onNodeTapped;

  const LadderToolbox({
    super.key,
    required this.isDraggingNode,
    required this.onNodeDeleted,
    required this.onNodeTapped,
  });

  static const List<Map<String, dynamic>> _tools = [
    {'label': 'NO', 'type': NodeType.contactNO},
    {'label': 'NC', 'type': NodeType.contactNC},
    {'label': 'COIL', 'type': NodeType.coil},
    {'label': 'SET', 'type': NodeType.coilSet},
    {'label': 'RST', 'type': NodeType.coilReset},
    {'label': 'TON', 'type': NodeType.timerTON},
    {'label': 'TOF', 'type': NodeType.timerTOF},
    {'label': 'CTU', 'type': NodeType.counterCTU},
    {'label': 'EQU', 'type': NodeType.compareEqual},
    {'label': 'GRT', 'type': NodeType.compareGreater},
    {'label': 'LES', 'type': NodeType.compareLess},
    {'label': 'ADD', 'type': NodeType.mathADD},
    {'label': 'SUB', 'type': NodeType.mathSUB},
    {'label': 'MUL', 'type': NodeType.mathMUL},
    {'label': 'DIV', 'type': NodeType.mathDIV},
    {'label': 'PID', 'type': NodeType.pid},
  ];

  @override
  Widget build(BuildContext context) {
    if (isDraggingNode) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF2A1C1C),
          border: Border(top: BorderSide(color: Color(0xFFD9503F), width: 1.5)),
        ),
        child: _buildTrashDropZone(),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF1C222C),
          border: Border(top: BorderSide(color: Color(0xFF4B5563), width: 1.2)),
        ),
        child: Center(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _tools.map((item) {
              return _buildToolItem(
                label: item['label'] as String,
                type: item['type'] as NodeType,
              );
            }).toList(),
          ),
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1C222C),
        border: Border(top: BorderSide(color: Color(0xFF4B5563), width: 1.2)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, idx) {
          final item = _tools[idx];
          return _buildToolItem(
            label: item['label'] as String,
            type: item['type'] as NodeType,
          );
        },
      ),
    );
  }

  Widget _buildTrashDropZone() {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => details.data['type'] == 'move',
      onAcceptWithDetails: (details) {
        final srcRung = details.data['srcRung'] as int;
        final srcNode = details.data['srcNode'] as int;
        onNodeDeleted(srcRung, srcNode);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_sweep, color: isHovered ? Colors.white : const Color(0xFFD9503F), size: 20),
            const SizedBox(width: 8),
            Text(
              'Solte aqui para excluir',
              style: TextStyle(
                color: isHovered ? Colors.white : const Color(0xFFD9503F),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolItem({
    required String label,
    required NodeType type,
  }) {
    final buttonContent = Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF262E3B),
        border: Border.all(color: const Color(0xFF4B5563), width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 20,
            child: CustomPaint(
              painter: _ToolSvgIconPainter(type: type, color: const Color(0xFFFFFFFF)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<NodeType>(
      data: type,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: buttonContent),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: buttonContent),
      child: InkWell(
        onTap: () => onNodeTapped(type),
        borderRadius: BorderRadius.circular(6),
        child: buttonContent,
      ),
    );
  }
}

class _ToolSvgIconPainter extends CustomPainter {
  final NodeType type;
  final Color color;

  _ToolSvgIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    switch (type) {
      case NodeType.contactNO:
        // Left wire lead
        canvas.drawLine(Offset(0, cy), Offset(w * 0.32, cy), paint);
        // Left plate
        canvas.drawLine(Offset(w * 0.32, cy - 6), Offset(w * 0.32, cy + 6), paint);
        // Right plate
        canvas.drawLine(Offset(w * 0.68, cy - 6), Offset(w * 0.68, cy + 6), paint);
        // Right wire lead
        canvas.drawLine(Offset(w * 0.68, cy), Offset(w, cy), paint);
        break;

      case NodeType.contactNC:
        // Left wire lead
        canvas.drawLine(Offset(0, cy), Offset(w * 0.32, cy), paint);
        // Left plate
        canvas.drawLine(Offset(w * 0.32, cy - 6), Offset(w * 0.32, cy + 6), paint);
        // Right plate
        canvas.drawLine(Offset(w * 0.68, cy - 6), Offset(w * 0.68, cy + 6), paint);
        // Right wire lead
        canvas.drawLine(Offset(w * 0.68, cy), Offset(w, cy), paint);
        // Diagonal slash
        canvas.drawLine(Offset(w * 0.68 + 2, cy - 7), Offset(w * 0.32 - 2, cy + 7), paint);
        break;

      case NodeType.coil:
      case NodeType.coilSet:
      case NodeType.coilReset:
        // Left lead
        canvas.drawLine(Offset(0, cy), Offset(w * 0.25, cy), paint);
        // Circle
        canvas.drawCircle(Offset(w / 2, cy), 6, paint);
        // Right lead
        canvas.drawLine(Offset(w * 0.75, cy), Offset(w, cy), paint);
        // Inner S/R text if needed
        if (type == NodeType.coilSet || type == NodeType.coilReset) {
          final letter = type == NodeType.coilSet ? 'S' : 'R';
          final textPainter = TextPainter(
            text: TextSpan(
              text: letter,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(w / 2 - textPainter.width / 2, cy - textPainter.height / 2));
        }
        break;

      default:
        // Box for block functions (TON, TOF, CTU, EQU, GRT, LES, ADD, SUB)
        canvas.drawRect(Rect.fromLTWH(2, 2, w - 4, h - 4), paint);
        final name = type.name.replaceAll('timer', '').replaceAll('counter', '').replaceAll('compare', '').replaceAll('math', '').toUpperCase();
        final textPainter = TextPainter(
          text: TextSpan(
            text: name.length > 3 ? name.substring(0, 3) : name,
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              fontFamily: 'JetBrains Mono',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(w / 2 - textPainter.width / 2, cy - textPainter.height / 2));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ToolSvgIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
