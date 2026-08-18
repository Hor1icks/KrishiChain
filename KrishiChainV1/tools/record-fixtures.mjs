/**
 * One-time fixture capture for the offline demo build.
 *
 * Logs into the LIVE Express API as one user per role, walks every GET
 * endpoint the front end calls, follows list responses to pick up the
 * per-id detail routes, and writes the JSON into
 * demo-client/src/demo/fixtures/.
 *
 * Recording beats hand-writing these: farmer.service.js alone aliases 60+
 * distinct camelCase fields, so an authored fixture that gets one shape
 * wrong shows up as a permanently blank page rather than an error.
 *
 * Needs the API on :5000 and a seeded database. Run once:
 *   node KrishiChainV1/tools/record-fixtures.mjs
 */
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const API = process.env.API ?? 'http://localhost:5000/api';
const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'demo-client', 'src', 'demo', 'fixtures');

/** One account per branch of the total specialization; all share Demo@1234. */
const ACCOUNTS = {
  FARMER: 'abdul.karim@krishichain.bd',
  BUYER: 'tanvir.hossain@krishichain.bd',
  STORAGE_MANAGER: 'ashraful.alam@krishichain.bd',
  TRANSPORT_PERSONNEL: 'sohel.rana@krishichain.bd',
  ADMIN: 'farhana.yasmin@krishichain.bd',
};

/** Reference endpoints are role-agnostic, so every role records them. */
const SHARED = ['/auth/me', '/reference/crops', '/reference/arats', '/reference/warehouses'];

const FLAT = {
  FARMER: ['/farmer/dashboard', '/farmer/farms', '/farmer/batches', '/farmer/orders',
           '/farmer/payments', '/farmer/storage', '/farmer/storage/proposals',
           '/farmer/storage/fees'],
  BUYER: ['/buyer/dashboard', '/buyer/batches', '/buyer/bids', '/buyer/orders',
          '/buyer/payments', '/buyer/reviews', '/buyer/storage',
          '/buyer/storage/proposals', '/buyer/storage/fees'],
  STORAGE_MANAGER: ['/storage/dashboard', '/storage/warehouses', '/storage/units',
                    '/storage/allocations', '/storage/awaiting/leg1',
                    '/storage/awaiting/leg2', '/storage/requests'],
  TRANSPORT_PERSONNEL: ['/transport/summary', '/transport/assignments',
                        '/transport/requests', '/transport/vehicles'],
  ADMIN: ['/admin/dashboard', '/admin/users', '/admin/prices', '/admin/complaints'],
};

/**
 * Detail routes, derived from a list already recorded. `from` is the list
 * path, `id` the field to read off each row, `path` builds the detail URL.
 */
const DERIVED = {
  FARMER: [
    { from: '/farmer/batches', id: 'batchId', path: (v) => `/farmer/batches/${v}` },
    { from: '/farmer/batches', id: 'batchId', path: (v) => `/farmer/batches/${v}/bids` },
    { from: '/reference/warehouses', id: 'warehouseId', path: (v) => `/reference/warehouses/${v}/units` },
  ],
  BUYER: [
    { from: '/buyer/batches', id: 'batchId', path: (v) => `/buyer/batches/${v}` },
    { from: '/reference/warehouses', id: 'warehouseId', path: (v) => `/reference/warehouses/${v}/units` },
  ],
  // /storage/warehouses/:id/units exists only as a POST (unit creation),
  // so there is no GET to record for it.
  STORAGE_MANAGER: [
    { from: '/reference/warehouses', id: 'warehouseId', path: (v) => `/reference/warehouses/${v}/units` },
  ],
  TRANSPORT_PERSONNEL: [],
  ADMIN: [],
};

async function call(path, token) {
  const res = await fetch(`${API}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  const text = await res.text();
  const body = text ? JSON.parse(text) : null;
  if (!res.ok) throw new Error(`${path} -> ${res.status} ${body?.error ?? ''}`);
  return body;
}

async function login(email) {
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Demo@1234' }),
  });
  if (!res.ok) throw new Error(`login ${email} -> ${res.status}`);
  return res.json();
}

const main = async () => {
  const bundle = {};
  const users = {};
  let ok = 0;
  const failed = [];

  for (const [role, email] of Object.entries(ACCOUNTS)) {
    const { user, token } = await login(email);
    users[role] = user;
    const store = {};

    const paths = [...SHARED, ...FLAT[role]];
    for (const p of paths) {
      try { store[p] = await call(p, token); ok++; }
      catch (e) { failed.push(`${role} ${e.message}`); }
    }

    for (const d of DERIVED[role]) {
      const list = store[d.from];
      if (!Array.isArray(list)) continue;
      const ids = [...new Set(list.map((r) => r[d.id]).filter((v) => v != null))];
      for (const v of ids) {
        const p = d.path(v);
        try { store[p] = await call(p, token); ok++; }
        catch (e) { failed.push(`${role} ${e.message}`); }
      }
    }

    bundle[role] = store;
    const counts = Object.entries(store)
      .map(([p, v]) => `${p}${Array.isArray(v) ? `[${v.length}]` : ''}`);
    console.log(`\n${role} — ${counts.length} endpoints`);
    console.log('  ' + counts.join('\n  '));
  }

  await mkdir(OUT, { recursive: true });
  const header = '// Recorded from the live API by tools/record-fixtures.mjs. Do not hand-edit.\n';
  await writeFile(join(OUT, 'responses.json'), JSON.stringify(bundle, null, 1));
  await writeFile(join(OUT, 'users.js'), `${header}export const USERS = ${JSON.stringify(users, null, 2)};\n`);

  console.log(`\nrecorded ${ok} endpoints across ${Object.keys(ACCOUNTS).length} roles`);
  if (failed.length) { console.log(`\n${failed.length} FAILED:`); failed.forEach((f) => console.log('  ' + f)); }
  else console.log('no failures');
};

main().catch((e) => { console.error(e); process.exit(1); });
