'use strict';

// Opens an unpaid sandbox session only. No database writes or real charges.
const assert = require('node:assert/strict');
const { sslcommerz, clientOrigin, port } = require('../config/env');

async function main() {
  assert(sslcommerz.enabled, 'Configure the SSLCommerz sandbox credentials first.');
  assert(sslcommerz.sandbox, 'Refusing to test against the live payment gateway.');
  const callback = `http://localhost:${port}/api/payments/sslcommerz`;
  const response = await fetch(`${sslcommerz.baseUrl}/gwprocess/v4/api.php`, {
    method: 'POST', signal: AbortSignal.timeout(20000),
    body: new URLSearchParams({ store_id: sslcommerz.storeId, store_passwd: sslcommerz.storePassword,
      total_amount: '10.00', currency: 'BDT', tran_id: `QA-${Date.now()}`,
      success_url: `${callback}/success`, fail_url: `${callback}/fail`, cancel_url: `${callback}/cancel`,
      product_name: 'Unpaid sandbox connectivity test', product_category: 'Agriculture', product_profile: 'physical-goods',
      cus_name: 'Sandbox Tester', cus_email: 'sandbox@example.invalid', cus_add1: 'Mirpur', cus_city: 'Dhaka',
      cus_country: 'Bangladesh', cus_phone: '01700000000', shipping_method: 'NO', num_of_item: '1',
    }),
  });
  assert(response.ok, `Gateway HTTP ${response.status}`);
  const result = await response.json();
  assert(result.status === 'SUCCESS' && result.GatewayPageURL, 'Sandbox rejected session initialization. Check credentials.');
  assert.equal(new URL(result.GatewayPageURL).protocol, 'https:');
  console.log('PASS: real SSLCommerz sandbox accepted the credentials and opened an unpaid BDT session.');
  if (process.argv.includes('--browser')) {
    const { chromium } = require('playwright-core');
    const browser = await chromium.launch({ ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : { channel: 'chrome' }), headless: true });
    try {
      const page = await browser.newPage();
      const checkout = await page.goto(result.GatewayPageURL, { waitUntil: 'domcontentloaded', timeout: 30000 });
      assert(checkout && checkout.ok(), 'Hosted checkout did not load');
      await page.locator('body').waitFor();
      console.log(`PASS: hosted checkout loaded (${await page.title()}). No payment submitted.`);
    } finally { await browser.close(); }
  }
  console.log(`Still required: complete a sandbox payment through the app at ${clientOrigin} and verify its return. This connectivity test is not an order/payment record.`);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
