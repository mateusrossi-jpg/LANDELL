import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/core/ui/studio_scaffold.dart';
import 'package:endap_studio/core/ui/widgets/audit_log_dialog.dart';
import 'package:endap_studio/core/ui/widgets/user_session_dialog.dart';
import 'package:endap_studio/ladder/models/demo_project.dart';
import 'package:endap_studio/core/services/network_manager.dart';
import 'package:endap_studio/core/services/studio_event_bus.dart';

void main() {
  testWidgets('Valida presenca de Saidas Analogicas AO0.0/AO0.1, Trilha de Auditoria e Gestao de Usuarios', (tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = DemoProject.createDemoProject();
    final networkManager = NetworkManager();

    // Emit event test
    StudioEventBus.instance.emit(
      type: 'AUDIT_TEST',
      source: 'UNIT_TEST',
      message: 'TESTE DE EVENTO AUDITORIA EXECUTADO COM SUCESSO',
      severity: EventSeverity.info,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StudioScaffold(
          initialIndex: 2, // Abre direto na tela GPIO / TAGS
          initialProject: project,
          networkManager: networkManager,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Scroll e verifica se a seção "SAÍDAS ANALÓGICAS" e os canais AO0.0 e AO0.1 aparecem
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.textContaining('SAÍDAS ANALÓGICAS'), findsOneWidget);
    expect(find.text('AO0.0'), findsWidgets);
    expect(find.text('AO0.1'), findsWidgets);

    // 2. Abre o menu Hamburguer (Drawer)
    final menuBtn = find.byTooltip('Menu');
    expect(menuBtn, findsOneWidget);
    await tester.tap(menuBtn);
    await tester.pumpAndSettle();

    // 3. Verifica se as opções de Auditoria e Usuários existem no Drawer
    expect(find.text('Trilha de Auditoria & Eventos'), findsOneWidget);
    expect(find.text('Gestão de Usuários & Login'), findsOneWidget);

    // Fecha o Drawer
    final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold).first);
    scaffoldState.closeDrawer();
    await tester.pumpAndSettle();

    // 4. Testa diretamente a abertura e renderização do AuditLogDialog
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    AuditLogDialog.show(context);
    await tester.pumpAndSettle();

    expect(find.text('TRILHA DE AUDITORIA & EVENTOS'), findsOneWidget);
    expect(find.descendant(of: find.byType(AuditLogDialog), matching: find.textContaining('TESTE DE EVENTO AUDITORIA EXECUTADO COM SUCESSO')), findsOneWidget);

    // Fecha o diálogo de auditoria
    final closeBtn = find.byIcon(Icons.close);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // 5. Testa diretamente a abertura e renderização do UserSessionDialog
    UserSessionDialog.show(
      context,
      networkManager: networkManager,
      onLogout: () {},
    );
    await tester.pumpAndSettle();

    expect(find.text('USUÁRIOS & SESSÃO ATIVA'), findsOneWidget);
    expect(find.text('Trocar de Usuário / Login'), findsOneWidget);
  });
}
