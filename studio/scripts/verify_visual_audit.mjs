import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

async function runAudit() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // ==========================================================
  // 1. DESKTOP (1440x900)
  // ==========================================================
  const desktopCtx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const dPage = await desktopCtx.newPage();

  await dPage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await dPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await dPage.reload({ waitUntil: 'domcontentloaded' });
  await dPage.waitForTimeout(3000);

  // 1.1 Redes & Topologia (Drawer y: 710)
  console.log('[DESKTOP] Abrindo Redes & Topologia...');
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 710);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/final_desktop_06_redes_topologia.png` });

  // 1.2 GPIO / TAGS (Drawer y: 398)
  console.log('[DESKTOP] Abrindo GPIO / TAGS...');
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 398);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/final_desktop_07_gpio_tags.png` });

  // 1.3 Modal Trilha de Auditoria (Drawer y: 780)
  console.log('[DESKTOP] Abrindo Modal Trilha de Auditoria...');
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 780);
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/final_desktop_08_auditoria.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  // 1.4 Modal Gestão de Usuários (Drawer y: 840)
  console.log('[DESKTOP] Abrindo Modal Gestão de Usuários...');
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 840);
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/final_desktop_09_user_session.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  // 1.5 Modal Exportar Projeto (Drawer scroll 250px -> y: 760)
  console.log('[DESKTOP] Abrindo Modal Exportar Projeto...');
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(700);
  await dPage.mouse.move(100, 600);
  await dPage.mouse.wheel(0, 350);
  await dPage.waitForTimeout(600);
  await dPage.mouse.click(100, 760);
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/final_desktop_10_exportar.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  await desktopCtx.close();

  // ==========================================================
  // 2. MOBILE (414x896 iPhone XR)
  // ==========================================================
  console.log('[MOBILE] Iniciando validação Mobile (iPhone XR)...');
  const mobileCtx = await browser.newContext({
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 2.0,
    isMobile: true,
    hasTouch: true,
  });
  const mPage = await mobileCtx.newPage();

  await mPage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await mPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await mPage.reload({ waitUntil: 'domcontentloaded' });
  await mPage.waitForTimeout(3000);

  // 2.1 Modal Auditoria no Mobile (Verificar responsividade e sem quebra vertical)
  console.log('[MOBILE] Abrindo Trilha de Auditoria no Mobile...');
  await mPage.mouse.click(20, 24);
  await mPage.waitForTimeout(700);
  // No mobile drawer, scroll e clica em Auditoria
  await mPage.mouse.move(100, 500);
  await mPage.mouse.wheel(0, 350);
  await mPage.waitForTimeout(600);
  // Auditoria após scroll
  await mPage.mouse.click(100, 680);
  await mPage.waitForTimeout(1500);
  await mPage.screenshot({ path: `${OUT_DIR}/final_mobile_01_auditoria_responsive.png` });
  await mPage.keyboard.press('Escape');
  await mPage.waitForTimeout(700);

  // 2.2 Redes & Topologia no Mobile
  console.log('[MOBILE] Abrindo Redes & Topologia no Mobile...');
  await mPage.mouse.click(20, 24);
  await mPage.waitForTimeout(700);
  await mPage.mouse.move(100, 500);
  await mPage.mouse.wheel(0, 300);
  await mPage.waitForTimeout(600);
  await mPage.mouse.click(100, 610); // Redes
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/final_mobile_02_redes_topologia.png` });

  // 2.3 Operador Kiosk no Mobile via Persona Dropdown (x: 340, y: 24)
  console.log('[MOBILE] Abrindo Kiosk no Mobile...');
  await mPage.mouse.click(340, 24);
  await mPage.waitForTimeout(600);
  // No popup, item 4 (Operador Kiosk) está por volta de y: 190
  await mPage.mouse.click(250, 190);
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/final_mobile_03_kiosk.png` });

  await mobileCtx.close();
  await browser.close();
  console.log('=== [ALL AUDIT SCREENSHOTS COMPLETED SUCCESSFULLY] ===');
}

runAudit().catch(console.error);
