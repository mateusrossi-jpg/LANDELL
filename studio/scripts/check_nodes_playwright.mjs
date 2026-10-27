import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  page.on('console', msg => console.log('LOG:', msg.text()));

  await page.goto('http://localhost:8080');
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"INTEGRADOR_CHEFE"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });

  await page.reload();
  await page.waitForTimeout(4000);

  // Inspect what nodes the studio sees via network
  const nodes = await page.evaluate(async () => {
    const res = await fetch('http://192.168.0.229/api/nodes');
    return await res.json();
  });
  console.log('Nodes from Gateway:', JSON.stringify(nodes));

  await browser.close();
})();
