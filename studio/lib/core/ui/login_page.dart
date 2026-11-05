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
    required IconData icon,
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
              Icon(icon, size: 16, color: color),
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
    return Scaffold(
      backgroundColor: AppTokens.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Industrial Brand Header
                  const Center(
                    child: EndapLogoWidget(
                      size: 48,
                      showText: true,
                      showSubtitle: true,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 32),

                  // Acesso Rápido Orientado por Perfil (1 Toque)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTokens.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.line, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt, size: 15, color: AppTokens.focus),
                            const SizedBox(width: 6),
                            Text(
                              'ACESSO RÁPIDO POR PERFIL (1 TOQUE)',
                              style: TextStyle(
                                color: AppTokens.focus,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildPersonaQuickPill(
                              icon: Icons.engineering_outlined,
                              label: 'Engenheiro',
                              subtitle: 'Acesso Total + Ladder',
                              color: const Color(0xFF38BDF8),
                              onTap: () => _handleQuickPersonaLogin('ENGENHEIRO', 'INTEGRADOR'),
                            ),
                            const SizedBox(width: 8),
                            _buildPersonaQuickPill(
                              icon: Icons.build_circle_outlined,
                              label: 'Manutenção',
                              subtitle: 'Diagnóstico & Force',
                              color: const Color(0xFFF59E0B),
                              onTap: () => _handleQuickPersonaLogin('MANUTENCAO', 'MANUTENÇÃO'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPersonaQuickPill(
                              icon: Icons.dashboard_outlined,
                              label: 'Operador IHM',
                              subtitle: 'Painel & Comando',
                              color: const Color(0xFF10B981),
                              onTap: () => _handleQuickPersonaLogin('OPERADOR', 'OPERADOR INDUSTRIAL'),
                            ),
                            const SizedBox(width: 8),
                            _buildPersonaQuickPill(
                              icon: Icons.analytics_outlined,
                              label: 'Gestor OEE',
                              subtitle: 'Métricas & Auditoria',
                              color: const Color(0xFFA855F7),
                              onTap: () => _handleQuickPersonaLogin('GESTOR', 'GESTOR'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTokens.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTokens.line, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'IDENTIFICAÇÃO DO OPERADOR',
                          style: TextStyle(
                            color: AppTokens.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 18),

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
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          style: TextStyle(
                            color: AppTokens.textPrimary,
                            fontSize: 13,
                            fontFamily: 'JetBrains Mono',
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'ex: operador_01',
                            hintStyle: TextStyle(color: AppTokens.muted.withValues(alpha: 0.6), fontSize: 12),
                            prefixIcon: Icon(Icons.person_outline, color: AppTokens.focus, size: 18),
                            filled: true,
                            fillColor: AppTokens.panel2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                        const SizedBox(height: 16),

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
                        const SizedBox(height: 6),
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
                            prefixIcon: Icon(Icons.lock_outline, color: AppTokens.focus, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppTokens.muted,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: AppTokens.panel2,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTokens.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTokens.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppTokens.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppTokens.error, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),

                        // Login Submit Button
                        SizedBox(
                          height: 46,
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
                  const SizedBox(height: 16),

                  // Secondary Technical Access Button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.textPrimary,
                        side: BorderSide(color: AppTokens.line),
                        backgroundColor: AppTokens.panel2.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(Icons.build_outlined, size: 16, color: AppTokens.focus),
                      label: const Text(
                        'ACESSO TÉCNICO EM CAMPO',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleTechnicalAccess,
                    ),
                  ),
                  const SizedBox(height: 24),

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
