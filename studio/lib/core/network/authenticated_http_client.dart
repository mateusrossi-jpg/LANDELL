import 'dart:async';
import 'package:http/http.dart' as http;
import '../auth/session_manager.dart';
import '../services/studio_event_bus.dart';

/// HTTP Client decorator that automatically attaches the X-ENDAP-Session header
/// to all requests and handles 401/403 authorization failures with friendly events.
class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;

  AuthenticatedHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = SessionManager.instance.sessionToken;
    if (token != null && token.isNotEmpty) {
      request.headers['X-ENDAP-Session'] = token;
    }

    final response = await _inner.send(request);

    if (response.statusCode == 401 || response.statusCode == 403) {
      StudioEventBus.instance.emit(
        type: 'AUTH_REQUIRED',
        source: 'HTTP_CLIENT',
        message: 'Acesso não autorizado ou sessão expirada no Gateway (${response.statusCode}). Faça login novamente.',
        severity: EventSeverity.warning,
      );
    }

    return response;
  }
}
