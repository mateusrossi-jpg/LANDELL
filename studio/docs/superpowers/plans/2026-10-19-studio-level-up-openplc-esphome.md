# Elevação do ENDAP Studio: Padrão OpenPLC & ESPHome

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Este plano detalha a implementação das 3 evoluções do ENDAP Studio sem modificar a base determinística já validada:
1. **Live Energization & Power Rails** (OpenPLC / Rockwell Studio 5000)
2. **Banner de Descoberta & Gaveta de Logs** (ESPHome / VS Code)
3. **Seletor Inteligente de Tags nos Widgets** (Rockwell Studio 5000)

---

## Estrutura de Arquivos

### Arquivos a Modificar:
- `lib/ladder/ui/editor/widgets/ladder_network_canvas.dart` (Evolução 1: Barramento L1/L2 iluminado)
- `lib/ladder/ui/editor/widgets/ladder_node_visual.dart` (Evolução 1: Badges de temporizadores/contadores em tempo real)
- `lib/core/ui/studio_scaffold.dart` (Evolução 2: Banner de descoberta de nós e ancoragem do terminal)
- `lib/home/ui/widgets/widget_config_dialog.dart` (Evolução 3: Seletor inteligente com busca e categorias)

### Novos Arquivos:
- `lib/core/ui/widgets/industrial_terminal_drawer.dart` (Evolução 2: Terminal retrátil com streaming de logs)
- `test/ladder_live_energization_visual_test.dart` (Testes da Evolução 1)
- `test/industrial_terminal_drawer_test.dart` (Testes da Evolução 2)
- `test/smart_tag_selector_test.dart` (Testes da Evolução 3)

---

## Tarefas

- [ ] **Task 1: Live Energization & Power Rails no Ladder**
  - [ ] Criar teste de renderização `test/ladder_live_energization_visual_test.dart`
  - [ ] Implementar iluminação verde neon no barramento L1 (24V) e L2 (0V) quando em modo RUN em `ladder_network_canvas.dart`
  - [ ] Adicionar indicadores de valor acumulado inline (`.ET`, `.CV`) nos blocos complexos em `ladder_node_visual.dart`
  - [ ] Rodar testes e validar zero regressão de geometria

- [ ] **Task 2: Banner de Descoberta de Nós & Gaveta de Logs Retrátil**
  - [ ] Criar teste unitário e de widget `test/industrial_terminal_drawer_test.dart`
  - [ ] Implementar `IndustrialTerminalDrawer` em `lib/core/ui/widgets/industrial_terminal_drawer.dart` com filtros de severidade (*Kernel*, *Rede*, *Falhas*)
  - [ ] Integrar `IndustrialTerminalDrawer` e banner de descoberta no `studio_scaffold.dart`
  - [ ] Rodar testes e verificar responsividade em 414px (iPhone XR) e desktop

- [ ] **Task 3: Seletor Inteligente de Tags nos Widgets da Home**
  - [ ] Criar teste unitário `test/smart_tag_selector_test.dart`
  - [ ] Implementar seletor com pesquisa rápida e abas de categorias (`%IX`, `%QX`, `%IW`, `%M`) em `widget_config_dialog.dart`
  - [ ] Garantir auto-preenchimento dos limites de escala e unidades industriais
  - [ ] Rodar auditoria completa de responsividade no iPhone XR (`test/iphone_xr_responsiveness_audit_test.dart`)

- [ ] **Task 4: Compilação Web Final e Verificação no Navegador**
  - [ ] Executar `flutter analyze` e confirmar 0 erros
  - [ ] Executar `flutter build web --no-web-resources-cdn`
  - [ ] Reiniciar serviço `systemctl --user restart endap-studio.service`
  - [ ] Capturar screenshot em iPhone XR e Desktop validando o produto final
