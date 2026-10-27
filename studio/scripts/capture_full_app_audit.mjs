import { chromium } from 'playwright';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/52b6caeb-2448-4662-8c57-10ba219cdbbd';

async function runCapture() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({ viewport: { width: 1366, height: 768 } });
  const page = await context.newPage();

  console.log('Navigating to', BASE_URL);
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 1. Home / HMI Page
  console.log('1. Capturing Home / HMI...');
  await page.screenshot({ path: `${OUT_DIR}/app_real_home_view.png` });

  // 2. Persona Engenheiro: click on ribbon persona button "Engenharia"
  // In ribbon bar, the segmented control buttons are at x ≈ 480-550, y ≈ 25
  console.log('2. Switching to Persona Engenheiro via Ribbon...');
  // Click on "Engenharia" in ribbon
  const textEng = page.getByText('Engenharia', { exact: false });
  if (await textEng.isVisible()) {
    await textEng.click();
  } else {
    // Or open drawer and click Workspace
    await page.mouse.click(20, 26);
    await page.waitForTimeout(500);
    await page.mouse.click(100, 320); // Ladder IEC
  }
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_real_engineering_view.png` });

  // 3. Maintenance Diagnostics (Diagnósticos de Campo)
  console.log('3. Navigating to Diagnósticos de Campo...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(600);
  await page.mouse.click(100, 485); // Diagnósticos de Campo
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_real_maintenance_view.png` });

  // 4. Gestão, OEE & Relatórios
  console.log('4. Navigating to Gestão & Analytics...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(600);
  await page.mouse.click(100, 565); // Gestão
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_real_manager_view.png` });

  // 5. Redes & Topologia
  console.log('5. Navigating to Rede & Topologia...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(600);
  await page.mouse.click(100, 645); // Rede & Topologia
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_real_networks_view.png` });

  await browser.close();
  console.log('All captures done successfully!');
}

runCapture().catch(console.error);
