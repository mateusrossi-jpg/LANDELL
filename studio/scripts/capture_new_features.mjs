import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

async function captureNewFeatures() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const page = await context.newPage();

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 1. Capture Drawer with 'Exportar' and 'Restaurar Pacote .endap'
  console.log('[NEW] Capturing Drawer with Restore & Export...');
  await page.mouse.click(20, 24);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/12_drawer_restore_endap_bundle.png` });

  // Close drawer
  await page.mouse.click(400, 200);
  await page.waitForTimeout(500);

  // 2. Navigate to Kiosk View
  console.log('[NEW] Navigating to Kiosk View...');
  await page.mouse.click(20, 24);
  await page.waitForTimeout(600);
  await page.mouse.click(140, 425); // Kiosk item
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${OUT_DIR}/13_kiosk_view_unlocked.png` });

  // 3. Click Lock Screen button on Kiosk View
  console.log('[NEW] Locking Kiosk View...');
  // The lock button is at the top right of the view
  // Let's click on the lock button area (~x: 1400, y: 75 or header)
  await page.mouse.click(1380, 80);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/14_kiosk_view_locked.png` });

  await browser.close();
  console.log('[NEW] All new feature captures completed!');
}

captureNewFeatures().catch(console.error);
