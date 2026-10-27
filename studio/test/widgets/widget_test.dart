import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:endap_studio/app_shell.dart';
import 'package:endap_studio/core/auth/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionManager.instance.login('OPERADOR INDUSTRIAL', 'OPERATOR');
  });

  testWidgets(
    'Studio AppShell opens and displays Studio Scaffold',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const AppShell());
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining(RegExp(r'(LANDELL|ENDAP)', caseSensitive: false)), findsWidgets);
    },
  );

  testWidgets(
    'Rede & Topologia navigation opens Redes tab with Controller section',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const AppShell());
      await tester.pump(const Duration(seconds: 1));

      final menuFinder = find.byWidgetPredicate(
        (w) => w is Icon && (w.icon == Icons.menu || w.icon == Icons.menu_rounded),
      );
      await tester.tap(menuFinder.first);
      await tester.pump(const Duration(milliseconds: 500));

      final tileFinder = find.textContaining('Rede & Topologia');
      expect(tileFinder, findsOneWidget);
      await tester.ensureVisible(tileFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(tileFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // A aba Redes exibe a seção de Rede & Topologia e o Controlador Principal
      expect(find.text('Rede & Topologia'), findsWidgets);
      expect(find.text('Controlador Principal'), findsOneWidget);

      final wifiButtonFinder = find.text('Conectar Wi-Fi');
      expect(wifiButtonFinder, findsOneWidget);
      await tester.ensureVisible(wifiButtonFinder);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(wifiButtonFinder);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('IP do Controlador Alvo (em modo AP):'), findsOneWidget);
    },
  );
}
