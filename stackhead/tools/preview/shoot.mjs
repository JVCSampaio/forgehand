// Renders each preview view in headless Chromium and saves PNGs.
//   node tools/preview/shoot.mjs http://localhost:8123 build/preview/shots
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

// Works with a local or a global playwright install.
const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); } catch { playwright = require(`${execSync('npm root -g').toString().trim()}/playwright`); }
const { chromium } = playwright;

const base = process.argv[2] ?? 'http://localhost:8123';
const out = process.argv[3] ?? 'build/preview/shots';
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', (m) => { if (m.type() === 'error') console.log('console:', m.text()); });
page.on('pageerror', (e) => console.log('pageerror:', e.message));
for (const view of ['overview', 'gameplay', 'tower', 'bank', 'collapse']) {
  await page.goto(`${base}/index.html?view=${view}`);
  await page.waitForFunction(() => document.title === 'ready', null, { timeout: 180000 });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  await page.screenshot({ path: `${out}/${view}.png` });
  console.log('shot', view);
}
await browser.close();
