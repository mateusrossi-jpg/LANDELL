import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

async function captureTabs() {
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
  await page.waitForTimeout(4000);

  // Function to click drawer items
  async function openDrawerAndClick(itemIndex) {
    // Click Menu hamburger button at (x: 22, y: 24)
    await page.mouse.click(22, 24);
    await page.waitForTimeout(600);

    // Coordinates of drawer items (drawer width is ~304px)
    // Header is ~140px tall. Item 0: ~170, Item 1 (Ladder): ~220, Item 2 (GPIO): ~270, Item 3 (Manut): ~320, Item 4 (Kiosk): ~370, Item 5 (Gestao): ~420, Rede: ~520
    const yMap = {
      ladder: 225,
      gpio: 280,
      manut: 335,
      kiosk: 390,
      gestao: 445,
      rede: 535,
    };

    if (yMap[itemIndex]) {
      await page.mouse.click(120, yMap[itemIndex]);
      await page.waitForTimeout(1500);
    }
  }

  // 1. Ladder IEC Editor
  console.log('[TABS] Navigating to Ladder IEC...');
  await openDrawerAndClick('ladder');
  await page.screenshot({ path: `${OUT_DIR}/06_desktop_ladder_iec.png` });
  console.log(`[TABS] Saved: ${OUT_DIR}/06_desktop_ladder_iec.png`);

  // 2. GPIO / TAGS
  console.log('[TABS] Navigating to GPIO / TAGS...');
  await openDrawerAndClick('gpio');
  await page.screenshot({ path: `${OUT_DIR}/07_desktop_gpio_tags.png` });
  console.log(`[TABS] Saved: ${OUT_DIR}/07_desktop_gpio_tags.png`);

  // 3. IHM Operador (Touch Kiosk)
  console.log('[TABS] Navigating to IHM Operador (Touch Kiosk)...');
  await openDrawerAndClick('kiosk');
  await page.screenshot({ path: `${OUT_DIR}/08_desktop_ihm_kiosk.png` });
  console.log(`[TABS] Saved: ${OUT_DIR}/08_desktop_ihm_kiosk.png`);

  // 4. Manutenção & Forçamento
  console.log('[TABS] Navigating to Manutenção...');
  await openDrawerAndClick('manut');
  await page.screenshot({ path: `${OUT_DIR}/09_desktop_manutencao.png` });
  console.log(`[TABS] Saved: ${OUT_DIR}/09_desktop_manutencao.png`);

  // 5. Redes & Topologia
  console.log('[TABS] Navigating to Redes & Topologia...');
  await openDrawerAndClick('rede');
  await page.screenshot({ path: `${OUT_DIR}/10_desktop_redes_topologia.png` });
  console.log(`[TABS] Saved: ${OUT_DIR}/10_desktop_redes_topologia.png`);

  await browser.close();
  console.log('[TABS] All tab views captured!');
}

captureTabs().catch(console.error);
