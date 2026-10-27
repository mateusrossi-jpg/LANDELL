import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'core/auth/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.instance.init();
  runApp(const AppShell());
}
