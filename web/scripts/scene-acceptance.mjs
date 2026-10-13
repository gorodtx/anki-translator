import http from 'node:http';
import path from 'node:path';
import { readFile, writeFile } from 'node:fs/promises';
import { chromium } from '@playwright/test';

const local = process.argv.includes('--local');
const base = local ? 'http://127.0.0.1:8768/preview/' : process.argv[2];
const dist = path.resolve('dist');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.png': 'image/png', '.svg': 'image/svg+xml' };
let server;
if (local) {
  server = http.createServer(async (request, response) => {
    try {
      let name = new URL(request.url, 'http://local').pathname.replace(/^\/preview\//, '/');
      if (name === '/') name = '/index.html';
      const file = path.resolve(dist, `.${name}`);
      if (!file.startsWith(`${dist}/`)) throw new Error('outside preview');
      response.setHeader('Content-Type', types[path.extname(file)] ?? 'application/octet-stream');
      response.end(await readFile(file));
    } catch { response.writeHead(404); response.end(); }
  });
  await new Promise(resolve => server.listen(8768, '127.0.0.1', resolve));
}
const browser = await chromium.launch({ headless: true });
try {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, reducedMotion: 'no-preference', colorScheme: 'light', userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/156.0 Safari/537.36' });
  await context.addInitScript(() => Object.defineProperty(navigator, 'platform', { value: 'Linux x86_64' }));
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(base);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(100);
  const before = await page.locator('.curved-text text').boundingBox();
  await page.waitForTimeout(900);
  const after = await page.locator('.curved-text text').boundingBox();
  const details = await page.evaluate(() => {
    const canvas = document.querySelector('canvas.cloud-canvas');
    return { pixels: canvas.width * canvas.height, fontLoaded: document.fonts.check('16px Montserrat') };
  });
  const linux = await page.getByRole('link', { name: 'GNOME / Arch Linux', exact: true }).first().getAttribute('href');
  const facts = { base, browser: browser.version(), normalMotion: true, staticText: JSON.stringify(before) === JSON.stringify(after), linux, details, errors };
  if (!facts.staticText || details.pixels > 900000 || !details.fontLoaded || !linux.includes('/tree/gnome') || errors.length) throw new Error(JSON.stringify(facts));
  await page.screenshot({ path: `../docs/demo/evidence/scene-${local ? 'subpath' : 'public'}.png`, fullPage: true });
  await writeFile(`../docs/demo/evidence/scene-${local ? 'subpath' : 'public'}.json`, JSON.stringify(facts, null, 2));
  console.log(JSON.stringify(facts));
  await context.close();
} finally { await browser.close(); server?.close(); }
