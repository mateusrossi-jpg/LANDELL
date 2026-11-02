# Especificação Técnica: PocketWP - WordPress.org Completo no Mobile

* **Data:** 2026-11-01
* **Status:** Aprovado para Planejamento
* **Repositório Alvo:** `/home/mateus/dev/github/pocket-wp`
* **Tecnologias Centrais:** Vite, React, TypeScript, Tailwind CSS, `@wp-playground/client` (WASM + SQLite), Capacitor 6+.

---

## 1. Contexto e Visão do Produto

O **PocketWP** é uma solução local-first que permite executar uma instância completa, autônoma e oficial do **WordPress.org** diretamente em dispositivos móveis (smartphones e tablets Android e iOS). 

Diferente de aplicativos tradicionais de gerenciamento que dependem de servidores remotos ou APIs limitadas, o PocketWP executa localmente o runtime do PHP em WebAssembly (WASM), o banco de dados em SQLite e todo o WordPress Core original, oferecendo a experiência exata do `wp-admin` do desktop na palma da mão, com funcionamento 100% offline.

---

## 2. Objetivos e Não-Objetivos

### Objetivos Principais
1. **WordPress 100% Completo:** Executar o WordPress Core oficial com suporte a instalação de plugins, temas, edição de páginas (Gutenberg/Classic Editor), custom fields e custom post types.
2. **Servidor Local Autônomo:** Executar PHP e banco de dados localmente no smartphone sem depender de servidor remoto, container Docker ou processo root.
3. **Persistência Confiável:** Manter todas as alterações salvas no aparelho (via OPFS / IndexedDB) entre reinicializações do app.
4. **Sem Recriar Telas:** Renderizar o `wp-admin` e o frontend originais do WordPress, sem criar interfaces substitutas para funcionalidades nativas do CMS.
5. **Portabilidade & Backup:** Exportar e importar sites completos em formato `.zip`, permitindo restaurar snapshots e transferir sites para servidores reais ou outros aparelhos.
6. **Multiplataforma:** Arquitetura PWA-first encapsulável via Capacitor para distribuição nativa em Android (.apk) e iOS.

### Não-Objetivos
* **Hospedagem Pública de Produção:** O app não se destina a servir sites de alto tráfego na internet aberta com endereço fixo para milhares de usuários simultâneos.
* **Execução de Binários Nativos C/MySQL:** Não utiliza MariaDB/MySQL nativo em background devido às limitações térmicas, de bateria e restrições de sandbox da Apple App Store.

---

## 3. Arquitetura do Sistema

O sistema é estruturado em três camadas bem definidas:

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Camada Nativa (Capacitor / Mobile OS)                      │
│    - Sistema de Arquivos Nativo (@capacitor/filesystem)      │
│    - Menu de Compartilhamento (@capacitor/share)              │
│    - Status Bar e Controle de Orientação                      │
├──────────────────────────────────────────────────────────────┤
│ 2. Shell da Aplicação (Vite + React + TypeScript + Tailwind) │
│    - Gerenciador de Inicialização e Boot Splash              │
│    - Alternador de Viewport (Desktop 1280px vs Mobile 100%)   │
│    - Drawer / Bottom Sheet de Controle do Servidor            │
│    - Monitor de Status do PHP e Console de Logs               │
├──────────────────────────────────────────────────────────────┤
│ 3. Motor WordPress (WordPress Playground WASM Runtime)       │
│    - PHP 8.2 compilado para WebAssembly (WASM)               │
│    - WordPress Core oficial (v6.5+)                          │
│    - SQLite Database Integration (drop-in db.php)             │
│    - Service Worker que atua como Servidor HTTP Virtual      │
└──────────────────────────────────────────────────────────────┘
```

### Componentes Chave:
* **`@wp-playground/client`:** Biblioteca que estabelece o canal de comunicação (`postMessage`) com o iframe/worker do Playground, permitindo inicializar o WordPress, despachar comandos WP-CLI e invocar rotinas de exportação.
* **Iframe Container Isolado:** O WordPress roda isolado em um iframe controlado pelo Shell React. Isso impede vazamento de estilos CSS do WordPress no Shell e vice-versa.
* **Virtual Network Layer (Service Worker):** O Service Worker intercepta requisições HTTP internas e as encaminha diretamente para a máquina virtual PHP em WASM, simulando um servidor Nginx/Apache em memória.

---

## 4. Persistência de Dados e Armazenamento

1. **Banco de Dados Relacional:**
   * Utiliza a integração oficial SQLite do WordPress Core (`wp-content/db.php`).
   * Todas as tabelas do WordPress são mantidas em um arquivo local único: `wp-content/database/.ht.sqlite`.
2. **Camada de Armazenamento:**
   * O sistema de arquivos virtual do WordPress mapeia o diretório `wp-content` (plugins, temas, uploads e database) para o **Origin Private File System (OPFS)** do navegador/WebView.
   * Suporte a armazenamento de longo prazo sem expiração automática de cache.
3. **Exportação e Importação de ZIP:**
   * **Export:** O Shell solicita ao motor Playground o empacotamento da pasta `wp-content` e do banco SQLite em um arquivo `.zip`.
   * **Import:** O usuário pode carregar um `.zip` do PocketWP para restaurar um site existente. O motor descompacta os arquivos no OPFS e reinicia a sessão do WordPress.

---

## 5. Interface do Shell Mobile e Experiência do Usuário

O Shell fornece utilitários de nível de sistema sem cobrir ou alterar o WordPress interno:

### 1. Alternador de Viewport
* **Modo Mobile (Default):** Viewport definido para 100% da largura do aparelho (`width=device-width`). Ideal para visualização de posts, comentários e leitura.
* **Modo Desktop (1280px Virtual):** Envolve o iframe em um viewport fixo de 1280px com suporte a **pinch-to-zoom** e rolagem horizontal suave. Permite utilizar construtores visuais de páginas (Gutenberg em modo desktop, Elementor) e tabelas administrativas sem distorção.

### 2. Barra Flutuante de Controle (Floating Action Button & Drawer)
Um botão discreto e semi-transparente no canto inferior que expande um menu com:
* **Alternar Site / Painel:** Alterna rapidamente entre a Home do site (`/`) e o painel (`/wp-admin`).
* **Botão Viewport:** Alterna entre Mobile e Desktop.
* **Gerenciador de Backups:** Botões para "Exportar Site (.zip)" e "Restaurar Site (.zip)".
* **Modo de Recuperação (Safe Mode):** Opção para desativar todos os plugins com um toque caso um plugin cause Fatal Error no PHP.
* **Console de Logs:** Visualizador retrátil dos logs de erro do PHP e avisos do servidor virtual.
* **Reiniciar Servidor:** Recarrega o runtime WebAssembly e limpa cache em memória.

### 3. Login Automático de Administrador
* Ao inicializar pela primeira vez, o Blueprint do Playground cria e autentica automaticamente o usuário com privilégios de Administrador (`admin` / `password`), abrindo diretamente na tela inicial do painel.

---

## 6. Tratamento de Erros e Resiliência

1. **Fatal Errors do PHP:** Erros de sintaxe ou exceções causadas por plugins de terceiros são interceptados pelo manipulador do Playground e reportados visualmente no Shell com opção de reverter o plugin problemático.
2. **Queda de Memória (OOM):** Configuração de limite de memória de `256MB` no `php.ini` virtual, garantindo estabilidade contra encerramentos abruptos pelo sistema operacional móvel.
3. **Modo Offline:** O motor é empacotado para inicializar completamente a partir do cache local do aplicativo sem necessidade de requisições de rede externas.

---

## 7. Estratégia de Verificação e Testes

* **Testes de Unidade/Integração:**
  * Teste do carregador de Blueprint e montagem do motor WASM.
  * Teste de integridade do banco SQLite e persistência no OPFS.
  * Teste de exportação e integridade do arquivo `.zip` gerado.
* **Testes Visuais em Dispositivos Móveis:**
  * Teste de responsividade e pinch-to-zoom no viewport desktop.
  * Teste de fluxo de toque (touch gestures) nos menus suspensos do `wp-admin`.
* **Testes de Build e Empacotamento:**
  * Build PWA de produção com Service Worker registrado.
  * Verificação de sincronização Capacitor para Android (`npx cap sync android`).
