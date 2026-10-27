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
  
  // Dialog 09: HMI Adicionar Widget / Nova Tela
  console.log('Capturing Dialog 09: HMI Nova Tela...');
  await page.mouse.click(240, 60); // "+ Nova Tela" button on HMI toolbar
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_09_hmi_nova_tela.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 10: HMI Exportar Tela
  console.log('Capturing Dialog 10: HMI Exportar Tela...');
  await page.mouse.click(1740, 60); // "EXPORTAR IHM" button
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_10_hmi_exportar_tela.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 11: Rede & Topologia - Menu de Transporte
  console.log('Capturing Dialog 11: Menu Transporte...');
  await page.mouse.click(1030, 20); // Engenharia
  await page.waitForTimeout(1000);
  await page.mouse.click(370, 95); // Tab Rede & Topologia
  await page.waitForTimeout(1500);
  await page.mouse.click(1904, 390); // 3 dots button
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_11_rede_menu_transporte.png` });
  await page.mouse.click(1000, 500); // dismiss popup
  await page.waitForTimeout(800);

  // Dialog 06: Configurar Pin GPIO
  console.log('Capturing Dialog 06: Configurar Pin GPIO...');
  await page.mouse.click(260, 95); // Tab GPIO / Tags
  await page.waitForTimeout(1500);
  await page.mouse.click(1875, 260); // Edit pencil on GPIO 16
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_06_configurar_pin_gpio.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 07: Calibração Analógica
  console.log('Capturing Dialog 07: Calibração Analógica...');
  await page.mouse.click(1840, 430); // Calibration slider on GPIO 35
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_07_calibracao_analogica.png` });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(800);

  // Dialog 08: Criar Variável Tag no Ladder
  console.log('Capturing Dialog 08: Criar Variável Tag...');
  await page.mouse.click(180, 95); // Tab Ladder IEC
  await page.waitForTimeout(1500);
  // Controller Tags (Globais) in tree at x=55, y=195
  await page.mouse.click(55, 195); 
  await page.waitForTimeout(1500);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/dialog_08_criar_variavel_tag.png` });

  await browser.close();
  console.log('Batch 2 complete.');
}

run().catch(err => {
  console.error('Error running playwright batch 2:', err);
  process.exit(1);
});
