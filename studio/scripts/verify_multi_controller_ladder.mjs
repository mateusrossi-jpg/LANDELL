import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const OUT_DIR = '/home/mateus/.gemini/antigravity-cli/brain/52b6caeb-2448-4662-8c57-10ba219cdbbd';

async function verifyMultiController() {
  console.log('=== [ENDAP STUDIO] VERIFICAÇÃO VISUAL: MULTI-CONTROLADOR & LADDER DISTRIBUÍDO ===');

  const browser = await chromium.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1.0,
  });

  const page = await context.newPage();

  // 1. Inicia sessão limpa
  await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => {
    localStorage.setItem('flutter.endap_session_active', 'true');
    localStorage.setItem('flutter.endap_session_user', '"ADMIN"');
    localStorage.setItem('flutter.endap_session_role', '"INTEGRADOR"');
    localStorage.removeItem('endap_ladder_autosave');
  });
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);

  // 2. Abre Drawer e vai para Ladder IEC
  console.log('Navegando para Lógica Ladder IEC...');
  await page.mouse.click(26, 26);
  await page.waitForTimeout(800);
  await page.mouse.click(120, 185);
  await page.waitForTimeout(2500);

  // 3. Captura Visão Global (Planta Completa) com Filtros e Badges
  console.log('Capturando Tela 1: Visão Geral de Planta (Todos os Controladores)...');
  await page.screenshot({ path: `${OUT_DIR}/ladder_multi_controller_global_view.png` });

  // 4. Clica no filtro Gateway (posição aproximada no strip de filtros x ~140, y ~110)
  console.log('Filtrando por Gateway...');
  // Procura elemento ou clica no chip Gateway
  await page.mouse.click(150, 110);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/ladder_multi_controller_gateway_view.png` });

  // 5. Clica no filtro Nó 01 (x ~220, y ~110)
  console.log('Filtrando por Nó 01...');
  await page.mouse.click(230, 110);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/ladder_multi_controller_node1_view.png` });

  // 6. Volta para Todos e clica no Badge do Controlador no Rung 1 para abrir diálogo de reatribuição/clonagem
  console.log('Abrindo diálogo de Reatribuição / Clonagem do Rung...');
  await page.mouse.click(80, 110); // Volta para Todos
  await page.waitForTimeout(1000);

  // Clica no badge do controlador do primeiro rung (canto superior direito do primeiro rung, x ~1300, y ~250)
  // Ou clica perto da barra de ações do rung
  await page.mouse.click(1260, 248);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: `${OUT_DIR}/ladder_multi_controller_dialog.png` });

  await browser.close();
  console.log('=== VERIFICAÇÃO VISUAL CONCLUÍDA COM SUCESSO! ===');
}

verifyMultiController().catch(err => {
  console.error('Erro na verificação:', err);
  process.exit(1);
});
