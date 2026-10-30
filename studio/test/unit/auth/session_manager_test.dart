import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/core/auth/session_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionManager - Default & Initial State', () {
    test('Default instance has initial values', () {
      final session = SessionManager.instance;
      expect(session.isLoggedIn, isTrue);
      expect(session.currentUser, equals('OPERADOR'));
      expect(session.currentRole, equals('OPERADOR INDUSTRIAL'));
      expect(session.sessionToken, isNull);
      expect(session.authHeaders, isEmpty);
    });
  });

  group('SessionManager - Role-based Permissions Matrix', () {
    test('Operator role permissions', () async {
      final session = SessionManager.instance;
      await session.login('operador1', 'pass');

      expect(session.currentUser, equals('operador1'));
      expect(session.currentRole, equals('OPERADOR INDUSTRIAL'));
      expect(session.isIntegrator, isFalse);
      expect(session.isMaintenance, isFalse);
      expect(session.canConfigureIO, isFalse);
      expect(session.canEditRules, isFalse);
    });

    test('Technical / Admin user permissions', () async {
      final session = SessionManager.instance;

      await session.login('ADMIN', 'pass');
      expect(session.isIntegrator, isTrue);
      expect(session.isMaintenance, isTrue);
      expect(session.canConfigureIO, isTrue);
      expect(session.canEditRules, isTrue);

      await session.login('TECNICO_CAMPO', 'pass');
      expect(session.isIntegrator, isTrue);
      expect(session.isMaintenance, isTrue);
      expect(session.canConfigureIO, isTrue);
      expect(session.canEditRules, isTrue);
    });

    test('Technical login (loginTechnical) permissions', () async {
      final session = SessionManager.instance;
      await session.loginTechnical();

      expect(session.currentUser, equals('TECNICO_CAMPO'));
      expect(session.currentRole, equals('ACESSO TÉCNICO AUTORIZADO'));
      expect(session.isIntegrator, isTrue);
      expect(session.isMaintenance, isTrue);
      expect(session.canConfigureIO, isTrue);
      expect(session.canEditRules, isTrue);
    });

    test('Logout clears session state and permissions', () async {
      final session = SessionManager.instance;
      await session.loginTechnical();
      expect(session.isLoggedIn, isTrue);

      await session.logout();

      expect(session.isLoggedIn, isFalse);
      expect(session.currentUser, isNull);
      expect(session.currentRole, isNull);
      expect(session.isIntegrator, isFalse);
      expect(session.isMaintenance, isFalse);
      expect(session.canConfigureIO, isFalse);
      expect(session.canEditRules, isFalse);
    });
  });

  group('SessionManager - Authentication Flow & Validation', () {
    test('Login with empty/whitespace username returns false and does not alter session', () async {
      final session = SessionManager.instance;
      await session.loginTechnical(); // set to known state

      final successEmpty = await session.login('', 'password');
      expect(successEmpty, isFalse);
      expect(session.currentUser, equals('TECNICO_CAMPO'));

      final successSpaces = await session.login('   ', 'password');
      expect(successSpaces, isFalse);
      expect(session.currentUser, equals('TECNICO_CAMPO'));
    });

    test('Login with valid username trims username and sets session', () async {
      final session = SessionManager.instance;
      final success = await session.login('  operator_2  ', 'password');

      expect(success, isTrue);
      expect(session.isLoggedIn, isTrue);
      expect(session.currentUser, equals('operator_2'));
      expect(session.currentRole, equals('OPERADOR INDUSTRIAL'));
    });
  });

  group('SessionManager - SharedPreferences Persistence & init()', () {
    test('init() loads saved session from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'endap_session_active': true,
        'endap_session_user': 'saved_user',
        'endap_session_role': 'INTEGRADOR',
      });

      final session = SessionManager.instance;
      await session.init();

      expect(session.isLoggedIn, isTrue);
      expect(session.currentUser, equals('saved_user'));
      expect(session.currentRole, equals('INTEGRADOR'));
      expect(session.isIntegrator, isTrue);
      expect(session.isMaintenance, isTrue);
    });

    test('init() handles inactive session from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'endap_session_active': false,
        'endap_session_user': 'previous_user',
        'endap_session_role': 'OPERADOR INDUSTRIAL',
      });

      final session = SessionManager.instance;
      await session.init();

      expect(session.isLoggedIn, isFalse);
      expect(session.currentUser, equals('previous_user'));
    });

    test('login, loginTechnical, and logout update SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final session = SessionManager.instance;

      await session.login('user_pref_test', '1234');
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('endap_session_active'), isTrue);
      expect(prefs.getString('endap_session_user'), equals('user_pref_test'));
      expect(prefs.getString('endap_session_role'), equals('OPERADOR INDUSTRIAL'));

      await session.logout();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('endap_session_active'), isNull);
      expect(prefs.getString('endap_session_user'), isNull);
      expect(prefs.getString('endap_session_role'), isNull);

      await session.loginTechnical();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('endap_session_active'), isTrue);
      expect(prefs.getString('endap_session_user'), equals('TECNICO_CAMPO'));
      expect(prefs.getString('endap_session_role'), equals('ACESSO TÉCNICO AUTORIZADO'));
    });
  });

  group('SessionManager - StudioEventBus Emissions', () {
    test('login emits AUTH event to StudioEventBus', () async {
      final session = SessionManager.instance;
      await session.login('audit_user', 'pass');

      final lastEvent = StudioEventBus.instance.events.first;
      expect(lastEvent.type, equals('AUTH'));
      expect(lastEvent.source, equals('LOGIN_PANEL'));
      expect(lastEvent.message, contains('AUTENTICAÇÃO REALIZADA: audit_user'));
      expect(lastEvent.severity, equals(EventSeverity.info));
    });

    test('loginTechnical emits warning AUTH event', () async {
      final session = SessionManager.instance;
      await session.loginTechnical();

      final lastEvent = StudioEventBus.instance.events.first;
      expect(lastEvent.type, equals('AUTH'));
      expect(lastEvent.source, equals('LOGIN_PANEL'));
      expect(lastEvent.message, contains('ACESSO TÉCNICO DIRETO EM CAMPO ATIVADO'));
      expect(lastEvent.severity, equals(EventSeverity.warning));
    });

    test('logout emits AUTH event', () async {
      final session = SessionManager.instance;
      await session.login('user_leaving', 'pass');
      await session.logout();

      final lastEvent = StudioEventBus.instance.events.first;
      expect(lastEvent.type, equals('AUTH'));
      expect(lastEvent.source, equals('SESSION_MANAGER'));
      expect(lastEvent.message, contains('SESSÃO ENCERRADA: user_leaving'));
      expect(lastEvent.severity, equals(EventSeverity.info));
    });
  });
}
