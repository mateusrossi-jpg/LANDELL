import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/52b6caeb-2448-4662-8c57-10ba219cdbbd';

async function runTonValidation() {
  console.log('=== [ENDAP STUDIO] VALIDACAO HUMANA DOM: TEMPORIZADOR TON & DEMO COMPONENTES ===');

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });

  const page = await context.newPage();

  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      if (!text.includes('favicon.ico') && !text.includes('Failed to load resource')) {
        console.warn(`  [CONSOLE ERROR] ${text.slice(0, 150)}`);
      }
    }
  });

  // 1. Configura sessao limpa de Integrador e carrega DemoProject
  console.log('1. Carregando aplicacao com DemoProject completo...');
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"ADMIN"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.removeItem('endap_ladder_autosave');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 2. Abre Drawer e clica em "Logica Ladder IEC" (item 1)
  console.log('2. Navegando para Lógica Ladder IEC via Drawer...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  // Item 1 "Lógica Ladder IEC" esta em y ~185 no drawer
  await page.mouse.click(120, 185);
  await page.waitForTimeout(2000);

  // Fecha o terminal inferior se estiver aberto para liberar visibilidade total
  await page.mouse.click(1420, 700);
  await page.waitForTimeout(500);

  // 3. Rola a tela para baixo ate o Rung 6 (TON T0)
  console.log('3. Rolando viewport para focar no Rung 6 (Temporizador TON)...');
  await page.mouse.move(700, 450);
  await page.mouse.wheel(0, 680);
  await page.waitForTimeout(1000);

  // 4. Captura Estado Inicial 1 (Repouso: I0.4 aberto, TON desenergizado, Q0.3 desligado)
  console.log('4. Capturando Estado 1: Repouso inicial (ET:0.0s, Q0.3 desligado)...');
  await page.screenshot({ path: `${OUT_DIR}/ton_state_1_initial.png` });

  // 5. Clica no Contato I0.4 para ligar a chave retentiva
  // No Rung 6, o contato I0.4 fica aproximadamente em x: 140, y: 375
  console.log('5. Clicando no contato I0.4 para energizar o temporizador TON...');
  // Movemos e clicamos no contato I0.4
  await page.mouse.click(140, 385);
  await page.waitForTimeout(100);

  // 6. Aguarda 1.5s (metade do preset de 3.0s) e captura Estado 2 (Em temporizacao ativa)
  console.log('6. Aguardando 1.5s de contagem...');
  await page.waitForTimeout(1500);
  console.log('7. Capturando Estado 2: Temporizacao ativa (ET ~1.5s, barra e borda ativas, Q0.3 desligado)...');
  await page.screenshot({ path: `${OUT_DIR}/ton_state_2_timing.png` });

  // 7. Aguarda mais 2.0s (total 3.5s > 3.0s preset) e captura Estado 3 (Preset concluído, Q0.3 ativado)
  console.log('8. Aguardando conclusao do preset (total >3.0s)...');
  await page.waitForTimeout(2000);
  console.log('9. Capturando Estado 3: Preset atingido (DN=true, Q0.3 ligado em verde luminoso!)...');
  await page.screenshot({ path: `${OUT_DIR}/ton_state_3_done_active.png` });

  // 8. Clica no contato I0.4 para abrir a chave e desenergizar o circuito
  console.log('10. Clicando em I0.4 para abrir a entrada e resetar o temporizador...');
  await page.mouse.click(140, 385);
  await page.waitForTimeout(400);
  console.log('11. Capturando Estado 4: Reset instantâneo (ET:0.0s, Q0.3 desativado)...');
  await page.screenshot({ path: `${OUT_DIR}/ton_state_4_reset_cleared.png` });

  // 9. Rola mais um pouco para capturar os Rungs 8 (TOF) e 9 (CTU) da nova demo
  console.log('12. Rolando para baixo para visualizar Rung 8 (TOF) e Rung 9 (CTU)...');
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/ton_state_5_demo_tof_ctu.png` });

  console.log('=== VALIDACAO CONCLUIDA COM SUCESSO! Screenshots geradas no artifact dir. ===');
  await browser.close();
}

runTonValidation().catch(err => {
  console.error('ERRO NA VALIDACAO HUMANA:', err);
  process.exit(1);
});
