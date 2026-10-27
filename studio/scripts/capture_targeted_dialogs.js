import { chromium } from 'playwright';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

async function initPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto('http://localhost:8080');
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });
  await page.reload();
  await page.waitForTimeout(2500);
  return page;
}

async function run() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // 1. Export Project Dialog
  console.log('1. Export Project Dialog...');
  let p = await initPage(browser);
  await p.mouse.click(25, 20); // Drawer
  await p.waitForTimeout(800);
  await p.mouse.click(120, 785); // Exportar Projeto
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_exportar_projeto_clean.png` });
  await p.close();

  // 2. Analog Calibration Dialog
  console.log('2. Analog Calibration Dialog...');
  p = await initPage(browser);
  await p.mouse.click(25, 20); // Drawer
  await p.waitForTimeout(800);
  await p.mouse.click(120, 335); // GPIO / TAGS
  await p.waitForTimeout(2000);
  await p.mouse.click(1835, 460); // Tune icon on GPIO 35
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_calibracao_analogica_clean.png` });
  await p.close();

  // 3. Configure Pin GPIO Dialog
  console.log('3. Configure Pin GPIO Dialog...');
  p = await initPage(browser);
  await p.mouse.click(25, 20); // Drawer
  await p.waitForTimeout(800);
  await p.mouse.click(120, 335); // GPIO / TAGS
  await p.waitForTimeout(2000);
  await p.mouse.click(500, 160); // Expand MAPA DE PINOS
  await p.waitForTimeout(1000);
  await p.mouse.click(80, 230); // Click first pin chip
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_configurar_pin_gpio_clean.png` });
  await p.close();

  // 4. Rede & Topologia - Menu Transporte
  console.log('4. Rede & Topologia - Menu Transporte...');
  p = await initPage(browser);
  await p.mouse.click(25, 20); // Drawer
  await p.waitForTimeout(800);
  await p.mouse.click(120, 585); // Rede & Topologia
  await p.waitForTimeout(2000);
  await p.mouse.click(1904, 390); // 3 dots
  await p.waitForTimeout(1000);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_menu_transporte_clean.png` });
  await p.close();

  await browser.close();
  console.log('Targeted captures complete!');
}

run().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
