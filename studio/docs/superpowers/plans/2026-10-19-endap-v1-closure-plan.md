# ENDAP v1 — Plano de Fechamento Integral (Trilhas 1, 2 e 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar o ENDAP Studio e Firmware em um produto completo e demonstrável, fechando a sincronização real ponta a ponta com o hardware ESP32 (Trilha 1), o fluxo guiado de onboarding e adoção de nós com perfis/templates (Trilha 2) e a customização dinâmica das visões de Operador e Gestor pelo Engenheiro (Trilha 3).

**Architecture:**
- **Trilha 1 (Hardware Sync):** Conectar os gatilhos da Ribbon Bar (`onDeploy`, `onFetch`, `onTriggerFailsafe`) e `MaintenanceDiagnosticsView` diretamente à API HTTP do ESP32 (`/api/automation/ladder`, `/api/failsafe/output/test`, `/api/installation/channel-map`).
- **Trilha 2 (Onboarding):** Implementar o diálogo e serviço `AdoptNodeDialog` com seleção de perfis (`Field Node`, `Sensor Node`, `Relay Node`, `Gateway`) e aplicação de templates de I/O em 1 clique via `/api/onboarding/claim` e `/api/nodes/template/apply`.
- **Trilha 3 (Personas Configuráveis):** Implementar o painel de personalização no `OperatorKioskView` e `ManagerAnalyticsView` onde o Engenheiro seleciona os atuadores, telemetrias e metas de OEE exibidos para os demais usuários.

**Tech Stack:** Flutter 3.x, Dart, C (ESP-IDF / FreeRTOS determinístico), HTTP REST / JSON / Binary Octet-Stream Bytecode.

**Spec:** Baseado no `AGENTS.md` (Escopo ativo oficial: Onboarding v1, Network v1, Gateway v1, Field Node v1, Dashboard de adoção/operação, Perfis e Templates v1).

---

## Global Constraints
- **Preservação do Kernel:** NENHUMA alteração no loop de controle de 1 ms (`control_loop.c`).
- **Não Bloqueante:** Todas as chamadas de rede no Studio utilizam timeouts estritos (máx 5s) e feedback visual assíncrono.
- **Responsividade:** Manter conformidade estrita com viewport mobile (iPhone XR 414px) e desktop (>=800px).
- **Consistência Visual:** Utilizar `IndustrialTokens` e `AppColors` em todos os novos componentes.

---

## Estrutura de Tarefas

### Fase 1: Trilha 1 — Conexão Ponta a Ponta Real (Studio ↔ ESP32)
- [ ] **Task 1.1:** Conectar `_handleDeploy` no `StudioScaffold` ao `FirmwareSyncService().syncRules` com modal de progresso, validação de rungs e feedback de bytecode gravado.
- [ ] **Task 1.2:** Conectar `_handleFetch` no `StudioScaffold` ao `FirmwareSyncService().fetchRules` para download e engenharia reversa do ladder em execução.
- [ ] **Task 1.3:** Conectar `_handleFailsafe` para disparar comando real de parada segura para a API do ESP32 (`/api/failsafe/output/test` e corte de saídas).
- [ ] **Task 1.4:** Integrar forçamento de canais na `MaintenanceDiagnosticsView` com a API `/api/installation/channel-map/save`.

### Fase 2: Trilha 2 — Onboarding & Adoção Guiada de Nós (Perfis & Templates)
- [ ] **Task 2.1:** Criar `AdoptNodeDialog` no Studio com seleção de:
  - Nome amigável do nó (ex: `Nó 02 - Esteira de Separação`)
  - Perfil Industrial: `Field Node`, `Sensor Node`, `Relay Node`, `Gateway`
  - Template Inicial: `Partida Direta de Motores`, `Controle de Nível PID`, `Estação de Solo/Irrigação`, `I/O Remoto Puro`
- [ ] **Task 2.2:** Integrar o diálogo de adoção na `NetworksPage` e no `StudioScaffold` (ação "Adotar" para nós pendentes).
- [ ] **Task 2.3:** Implementar provisionamento do template no firmware via chamada à API `/api/nodes/template/apply`.

### Fase 3: Trilha 3 — Customização de Telas pelo Engenheiro (Personas Dinâmicas)
- [ ] **Task 3.1:** Criar modelo de dados de configuração de IHM e KPIs (`PersonaConfigModel`) com persistência em `SharedPreferences`.
- [ ] **Task 3.2:** No `OperatorKioskView`, implementar o botão de engrenagem "Configurar IHM" (visível apenas para `INTEGRADOR`/`ADMIN`), permitindo selecionar botões e mostradores liberados para o operador.
- [ ] **Task 3.3:** No `ManagerAnalyticsView`, implementar o configurador de metas (Meta horária, metas de OEE, tags de contagem de produção).

### Fase 4: Validação, Testes Automatizados e Build de Release
- [ ] **Task 4.1:** Criar teste de integração para o ciclo de deploy e onboarding (`test/end_to_end_product_flow_test.dart`).
- [ ] **Task 4.2:** Executar auditoria de DOM e responsividade para garantir zero regressões no iPhone XR.
- [ ] **Task 4.3:** Recompilar o bundle de produção web (`flutter build web --no-web-resources-cdn`) e reiniciar o servidor.
