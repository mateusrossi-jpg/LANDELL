import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = './screenshots/audit';

if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

async function runAudit() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  console.log('[AUDIT] Browser launched. Capturing Desktop (1440x900)...');
  
  // 1. Desktop Mode - Home
  const desktopCtx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });
  const page = await desktopCtx.newPage();
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(4000);

  // Click on the screen to initialize audio/flutter interaction if needed
  await page.mouse.click(100, 100);
  await page.waitForTimeout(1000);

  await page.screenshot({ path: `${OUT_DIR}/01_desktop_home_dashboard.png` });
  console.log(`[AUDIT] Saved: ${OUT_DIR}/01_desktop_home_dashboard.png`);

  // Open Terminal Drawer by clicking the bottom terminal bar
  await page.mouse.click(720, 890); // Click near bottom center where the terminal drawer header sits
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/02_desktop_terminal_open.png` });
  console.log(`[AUDIT] Saved: ${OUT_DIR}/02_desktop_terminal_open.png`);

  await desktopCtx.close();

  // 2. Mobile Viewport (iPhone XR - 414x896)
  console.log('[AUDIT] Capturing Mobile iPhone XR (414x896)...');
  const mobileCtx = await browser.newContext({
    viewport: { width: 414, height: 896 },
    deviceScaleFactor: 2.0,
    isMobile: true,
    hasTouch: true,
  });
  const mobilePage = await mobileCtx.newPage();
  await mobilePage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await mobilePage.waitForTimeout(4000);

  await mobilePage.screenshot({ path: `${OUT_DIR}/03_mobile_iphone_xr_home.png` });
  console.log(`[AUDIT] Saved: ${OUT_DIR}/03_mobile_iphone_xr_home.png`);

  // Open Menu Drawer on Mobile by clicking top-left hamburger menu (x: 20, y: 24)
  await mobilePage.mouse.click(20, 24);
  await mobilePage.waitForTimeout(1000);
  await mobilePage.screenshot({ path: `${OUT_DIR}/04_mobile_drawer_open.png` });
  console.log(`[AUDIT] Saved: ${OUT_DIR}/04_mobile_drawer_open.png`);

  await mobileCtx.close();

  // 3. Kiosk / Tablet Mode (1024x768 - Industrial Touch Panel)
  console.log('[AUDIT] Capturing Kiosk Tablet (1024x768)...');
  const kioskCtx = await browser.newContext({
    viewport: { width: 1024, height: 768 },
    deviceScaleFactor: 1.0,
    hasTouch: true,
  });
  const kioskPage = await kioskCtx.newPage();
  await kioskPage.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await kioskPage.waitForTimeout(4000);

  await kioskPage.screenshot({ path: `${OUT_DIR}/05_kiosk_tablet_initial.png` });
  console.log(`[AUDIT] Saved: ${OUT_DIR}/05_kiosk_tablet_initial.png`);

  await kioskCtx.close();

  await browser.close();
  console.log('[AUDIT] All visual screenshots captured successfully!');
}

runAudit().catch(err => {
  console.error('[AUDIT ERROR]', err);
  process.exit(1);
});
