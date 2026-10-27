import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/52b6caeb-2448-4662-8c57-10ba219cdbbd';

async function runShowcase() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // =========================================================================
  // 1. DESKTOP (1440x900)
  // =========================================================================
  const desktopCtx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const dPage = await desktopCtx.newPage();

  // 1.0 Login Page (set session active to false)
  await dPage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await dPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'false');
    localStorage.removeItem('flutter.endap_session_user');
    localStorage.removeItem('flutter.endap_session_role');
  });
  await dPage.reload({ waitUntil: 'domcontentloaded' });
  await dPage.waitForTimeout(2500);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_00_desktop_login.png` });

  // Now login as Técnico de Campo
  await dPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await dPage.reload({ waitUntil: 'domcontentloaded' });
  await dPage.waitForTimeout(3000);

  // 1.1 Home Dashboard
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_01_desktop_home.png` });

  // 1.2 Engenharia (Ladder IEC) -> Click Engenharia tab (~ x: 660, y: 26)
  await dPage.mouse.click(660, 26);
  await dPage.waitForTimeout(2500);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_02_desktop_ladder.png` });

  // 1.3 Manutenção & Forçamento -> Click Manutenção tab (~ x: 755, y: 26)
  await dPage.mouse.click(755, 26);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_03_desktop_manutencao.png` });

  // 1.4 Operação (Kiosk) -> Click Operação tab (~ x: 845, y: 26)
  await dPage.mouse.click(845, 26);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_04_desktop_kiosk.png` });

  // 1.5 Gestão & BI -> Click Gestão & BI tab (~ x: 935, y: 26)
  await dPage.mouse.click(935, 26);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_05_desktop_gestao_bi.png` });

  // 1.6 Open Drawer for Redes & Topologia -> Click menu (20, 26)
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(800);
  await dPage.mouse.click(120, 695);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_06_desktop_redes.png` });

  // 1.7 Open Drawer for GPIO / TAGS -> Click menu (20, 26) then GPIO / TAGS around y: 395
  await dPage.mouse.click(20, 26);
  await dPage.waitForTimeout(800);
  await dPage.mouse.click(120, 395);
  await dPage.waitForTimeout(2000);
  await dPage.screenshot({ path: `${OUT_DIR}/obsidian_07_desktop_gpio_tags.png` });

  // =========================================================================
  // 2. MOBILE (iPhone XR 414x896)
  // =========================================================================
  const mobileCtx = await browser.newContext({
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 2.0,
    isMobile: true,
    hasTouch: true,
  });
  const mPage = await mobileCtx.newPage();

  // 2.0 Mobile Login
  await mPage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await mPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'false');
    localStorage.removeItem('flutter.endap_session_user');
    localStorage.removeItem('flutter.endap_session_role');
  });
  await mPage.reload({ waitUntil: 'domcontentloaded' });
  await mPage.waitForTimeout(2500);
  await mPage.screenshot({ path: `${OUT_DIR}/obsidian_08_mobile_login.png` });

  // Mobile Logged In Home
  await mPage.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await mPage.reload({ waitUntil: 'domcontentloaded' });
  await mPage.waitForTimeout(3000);
  await mPage.screenshot({ path: `${OUT_DIR}/obsidian_09_mobile_home.png` });

  // Mobile Drawer
  await mPage.mouse.click(20, 23);
  await mPage.waitForTimeout(1000);
  await mPage.screenshot({ path: `${OUT_DIR}/obsidian_10_mobile_drawer.png` });

  // Mobile Ladder via Drawer (y: 340)
  await mPage.mouse.click(120, 340);
  await mPage.waitForTimeout(2500);
  await mPage.screenshot({ path: `${OUT_DIR}/obsidian_11_mobile_ladder.png` });

  await browser.close();
  console.log('=== SHOWCASE CAPTURE COMPLETED SUCCESSFULLY ===');
}

runShowcase().catch(console.error);
