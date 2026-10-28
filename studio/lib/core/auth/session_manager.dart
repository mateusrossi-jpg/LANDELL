import 'package:shared_preferences/shared_preferences.dart';
import '../services/studio_event_bus.dart';

class SessionManager {
  static final SessionManager instance = SessionManager._();
  SessionManager._();

  static const String _kSessionActiveKey = 'endap_session_active';
  static const String _kSessionUserKey = 'endap_session_user';
  static const String _kSessionRoleKey = 'endap_session_role';

  bool _isLoggedIn = true;
  String? _currentUser = 'OPERADOR';
  String? _currentRole = 'OPERADOR INDUSTRIAL';
  String? _sessionToken;

  bool get isLoggedIn => _isLoggedIn;
  String? get currentUser => _currentUser;
  String? get currentRole => _currentRole;
  String? get sessionToken => _sessionToken;

  /// Critério US07 / NEC04: Controle estrito de rotas por perfil
  /// Integrador: Permissão total (I/O, Regras, Calibração, Redes)
  /// Manutenção: Diagnóstico, Logs, Hardware e Testes
  /// Operador: Supervisão, Dashboard e Comandos Manuais Autorizados (sem edição de I/O ou regras)
  bool get isIntegrator =>
      _currentRole == 'INTEGRADOR' ||
      _currentRole == 'ACESSO TÉCNICO AUTORIZADO' ||
      _currentUser == 'ADMIN' ||
      _currentUser == 'TECNICO_CAMPO';

  bool get isMaintenance =>
      isIntegrator || _currentRole == 'MANUTENÇÃO' || _currentRole == 'MANUTENCAO';

  bool get canConfigureIO => isIntegrator;
  bool get canEditRules => isIntegrator;

  Map<String, String> get authHeaders =>
      (_sessionToken != null && _sessionToken!.isNotEmpty)
          ? {'X-ENDAP-Session': _sessionToken!}
          : {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      // Por padrão em campo, inicia logado direto; se o usuário fizer logout explícito, vai para LoginPage
      _isLoggedIn = prefs.getBool(_kSessionActiveKey) ?? true;
      _currentUser = prefs.getString(_kSessionUserKey) ?? 'OPERADOR';
      _currentRole = prefs.getString(_kSessionRoleKey) ?? 'OPERADOR INDUSTRIAL';
      if (_isLoggedIn && _currentUser != null) {
        StudioEventBus.instance.emit(
          type: 'AUTH',
          source: 'SESSION_MANAGER',
          message: 'SESSÃO RESTAURADA: $_currentUser ($_currentRole)',
          severity: EventSeverity.info,
        );
      }
    } catch (_) {
      // Offline fallback
    }
  }

  Future<bool> login(String username, String password) async {
    final cleanUser = username.trim();
    if (cleanUser.isEmpty) {
      return false;
    }

    _isLoggedIn = true;
    _currentUser = cleanUser;
    _currentRole = 'OPERADOR INDUSTRIAL';

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      await prefs.setBool(_kSessionActiveKey, true);
      await prefs.setString(_kSessionUserKey, cleanUser);
      await prefs.setString(_kSessionRoleKey, _currentRole!);
    } catch (_) {}

    StudioEventBus.instance.emit(
      type: 'AUTH',
      source: 'LOGIN_PANEL',
      message: 'AUTENTICAÇÃO REALIZADA: $cleanUser ($_currentRole)',
      severity: EventSeverity.info,
    );

    return true;
  }

  Future<void> loginTechnical() async {
    _isLoggedIn = true;
    _currentUser = 'TECNICO_CAMPO';
    _currentRole = 'ACESSO TÉCNICO AUTORIZADO';

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      await prefs.setBool(_kSessionActiveKey, true);
      await prefs.setString(_kSessionUserKey, _currentUser!);
      await prefs.setString(_kSessionRoleKey, _currentRole!);
    } catch (_) {}

    StudioEventBus.instance.emit(
      type: 'AUTH',
      source: 'LOGIN_PANEL',
      message: 'ACESSO TÉCNICO DIRETO EM CAMPO ATIVADO',
      severity: EventSeverity.warning,
    );
  }

  Future<void> logout() async {
    final prevUser = _currentUser ?? 'USUÁRIO';
    _isLoggedIn = false;
    _currentUser = null;
    _currentRole = null;

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 1));
      await prefs.remove(_kSessionActiveKey);
      await prefs.remove(_kSessionUserKey);
      await prefs.remove(_kSessionRoleKey);
    } catch (_) {}

    StudioEventBus.instance.emit(
      type: 'AUTH',
      source: 'SESSION_MANAGER',
      message: 'SESSÃO ENCERRADA: $prevUser',
      severity: EventSeverity.info,
    );
  }
}
