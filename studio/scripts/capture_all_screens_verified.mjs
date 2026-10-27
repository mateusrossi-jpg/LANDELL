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
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 1. Diagnósticos de Campo
  console.log('1. Capturing Diagnósticos de Campo...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(700);
  await page.mouse.click(100, 485);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_diagnosticos_campo_v2.png` });

  // 2. Gestão, OEE & Relatórios
  console.log('2. Capturing Gestão, OEE & Relatórios...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(700);
  await page.mouse.click(100, 565);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_gestao_oee_v2.png` });

  // 3. Rede & Topologia
  console.log('3. Capturing Rede & Topologia...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(700);
  await page.mouse.click(100, 700);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_rede_topologia_v2.png` });

  // 4. Trilha de Auditoria Dialog
  console.log('4. Capturing Trilha de Auditoria Dialog...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(700);
  await page.mouse.click(100, 780);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_trilha_auditoria_v2.png` });

  // Fechar dialog
  await page.keyboard.press('Escape');
  await page.waitForTimeout(500);

  // 5. Lógica Ladder IEC
  console.log('5. Capturing Lógica Ladder IEC...');
  await page.mouse.click(18, 80);
  await page.waitForTimeout(700);
  await page.mouse.click(100, 320);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_ladder_ide_v2.png` });

  await browser.close();
  console.log('Done captures!');
}

run().catch(console.error);
