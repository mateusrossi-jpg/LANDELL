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

async function capture() {
  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  // 1. View: Painel HMI
  console.log('1. view_01_painel_hmi...');
  let p = await initPage(browser);
  await p.mouse.click(930, 20); // HMI
  await p.waitForTimeout(1000);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_01_painel_hmi.png` });
  await p.close();

  // 2. View: Kiosk Mode
  console.log('2. view_02_kiosk_mode...');
  p = await initPage(browser);
  await p.mouse.click(930, 20);
  await p.waitForTimeout(1000);
  await p.mouse.click(1680, 60); // KIOSK button
  await p.waitForTimeout(1000);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_02_kiosk_mode.png` });
  await p.close();

  // 3. View: Engenharia - Ladder IEC
  console.log('3. view_03_engenharia_ladder...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20); // Engenharia
  await p.waitForTimeout(1000);
  await p.mouse.click(180, 95); // Ladder IEC
  await p.waitForTimeout(1200);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_03_engenharia_ladder.png` });
  await p.close();

  // 4. View: Engenharia - GPIO & TAGS
  console.log('4. view_04_engenharia_gpio_tags...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(260, 95); // GPIO/Tags
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_04_engenharia_gpio_tags.png` });
  await p.close();

  // 5. View: Engenharia - Rede & Topologia
  console.log('5. view_05_engenharia_rede_topologia...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(370, 95); // Rede & Topologia
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_05_engenharia_rede_topologia.png` });
  await p.close();

  // 6. View: Manutenção (Energy Flow)
  console.log('6. view_06_manutencao_energy_flow...');
  p = await initPage(browser);
  await p.mouse.click(1130, 20); // Manutenção
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_06_manutencao_energy_flow.png` });
  await p.close();

  // 7. View: Gestão & BI (OEE)
  console.log('7. view_07_gestao_oee_bi...');
  p = await initPage(browser);
  await p.mouse.click(1220, 20); // Gestão & BI
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_07_gestao_oee_bi.png` });
  await p.close();

  // 8. View: Drawer de Navegação Aberto
  console.log('8. view_08_drawer_aberto...');
  p = await initPage(browser);
  await p.mouse.click(25, 20); // Hamburger
  await p.waitForTimeout(1000);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/view_08_drawer_aberto.png` });
  await p.close();

  // 9. Dialog: Trilha de Auditoria & Eventos
  console.log('9. dialog_01_trilha_auditoria...');
  p = await initPage(browser);
  await p.mouse.click(25, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(120, 650); // Trilha de Auditoria
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_01_trilha_auditoria.png` });
  await p.close();

  // 10. Dialog: Gestão de Usuários & Login
  console.log('10. dialog_02_gestao_usuarios...');
  p = await initPage(browser);
  await p.mouse.click(25, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(120, 715); // Gestão de Usuários
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_02_gestao_usuarios.png` });
  await p.close();

  // 11. Dialog: Exportar Projeto (.endap)
  console.log('11. dialog_03_exportar_projeto...');
  p = await initPage(browser);
  await p.mouse.click(25, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(120, 785); // Exportar Projeto
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_03_exportar_projeto.png` });
  await p.close();

  // 12. Dialog: Gravar no CLP (Deploy)
  console.log('12. dialog_04_gravar_clp_deploy...');
  p = await initPage(browser);
  await p.mouse.click(1750, 20); // Deploy cloud upload icon
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_04_gravar_clp_deploy.png` });
  await p.close();

  // 13. Dialog: Failsafe Ativado
  console.log('13. dialog_05_failsafe_ativado...');
  p = await initPage(browser);
  await p.mouse.click(1860, 20); // FAILSAFE button
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_05_failsafe_ativado.png` });
  await p.close();

  // 14. Dialog: Calibração Analógica de Canal
  console.log('14. dialog_06_calibracao_analogica...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20); // Engenharia
  await p.waitForTimeout(800);
  await p.mouse.click(260, 95); // GPIO/Tags
  await p.waitForTimeout(1500);
  await p.mouse.click(1835, 460); // Amber tune icon on GPIO 35
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_06_calibracao_analogica.png` });
  await p.close();

  // 15. Dialog: Configurar Pin GPIO
  console.log('15. dialog_07_configurar_pin_gpio...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20);
  await p.waitForTimeout(800);
  await p.mouse.click(260, 95); // GPIO/Tags
  await p.waitForTimeout(1500);
  await p.mouse.click(500, 160); // Expand MAPA DE PINOS
  await p.waitForTimeout(1000);
  // In the expanded wrap, let's click one of the pin chips (around y=230, x=50)
  await p.mouse.click(80, 230);
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_07_configurar_pin_gpio.png` });
  await p.close();

  // 16. Dialog: Gerador de IHM (.endap-hmi)
  console.log('16. dialog_08_exportar_ihm...');
  p = await initPage(browser);
  await p.mouse.click(930, 20); // HMI
  await p.waitForTimeout(1000);
  await p.mouse.click(1740, 60); // EXPORTAR IHM
  await p.waitForTimeout(1500);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_08_exportar_ihm.png` });
  await p.close();

  // 17. Dialog: Menu de Transporte Rede (ESP-NOW vs Wi-Fi)
  console.log('17. dialog_09_menu_transporte_rede...');
  p = await initPage(browser);
  await p.mouse.click(1030, 20); // Engenharia
  await p.waitForTimeout(800);
  await p.mouse.click(370, 95); // Rede & Topologia
  await p.waitForTimeout(1500);
  await p.mouse.click(1904, 390); // 3 dots on remote node
  await p.waitForTimeout(1000);
  await p.screenshot({ path: `${SCREENSHOT_DIR}/dialog_09_menu_transporte_rede.png` });
  await p.close();

  await browser.close();
  console.log('All 17 captures completed cleanly!');
}

capture().catch(err => {
  console.error('Fatal error during capture:', err);
  process.exit(1);
});
