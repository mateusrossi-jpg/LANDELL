import { chromium } from 'playwright';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

(async () => {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  await page.goto('http://localhost:8080');
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });

  await page.reload();
  await page.waitForTimeout(3000);

  // Abre drawer e clica em GPIO / TAGS
  await page.mouse.click(20, 20);
  await page.waitForTimeout(1000);
  await page.mouse.click(80, 335);
  await page.waitForTimeout(2000);

  // Clica no filtro "Nó 1" em x=230, y=108
  console.log('Clicando no filtro Nó 1 em x=230, y=108...');
  await page.mouse.click(230, 108);
  await page.waitForTimeout(1500);

  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_node1_view_clean.png` });
  console.log('Print filtro Nó 1 salvo.');

  await browser.close();
})();
