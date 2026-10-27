const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1920, height: 1080 } });
  const page = await context.newPage();

  page.on('console', msg => console.log('BROWSER CONSOLE:', msg.type(), msg.text()));
  page.on('requestfailed', req => console.log('REQ FAILED:', req.url(), req.failure().errorText));
  page.on('response', resp => {
    if (resp.url().includes('api/automation/ladder') || resp.url().includes('192.168.0.229')) {
      console.log('HTTP RESP:', resp.status(), resp.url());
    }
  });

  console.log('Navegando para o Studio...');
  await page.goto('http://localhost:8080');
  await page.waitForTimeout(4000);

  console.log('Procurando botão Gravar CLP...');
  // Click on "Gravar CLP" in the ribbon bar
  const deployBtn = page.getByText('Gravar CLP', { exact: true });
  await deployBtn.click();
  await page.waitForTimeout(1000);

  // Take screenshot of the dialog
  await page.screenshot({ path: '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots/test_deploy_dialog.png' });

  console.log('Clicando em Compilar & Gravar...');
  const compileBtn = page.getByRole('button', { name: 'Compilar & Gravar' });
  await compileBtn.click();

  // Wait 4 seconds for deploy to finish and SnackBar to appear
  await page.waitForTimeout(4000);

  await page.screenshot({ path: '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots/test_deploy_result.png' });
  console.log('Screenshots salvos.');

  await browser.close();
})();
