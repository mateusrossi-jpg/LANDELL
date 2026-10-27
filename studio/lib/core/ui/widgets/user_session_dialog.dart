import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';
import '../../auth/session_manager.dart';
import '../../services/network_manager.dart';
import '../login_page.dart';

class UserSessionDialog extends StatelessWidget {
  final NetworkManager networkManager;
  final VoidCallback onLogout;

  const UserSessionDialog({
    super.key,
    required this.networkManager,
    required this.onLogout,
  });

  static Future<void> show(
    BuildContext context, {
    required NetworkManager networkManager,
    required VoidCallback onLogout,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => UserSessionDialog(
        networkManager: networkManager,
        onLogout: onLogout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser ?? 'OPERADOR INDUSTRIAL';
    final role = SessionManager.instance.currentRole ?? 'LOCAL';
    final isTech = user.toUpperCase().contains('TECNICO');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      backgroundColor: AppTokens.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTokens.line, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTokens.panel2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTokens.focus.withValues(alpha: 0.3), width: 1.0),
                          ),
                          child: const Icon(Icons.manage_accounts_outlined, color: AppTokens.focus, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'USUÁRIOS & SESSÃO ATIVA',
                                style: TextStyle(
                                  color: AppTokens.text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Controle de acesso e privilégios operacionais',
                                style: TextStyle(color: AppTokens.textDim, fontSize: 10.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTokens.textDim, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTokens.line, height: 1),
              const SizedBox(height: 16),

              // Card do Operador Atual
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTokens.panel2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTokens.line, width: 1.0),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTokens.background,
                      child: Icon(
                        isTech ? Icons.engineering : Icons.person,
                        color: AppTokens.focus,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user,
                            style: const TextStyle(
                              color: AppTokens.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role,
                            style: const TextStyle(
                              color: AppTokens.focus,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTokens.run.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTokens.run.withValues(alpha: 0.5), width: 1.0),
                      ),
                      child: const Text(
                        'AUTENTICADO',
                        style: TextStyle(
                          color: AppTokens.run,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Lista de Perfis Disponíveis
              const Text(
                'PERFIS DE OPERAÇÃO DO CONTROLADOR',
                style: TextStyle(
                  color: AppTokens.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              _buildRoleItem(
                title: 'Operador Industrial',
                desc: 'Supervisão de Home Widgets, monitoramento e acionamento manual de I/Os',
                isActive: !isTech,
              ),
              const SizedBox(height: 6),
              _buildRoleItem(
                title: 'Técnico de Campo (Acesso Completo)',
                desc: 'Edição Ladder, download de bytecode, provisionamento Wi-Fi e forçamento',
                isActive: isTech,
              ),

              const SizedBox(height: 18),
              const Divider(color: AppTokens.line, height: 1),
              const SizedBox(height: 14),

              // Botões de Ação
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.focus,
                      side: const BorderSide(color: AppTokens.line, width: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.switch_account_outlined, size: 16),
                    label: const Text('Trocar de Usuário / Login', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginPage(
                            networkManager: networkManager,
                          ),
                        ),
                      );
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.panel2,
                      foregroundColor: AppTokens.fault,
                      side: BorderSide(color: AppTokens.fault.withValues(alpha: 0.4), width: 1.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Encerrar Sessão', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleItem({
    required String title,
    required String desc,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTokens.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTokens.focus : AppTokens.line,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? AppTokens.focus : AppTokens.textDim,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isActive ? AppTokens.text : AppTokens.textDim,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: AppTokens.textDim, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
