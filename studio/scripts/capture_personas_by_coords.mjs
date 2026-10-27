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
  await page.screenshot({ path: `${OUT_DIR}/app_persona_1_home.png` });

  // 2. Persona Engenharia (x ≈ 560, y ≈ 25)
  console.log('2. Switching to Engenharia...');
  await page.mouse.click(560, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_persona_2_engenharia.png` });

  // 3. Persona Manutenção (x ≈ 635, y ≈ 25)
  console.log('3. Switching to Manutenção...');
  await page.mouse.click(635, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_persona_3_manutencao.png` });

  // 4. Persona Gestão & BI (x ≈ 705, y ≈ 25)
  console.log('4. Switching to Gestão...');
  await page.mouse.click(705, 25);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/app_persona_4_gestao.png` });

  await browser.close();
  console.log('All personas captured successfully!');
}

runCapture().catch(console.error);
