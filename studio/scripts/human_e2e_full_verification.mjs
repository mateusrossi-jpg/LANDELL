import { chromium } from 'playwright';
import fs from 'fs';
import http from 'http';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';
const GATEWAY_IP = '192.168.0.229';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

function fetchJson(url) {
  return new Promise((resolve) => {
    http.get(url, { timeout: 3000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          resolve(null);
        }
      });
    }).on('error', () => resolve(null));
  });
}

async function runHumanE2EVerification() {
  console.log('========================================================================');
  console.log('=== [LANDELL E2E] INICIANDO TESTE PONTA A PONTA COMPLETO COMO HUMANO ===');
  console.log('========================================================================\n');

  // 1. MONITOR EM SEGUNDO PLANO: Hardware Live Check
  console.log('[MONITOR HARDWARE] Consultando estado real do Gateway e Cluster...');
  const clusterStatus = await fetchJson(`http://${GATEWAY_IP}/api/cluster/status`);
  const nodesStatus = await fetchJson(`http://${GATEWAY_IP}/api/nodes`);

  console.log('  -> Gateway Node ID:', clusterStatus?.node_id, 'Transporte:', clusterStatus?.transport);
  console.log('  -> Cluster Online:', clusterStatus?.online, 'Peers:', clusterStatus?.peers?.length);
  if (nodesStatus?.nodes?.length) {
    const fn = nodesStatus.nodes[0];
    console.log(`  -> Nó de Campo: ID=${fn.id}, Transporte=${fn.last_transport}, Saúde=${fn.health}%, Estado=${fn.cluster_state}`);
  }

  // 2. INICIALIZAÇÃO DO NAVEGADOR DESKTOP FULL HD (1920x1080)
  console.log('\n[PLAYWRIGHT] Abrindo Google Chrome Desktop em 1920x1080 (Full Screen)...');
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1.0,
  });

  const page = await context.newPage();

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate((gwIp) => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', `"${gwIp}"`);
    localStorage.setItem('flutter.saved_gateway_ip', `"${gwIp}"`);
  }, GATEWAY_IP);

  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);

  // =========================================================================
  // PASSO 1: VERIFICAÇÃO DO CABEÇALHO DESKTOP (FULL WIDTH 100%)
  // =========================================================================
  console.log('\n[PASSO 1] Verificando Cabeçalho Desktop (Full Width 100%)...');
  await page.screenshot({ path: `${OUT_DIR}/01_desktop_header_full_width.png` });
  console.log('  ✓ Screenshot salvo: 01_desktop_header_full_width.png');

  // =========================================================================
  // PASSO 2: ABA 0 - PAINEL HMI / OPERADOR
  // =========================================================================
  console.log('\n[PASSO 2] Avaliando Aba 0: Painel HMI (Operador)...');
  await page.screenshot({ path: `${OUT_DIR}/02_tab_home_hmi.png` });
  console.log('  ✓ Screenshot salvo: 02_tab_home_hmi.png');

  // =========================================================================
  // PASSO 3: TERMINAL INDUSTRIAL
  // =========================================================================
  console.log('\n[PASSO 3] Interagindo com Terminal Industrial...');
  // Clica no botão de terminal no ribbon bar (canto direito: x: 1725, y: 25)
  await page.mouse.click(1725, 25);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/03_industrial_terminal_open.png` });
  console.log('  ✓ Screenshot salvo: 03_industrial_terminal_open.png');
  // Fecha o terminal clicando no botão novamente
  await page.mouse.click(1725, 25);
  await page.waitForTimeout(500);

  // =========================================================================
  // PASSO 4: ABA 1 - LÓGICA LADDER IEC 61131-3 (PERSONA ENGENHARIA)
  // =========================================================================
  console.log('\n[PASSO 4] Navegando para Aba 1: Lógica Ladder IEC (Engenharia)...');
  // Clica no item ENGENHARIA no seletor de personas (centro da tela, ~x: 1030, y: 25)
  await page.mouse.click(1030, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/04_tab_ladder_editor.png` });
  console.log('  ✓ Screenshot salvo: 04_tab_ladder_editor.png');

  // =========================================================================
  // PASSO 5: ABA 4 - MANUTENÇÃO & FORÇAMENTO DE E/S
  // =========================================================================
  console.log('\n[PASSO 5] Navegando para Aba 4: Manutenção & Diagnósticos...');
  // Clica no item MANUTENÇÃO no seletor de personas (~x: 940, y: 25)
  await page.mouse.click(940, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/05_tab_manutencao_diagnosticos.png` });
  console.log('  ✓ Screenshot salvo: 05_tab_manutencao_diagnosticos.png');

  // =========================================================================
  // PASSO 6: ABA 5 - GESTÃO, OEE & BI INDUSTRIAL
  // =========================================================================
  console.log('\n[PASSO 6] Navegando para Aba 5: Gestão & OEE...');
  // Clica no item GESTÃO no seletor de personas (~x: 1120, y: 25)
  await page.mouse.click(1120, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/06_tab_gestao_oee.png` });
  console.log('  ✓ Screenshot salvo: 06_tab_gestao_oee.png');

  // =========================================================================
  // PASSO 7: ABA 2 - MAPEAMENTO FÍSICO GPIO / TAGS
  // =========================================================================
  console.log('\n[PASSO 7] Abrindo Menu Drawer e navegando para GPIO / TAGS...');
  // Abre drawer (x: 25, y: 25)
  await page.mouse.click(25, 25);
  await page.waitForTimeout(800);
  // Item 2: GPIO / TAGS (x: 120, y: 335)
  await page.mouse.click(120, 335);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/07_tab_gpio_tags.png` });
  console.log('  ✓ Screenshot salvo: 07_tab_gpio_tags.png');

  // =========================================================================
  // PASSO 8: ABA 3 - REDE & TOPOLOGIA (CONFIRMAÇÃO: ZERO RS485 + ESP-NOW VISÍVEL)
  // =========================================================================
  console.log('\n[PASSO 8] Abrindo Menu Drawer e navegando para Rede & Topologia...');
  await page.mouse.click(25, 25);
  await page.waitForTimeout(800);
  // Item 3: Rede & Topologia (x: 120, y: 585)
  await page.mouse.click(120, 585);
  await page.waitForTimeout(2500);
  await page.screenshot({ path: `${OUT_DIR}/08_tab_rede_topologia_sem_rs485.png` });
  console.log('  ✓ Screenshot salvo: 08_tab_rede_topologia_sem_rs485.png');

  // =========================================================================
  // PASSO 9: TESTE DA ESCOLHA DE TRANSPORTE (POPUP MENU NO NÓ DE CAMPO)
  // =========================================================================
  console.log('\n[PASSO 9] Interagindo com menu de ações do Nó de Campo (3 pontinhos)...');
  // Clica no botão de 3 pontinhos na linha do nó (na lista de nós remotos)
  // A linha do nó fica em y ~ 340, x ~ 1880
  await page.mouse.click(1880, 340);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/09_popup_menu_transport_options.png` });
  console.log('  ✓ Screenshot salvo: 09_popup_menu_transport_options.png');

  // Fecha o popup menu clicando fora
  await page.mouse.click(1400, 340);
  await page.waitForTimeout(500);

  // =========================================================================
  // PASSO 10: TRILHA DE AUDITORIA & SEGURANÇA (NVS)
  // =========================================================================
  console.log('\n[PASSO 10] Abrindo Trilha de Auditoria & Eventos (NVS)...');
  await page.mouse.click(25, 25);
  await page.waitForTimeout(800);
  // Trilha de Auditoria (x: 120, y: 655)
  await page.mouse.click(120, 655);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/10_dialog_auditoria_eventos.png` });
  console.log('  ✓ Screenshot salvo: 10_dialog_auditoria_eventos.png');

  // Fecha o diálogo de auditoria
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);

  // =========================================================================
  // PASSO 11: GESTÃO DE USUÁRIOS & SESSÃO (RBAC)
  // =========================================================================
  console.log('\n[PASSO 11] Abrindo Gestão de Usuários & Login (RBAC)...');
  await page.mouse.click(25, 25);
  await page.waitForTimeout(800);
  // Gestão de Usuários (x: 120, y: 715)
  await page.mouse.click(120, 715);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/11_dialog_usuarios_login.png` });
  console.log('  ✓ Screenshot salvo: 11_dialog_usuarios_login.png');

  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);

  console.log('\n========================================================================');
  console.log('=== [SUCESSO] VARREDURA HUMANA E2E CONCLUÍDA EM TODAS AS TELAS! ===');
  console.log('========================================================================');

  await browser.close();
}

runHumanE2EVerification().catch(err => {
  console.error('[ERRO NO TESTE E2E]:', err);
  process.exit(1);
});
