import 'package:flutter/material.dart';
import '../../models/enums.dart';

class LadderNodePainter extends CustomPainter {
  final NodeType type;
  final bool isEnergized;
  final Color color;

  LadderNodePainter({
    required this.type,
    required this.isEnergized,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    
    // Fio de entrada e saída
    canvas.drawLine(Offset(0, centerY), Offset(size.width * 0.2, centerY), paint);
    canvas.drawLine(Offset(size.width * 0.8, centerY), Offset(size.width, centerY), paint);

    if (type == NodeType.contactNO || type == NodeType.contactNC) {
      // Duas barras verticais
      canvas.drawLine(Offset(size.width * 0.35, size.height * 0.2), Offset(size.width * 0.35, size.height * 0.8), paint);
      canvas.drawLine(Offset(size.width * 0.65, size.height * 0.2), Offset(size.width * 0.65, size.height * 0.8), paint);
      
      if (type == NodeType.contactNC) {
        // Barra diagonal para NF
        canvas.drawLine(Offset(size.width * 0.25, size.height * 0.8), Offset(size.width * 0.75, size.height * 0.2), paint);
      }
    } else if (type == NodeType.coil || type == NodeType.coilSet || type == NodeType.coilReset) {
      // Parênteses ou Círculo
      canvas.drawArc(
        Rect.fromLTRB(size.width * 0.2, size.height * 0.2, size.width * 0.5, size.height * 0.8),
        3.1415 / 2, 3.1415, false, paint,
      );
      canvas.drawArc(
        Rect.fromLTRB(size.width * 0.5, size.height * 0.2, size.width * 0.8, size.height * 0.8),
        -3.1415 / 2, 3.1415, false, paint,
      );
      
      if (type == NodeType.coilSet || type == NodeType.coilReset) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: type == NodeType.coilSet ? 'S' : 'R',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, centerY - textPainter.height / 2));
      }
    } else {
      // Blocos complexos (TON, TOF, CTU, CMP)
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromLTRB(size.width * 0.2, size.height * 0.1, size.width * 0.8, size.height * 0.9), paint);
      
      String label = '';
      if (type == NodeType.timerTON) {
        label = 'TON';
      } else if (type == NodeType.timerTOF) {
        label = 'TOF';
      } else if (type == NodeType.counterCTU) {
        label = 'CTU';
      } else if (type == NodeType.counterCTD) {
        label = 'CTD';
      } else if (type == NodeType.compareEqual) {
        label = 'EQU';
      } else if (type == NodeType.compareGreater) {
        label = 'GRT';
      } else if (type == NodeType.compareLess) {
        label = 'LES';
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height * 0.2));
    }
  }

  @override
  bool shouldRepaint(covariant LadderNodePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.isEnergized != isEnergized || oldDelegate.color != color;
  }
}
