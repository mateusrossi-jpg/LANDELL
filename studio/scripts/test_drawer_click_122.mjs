import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/52b6caeb-2448-4662-8c57-10ba219cdbbd';

async function run() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();

  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // Click on the hamburger icon at x = 122, y = 25
  console.log('Clicking hamburger at (122, 25)...');
  await page.mouse.click(122, 25);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/test_drawer_122.png` });

  // Click on the hamburger icon at x = 125, y = 80 (the second header)
  console.log('Clicking second hamburger at (18, 80)...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/test_drawer_18_80.png` });

  await browser.close();
}

run().catch(console.error);
