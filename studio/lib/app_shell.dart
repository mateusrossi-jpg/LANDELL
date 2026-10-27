import 'package:flutter/material.dart';
import 'design_system/theme.dart';
import 'core/auth/session_manager.dart';
import 'core/ui/login_page.dart';
import 'core/ui/studio_scaffold.dart';
import 'ladder/models/ladder_project.dart';
import 'ladder/models/demo_project.dart';
import 'core/services/network_manager.dart' hide ConnectionState;
import 'ladder_autosave.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Single shared NetworkManager instance for the app
  late final NetworkManager _networkManager;
  LadderProject _project = DemoProject.createCleanTccProject();

  @override
  void initState() {
    super.initState();
    _networkManager = NetworkManager(autoStartPeriodicCheck: true);
    _restoreProject();
  }

  void _restoreProject() {
    if (SessionManager.instance.isLoggedIn) {
      loadCurrentLadder()
          .timeout(const Duration(milliseconds: 500), onTimeout: () => null)
          .then((loaded) {
        if (mounted && loaded != null) {
          // Se for versão anterior da bancada ou demo legado, carrega a lógica limpa com PID em AI0.0
          final isCleanCurrent = loaded.id == 'proj_bancada_tcc_v4_pid_clean';
          final finalProj = isCleanCurrent ? loaded : DemoProject.createCleanTccProject();
          if (!isCleanCurrent) {
            saveCurrentLadder(finalProj);
          }
          setState(() {
            _project = finalProj;
          });
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _networkManager.dispose();
    super.dispose();
  }

  void _handleLoginSuccess() {
    setState(() {
      _restoreProject();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Endap Studio',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: SessionManager.instance.isLoggedIn
          ? StudioScaffold(
              initialIndex: 0,
              initialProject: _project,
              networkManager: _networkManager,
            )
          : LoginPage(
              networkManager: _networkManager,
              onLoginSuccess: _handleLoginSuccess,
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}

