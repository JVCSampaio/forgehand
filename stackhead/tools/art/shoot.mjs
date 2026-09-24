// Renders marketing art from tools/art/art.html in headless Chromium.
//   node tools/art/shoot.mjs http://localhost:8124 build/art/out
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(`${execSync('npm root -g').toString().trim()}/playwright`); }
const { chromium } = playwright;

const base = process.argv[2] ?? 'http://localhost:8124';
const out = process.argv[3] ?? 'build/art/out';
const only = (process.env.SHOTS ?? 'tower crash icon panels').split(' ');
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

async function shot(query, file, width, height) {
  const page = await browser.newPage({ viewport: { width, height } });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.log('console:', m.text()); });
  await page.goto(`${base}/art.html?${query}`);
  await page.waitForFunction(() => document.title === 'ready', null, { timeout: 600000 });
  await page.waitForTimeout(300);
  await page.screenshot({ path: `${out}/${file}` });
  await page.close();
  console.log('rendered', file);
}

if (only.includes('tower')) await shot('shot=tower', 'thumbnail-tower.png', 1920, 1080);
if (only.includes('crash')) await shot('shot=crash', 'thumbnail-crash.png', 1920, 1080);
if (only.includes('icon')) await shot('shot=icon', 'icon-1024.png', 1024, 1024);
if (only.includes('gallery')) {
  for (let t = 1; t <= 16; t += 2) await shot(`shot=gallery&sharp=1&from=${t}&to=${t + 1}`, `gallery-${t}-${t + 1}.png`, 1920, 1080);
  await shot('shot=gallery&sharp=1&meme=1', 'gallery-memes.png', 1920, 1080);
}
if (only.includes('panels')) {
  for (const w of ['Stackville', 'Frostpeak', 'CandyCoast', 'NeonCity']) await shot(`shot=panel&world=${w}`, `panel-${w}.png`, 1920, 1080);
}
if (only.includes('worlds')) {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto(`${base}/composite.html`);
  await page.waitForFunction(() => document.title === 'ready', null, { timeout: 60000 });
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/thumbnail-worlds.png` });
  console.log('rendered thumbnail-worlds.png');
}
// Roblox wants 512x512 icons; render big, downscale for clean edges.
if (only.includes('icon')) {
  const page = await browser.newPage({ viewport: { width: 512, height: 512 } });
  await page.setContent(`<body style="margin:0"><img src="${base}/out/icon-1024.png" style="width:512px;height:512px;display:block"></body>`);
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${out}/icon-512.png` });
  console.log('rendered icon-512.png');
}
await browser.close();
