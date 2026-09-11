'use strict';

// Real Oracle SQL, routes and triggers; all fixture DML is rolled back.
// The payment provider is mocked: this is NOT proof of a hosted sandbox payment.
const assert = require('node:assert/strict');
const { once } = require('node:events');
const oracledb = require('oracledb');
const db = require('../src/config/db');
const env = require('../src/config/env');

async function main() {
  await db.initialize();
  const pool = db.getPool();
  const borrow = pool.getConnection.bind(pool);
  const connection = await borrow();
  const execute = connection.execute.bind(connection);
  let server;
  let checks = 0;
  let savepoint = 0;
  let fault = null;
  const realFetch = global.fetch;
  const prefix = `qa${Date.now()}`;
  const password = 'Workflow-test-2026!';
  const users = {};
  let validation = {};
  let gatewayFailure = false;
  const sessions = new Map();
  const originalTransaction = db.withTransaction;

  // Keep the production cursor reader and query helper, but close/commit nothing.
  const sandboxConnection = {
    execute: async (sql, binds = {}, options = {}) => {
      assert(!/^\s*(CREATE|ALTER|DROP|TRUNCATE|COMMIT)\b/i.test(sql), 'No DDL or commit in tests');
      if (fault && fault.test(sql)) throw new Error('Injected workflow failure');
      return execute(sql, binds, { ...options, autoCommit: false });
    },
    executeMany: (sql, binds, options = {}) => connection.executeMany(sql, binds, { ...options, autoCommit: false }),
    close: async () => {},
  };
  pool.getConnection = async () => sandboxConnection;
  db.withTransaction = async (work) => {
    const name = `qa_${++savepoint}`;
    await execute(`SAVEPOINT ${name}`);
    try { return await work(sandboxConnection); }
    catch (error) { await execute(`ROLLBACK TO ${name}`); throw error; }
  };

  // No real provider requests or charges, even if live credentials are configured.
  env.sslcommerz.storeId = 'workflow-mock';
  env.sslcommerz.storePassword = 'workflow-mock';
  env.sslcommerz.sandbox = true;
  global.fetch = async (url, options) => {
    if (String(url).startsWith(env.sslcommerz.baseUrl)) {
      if (String(url).includes('/gwprocess/')) {
        if (gatewayFailure) throw new Error('Simulated gateway unavailable');
        const form = options.body;
        sessions.set(form.get('tran_id'), Object.fromEntries(form));
        return Response.json({ status: 'SUCCESS', GatewayPageURL: 'https://example.invalid/mock-checkout' });
      }
      return Response.json(validation);
    }
    return realFetch(url, options);
  };

  async function check(name, work) {
    await work();
    console.log(`PASS ${++checks}: ${name}`);
  }
  async function row(sql, binds = {}) { return (await execute(sql, binds)).rows[0]; }
  async function insert(sql, binds = {}) {
    const result = await execute(sql, { ...binds, id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER } });
    return result.outBinds.id[0];
  }

  try {
    // Do not even temporarily expire another user's checkout while testing.
    require('../src/services/checkoutReservations').releaseAbandoned = async () => 0;
    const auth = require('../src/services/auth.service');
    const farmer = require('../src/services/farmer.service');
    const gateway = require('../src/services/sslcommerz.service');
    const app = require('../src/app');
    const express = require('express');
    const path = require('node:path');
    const web = express();
    web.use((req, res, next) => req.path.startsWith('/api/') ? app(req, res, next) : next());
    web.use(express.static(path.resolve(__dirname, '../../client/dist')));
    web.get('/{*path}', (_req, res) => res.sendFile(path.resolve(__dirname, '../../client/dist/index.html')));
    server = web.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}/api`;
    async function api(role, path, method = 'GET', body, expected = 200) {
      const response = await fetch(base + path, {
        method,
        headers: { 'Content-Type': 'application/json', ...(users[role] ? { Authorization: `Bearer ${users[role].token}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const data = await response.json();
      assert.equal(response.status, expected, `${method} ${path}: ${JSON.stringify(data)}`);
      return data;
    }
    const post = (role, path, body, expected = 200) => api(role, path, 'POST', body, expected);
    const patch = (role, path, body, expected = 200) => api(role, path, 'PATCH', body, expected);
    async function validCallback(session, overrides = {}) {
      validation = { status: 'VALID', tran_id: session.transactionId, amount: session.amount,
        currency: 'BDT', currency_type: 'BDT', currency_amount: session.amount, ...overrides };
      return gateway.completeCheckout({ tran_id: session.transactionId, val_id: 'mock-validation' });
    }

    await check('all five roles register, log in and load their profiles', async () => {
      for (const [i, role] of auth.ROLES.entries()) {
        const payload = { firstName: 'Workflow', lastName: role, email: `${prefix}.${role}@example.invalid`,
          password, gender: 'O', dateOfBirth: '1995-01-01', district: 'Dhaka', upazila: 'Mirpur',
          phones: [`${prefix}${i}`], role, nid: `${prefix}${i}`, employeeId: `${prefix}${i}`,
          licenseNo: `${prefix}${i}`, designation: 'Officer', buyerType: 'WHOLESALER' };
        await auth.register(payload, { allowStaffRoles: true });
        users[role] = await post(null, '/auth/login', { email: payload.email, password });
        await api(role, '/auth/me');
      }
    });
    await check('role boundaries and unauthenticated access', async () => {
      await api(null, '/farmer/orders', 'GET', null, 401);
      await api('BUYER', '/admin/users', 'GET', null, 403);
    });
    await check('late registration failure rolls back the user and subclass', async () => {
      const email = `${prefix}.duplicate@example.invalid`;
      await assert.rejects(auth.register({ firstName: 'Duplicate', lastName: 'Phone', email,
        password, gender: 'O', dateOfBirth: '1995-01-01', district: 'Dhaka', upazila: 'Mirpur',
        role: 'FARMER', nid: `${prefix}dup`, phones: [`${prefix}0`] }), /phone number/i);
      assert.equal((await row('SELECT COUNT(*) AS N FROM USERS WHERE Email = :email', { email })).N, 0);
    });

    const crop = await row('SELECT CropID, BasePrice FROM CROP WHERE ROWNUM = 1');
    const arat = await row('SELECT AratID FROM VIRTUAL_ARAT WHERE ROWNUM = 1');
    assert(crop && arat, 'At least one reference crop and arat must exist');
    const { farmId } = await post('FARMER', '/farmer/farms', { farmName: prefix, area: 10, district: 'Dhaka', location: 'Mirpur' }, 201);
    const makeBatch = (extra = {}) => post('FARMER', '/farmer/batches', { farmId, cropId: crop.CROPID,
      aratId: arat.ARATID, harvestDate: new Date().toISOString().slice(0, 10), totalQuantity: 100,
      minimumPrice: crop.BASEPRICE, minimumBidQuantity: 10, ...extra }, 201);
    const window = { biddingStartTime: new Date(Date.now() - 86400000).toISOString(),
      biddingEndTime: new Date(Date.now() + 86400000).toISOString() };
    let batchId;
    await check('draft creation, validation, publishing, ownership and repeat protection', async () => {
      ({ batchId } = await makeBatch());
      assert.equal((await api('FARMER', `/farmer/batches/${batchId}`)).status, 'CREATED');
      await patch('FARMER', `/farmer/batches/${batchId}/listing`, {}, 400);
      await assert.rejects(farmer.scheduleBatch(-1, batchId, window), /No such batch/);
      await patch('FARMER', `/farmer/batches/${batchId}/listing`, window);
      await patch('FARMER', `/farmer/batches/${batchId}/listing`, window, 422);
      assert((await api('BUYER', '/buyer/batches')).some(b => b.batchId === batchId));
    });
    await check('base-price guard applies to SQL inserts as well as the UI', async () => {
      await assert.rejects(execute('UPDATE HARVEST_BATCH SET MinimumPrice = :price WHERE BatchID = :batchId',
        { price: crop.BASEPRICE / 2, batchId }), /ORA-20/);
    });
    await check('direct SQL bid guards and email normalization', async () => {
      await assert.rejects(execute(`INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity)
        VALUES (seq_bid_id.NEXTVAL, :batchId, :buyerId, :price, 100)`,
      { batchId, buyerId: users.BUYER.user.userId, price: crop.BASEPRICE / 2 }), /ORA-20022/);
      const id = users.FARMER.user.userId;
      await execute('UPDATE USERS SET Email = :email WHERE UserID = :id', { id, email: `  ${users.FARMER.user.email.toUpperCase()}  ` });
      assert.equal((await row('SELECT Email FROM USERS WHERE UserID = :id', { id })).EMAIL, users.FARMER.user.email);
    });
    const bidPayload = { batchId, bidPricePerKg: crop.BASEPRICE + 1, requestedQuantity: 100 };
    let bid;
    await check('bid quantity/price checks and farmer notification', async () => {
      await post('BUYER', '/buyer/bids', { ...bidPayload, requestedQuantity: 101 }, 422);
      await post('BUYER', '/buyer/bids', { ...bidPayload, bidPricePerKg: crop.BASEPRICE / 2 }, 422);
      bid = await post('BUYER', '/buyer/bids', bidPayload, 201);
      const notifications = await api('FARMER', '/notifications');
      assert(notifications.unreadCount > 0);
      const id = notifications.notifications[0].notificationId;
      await post('BUYER', `/notifications/${id}/read`, {}, 404);
      await post('FARMER', `/notifications/${id}/read`, {});
    });
    await check('late award failure rolls back bid, batch, order and transport', async () => {
      fault = /INSERT INTO TRANSPORT_REQUEST/i;
      try { await assert.rejects(farmer.awardBid(users.FARMER.user.userId, bid.bidId), /Injected/); }
      finally { fault = null; }
      assert.equal((await row('SELECT Status FROM BID WHERE BidID = :id', { id: bid.bidId })).STATUS, 'ACTIVE');
      assert.equal((await row('SELECT SoldQuantity FROM HARVEST_BATCH WHERE BatchID = :id', { id: batchId })).SOLDQUANTITY, 0);
      assert.equal((await row('SELECT COUNT(*) AS N FROM SALE_ORDER WHERE BidID = :id', { id: bid.bidId })).N, 0);
    });
    const order = await post('FARMER', `/farmer/bids/${bid.bidId}/award`, { paymentTerms: 'ADVANCE' }, 201);
    await check('duplicate awards and invalid transport transitions are rejected', async () => {
      await post('FARMER', `/farmer/bids/${bid.bidId}/award`, {}, 422);
      await assert.rejects(execute("UPDATE TRANSPORT_REQUEST SET DeliveryStatus = 'DELIVERED' WHERE TransportID = :id",
        { id: order.transportId }), /ORA-20/);
    });
    await post('BUYER', `/buyer/orders/${order.saleOrderId}/delivery-preference`, {});
    const vehicleId = await insert(`INSERT INTO VEHICLE (VehicleID, VehicleNo, Capacity)
      VALUES (seq_vehicle_id.NEXTVAL, :name, 1000) RETURNING VehicleID INTO :id`, { name: prefix });
    const deliver = async (transportId) => {
      await post('TRANSPORT_PERSONNEL', '/transport/assignments', { transportId, vehicleId }, 201);
      await post('TRANSPORT_PERSONNEL', `/transport/assignments/${transportId}/advance`, {});
      await post('TRANSPORT_PERSONNEL', `/transport/assignments/${transportId}/advance`, {});
      return post('TRANSPORT_PERSONNEL', `/transport/assignments/${transportId}/deliver`, {});
    };
    async function assertRecipients(transportId, roles) {
      const result = await execute(`SELECT DISTINCT UserID FROM NOTIFICATION
        WHERE RelatedEntityType = 'TRANSPORT_REQUEST' AND RelatedEntityID = :id`, { id: transportId });
      assert.deepEqual(result.rows.map(r => r.USERID).sort((a, b) => a - b),
        roles.map(role => users[role].user.userId).sort((a, b) => a - b));
    }
    let saleSession;
    await check('sale checkout reserves once, rejects tiny/over payments and validates identity/currency/amount', async () => {
      const path = `/buyer/orders/${order.saleOrderId}/pay/online`;
      await post('BUYER', path, { amount: 0.001 }, 400);
      await post('BUYER', path, { amount: order.totalAmount + 1 }, 422);
      saleSession = await post('BUYER', path, {});
      assert.equal(sessions.get(saleSession.transactionId).currency, 'BDT');
      assert.equal(Number(sessions.get(saleSession.transactionId).total_amount), saleSession.amount);
      await post('BUYER', path, {}, 422);
      for (const [overrides, reason] of [[{ tran_id: 'another-payment' }, 'transaction-mismatch'],
        [{ currency_type: 'USD' }, 'currency-mismatch'], [{ amount: 1 }, 'amount-mismatch']]) {
        assert.equal((await validCallback(saleSession, overrides)).reason, reason);
        assert.equal((await row('SELECT PaymentStatus FROM PAYMENT WHERE TransactionReference = :ref',
          { ref: saleSession.transactionId })).PAYMENTSTATUS, 'PENDING');
      }
      assert((await validCallback(saleSession)).settled);
      assert((await validCallback(saleSession, { status: 'VALIDATED' })).alreadySettled);
      assert.notEqual((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: order.saleOrderId })).STATUS, 'COMPLETED');
    });
    await check('sale delivery, two-party transport notifications and completed-order review', async () => {
      await post('BUYER', '/buyer/reviews', { saleOrderId: order.saleOrderId, rating: 5 }, 422);
      await deliver(order.transportId);
      assert.equal((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: order.saleOrderId })).STATUS, 'COMPLETED');
      await assertRecipients(order.transportId, ['FARMER', 'BUYER']);
      await post('BUYER', '/buyer/reviews', { saleOrderId: order.saleOrderId, rating: 5, reviewComment: 'Workflow test' }, 201);
    });
    await check('pending sale sessions never complete a delivered order; partial callbacks settle independently', async () => {
      const batch = await makeBatch(window);
      const b = await post('BUYER', '/buyer/bids', { ...bidPayload, batchId: batch.batchId }, 201);
      const o = await post('FARMER', `/farmer/bids/${b.bidId}/award`, { paymentTerms: 'ADVANCE' }, 201);
      await post('BUYER', `/buyer/orders/${o.saleOrderId}/delivery-preference`, {});
      const a = await post('BUYER', `/buyer/orders/${o.saleOrderId}/pay/online`, { amount: o.totalAmount / 2 });
      const bSession = await post('BUYER', `/buyer/orders/${o.saleOrderId}/pay/online`, {});
      assert.notEqual((await deliver(o.transportId)).orderStatus, 'COMPLETED');
      await validCallback(a);
      assert.notEqual((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: o.saleOrderId })).STATUS, 'COMPLETED');
      await validCallback(bSession);
      assert.equal((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: o.saleOrderId })).STATUS, 'COMPLETED');
    });
    await check('cash on delivery remains available with ON_DELIVERY terms', async () => {
      const batch = await makeBatch(window);
      const b = await post('BUYER', '/buyer/bids', { ...bidPayload, batchId: batch.batchId }, 201);
      const o = await post('FARMER', `/farmer/bids/${b.bidId}/award`, { paymentTerms: 'ON_DELIVERY' }, 201);
      await post('BUYER', `/buyer/orders/${o.saleOrderId}/delivery-preference`, {});
      await post('BUYER', `/buyer/orders/${o.saleOrderId}/pay/online`, {}, 422);
      const delivered = await deliver(o.transportId);
      assert.equal(delivered.payment.method, 'CASH');
      assert.equal(delivered.payment.amount, o.totalAmount);
      assert.equal(delivered.orderStatus, 'COMPLETED');
    });
    await check('farm verification waitlist, approval and notification', async () => {
      assert((await api('ADMIN', '/admin/farm-verifications')).some(f => f.farmId === farmId));
      await patch('ADMIN', `/admin/farm-verifications/${farmId}`, { decision: 'VERIFIED' });
      assert.equal((await row('SELECT VerificationStatus FROM FARM WHERE FarmID = :id', { id: farmId })).VERIFICATIONSTATUS, 'VERIFIED');
      assert.equal((await row(`SELECT COUNT(*) AS N FROM NOTIFICATION WHERE Type = 'FARM_VERIFICATION'
        AND RelatedEntityID = :id AND UserID = :farmerId`, { id: farmId, farmerId: users.FARMER.user.userId })).N, 1);
    });
    const { warehouseId } = await post('STORAGE_MANAGER', '/storage/warehouses', {
      warehouseName: prefix, district: 'Dhaka', address: 'Mirpur', capacity: 1000, storageFeePerKgRate: 2 }, 201);
    const { unitNo } = await post('STORAGE_MANAGER', `/storage/warehouses/${warehouseId}/units`, { locationTag: 'Mirpur 12', capacity: 1000 }, 201);
    for (const role of ['FARMER', 'BUYER']) {
      await check(`${role.toLowerCase()} storage negotiation, inbound arrival, online fee and release`, async () => {
        const storageBatch = await makeBatch(role === 'BUYER' ? window : {});
        let storageOrder;
        if (role === 'BUYER') {
          const b = await post('BUYER', '/buyer/bids', { ...bidPayload, batchId: storageBatch.batchId }, 201);
          storageOrder = await post('FARMER', `/farmer/bids/${b.bidId}/award`, { paymentTerms: 'ADVANCE' }, 201);
          const advance = await post('BUYER', `/buyer/orders/${storageOrder.saleOrderId}/pay/online`, {});
          await validCallback(advance);
          assert.notEqual((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: storageOrder.saleOrderId })).STATUS, 'COMPLETED');
        }
        const path = `/${role.toLowerCase()}/storage`;
        const { allocationId } = await post(role, `${path}/requests`, { warehouseId, unitNo, quantityStored: 100,
          minimumStorageDays: 1, ...(storageOrder ? { saleOrderId: storageOrder.saleOrderId } : { batchId: storageBatch.batchId }) }, 201);
        await post('STORAGE_MANAGER', `/storage/requests/${allocationId}/respond`, { decision: 'COUNTER', counterRatePerKg: 1 });
        assert.equal((await post(role, `${path}/${allocationId}/counter/respond`, { decision: 'ACCEPT' })).status, 'IN_TRANSIT');
        const allocation = await row('SELECT DateIn, RequestedByBuyerID FROM STORES WHERE AllocationID = :id', { id: allocationId });
        assert.equal(allocation.DATEIN, null);
        assert.equal(allocation.REQUESTEDBYBUYERID, role === 'BUYER' ? users.BUYER.user.userId : null);
        const trip = await row('SELECT TransportID FROM TRANSPORT_REQUEST WHERE AllocationID = :id', { id: allocationId });
        await assert.rejects(execute("UPDATE STORES SET AllocationStatus = 'COMPLETED' WHERE AllocationID = :id",
          { id: allocationId }), /ORA-20/);
        await post(role, `${path}/${allocationId}/pay/online`, {}, 422);
        await deliver(trip.TRANSPORTID);
        if (storageOrder) assert.equal((await row('SELECT Status FROM SALE_ORDER WHERE SaleOrderID = :id', { id: storageOrder.saleOrderId })).STATUS, 'COMPLETED');
        await assertRecipients(trip.TRANSPORTID, role === 'BUYER' ? ['FARMER', 'BUYER', 'STORAGE_MANAGER'] : ['FARMER', 'STORAGE_MANAGER']);
        assert.equal((await row('SELECT AllocationStatus FROM STORES WHERE AllocationID = :id', { id: allocationId })).ALLOCATIONSTATUS, 'ACTIVE');
        if (role === 'FARMER') await patch(role, `/farmer/batches/${storageBatch.batchId}/listing`, window);
        gatewayFailure = true;
        try { await assert.rejects(gateway.beginStorageCheckout(role, users[role].user.userId, allocationId), /unavailable/); }
        finally { gatewayFailure = false; }
        let session = await post(role, `${path}/${allocationId}/pay/online`, {});
        const cancelled = await gateway.abandonCheckout({ tran_id: session.transactionId }, 'cancelled');
        assert(gateway.resultRedirect(cancelled).includes(`${path}?status=failed`));
        session = await post(role, `${path}/${allocationId}/pay/online`, {});
        await post(role, `${path}/${allocationId}/release`, {});
        await post('STORAGE_MANAGER', `/storage/allocations/${allocationId}/release/respond`, { decision: 'APPROVE' }, 422);
        const result = await validCallback(session);
        assert(result.settled);
        assert(gateway.resultRedirect(result).includes(`${path}?status=paid`));
        const callback = await fetch(`${base}/payments/sslcommerz/success`, { method: 'POST', redirect: 'manual',
          body: new URLSearchParams({ tran_id: session.transactionId, val_id: 'mock-validation', amount: '0' }) });
        assert.equal(callback.status, 303);
        assert(callback.headers.get('location').includes(`${path}?status=paid`));
        await post('STORAGE_MANAGER', `/storage/allocations/${allocationId}/release/respond`, { decision: 'APPROVE' });
        assert.equal((await row('SELECT AllocationStatus FROM STORES WHERE AllocationID = :id', { id: allocationId })).ALLOCATIONSTATUS, 'COMPLETED');
      });
    }
    await check('all role read endpoints and six cursor reports', async () => {
      const routes = {
        FARMER: ['dashboard', 'farms', 'batches', 'orders', 'payments', 'storage', 'storage/payments', 'storage/fees', 'storage/proposals'],
        BUYER: ['dashboard', 'batches', 'bids', 'orders', 'payments', 'storage', 'storage/fees', 'storage/proposals', 'reviews'],
        STORAGE_MANAGER: ['dashboard', 'warehouses', 'units', 'allocations', 'requests', 'awaiting/leg1', 'awaiting/leg2'],
        TRANSPORT_PERSONNEL: ['summary', 'requests', 'vehicles', 'assignments'],
        ADMIN: ['dashboard', 'users', 'prices', 'complaints', 'farm-verifications', 'reports'],
      };
      for (const [role, paths] of Object.entries(routes)) {
        const root = { STORAGE_MANAGER: 'storage', TRANSPORT_PERSONNEL: 'transport' }[role] || role.toLowerCase();
        for (const path of paths) await api(role, `/${root}/${path}`);
      }
      for (const name of ['harvest', 'storage', 'sales', 'payment', 'market-price', 'activity']) {
        const report = await api('ADMIN', `/admin/reports/${name}`);
        assert(Array.isArray(report.rows));
      }
      assert((await api('FARMER', `/reference/warehouses/${warehouseId}/units`)).some(u => u.locationTag === 'Mirpur 12'));
    });
    if (process.argv.includes('--browser')) {
      await check('browser login for five roles, role pages, crop base price and draft publishing', async () => {
        await require('./browser')({ base: base.replace(/\/api$/, ''), users, password, farmId, crop, arat, batchId });
      });
    }
    console.log(`${checks} workflow groups passed. Gateway calls were mocked; no hosted payment attempted.`);
  } finally {
    global.fetch = realFetch;
    db.withTransaction = originalTransaction;
    if (server) await new Promise(resolve => server.close(resolve));
    pool.getConnection = borrow;
    await connection.rollback();
    const remaining = await execute('SELECT COUNT(*) AS N FROM USERS WHERE Email LIKE :prefix', { prefix: `${prefix}.%` });
    assert.equal(remaining.rows[0].N, 0, 'Fixture users must not survive rollback');
    console.log('All fixture rows rolled back. Oracle sequence gaps are expected.');
    await connection.close();
    await db.close();
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
