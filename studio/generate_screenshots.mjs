import { chromium } from 'playwright';
import fs from 'fs';

const BASE_URL = 'http://localhost:8080';
const SCREENSHOTS_DIR = './screenshots';

if (!fs.existsSync(SCREENSHOTS_DIR)){
    fs.mkdirSync(SCREENSHOTS_DIR);
}

const state1 = {
  id: "proj_1",
  name: "Toolbox Completa & Níveis",
  tags: {},
  networks: [
    {
      id: "net_1",
      name: "Rung 1",
      nodes: [],
      connections: []
    }
  ],
  metadata: {}
};

const stateLevel1 = {
  id: "proj_l1",
  name: "Nível 1 - Lógica Booliana & Selo",
  tags: {
    "I0.0": {"id": "I0.0", "name": "I0.0", "type": "bool", "initialValue": {"boolValue": true}},
    "I0.1": {"id": "I0.1", "name": "I0.1", "type": "bool", "initialValue": {"boolValue": false}},
    "Q0.0": {"id": "Q0.0", "name": "Q0.0", "type": "bool", "initialValue": {"boolValue": true}},
    "Q0.1": {"id": "Q0.1", "name": "Q0.1", "type": "bool", "initialValue": {"boolValue": true}}
  },
  networks: [
    {
      id: "net_1",
      name: "Partida Direta com Selo (I0.0 | Q0.0) -> /I0.1/ -> (Q0.0)",
      nodes: [
        {
          "id": "node_par",
          "type": "parallel",
          "config": {},
          "branches": [
            [{"id": "n1", "type": "contactNO", "config": {"tagId": "I0.0"}}],
            [{"id": "n2", "type": "contactNO", "config": {"tagId": "Q0.0"}}]
          ]
        },
        {"id": "n3", "type": "contactNC", "config": {"tagId": "I0.1"}},
        {"id": "n4", "type": "coil", "config": {"tagId": "Q0.0"}}
      ],
      connections: []
    }
  ],
  metadata: {}
};

const stateLevel2 = {
  id: "proj_l2",
  name: "Nível 2 - Temporizadores TON / TOF",
  tags: {
    "Q0.0": {"id": "Q0.0", "name": "Q0.0", "type": "bool", "initialValue": {"boolValue": true}},
    "T0": {"id": "T0", "name": "T0", "type": "timer", "initialValue": {"intValue": 3000}},
    "Q0.2": {"id": "Q0.2", "name": "Q0.2", "type": "bool", "initialValue": {"boolValue": true}}
  },
  networks: [
    {
      id: "net_2",
      name: "Temporização TON 3s para Acionamento de Q0.2",
      nodes: [
        {"id": "n10", "type": "contactNO", "config": {"tagId": "Q0.0"}},
        {"id": "n11", "type": "timerTON", "config": {"tagId": "T0", "presetValue": {"intValue": 3000}}},
        {"id": "n12", "type": "coil", "config": {"tagId": "Q0.2"}}
      ],
      connections: []
    }
  ],
  metadata: {}
};

const stateLevel3 = {
  id: "proj_l3",
  name: "Nível 3 - Contadores & Comparadores",
  tags: {
    "I0.2": {"id": "I0.2", "name": "I0.2", "type": "bool", "initialValue": {"boolValue": true}},
    "C0": {"id": "C0", "name": "C0", "type": "counter", "initialValue": {"intValue": 5}},
    "Q0.3": {"id": "Q0.3", "name": "Q0.3", "type": "bool", "initialValue": {"boolValue": true}}
  },
  networks: [
    {
      id: "net_3",
      name: "Contagem de Peças CTU (Preset=5)",
      nodes: [
        {"id": "n20", "type": "contactNO", "config": {"tagId": "I0.2"}},
        {"id": "n21", "type": "counterCTU", "config": {"tagId": "C0", "presetValue": {"intValue": 5}}},
        {"id": "n22", "type": "coil", "config": {"tagId": "Q0.3"}}
      ],
      connections: []
    }
  ],
  metadata: {}
};

const states = [
  { name: '01-toolbox-completa', data: state1 },
  { name: '02-nivel1-selo-booliano', data: stateLevel1 },
  { name: '03-nivel2-temporizadores', data: stateLevel2 },
  { name: '04-nivel3-contadores', data: stateLevel3 }
];

async function main() {
  const browser = await chromium.launch({
    executablePath: '/snap/bin/chromium',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  for (const state of states) {
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
      deviceScaleFactor: 1.5,
    });
    const page = await context.newPage();
    
    await page.goto(BASE_URL);
    await page.waitForLoadState('networkidle');

    // Clica no centro da tela usando coordenadas relativas do Canvas para simular o toque do usuário
    await page.mouse.click(720, 560);
    await page.waitForTimeout(2000);
    
    await page.evaluate((projectData) => {
      window.localStorage.setItem('flutter.endap_ladder_autosave', JSON.stringify(JSON.stringify(projectData)));
    }, state.data);
    
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3500); 
    
    await page.screenshot({ path: `${SCREENSHOTS_DIR}/${state.name}.png` });
    console.log(`Saved screenshot: ${SCREENSHOTS_DIR}/${state.name}.png`);
    
    await context.close();
  }
  
  await browser.close();
}

main().catch(console.error);
