import { firefox } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const base = process.argv[2] ?? 'http://127.0.0.1:8768/';
const live = process.argv.includes('--live');
const evidence = resolve('../docs/demo/evidence');
await mkdir(evidence, { recursive: true });
const browser = await firefox.launch({ headless: true });
const facts = { base, live, browser: 'Firefox', version: browser.version(), results: [], errors: [] };
function check(condition, name, detail = '') { facts.results.push({ name, pass: Boolean(condition), detail }); if (!condition) throw new Error(`${name}: ${detail}`); }
async function point(page, index) {
  return page.locator('.curved-text text').evaluate((node, index) => {
    const rect = node.getExtentOfChar(index);
    const point = new DOMPoint(rect.x + rect.width / 2, rect.y + rect.height / 2).matrixTransform(node.getScreenCTM());
    return { x: point.x, y: point.y };
  }, index);
}
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, colorScheme: 'light', reducedMotion: 'reduce' });
  const page = await context.newPage();
  page.on('pageerror', error => facts.errors.push(error.message));
  await page.goto(base); await page.evaluate(() => document.fonts.ready); await page.waitForTimeout(150);
  const initial = await page.locator('.curved-text text').textContent();
  for (let index = 3; index <= 20; index++) {
    const p = await point(page, index); await page.mouse.move(p.x, p.y);
    if (index === 3) await page.mouse.down();
  }
  await page.mouse.up();
  const selection = await page.evaluate(() => getSelection()?.toString().trim());
  check(selection && initial.includes(selection), 'native desktop drag selection', selection);
  check(await page.getByRole('button', { name: 'Перевести', exact: false }).isEnabled(), 'translation button enabled');
  await page.screenshot({ path: `${evidence}/desktop-light.png`, fullPage: true });
  if (live) {
    await page.getByRole('button', { name: 'Перевести', exact: false }).click();
    await page.locator('.translation').waitFor({ timeout: 20_000 });
    check(Boolean(await page.locator('.translation').textContent()), 'real selected-fragment translation');
    await page.screenshot({ path: `${evidence}/desktop-result.png`, fullPage: true });
    await page.getByRole('button', { name: 'Закрыть перевод' }).click();
  }
  await page.getByRole('button', { name: 'Свой текст' }).click();
  await page.getByLabel('Ваша фраза на английском').fill('bank');
  await page.getByRole('button', { name: 'Готово' }).click();
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.waitForTimeout(150);
  await page.screenshot({ path: `${evidence}/desktop-dark.png`, fullPage: true });
  await page.getByRole('button', { name: 'Как попробовать перевод?' }).click();
  check(await page.getByText('Выделите мышью слово', { exact: false }).isVisible(), 'FAQ opens');
  await context.close();

  const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile', colorScheme: 'light', reducedMotion: 'reduce' });
  const phone = await mobile.newPage(); phone.on('pageerror', error => facts.errors.push(error.message));
  await phone.goto(base); await phone.evaluate(() => document.fonts.ready);
  const p = await point(phone, 18); await phone.touchscreen.tap(p.x, p.y);
  await phone.waitForTimeout(100);
  check((await phone.locator('.selection-hint').textContent()).startsWith('Выбрано:'), 'mobile tap selection');
  check(await phone.evaluate(() => document.documentElement.scrollWidth <= innerWidth), '390px no horizontal overflow');
  if (live) {
    await phone.getByRole('button', { name: 'Свой текст' }).click(); await phone.getByLabel('Ваша фраза на английском').fill('bank'); await phone.getByRole('button', { name: 'Готово' }).click();
    const word = await point(phone, 1); await phone.touchscreen.tap(word.x, word.y);
    await phone.getByRole('button', { name: 'Перевести', exact: false }).click();
    await phone.locator('.translation').waitFor({ timeout: 20_000 });
    check((await phone.locator('.translation').textContent()).length > 0, 'real mobile word translation');
  }
  await phone.screenshot({ path: `${evidence}/mobile-light.png`, fullPage: true });
  await phone.emulateMedia({ colorScheme: 'dark' });
  await phone.waitForTimeout(150);
  await phone.screenshot({ path: `${evidence}/mobile-dark.png`, fullPage: true });
  await mobile.close();
  check(facts.errors.length === 0, 'no page errors', facts.errors.join('; '));
} finally {
  await browser.close(); await writeFile(`${evidence}/browser-${live ? 'live' : 'local'}.json`, JSON.stringify(facts, null, 2));
}
console.log(JSON.stringify(facts));
