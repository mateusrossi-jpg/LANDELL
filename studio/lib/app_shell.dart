import 'package:flutter/material.dart';
import 'design_system/theme.dart';
import 'core/auth/session_manager.dart';
import 'core/ui/login_page.dart';
import 'core/ui/studio_scaffold.dart';
import 'ladder/models/ladder_project.dart';
import 'core/services/network_manager.dart' hide ConnectionState;
import 'ladder_autosave.dart';

class AppShell extends StatefulWidget {
  final LadderProject? initialProject;
  const AppShell({super.key, this.initialProject});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Single shared NetworkManager instance for the app
  late final NetworkManager _networkManager;
  late LadderProject _project;

  @override
  void initState() {
    super.initState();
    _networkManager = NetworkManager(autoStartPeriodicCheck: true);
    _project = widget.initialProject ?? LadderProject.raw();
    if (widget.initialProject == null) {
      _restoreProject();
    }
  }

  void _restoreProject() {
    loadCurrentLadder()
        .timeout(const Duration(seconds: 2), onTimeout: () => null)
        .then((loaded) {
      if (!mounted) return;
      if (loaded != null) {
        setState(() {
          _project = loaded;
        });
      } else {
        saveCurrentLadder(_project);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _networkManager.dispose();
    super.dispose();
  }

  void _handleLoginSuccess() {
    _restoreProject();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANDELL Studio',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        );
      },
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

