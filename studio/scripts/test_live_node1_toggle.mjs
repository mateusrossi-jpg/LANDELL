import { chromium } from 'playwright';
import { spawn } from 'child_process';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

// Inicia monitor serial no Nó 1 (/dev/ttyUSB1)
let serialLogs = [];
const pySerial = spawn('python3', ['-u', '-c', `
import serial, sys
s = serial.Serial('/dev/ttyUSB1', 115200, timeout=0.1)
s.reset_input_buffer()
while True:
    line = s.readline()
    if line:
        text = line.decode('utf-8', errors='ignore').strip()
        if any(k in text for k in ['AUTOMATION', 'PROTOCOL', 'Comando remoto', 'CLUSTER_NOW']):
            print(text, flush=True)
`]);

pySerial.stdout.on('data', data => {
  const lines = data.toString().split('\n').filter(Boolean);
  for (const line of lines) {
    console.log('[NODE 1 SERIAL]:', line);
    serialLogs.push(line);
  }
});

(async () => {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  page.on('console', msg => {
    const text = msg.text();
    if (text.includes('Gpio') || text.includes('Output') || text.includes('set') || text.includes('ERROR')) {
      console.log('[UI LOG]:', text);
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

  // 1. Abrir Drawer e clicar em GPIO / TAGS
  console.log('1. Navegando para GPIO / TAGS...');
  await page.mouse.click(20, 20);
  await page.waitForTimeout(800);
  await page.mouse.click(80, 335);
  await page.waitForTimeout(2000);

  // 2. Clicar no filtro Nó 1
  console.log('2. Selecionando filtro "Nó 1"...');
  await page.mouse.click(230, 108);
  await page.waitForTimeout(1500);

  // 3. Clicar no botão LIGAR de Q1.0 nas coordenadas exatas (x=1818, y=729)
  console.log('3. Clicando no botão LIGAR de Q1.0 nas coordenadas exatas (x=1818, y=729)...');
  await page.mouse.click(1818, 729);
  await page.waitForTimeout(3000);

  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_node1_q1_0_turned_on.png` });
  console.log('Screenshot 1 salvo: Q1.0 ligado.');

  // 4. Clicar no botão DESLIGAR de Q1.0 (x=1818, y=729)
  console.log('4. Clicando no botão DESLIGAR de Q1.0 (x=1818, y=729)...');
  await page.mouse.click(1818, 729);
  await page.waitForTimeout(3000);

  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_node1_q1_0_turned_off.png` });
  console.log('Screenshot 2 salvo: Q1.0 desligado.');

  await browser.close();
  pySerial.kill();

  console.log('--- RESUMO DOS LOGS SERIAIS DO NÓ 1 ---');
  console.log(serialLogs.join('\n'));
  process.exit(0);
})();
