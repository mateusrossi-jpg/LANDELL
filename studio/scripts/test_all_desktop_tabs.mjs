import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

async function testDesktopTabs() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const page = await ctx.newPage();

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 1. Home Dashboard
  console.log('[TABS] Capturando tab_desktop_01_home.png...');
  await page.screenshot({ path: `${OUT_DIR}/tab_desktop_01_home.png` });

  // 2. Engenharia (Ladder IEC) - Clica em Engenharia (x: 840, y: 26)
  console.log('[TABS] Clicando em Engenharia (x: 840, y: 26)...');
  await page.mouse.click(840, 26);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/tab_desktop_02_ladder_engenharia.png` });

  // 3. Manutenção (Diagnósticos de Campo) - Clica em Manutenção (x: 940, y: 26)
  console.log('[TABS] Clicando em Manutenção (x: 940, y: 26)...');
  await page.mouse.click(940, 26);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/tab_desktop_03_manutencao.png` });

  // 4. Operação (IHM Kiosk) - Clica em Operação (x: 1025, y: 26)
  console.log('[TABS] Clicando em Operação (x: 1025, y: 26)...');
  await page.mouse.click(1025, 26);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/tab_desktop_04_operacao_kiosk.png` });

  // 5. Gestão & BI - Clica em Gestão & BI (x: 1115, y: 26)
  console.log('[TABS] Clicando em Gestão & BI (x: 1115, y: 26)...');
  await page.mouse.click(1115, 26);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/tab_desktop_05_gestao_bi.png` });

  await browser.close();
  console.log('=== [TABS] PERSONAS CAPTURADAS COM SUCESSO! ===');
}

testDesktopTabs().catch(console.error);
