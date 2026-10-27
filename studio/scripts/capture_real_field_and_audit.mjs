import { chromium } from 'playwright';
import fs from 'fs';

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
    localStorage.setItem('flutter.endap_session_user', '"TECNICO_CAMPO"');
    localStorage.setItem('flutter.endap_session_role', '"ACESSO TÉCNICO AUTORIZADO"');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 1. Diagnósticos de Campo (Item 4 do Drawer: y ≈ 485)
  console.log('Opening drawer and navigating to Diagnósticos de Campo...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(700);
  await page.mouse.click(100, 485); // Diagnósticos de Campo
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_field_diagnostics.png` });
  console.log('Captured real_field_diagnostics.png');

  // 2. Gestão, OEE & Relatórios (Item 5 do Drawer: y ≈ 565)
  console.log('Opening drawer and navigating to Gestão...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(700);
  await page.mouse.click(100, 565); // Gestão
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_manager_analytics.png` });
  console.log('Captured real_manager_analytics.png');

  // 3. Trilha de Auditoria & Eventos (Item no rodapé do Drawer: y ≈ 695)
  console.log('Opening drawer and opening Trilha de Auditoria...');
  await page.mouse.click(20, 26); // Hamburger drawer
  await page.waitForTimeout(700);
  await page.mouse.click(100, 695); // Trilha de Auditoria
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${OUT_DIR}/real_audit_log_dialog.png` });
  console.log('Captured real_audit_log_dialog.png');

  await browser.close();
  console.log('All captures done successfully!');
}

runCapture().catch(console.error);
