import { chromium } from 'playwright';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

(async () => {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  
  page.on('console', msg => console.log('LOG:', msg.text()));
  page.on('request', req => {
    if (req.url().includes('ladder') || req.url().includes('192.168.0.229')) {
      console.log('HTTP REQ:', req.method(), req.url());
    }
  });
  page.on('response', resp => {
    if (resp.url().includes('ladder') || resp.url().includes('192.168.0.229')) {
      console.log('HTTP RESP:', resp.status(), resp.url());
    }
  });

  await page.goto('http://localhost:8080');
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });
  await page.reload();
  await page.waitForTimeout(3000);

  console.log('Clicando no ícone de Gravar CLP (Deploy) em 1750, 20...');
  await page.mouse.click(1750, 20);
  await page.waitForTimeout(1200);

  await page.screenshot({ path: `${SCREENSHOT_DIR}/deploy_passo1_dialog.png` });
  console.log('Print do diálogo salvo.');

  console.log('Clicando em "Compilar & Gravar" em 1080, 658...');
  await page.mouse.click(1080, 658);

  await page.waitForTimeout(3000);
  await page.screenshot({ path: `${SCREENSHOT_DIR}/deploy_passo2_sucesso.png` });
  console.log('Print pós-deploy salvo.');

  await browser.close();
})();
