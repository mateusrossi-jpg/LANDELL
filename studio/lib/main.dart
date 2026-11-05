import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'core/auth/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF353B4A)),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Componente indisponível no momento',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  };
  await SessionManager.instance.init();
  runApp(const AppShell());
}
