'use strict';

const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');

module.exports = async ({ base, users, password, farmId, crop, arat, batchId }) => {
  const browser = await chromium.launch({
    ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : { channel: 'chrome' }),
    headless: true,
  });
  const errors = [];
  try {
    const routes = {
      FARMER: ['/farmer', '/profile', '/farmer/farms', '/farmer/batches', `/farmer/batches/${batchId}`, '/farmer/orders', '/farmer/payments', '/farmer/storage'],
      BUYER: ['/buyer', '/buyer/browse', `/buyer/batches/${batchId}`, '/buyer/bids', '/buyer/orders', '/buyer/payments', '/buyer/storage', '/buyer/reviews'],
      STORAGE_MANAGER: ['/storage', '/storage/warehouses', '/storage/allocations'],
      TRANSPORT_PERSONNEL: ['/transport'],
      ADMIN: ['/admin', '/admin/users', '/admin/prices', '/admin/complaints', '/admin/reports', '/admin/farm-verifications'],
    };
    for (const [role, paths] of Object.entries(routes)) {
      const context = await browser.newContext();
      context.setDefaultTimeout(10000);
      context.setDefaultNavigationTimeout(15000);
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(`${role}: ${error.message}`));
      page.on('response', response => {
        if (response.url().includes('/api/') && response.status() >= 400) {
          errors.push(`${role}: HTTP ${response.status()} ${new URL(response.url()).pathname}`);
        }
      });
      await page.goto(`${base}/login`);
      await page.getByLabel('Email', { exact: true }).fill(users[role].user.email);
      await page.getByLabel('Password', { exact: true }).fill(password);
      await page.getByRole('button', { name: 'Sign in', exact: true }).click();
      await page.waitForURL(`${base}${paths[0]}`);
      for (const route of paths) {
        console.log(`  Browser checking ${route}`);
        await page.goto(base + route);
        await page.waitForLoadState('networkidle');
        assert.equal(new URL(page.url()).pathname, route);
        assert(await page.locator('h1').count(), `${route}: heading missing`);
        assert.equal(await page.locator('.error').count(), 0, `${route}: visible error`);
      }
      if (role === 'FARMER') {
        await page.goto(`${base}/farmer/batches/new`);
        await page.getByLabel(/^Farm \*/).selectOption(String(farmId));
        await page.getByLabel(/^Crop \*/).selectOption(String(crop.CROPID));
        const price = page.getByLabel(/Minimum price/);
        assert.equal(await price.getAttribute('min'), String(crop.BASEPRICE));
        assert.match(await page.locator('body').innerText(), /base price/i);
        await page.getByLabel(/Sell through ARAT/).selectOption(String(arat.ARATID));
        await page.getByLabel(/Harvest date/).fill(new Date().toISOString().slice(0, 10));
        await page.getByLabel(/Total quantity/).fill('100');
        await price.fill(String(crop.BASEPRICE));
        await page.getByLabel(/Minimum bid quantity/).fill('10');
        await page.getByRole('button', { name: /Create batch/i }).click();
        await page.waitForURL(/\/farmer\/batches\/\d+$/);
        const start = new Date(Date.now() + 3600000).toISOString().slice(0, 16);
        const end = new Date(Date.now() + 86400000).toISOString().slice(0, 16);
        await page.getByLabel(/Bidding opens/).fill(start);
        await page.getByLabel(/Bidding closes/).fill(end);
        await page.getByRole('button', { name: /List batch/i }).click();
        await page.getByText('Batch listed.', { exact: false }).waitFor();
        assert.equal(await page.locator('.error').count(), 0);
      }
      console.log(`  Browser: ${role} screens passed`);
      await context.close();
    }
    const publicPage = await browser.newPage();
    await publicPage.goto(`${base}/register`);
    assert(await publicPage.locator('form').count());
    assert.deepEqual(errors, []);
  } finally { await browser.close(); }
};
