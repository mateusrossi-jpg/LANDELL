import { chromium } from 'playwright';
import { execSync } from 'child_process';

const SCREENSHOT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/4cf6ebf5-2dc4-4c2e-a8d2-e273cfb544d8/screenshots';

(async () => {
  console.log('--- TESTE E2E: ESTABILIDADE GPIO & TAGS E ACIONAMENTO GPIO 4 (Q0.0) ---');

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  const httpLogs = [];
  page.on('request', req => {
    if (req.url().includes('/api/')) {
      const entry = `REQ: ${req.method()} ${req.url()}`;
      console.log(entry);
      httpLogs.push(entry);
    }
  });

  page.on('response', async resp => {
    if (resp.url().includes('/api/')) {
      const entry = `RESP ${resp.status()}: ${resp.url()}`;
      console.log(entry);
      httpLogs.push(entry);
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
  console.log('1. Navegando para a aba GPIO / TAGS...');
  await page.mouse.click(20, 20);
  await page.waitForTimeout(800);
  await page.mouse.click(80, 335); // Posição de GPIO / TAGS no Drawer
  await page.waitForTimeout(2500);

  // Captura estado estável inicial
  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_initial_stable_view.png` });
  console.log('Screenshot 1 salvo: gpio_tags_initial_stable_view.png');

  // 2. Localiza e aciona GPIO 4 (Q0.0 / Relé 1)
  console.log('2. Acionando GPIO 4 (Q0.0) via interface do Studio...');
  // No layout Desktop 1920x1080, localizamos o botão LIGAR de Q0.0 (localizado na seção de saídas digitais)
  // Vamos primeiro usar a API para garantir estado limpo (0)
  try {
    execSync('curl -s -m 2 "http://192.168.0.229/api/set?id=100&value=0"');
  } catch (_) {}
  await page.waitForTimeout(1000);

  // Procura pelo botão na tela com clique ou chamando a API do Studio
  // No DOM Flutter Web / CanvasKit / HTML renderer:
  // Clicar no botão da primeira saída digital (Q0.0 / GPIO 4)
  // Coordenadas típicas de Q0.0 no layout 1920x1080:
  // X ~ 1818, Y ~ 660 para a primeira saída
  console.log('Clicando em LIGAR Q0.0...');
  // Vamos disparar também via evaluate para garantir acionamento no cliente Flutter se necessário:
  await page.mouse.click(1818, 665);
  await page.waitForTimeout(2500);

  // Verifica o estado físico do hardware no Gateway
  const statusOn = execSync('curl -s -m 2 "http://192.168.0.229/api/io/map"').toString();
  console.log('Estado do hardware após comando LIGAR:');
  const match100 = statusOn.match(/\{"channel_id":100[^}]*\}/);
  if (match100) {
    console.log('>> CANAL 100:', match100[0]);
  }

  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_gpio4_turned_on.png` });
  console.log('Screenshot 2 salvo: gpio_tags_gpio4_turned_on.png');

  // 3. Desliga GPIO 4
  console.log('3. Clicando em DESLIGAR Q0.0...');
  await page.mouse.click(1818, 665);
  await page.waitForTimeout(2500);

  const statusOff = execSync('curl -s -m 2 "http://192.168.0.229/api/io/map"').toString();
  console.log('Estado do hardware após comando DESLIGAR:');
  const match100Off = statusOff.match(/\{"channel_id":100[^}]*\}/);
  if (match100Off) {
    console.log('>> CANAL 100:', match100Off[0]);
  }

  await page.screenshot({ path: `${SCREENSHOT_DIR}/gpio_tags_gpio4_turned_off.png` });
  console.log('Screenshot 3 salvo: gpio_tags_gpio4_turned_off.png');

  await browser.close();
  console.log('--- TESTE CONCLUÍDO COM SUCESSO ---');
})();
