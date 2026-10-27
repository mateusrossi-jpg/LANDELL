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

  // 1. Abre Drawer
  await page.mouse.click(20, 26);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/debug_drawer_view.png` });

  // 2. Clica no item Diagnósticos de Campo (y ≈ 370)
  await page.mouse.click(100, 370);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/debug_field_diagnostics.png` });

  // 3. Abre Drawer novamente e clica em Gestão, OEE & Relatórios (y ≈ 430)
  await page.mouse.click(20, 26);
  await page.waitForTimeout(1000);
  await page.mouse.click(100, 430);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/debug_manager_analytics.png` });

  // 4. Abre Drawer novamente e clica em Trilha de Auditoria & Eventos (y ≈ 600)
  await page.mouse.click(20, 26);
  await page.waitForTimeout(1000);
  await page.mouse.click(100, 600);
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/debug_audit_log_dialog.png` });

  await browser.close();
  console.log('Done!');
}

run().catch(console.error);
