import { chromium } from 'playwright';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

async function run() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  
  console.log('Loading app at localhost:8080...');
  await page.goto('http://localhost:8080');
  
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });
  
  await page.reload();
  await page.waitForTimeout(3000);
  
  // 1. Painel HMI
  console.log('Capturing View 01: Painel HMI...');
  await page.mouse.click(930, 20); // Persona HMI
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_01_painel_hmi.png` });

  // 2. Kiosk Mode
  console.log('Capturing View 07: Kiosk Mode...');
  await page.mouse.click(1680, 60); // Kiosk button on HMI toolbar
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_07_kiosk_mode.png` });
  // Exit kiosk: click anywhere top right or ESC
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // 3. Engenharia - Ladder IEC
  console.log('Capturing View 02: Engenharia - Ladder IEC...');
  await page.mouse.click(1030, 20); // Persona Engenharia
  await page.waitForTimeout(1000);
  await page.mouse.click(180, 95); // Tab Ladder IEC
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_02_engenharia_ladder.png` });

  // 4. Engenharia - GPIO / TAGS
  console.log('Capturing View 03: Engenharia - GPIO & TAGS...');
  await page.mouse.click(260, 95); // Tab GPIO / Tags
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_03_engenharia_gpio_tags.png` });

  // 5. Engenharia - Rede & Topologia
  console.log('Capturing View 04: Engenharia - Rede & Topologia...');
  await page.mouse.click(370, 95); // Tab Rede & Topologia
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_04_engenharia_rede_topologia.png` });

  // 6. Manutencao
  console.log('Capturing View 05: Manutencao...');
  await page.mouse.click(1130, 20); // Persona Manutencao
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_05_manutencao_energy_flow.png` });

  // 7. Gestao & BI
  console.log('Capturing View 06: Gestao & BI...');
  await page.mouse.click(1220, 20); // Persona Gestao & BI
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/view_06_gestao_oee_bi.png` });

  // DIALOGS:
  // Dialog 01: Trilha de Auditoria
  console.log('Capturing Dialog 01: Trilha de Auditoria...');
  await page.mouse.click(25, 20); // Open Drawer
  await page.waitForTimeout(800);
  await page.mouse.click(120, 690); // Trilha de Auditoria
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_01_trilha_auditoria.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 02: Gestao de Usuarios & Login
  console.log('Capturing Dialog 02: Gestao de Usuarios & Login...');
  await page.mouse.click(25, 20); // Open Drawer
  await page.waitForTimeout(800);
  await page.mouse.click(120, 715); // Gestao de Usuarios
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_02_gestao_usuarios_login.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 03: Exportar Projeto
  console.log('Capturing Dialog 03: Exportar Projeto...');
  await page.mouse.click(25, 20); // Open Drawer
  await page.waitForTimeout(800);
  await page.mouse.click(120, 745); // Exportar Projeto
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_03_exportar_projeto.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 04: Gravar no CLP (Deploy)
  console.log('Capturing Dialog 04: Gravar no CLP (Deploy)...');
  await page.mouse.click(1750, 20); // Cloud upload button
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_04_gravar_clp_deploy.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 05: Failsafe
  console.log('Capturing Dialog 05: Failsafe...');
  await page.mouse.click(1860, 20); // FAILSAFE button
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_05_failsafe.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  await browser.close();
  console.log('Batch 1 complete.');
}

run().catch(err => {
  console.error('Error running playwright:', err);
  process.exit(1);
});
