import { chromium } from 'playwright';
import fs from 'fs';

const OUT_DIRS = [
  '/home/mateus/dev/github/TCC/fotos_studio',
  '/home/mateus/.gemini/antigravity-cli/brain/5d5966f2-3d8f-4ed3-9f29-c423104eb460/assets',
];

for (const d of OUT_DIRS) {
  fs.mkdirSync(d, { recursive: true });
}

async function saveShot(page, filename) {
  for (const d of OUT_DIRS) {
    await page.screenshot({ path: `${d}/${filename}` });
  }
  console.log(`Saved ${filename}`);
}

async function main() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const p = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await p.goto('http://localhost:8089');
  await p.evaluate(() => {
    localStorage.clear();
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"MATEUS_TCC"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.setItem('flutter.firmware_gateway_ip', '"192.168.0.229"');
  });
  await p.reload();
  await p.waitForTimeout(3500);

  // 1. Aba Home / Supervisório IHM
  await p.mouse.click(915, 20); // Painel HMI
  await p.waitForTimeout(1800);
  await saveShot(p, 'tab_01_home_hmi.png');

  // 2. Aba Engenharia - Editor Ladder IEC 61131-3
  await p.mouse.click(1015, 20); // Engenharia
  await p.waitForTimeout(1000);
  await p.mouse.click(310, 95); // Lógica Ladder IEC tab
  await p.waitForTimeout(1500);
  await saveShot(p, 'tab_02_engenharia_ladder.png');

  // 3. Aba Engenharia - Mapeamento de I/O & Tags
  await p.mouse.click(460, 95); // Mapeamento de I/O & Tags tab
  await p.waitForTimeout(1800);
  await saveShot(p, 'tab_03_engenharia_gpio_tags.png');

  // 4. Mapa de Pinos Expandido (y=225)
  await p.mouse.click(600, 225);
  await p.waitForTimeout(1200);
  await saveShot(p, 'tab_04_mapa_pinos_expandido.png');
  // Recolher Mapa de Pinos
  await p.mouse.click(600, 225);
  await p.waitForTimeout(800);

  // 4b. Modal de Calibração Analógica (PVE) em UMID_SOLO / GPIO 34 (x=1852, y=780)
  await p.mouse.click(1852, 780);
  await p.waitForTimeout(1200);
  await saveShot(p, 'tab_09_calibracao_sensor_capacitivo.png');
  await p.keyboard.press('Escape');
  await p.waitForTimeout(600);

  // 5. Aba Engenharia - Rede & Controlador
  await p.mouse.click(640, 95); // Rede & Topologia tab
  await p.waitForTimeout(1500);
  await saveShot(p, 'tab_05_engenharia_rede_controlador.png');

  // 6. Aba Manutenção & Diagnóstico 1 ms
  await p.mouse.click(1115, 20); // Manutenção
  await p.waitForTimeout(1500);
  await saveShot(p, 'tab_06_manutencao_diagnostico_1ms.png');

  // 7. Aba Gestão & BI
  await p.mouse.click(1210, 20); // Gestão & BI
  await p.waitForTimeout(1500);
  await saveShot(p, 'tab_07_gestao_bi_oee.png');

  // 8. Modal Gravar no CLP (Deploy Bytecode)
  await p.mouse.click(1015, 20); // Engenharia
  await p.waitForTimeout(800);
  await p.mouse.click(310, 95); // Lógica Ladder IEC tab
  await p.waitForTimeout(800);
  await p.mouse.click(1750, 20); // Botão Gravar no CLP (cloud upload icon)
  await p.waitForTimeout(1200);
  await saveShot(p, 'tab_08_gravar_clp_deploy.png');
  await p.keyboard.press('Escape');
  await p.waitForTimeout(600);

  // 1b. Voltar para Aba Home / Supervisório IHM após sincronização completa para capturar Q0.1 ativo
  await p.mouse.click(915, 20);
  await p.waitForTimeout(1500);
  await saveShot(p, 'tab_01_home_hmi.png');

  await p.close();
  await browser.close();
  console.log('All TCC Studio screenshots captured successfully!');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
