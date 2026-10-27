import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

async function runUsabilitySweep() {
  console.log('=== [ENDAP STUDIO] INICIANDO VARREDURA DE USABILIDADE HUMANA & TESTE DOM ===');

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const issuesFound = [];

  // =========================================================================
  // FASE 1: DESKTOP (1440x900) - SESSÃO INTEGRADOR COMPLETA
  // =========================================================================
  console.log('\n[FASE 1] Configurando Sessão de Integrador / Engenheiro (Desktop 1440x900)...');
  const desktopCtx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const page = await desktopCtx.newPage();

  // Escuta erros de console da página
  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      // Ignora avisos esperados de canvas kit ou fontes
      if (!text.includes('favicon.ico') && !text.includes('Failed to load resource')) {
        console.warn(`  [CONSOLE ERROR] ${text.slice(0, 150)}`);
      }
    }
  });

  page.on('pageerror', err => {
    console.error(`  [PAGE EXCEPTION] ${err.message}`);
    issuesFound.push(`Uncaught Page Exception: ${err.message}`);
  });

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);

  // 1.1 Home Dashboard
  console.log('[FASE 1.1] Avaliando Home Dashboard...');
  await page.screenshot({ path: `${OUT_DIR}/01_human_home_dashboard.png` });
  console.log('  -> Salvo: 01_human_home_dashboard.png');

  // Interação Humana no Home Dashboard: Clica no terminal bar (bottom)
  console.log('[FASE 1.2] Abrindo e inspecionando Terminal Industrial...');
  await page.mouse.click(720, 890);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/02_human_terminal_open.png` });
  console.log('  -> Salvo: 02_human_terminal_open.png');

  // Fecha o terminal
  await page.mouse.click(1420, 700); // Fechar ou recolher terminal
  await page.waitForTimeout(500);

  // 1.3 Navegação para Ladder IEC (via Persona Engenharia no Top Bar: x: 585, y: 26)
  console.log('[FASE 1.3] Navegando para Lógica Ladder IEC (Persona Engenharia)...');
  await page.mouse.click(585, 26);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/04_human_ladder_edicao.png` });
  console.log('  -> Salvo: 04_human_ladder_edicao.png');

  // 1.4 Navegação para Manutenção & Diagnósticos de Campo (Persona Manutenção: x: 655, y: 26)
  console.log('[FASE 1.4] Navegando para Diagnósticos de Campo (Persona Manutenção)...');
  await page.mouse.click(655, 26);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/08_human_diagnosticos.png` });
  console.log('  -> Salvo: 08_human_diagnosticos.png');

  // 1.5 Navegação para IHM Operador (Persona Operação: x: 720, y: 26)
  console.log('[FASE 1.5] Navegando para IHM Operador (Touch Kiosk)...');
  await page.mouse.click(720, 26);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/09_human_ihm_kiosk.png` });
  console.log('  -> Salvo: 09_human_ihm_kiosk.png');

  // 1.6 Navegação para Gestão, OEE & Relatórios (Persona Gestão: x: 785, y: 26)
  console.log('[FASE 1.6] Navegando para Gestão & OEE (Persona Gestão & BI)...');
  await page.mouse.click(785, 26);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/10_human_gestao_oee.png` });
  console.log('  -> Salvo: 10_human_gestao_oee.png');

  // 1.7 Navegação para GPIO / TAGS (via Menu Drawer: item 2 em y: 400)
  console.log('[FASE 1.7] Navegando para GPIO / TAGS (via Drawer)...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  await page.mouse.click(120, 400);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/07_human_gpio_tags.png` });
  console.log('  -> Salvo: 07_human_gpio_tags.png');

  // 1.8 Navegação para Redes & Topologia (via Drawer: item em y: 770)
  console.log('[FASE 1.8] Navegando para Redes & Topologia (via Drawer)...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  await page.mouse.click(120, 770);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/11_human_redes_topologia.png` });
  console.log('  -> Salvo: 11_human_redes_topologia.png');

  // 1.9 Abrir Modal Trilha de Auditoria (via Drawer: item em y: 840)
  console.log('[FASE 1.9] Abrindo Trilha de Auditoria (via Drawer)...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  await page.mouse.click(120, 840);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/12_human_modal_auditoria.png` });
  console.log('  -> Salvo: 12_human_modal_auditoria.png');

  // Fechar Modal (clica no backdrop do diálogo)
  await page.mouse.click(1300, 150);
  await page.waitForTimeout(600);

  // 1.10 Abrir Modal Exportar Projeto (via Drawer: rolar até o fim do drawer)
  console.log('[FASE 1.10] Abrindo Modal Exportar Projeto...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  // Rola o mouse sobre o drawer
  await page.mouse.move(150, 500);
  await page.mouse.wheel(0, 300);
  await page.waitForTimeout(600);
  // Clica no item Exportar Projeto (agora visível próximo a y: 720)
  await page.mouse.click(120, 720);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/13_human_modal_exportar.png` });
  console.log('  -> Salvo: 13_human_modal_exportar.png');

  // Fechar Modal
  await page.mouse.click(1300, 150);
  await page.waitForTimeout(600);

  await desktopCtx.close();

  // =========================================================================
  // FASE 2: MOBILE (iPhone XR - 414x896) - USABILIDADE TOUCH
  // =========================================================================
  console.log('\n[FASE 2] Avaliando Usabilidade Humana em Celular (iPhone XR 414x896)...');
  const mobileCtx = await browser.newContext({
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 2.0,
    isMobile: true,
    hasTouch: true,
  });
  const mobilePage = await mobileCtx.newPage();

  await mobilePage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await mobilePage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await mobilePage.reload({ waitUntil: 'domcontentloaded' });
  await mobilePage.waitForTimeout(3000);

  // 2.1 Home no Mobile
  await mobilePage.screenshot({ path: `${OUT_DIR}/14_mobile_human_home.png` });
  console.log('  -> Salvo: 14_mobile_human_home.png');

  // 2.2 Drawer no Mobile
  await mobilePage.mouse.click(20, 24);
  await mobilePage.waitForTimeout(800);
  await mobilePage.screenshot({ path: `${OUT_DIR}/15_mobile_human_drawer.png` });
  console.log('  -> Salvo: 15_mobile_human_drawer.png');

  // 2.3 Ladder IEC no Mobile
  console.log('[FASE 2.3] Abrindo Ladder IEC no Mobile...');
  await mobilePage.mouse.click(120, 270);
  await mobilePage.waitForTimeout(1800);
  await mobilePage.screenshot({ path: `${OUT_DIR}/16_mobile_human_ladder.png` });
  console.log('  -> Salvo: 16_mobile_human_ladder.png');

  // 2.4 GPIO / TAGS no Mobile
  console.log('[FASE 2.4] Abrindo GPIO / TAGS no Mobile...');
  await mobilePage.mouse.click(20, 24);
  await mobilePage.waitForTimeout(800);
  await mobilePage.mouse.click(120, 330);
  await mobilePage.waitForTimeout(1800);
  await mobilePage.screenshot({ path: `${OUT_DIR}/17_mobile_human_gpio_tags.png` });
  console.log('  -> Salvo: 17_mobile_human_gpio_tags.png');

  // 2.5 Kiosk no Mobile
  console.log('[FASE 2.5] Abrindo Kiosk no Mobile...');
  await mobilePage.mouse.click(20, 24);
  await mobilePage.waitForTimeout(800);
  await mobilePage.mouse.click(120, 450);
  await mobilePage.waitForTimeout(1800);
  await mobilePage.screenshot({ path: `${OUT_DIR}/18_mobile_human_kiosk.png` });
  console.log('  -> Salvo: 18_mobile_human_kiosk.png');

  await mobileCtx.close();
  await browser.close();

  console.log('\n=== VARREDURA DE USABILIDADE HUMANA CONCLUÍDA COM SUCESSO! ===');
  if (issuesFound.length > 0) {
    console.warn(`Problemas identificados (${issuesFound.length}):`);
    issuesFound.forEach(iss => console.warn(` - ${iss}`));
  } else {
    console.log('Zero exceções não tratadas detectadas durante a simulação.');
  }
}

runUsabilitySweep().catch(err => {
  console.error('[FATAL SWEEP ERROR]', err);
  process.exit(1);
});
