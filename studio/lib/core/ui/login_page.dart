import 'package:flutter/material.dart';
import '../services/network_manager.dart';
import '../auth/session_manager.dart';
import 'studio_scaffold.dart';
import 'widgets/endap_logo_widget.dart';
import '../../ladder/models/ladder_project.dart';
import '../../ladder_autosave.dart';
import '../../design_system/tokens.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  final NetworkManager networkManager;

  const LoginPage({super.key, this.onLoginSuccess, required this.networkManager});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Informe o usuário para autenticar.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await SessionManager.instance.login(username, password);
    if (!mounted) return;

    if (success) {
      await _navigateToHome();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Falha na autenticação. Verifique os dados informados.';
      });
    }
  }

  Future<void> _handleTechnicalAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await SessionManager.instance.loginTechnical();
    if (!mounted) return;

    await _navigateToHome();
  }

  Future<void> _handleQuickPersonaLogin(String username, String role) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _usernameController.text = username;
    });
    await SessionManager.instance.login(username, '', role: role);
    if (!mounted) return;
    await _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    if (widget.onLoginSuccess != null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      widget.onLoginSuccess!();
      return;
    }

    final savedProject = await loadCurrentLadder();
    if (!mounted) return;

    final project = savedProject ??
        LadderProject.raw(
          id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Meu Projeto',
        );
    if (savedProject == null) {
      await saveCurrentLadder(project);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudioScaffold(
          initialIndex: 0,
          initialProject: project,
          networkManager: widget.networkManager,
        ),
      ),
    );
  }

  Widget _buildPersonaQuickPill({
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTokens.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTokens.muted,
                        fontSize: 9.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShortScreen = MediaQuery.sizeOf(context).height < 700;
    return Scaffold(
      backgroundColor: AppTokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: isShortScreen ? 8 : 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Industrial Brand Header
                  Center(
                    child: EndapLogoWidget(
                      size: isShortScreen ? 32 : 48,
                      showText: true,
                      showSubtitle: !isShortScreen,
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 4 : 12),
                  Center(
                    child: Text(
                      'AUTENTICAÇÃO & CONTROLE INDUSTRIAL',
                      style: TextStyle(
                        color: AppTokens.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 10 : 28),

                  // Login Form Card
                  Container(
                    padding: EdgeInsets.all(isShortScreen ? 14 : 24),
                    decoration: BoxDecoration(
                      color: AppTokens.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTokens.line, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'IDENTIFICAÇÃO DO USUÁRIO',
                          style: TextStyle(
                            color: AppTokens.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 10 : 18),

                        // Username field
                        Text(
                          'USUÁRIO',
                          style: TextStyle(
                            color: AppTokens.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 4 : 6),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(
                            color: AppTokens.textPrimary,
                            fontSize: 13,
                            fontFamily: 'JetBrains Mono',
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Digite seu usuário',
                            hintStyle: TextStyle(color: AppTokens.muted.withValues(alpha: 0.6), fontSize: 12),
                            filled: true,
                            fillColor: AppTokens.panel2,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isShortScreen ? 9 : 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.focus, width: 1.2),
                            ),
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 10 : 16),

                        // Password field
                        Text(
                          'SENHA',
                          style: TextStyle(
                            color: AppTokens.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 4 : 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                            color: AppTokens.textPrimary,
                            fontSize: 13,
                            fontFamily: 'JetBrains Mono',
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '••••••••',
                            hintStyle: TextStyle(color: AppTokens.muted.withValues(alpha: 0.6), fontSize: 12),
                            suffixIcon: TextButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Text(
                                _obscurePassword ? 'MOSTRAR' : 'OCULTAR',
                                style: TextStyle(
                                  color: AppTokens.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: AppTokens.panel2,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: isShortScreen ? 9 : 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppTokens.focus, width: 1.2),
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          SizedBox(height: isShortScreen ? 8 : 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTokens.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.error.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppTokens.error, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                        SizedBox(height: isShortScreen ? 12 : 22),

                        // Login Submit Button
                        SizedBox(
                          height: isShortScreen ? 38 : 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTokens.focus,
                              foregroundColor: AppTokens.bg,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTokens.bg,
                                    ),
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 8 : 14),

                  // Perfis de Operação
                  Container(
                    padding: EdgeInsets.all(isShortScreen ? 10 : 14),
                    decoration: BoxDecoration(
                      color: AppTokens.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.line, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECIONAR PERFIL DE ACESSO',
                          style: TextStyle(
                            color: AppTokens.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 6 : 10),
                        Row(
                          children: [
                            _buildPersonaQuickPill(
                              label: 'Engenheiro',
                              subtitle: 'Acesso completo',
                              color: const Color(0xFF38BDF8),
                              onTap: () => _handleQuickPersonaLogin('ENGENHEIRO', 'INTEGRADOR'),
                            ),
                            const SizedBox(width: 8),
                            _buildPersonaQuickPill(
                              label: 'Manutenção',
                              subtitle: 'Diagnóstico e E/S',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _handleQuickPersonaLogin('MANUTENCAO', 'MANUTENÇÃO'),
                            ),
                          ],
                        ),
                        SizedBox(height: isShortScreen ? 6 : 8),
                        Row(
                          children: [
                            _buildPersonaQuickPill(
                              label: 'Operador IHM',
                              subtitle: 'Supervisão e comando',
                              color: const Color(0xFF10B981),
                              onTap: () => _handleQuickPersonaLogin('OPERADOR', 'OPERADOR INDUSTRIAL'),
                            ),
                            const SizedBox(width: 8),
                            _buildPersonaQuickPill(
                              label: 'Gestor',
                              subtitle: 'Indicadores e auditoria',
                              color: const Color(0xFFA855F7),
                              onTap: () => _handleQuickPersonaLogin('GESTOR', 'GESTOR'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 8 : 14),

                  // Secondary Technical Access Button
                  SizedBox(
                    height: isShortScreen ? 36 : 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.textPrimary,
                        side: BorderSide(color: AppTokens.line),
                        backgroundColor: AppTokens.panel2.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _handleTechnicalAccess,
                      child: const Text(
                        'ACESSO TÉCNICO EM CAMPO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isShortScreen ? 8 : 24),

                  // System Status Footer
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MODO OFFLINE-READY',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
