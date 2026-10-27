import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

async function runCleanCapture() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // =========================================================================
  // 1. DESKTOP (1440x900)
  // =========================================================================
  console.log('[DESKTOP] Iniciando captura desktop (1440x900)...');
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

  // Certificar que terminal não obstrui o centro
  // 1. Rede & Topologia
  console.log('-> Capturando 06_desktop_redes_topologia.png...');
  await dPage.mouse.click(20, 26); // Menu Drawer
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 780); // Rede & Topologia
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/06_desktop_redes_topologia.png` });

  // 2. GPIO / TAGS
  console.log('-> Capturando 07_desktop_gpio_tags.png...');
  await dPage.mouse.click(20, 26); // Menu Drawer
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 398); // GPIO / TAGS
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/07_desktop_gpio_tags.png` });

  // 3. Modal Trilha de Auditoria
  console.log('-> Capturando dialog_desktop_08_auditoria.png...');
  await dPage.mouse.click(20, 26); // Menu Drawer
  await dPage.waitForTimeout(700);
  await dPage.mouse.click(100, 860); // Trilha de Auditoria
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/dialog_desktop_08_auditoria.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  // 4. Modal Gestão de Usuários
  console.log('-> Capturando dialog_desktop_09_user_session.png...');
  await dPage.mouse.click(20, 26); // Menu Drawer
  await dPage.waitForTimeout(700);
  await dPage.mouse.move(100, 600);
  await dPage.mouse.wheel(0, 250); // Rola drawer para baixo
  await dPage.waitForTimeout(600);
  await dPage.mouse.click(100, 780); // Gestão de Usuários pós scroll
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/dialog_desktop_09_user_session.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  // 5. Modal Exportar Projeto
  console.log('-> Capturando dialog_desktop_10_exportar.png...');
  await dPage.mouse.click(20, 26); // Menu Drawer
  await dPage.waitForTimeout(700);
  await dPage.mouse.move(100, 600);
  await dPage.mouse.wheel(0, 350); // Rola mais
  await dPage.waitForTimeout(600);
  await dPage.mouse.click(100, 755); // Exportar Projeto pós scroll
  await dPage.waitForTimeout(1500);
  await dPage.screenshot({ path: `${OUT_DIR}/dialog_desktop_10_exportar.png` });
  await dPage.keyboard.press('Escape');
  await dPage.waitForTimeout(700);

  await desktopCtx.close();

  // =========================================================================
  // 2. MOBILE (iPhone XR - 414x896)
  // =========================================================================
  console.log('\n[MOBILE] Iniciando captura Mobile (iPhone XR 414x896)...');
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

  // 2.1 Home Mobile
  console.log('-> Capturando 20_mobile_home.png...');
  await mPage.screenshot({ path: `${OUT_DIR}/20_mobile_home.png` });

  // 2.2 Drawer Mobile
  console.log('-> Capturando 21_mobile_drawer.png...');
  await mPage.mouse.click(20, 24);
  await mPage.waitForTimeout(700);
  await mPage.screenshot({ path: `${OUT_DIR}/21_mobile_drawer.png` });

  // 2.3 Redes & Topologia Mobile
  console.log('-> Capturando 22_mobile_redes_topologia.png...');
  await mPage.mouse.move(100, 500);
  await mPage.mouse.wheel(0, 300);
  await mPage.waitForTimeout(500);
  await mPage.mouse.click(100, 680); // Redes
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/22_mobile_redes_topologia.png` });

  // 2.4 Manutenção & Forçamento Mobile (via Dropdown Persona x: 388, y: 24)
  console.log('-> Capturando 23_mobile_manutencao.png...');
  await mPage.mouse.click(388, 24);
  await mPage.waitForTimeout(600);
  // Item 3 no popup
  await mPage.mouse.click(250, 140);
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/23_mobile_manutencao.png` });

  // 2.5 Gestão & BI Mobile (via Dropdown Persona)
  console.log('-> Capturando 24_mobile_gestao_bi.png...');
  await mPage.mouse.click(388, 24);
  await mPage.waitForTimeout(600);
  // Item 5 no popup
  await mPage.mouse.click(250, 220);
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/24_mobile_gestao_bi.png` });

  // 2.6 Kiosk Mobile
  console.log('-> Capturando 25_mobile_kiosk.png...');
  await mPage.mouse.click(388, 24);
  await mPage.waitForTimeout(600);
  // Item 4 no popup
  await mPage.mouse.click(250, 180);
  await mPage.waitForTimeout(2000);
  await mPage.screenshot({ path: `${OUT_DIR}/25_mobile_kiosk.png` });

  await mobileCtx.close();
  await browser.close();
  console.log('=== [CLEAN CAPTURE COMPLETED SUCCESSFULLY] ===');
}

runCleanCapture().catch(console.error);
