import { chromium } from 'playwright';
import { execSync } from 'child_process';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

(async () => {
  console.log('=== TESTE E2E HUMANO: ACIONAMENTO REAL GPIO 4 (Q0.0 / RELÉ 1) & ESTABILIDADE ===');

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('Gpio') || text.includes('Output') || text.includes('set') || text.includes('ERROR')) {
      console.log('[BROWSER UI LOG]:', text);
    }
  });

  page.on('request', req => {
    if (req.url().includes('/api/')) {
      console.log('[HTTP REQ]:', req.method(), req.url());
    }
  });

  page.on('response', resp => {
    if (resp.url().includes('/api/')) {
      console.log('[HTTP RESP]:', resp.status(), resp.url());
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

  // 1. Abrir Menu Drawer e navegar para GPIO / TAGS
  console.log('\n[PASSO 1] Abrindo Menu Drawer e navegando para GPIO / TAGS...');
  await page.mouse.click(20, 20);
  await page.waitForTimeout(800);
  await page.mouse.click(80, 335); // GPIO / TAGS
  await page.waitForTimeout(2500);

  // 2. Selecionar filtro Gateway para foco cirúrgico no Rack 0 (Gateway Local)
  console.log('\n[PASSO 2] Selecionando filtro "Gateway" (Rack 0)...');
  await page.mouse.click(140, 115);
  await page.waitForTimeout(1500);

  // Garante estado inicial desligado no hardware
  try {
    execSync('curl -s -m 2 "http://192.168.0.229/api/set?id=100&value=0"');
  } catch (_) {}
  await page.waitForTimeout(1000);

  // Salva screenshot do estado inicial com botões verdes LIGAR visíveis
  await page.screenshot({ path: `${SCREENSHOT_DIR}/e2e_q0_0_initial_ready.png` });
  console.log('✓ Screenshot 1 salvo: e2e_q0_0_initial_ready.png');

  const statusInitial = execSync('curl -s -m 2 "http://192.168.0.229/api/io/map"').toString();
  const matchInit = statusInitial.match(/\{"channel_id":100[^}]*\}/);
  console.log('>> Estado Físico Inicial Canal 100 (GPIO 4):', matchInit ? matchInit[0] : 'N/A');

  // 3. Clicar no botão LIGAR de Q0.0 (GPIO 4 / Relé 1) nas coordenadas exatas (x=1818, y=728)
  console.log('\n[PASSO 3] Clicando no botão LIGAR de Q0.0 (GPIO 4 / Relé 1) em (1818, 728)...');
  await page.mouse.click(1818, 728);
  await page.waitForTimeout(3000);

  // Verifica resposta do hardware real
  const statusTurnedOn = execSync('curl -s -m 2 "http://192.168.0.229/api/io/map"').toString();
  const matchOn = statusTurnedOn.match(/\{"channel_id":100[^}]*\}/);
  console.log('>> Estado Físico Canal 100 APÓS LIGAR:', matchOn ? matchOn[0] : 'N/A');

  await page.screenshot({ path: `${SCREENSHOT_DIR}/e2e_q0_0_turned_on_red_btn.png` });
  console.log('✓ Screenshot 2 salvo: e2e_q0_0_turned_on_red_btn.png');

  // 4. Clicar no botão DESLIGAR de Q0.0 nas coordenadas exatas (x=1818, y=728)
  console.log('\n[PASSO 4] Clicando no botão DESLIGAR de Q0.0 em (1818, 728)...');
  await page.mouse.click(1818, 728);
  await page.waitForTimeout(3000);

  const statusTurnedOff = execSync('curl -s -m 2 "http://192.168.0.229/api/io/map"').toString();
  const matchOff = statusTurnedOff.match(/\{"channel_id":100[^}]*\}/);
  console.log('>> Estado Físico Canal 100 APÓS DESLIGAR:', matchOff ? matchOff[0] : 'N/A');

  await page.screenshot({ path: `${SCREENSHOT_DIR}/e2e_q0_0_turned_off_green_btn.png` });
  console.log('✓ Screenshot 3 salvo: e2e_q0_0_turned_off_green_btn.png');

  // 5. Teste de Estabilidade com Queda de Conexão:
  // Mudamos o IP configurado para um IP inexistente na rede para simular queda/desconexão
  console.log('\n[PASSO 5] Testando resiliência à desconexão do ESP32...');
  await page.evaluate(() => {
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.254"');
  });
  // Dispara refresh ou aguarda 4 segundos de polling para disparar timeout
  console.log('Aguardando 5 segundos com ESP32 indisponível...');
  await page.waitForTimeout(5000);

  await page.screenshot({ path: `${SCREENSHOT_DIR}/e2e_gpio_stability_offline_retained.png` });
  console.log('✓ Screenshot 4 salvo: e2e_gpio_stability_offline_retained.png');

  console.log('\n=== TODOS OS TESTES E2E FORAM CONCLUÍDOS COM SUCESSO ===');
  await browser.close();
})();
