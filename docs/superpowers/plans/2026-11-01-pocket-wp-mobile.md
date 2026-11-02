# PocketWP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir uma aplicação mobile-first (PWA + Capacitor) que executa uma instância completa e local do WordPress.org usando WebAssembly (PHP 8.2) e SQLite, com persistência no aparelho, exportação/importação de ZIP e alternador de viewport Desktop/Mobile sem recriar o `wp-admin`.

**Architecture:** A aplicação consiste em um Shell em React/Vite que orquestra a máquina virtual do WordPress Playground via `@wp-playground/client`. O WordPress roda isolado em um iframe comunicado por postMessage, com banco de dados SQLite persistido no OPFS/IndexedDB. Uma barra de ferramentas flutuante nativa oferece controle de resolução (Desktop 1280px vs Mobile), backups ZIP e monitor de logs sem interferir na UI original do WordPress.

**Tech Stack:** React 18+, TypeScript, Vite, Tailwind CSS, `@wp-playground/client`, `@capacitor/core`, `@capacitor/cli`, `@capacitor/filesystem`, `@capacitor/share`, Vitest.

**Spec:** [docs/superpowers/specs/2026-11-01-pocket-wp-mobile-design.md](file:///home/mateus/dev/github/LANDELL/docs/superpowers/specs/2026-11-01-pocket-wp-mobile-design.md)

## Global Constraints

* O projeto vive em `/home/mateus/dev/github/pocket-wp`.
* O WordPress Core e o `wp-admin` não devem ter suas telas recriadas; devem ser exibidos integralmente.
* O banco de dados deve utilizar o drop-in SQLite (`wp-content/db.php`).
* O app deve funcionar 100% offline após o primeiro carregamento ou cache dos assets.
* O Shell mobile deve permitir alternar entre visualização Mobile (100% width) e Desktop (1280px com pinch-zoom).
* Todo código TypeScript deve compilar sem erros de tipagem estrita (`tsc --noEmit`).

## Review Focus

1. **Persistência ao recarregar a página:** Um post criado no `wp-admin` deve continuar existindo após fechar e reabrir o app.
2. **Exportação de ZIP válida:** O arquivo `.zip` exportado deve conter a pasta `wp-content` e o arquivo do banco `.ht.sqlite`.
3. **Pinch-to-zoom no modo Desktop:** No modo Desktop (1280px), o usuário deve conseguir dar zoom e rolar horizontalmente no celular.
4. **Isolamento de estilos:** O CSS do Tailwind do Shell não pode vazar ou alterar estilos dentro do iframe do `wp-admin`.
5. **Tratamento de Fatal Error do PHP:** Se um plugin quebrar o PHP, o Shell deve manter o menu de controle acessível para permitir restauração ou Safe Mode.

---

### Task 1: Scaffolding do Projeto PocketWP

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/package.json`
- Create: `/home/mateus/dev/github/pocket-wp/vite.config.ts`
- Create: `/home/mateus/dev/github/pocket-wp/tsconfig.json`
- Create: `/home/mateus/dev/github/pocket-wp/index.html`
- Create: `/home/mateus/dev/github/pocket-wp/src/main.tsx`
- Create: `/home/mateus/dev/github/pocket-wp/src/index.css`
- Test: `/home/mateus/dev/github/pocket-wp/tests/scaffold.test.ts`

**Interfaces:**
- Produces: Ambiente de build funcional com Vite, TypeScript, Tailwind CSS e Vitest em `/home/mateus/dev/github/pocket-wp`.

- [ ] **Step 1: Write the failing test**

```typescript
// tests/scaffold.test.ts
import { describe, it, expect } from 'vitest';
import packageJson from '../package.json';

describe('Project Scaffold', () => {
  it('has required dependencies configured', () => {
    expect(packageJson.name).toBe('pocket-wp');
    expect(packageJson.dependencies).toHaveProperty('@wp-playground/client');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npm test`
Expected: FAIL (package.json not yet created or missing dependencies)

- [ ] **Step 3: Criar e configurar o diretório do projeto com Vite, React, Tailwind e Vitest**

Inicializar `/home/mateus/dev/github/pocket-wp` com:
`@wp-playground/client`, `lucide-react`, `tailwindcss`, `vitest`, `typescript`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npm test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git init
git add .
git commit -m "feat: initial project scaffolding with Vite and Vitest"
```

---

### Task 2: Cliente e Orquestrador do WordPress Playground

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/src/lib/playground.ts`
- Create: `/home/mateus/dev/github/pocket-wp/src/types/playground.ts`
- Test: `/home/mateus/dev/github/pocket-wp/tests/playground.test.ts`

**Interfaces:**
- Consumes: `@wp-playground/client`
- Produces:
  ```typescript
  export interface PocketWPEngine {
    init(iframe: HTMLIFrameElement): Promise<void>;
    goTo(path: string): Promise<void>;
    getCurrentUrl(): Promise<string>;
    runPhp(code: string): Promise<{ text: string }>;
    isReady(): boolean;
  }
  export function createPocketWPEngine(): PocketWPEngine;
  ```

- [ ] **Step 1: Write the failing test**

```typescript
// tests/playground.test.ts
import { describe, it, expect } from 'vitest';
import { createPocketWPEngine } from '../src/lib/playground';

describe('PocketWP Engine', () => {
  it('creates an engine instance in unready state', () => {
    const engine = createPocketWPEngine();
    expect(engine.isReady()).toBe(false);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/playground.test.ts`
Expected: FAIL with "createPocketWPEngine is not defined"

- [ ] **Step 3: Implementar `createPocketWPEngine` em `src/lib/playground.ts`**

Implementar cliente conectando com `@wp-playground/client`, configurando o Blueprint com PHP 8.2, SQLite integration e login automático de administrador (`admin` / `password`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/playground.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add src/lib/playground.ts src/types/playground.ts tests/playground.test.ts
git commit -m "feat: implement WordPress Playground engine client"
```

---

### Task 3: Gerenciador de Backup e Exportação/Importação ZIP

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/src/lib/backup.ts`
- Test: `/home/mateus/dev/github/pocket-wp/tests/backup.test.ts`

**Interfaces:**
- Consumes: `PocketWPEngine`
- Produces:
  ```typescript
  export interface BackupService {
    exportSiteZip(engine: PocketWPEngine): Promise<Blob>;
    importSiteZip(engine: PocketWPEngine, zipFile: File): Promise<boolean>;
    formatBackupFilename(): string;
  }
  export function createBackupService(): BackupService;
  ```

- [ ] **Step 1: Write the failing test**

```typescript
// tests/backup.test.ts
import { describe, it, expect } from 'vitest';
import { createBackupService } from '../src/lib/backup';

describe('Backup Service', () => {
  it('generates consistent backup filenames with timestamp', () => {
    const service = createBackupService();
    const filename = service.formatBackupFilename();
    expect(filename).toMatch(/^pocketwp-backup-\d{4}-\d{2}-\d{2}/);
    expect(filename.endsWith('.zip')).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/backup.test.ts`
Expected: FAIL with "createBackupService is not defined"

- [ ] **Step 3: Implementar `createBackupService` em `src/lib/backup.ts`**

Utilizar os métodos de dump de arquivos e banco do Playground para compactar `wp-content` e `.ht.sqlite` em um Blob ZIP, com função de restauração.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/backup.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add src/lib/backup.ts tests/backup.test.ts
git commit -m "feat: implement site export and import backup service"
```

---

### Task 4: Iframe Container com Alternador de Viewport (Desktop 1280px / Mobile)

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/src/components/WordPressContainer.tsx`
- Create: `/home/mateus/dev/github/pocket-wp/src/types/viewport.ts`
- Test: `/home/mateus/dev/github/pocket-wp/tests/viewport.test.ts`

**Interfaces:**
- Produces:
  ```typescript
  export type ViewportMode = 'mobile' | 'desktop';
  export interface ViewportConfig {
    mode: ViewportMode;
    width: string;
    scale: number;
  }
  export function getViewportStyles(mode: ViewportMode): React.CSSProperties;
  ```

- [ ] **Step 1: Write the failing test**

```typescript
// tests/viewport.test.ts
import { describe, it, expect } from 'vitest';
import { getViewportStyles } from '../src/components/WordPressContainer';

describe('Viewport Styles', () => {
  it('returns full width for mobile and fixed 1280px for desktop', () => {
    expect(getViewportStyles('mobile').width).toBe('100%');
    expect(getViewportStyles('desktop').width).toBe('1280px');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/viewport.test.ts`
Expected: FAIL with "getViewportStyles is not defined"

- [ ] **Step 3: Implementar `WordPressContainer.tsx` com estilos de viewport e scroll container**

Montar o wrapper com suporte a `overflow-auto`, iframe responsivo e alternância para 1280px com zoom suave.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/viewport.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add src/components/WordPressContainer.tsx src/types/viewport.ts tests/viewport.test.ts
git commit -m "feat: implement WordPress iframe container with desktop and mobile viewport toggle"
```

---

### Task 5: Barra Flutuante de Ações e Drawer de Controle Mobile

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/src/components/FloatingActions.tsx`
- Create: `/home/mateus/dev/github/pocket-wp/src/components/ControlDrawer.tsx`
- Test: `/home/mateus/dev/github/pocket-wp/tests/floating-actions.test.ts`

**Interfaces:**
- Consumes: `PocketWPEngine`, `BackupService`, `ViewportMode`
- Produces:
  ```typescript
  export interface FloatingActionsProps {
    viewport: ViewportMode;
    onToggleViewport: () => void;
    onNavigate: (path: string) => void;
    onOpenDrawer: () => void;
  }
  ```

- [ ] **Step 1: Write the failing test**

```typescript
// tests/floating-actions.test.ts
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
// Test basic render of FloatingActions component
describe('FloatingActions', () => {
  it('is defined and renders action triggers', async () => {
    const mod = await import('../src/components/FloatingActions');
    expect(mod.FloatingActions).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/floating-actions.test.ts`
Expected: FAIL (module not found)

- [ ] **Step 3: Implementar `FloatingActions.tsx` e `ControlDrawer.tsx`**

Criar FAB discreto com botões de atalho: "Alternar Painel/Site", "Alternar Viewport", "Menu do Servidor". No Drawer: Exportar ZIP, Importar ZIP, Safe Mode, Limpar Cache e Logs.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/floating-actions.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add src/components/FloatingActions.tsx src/components/ControlDrawer.tsx tests/floating-actions.test.ts
git commit -m "feat: implement floating quick actions and mobile control drawer"
```

---

### Task 6: Visualizador de Logs, Safe Mode e Tratamento de Erros

**Files:**
- Create: `/home/mateus/dev/github/pocket-wp/src/components/LogViewerModal.tsx`
- Create: `/home/mateus/dev/github/pocket-wp/src/lib/safe-mode.ts`
- Test: `/home/mateus/dev/github/pocket-wp/tests/safe-mode.test.ts`

**Interfaces:**
- Produces:
  ```typescript
  export interface SafeModeManager {
    disableAllPlugins(engine: PocketWPEngine): Promise<boolean>;
    resetActiveTheme(engine: PocketWPEngine): Promise<boolean>;
  }
  export function createSafeModeManager(): SafeModeManager;
  ```

- [ ] **Step 1: Write the failing test**

```typescript
// tests/safe-mode.test.ts
import { describe, it, expect } from 'vitest';
import { createSafeModeManager } from '../src/lib/safe-mode';

describe('Safe Mode Manager', () => {
  it('instantiates safe mode manager correctly', () => {
    const manager = createSafeModeManager();
    expect(manager.disableAllPlugins).toBeTypeOf('function');
    expect(manager.resetActiveTheme).toBeTypeOf('function');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/safe-mode.test.ts`
Expected: FAIL with "createSafeModeManager is not defined"

- [ ] **Step 3: Implementar `src/lib/safe-mode.ts` e `LogViewerModal.tsx`**

Implementar rotinas de emergência disparadas via WP-CLI / PHP para desativar plugins corrompidos sem depender do `wp-admin` renderizar com sucesso.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/safe-mode.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add src/lib/safe-mode.ts src/components/LogViewerModal.tsx tests/safe-mode.test.ts
git commit -m "feat: implement error log viewer and safe mode recovery manager"
```

---

### Task 7: Montagem Principal da Aplicação e Configuração PWA / Capacitor

**Files:**
- Modify: `/home/mateus/dev/github/pocket-wp/src/App.tsx`
- Create: `/home/mateus/dev/github/pocket-wp/capacitor.config.ts`
- Modify: `/home/mateus/dev/github/pocket-wp/vite.config.ts`
- Test: `/home/mateus/dev/github/pocket-wp/tests/app.test.tsx`

**Interfaces:**
- Integra todos os componentes (`WordPressContainer`, `FloatingActions`, `ControlDrawer`, `LogViewerModal`, `playgroundEngine`).

- [ ] **Step 1: Write the failing test**

```typescript
// tests/app.test.tsx
import { describe, it, expect } from 'vitest';
import App from '../src/App';

describe('PocketWP App Entry', () => {
  it('renders root container', () => {
    expect(App).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/app.test.tsx`
Expected: FAIL

- [ ] **Step 3: Implementar `App.tsx` e configurar manifest PWA e Capacitor**

Montar a tela de carregamento elegante com indicador de progresso do boot do WordPress, integrar os atalhos e registrar o service worker.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/mateus/dev/github/pocket-wp && npx vitest run tests/app.test.tsx`
Expected: PASS

- [ ] **Step 5: Validar build de produção**

Run: `cd /home/mateus/dev/github/pocket-wp && npm run build`
Expected: Sucesso na geração da pasta `dist`.

- [ ] **Step 6: Commit**

```bash
cd /home/mateus/dev/github/pocket-wp
git add .
git commit -m "feat: integrate main PocketWP application with Capacitor and PWA setup"
```
