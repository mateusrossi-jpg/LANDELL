import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

async function captureAll() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const page = await context.newPage();

  // 1. Setup authorized technical session
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);

  // Helper to open drawer and click
  async function selectDrawerItem(yCoord, label) {
    console.log(`[CAPTURE] Opening drawer for ${label}...`);
    // Click menu icon
    await page.mouse.click(20, 24);
    await page.waitForTimeout(600);
    // Click drawer item
    await page.mouse.click(140, yCoord);
    await page.waitForTimeout(1500);
  }

  // Helper to click persona on ribbon bar
  async function selectPersona(xCoord, label) {
    console.log(`[CAPTURE] Switching persona to ${label}...`);
    await page.mouse.click(xCoord, 24);
    await page.waitForTimeout(1500);
  }

  // 1. Home Dashboard
  console.log('[CAPTURE] 01 Home Dashboard...');
  await page.screenshot({ path: `${OUT_DIR}/01_desktop_home_dashboard.png` });

  // 2. Ladder IEC Editor (from drawer: y ~ 245)
  console.log('[CAPTURE] 06 Desktop Ladder IEC...');
  await selectDrawerItem(245, 'Ladder IEC');
  await page.screenshot({ path: `${OUT_DIR}/06_desktop_ladder_iec.png` });

  // 3. GPIO / TAGS (from drawer: y ~ 305)
  console.log('[CAPTURE] 07 Desktop GPIO Tags...');
  await selectDrawerItem(305, 'GPIO / TAGS');
  await page.screenshot({ path: `${OUT_DIR}/07_desktop_gpio_tags.png` });

  // 4. Diagnósticos de Campo / Manutenção (y ~ 365)
  console.log('[CAPTURE] 09 Desktop Manutencao...');
  await selectDrawerItem(365, 'Diagnósticos / Manutenção');
  await page.screenshot({ path: `${OUT_DIR}/09_desktop_manutencao.png` });

  // 5. IHM Operador (Touch Kiosk) (y ~ 425)
  console.log('[CAPTURE] 08 Desktop IHM Kiosk...');
  await selectDrawerItem(425, 'IHM Operador Touch Kiosk');
  await page.screenshot({ path: `${OUT_DIR}/08_desktop_ihm_kiosk.png` });

  // 6. Gestão, OEE & Relatórios (y ~ 485)
  console.log('[CAPTURE] 11 Desktop Gestao OEE...');
  await selectDrawerItem(485, 'Gestão & OEE');
  await page.screenshot({ path: `${OUT_DIR}/11_desktop_gestao_oee.png` });

  // 7. Redes & Topologia (y ~ 560)
  console.log('[CAPTURE] 10 Desktop Redes...');
  await selectDrawerItem(560, 'Redes & Topologia');
  await page.screenshot({ path: `${OUT_DIR}/10_desktop_redes_topologia.png` });

  // 8. Kiosk Mode on Tablet (1024x768)
  console.log('[CAPTURE] 05 Kiosk Tablet Touch...');
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.waitForTimeout(1000);
  await selectDrawerItem(425, 'IHM Operador Touch Kiosk Tablet');
  await page.screenshot({ path: `${OUT_DIR}/05_kiosk_tablet_initial.png` });

  await browser.close();
  console.log('[CAPTURE] All persona audit views successfully captured!');
}

captureAll().catch(console.error);
