# KrishiChain API

Express + node-oracledb against Oracle XE 11.2. The API implements all five
roles and all six atomic workflows from PRD §9.10.

## Setup

```bash
cd server
npm install
cp .env.example .env      # then edit it for your machine
npm start                 # http://localhost:5000
```

`ORACLE_CLIENT_DIR` must point at an Oracle Instant Client 19c directory.
Thick mode is required because node-oracledb Thin mode cannot connect to
Oracle Database 11.2. The Instant Client, XE and Node.js architectures must
match. Also quote `DB_PASSWORD` in `.env` when it contains `#`, because an
unquoted `#` begins a comment.

## API modules

| Prefix | Access | Main responsibilities |
|---|---|---|
| `/api/health` | Public | Database connectivity check |
| `/api/auth` | Public / signed in | Roles, registration, login and profile |
| `/api/reference` | Signed in | Crops, ARATs, warehouses and units |
| `/api/farmer` | Farmer | Farms, batches, bids, awards, orders, payments and storage |
| `/api/buyer` | Buyer | Listings, bids, orders, payments, reviews and storage |
| `/api/storage` | Storage manager | Warehouses, units, requests and allocations |
| `/api/transport` | Transport personnel | Vehicles, assignments, pickup and delivery |
| `/api/admin` | Admin | Users, prices, complaints, dashboard and reports |
| `/api/payments` | Payment gateway | SSLCommerz success, failure and cancellation callbacks |

Every protected endpoint authenticates the bearer token and checks the role
again on the server. Routes are thin; SQL and workflow logic live in services.

## Atomic workflows

Each workflow uses one `withTransaction()` call, commits on success and rolls
back on failure:

1. Registration
2. Storage allocation
3. Place bid
4. Award winning bid
5. Assign transport
6. Delivery and payment

`oracledb.autoCommit` stays disabled. The service layer also locks the rows
whose state or capacity it is about to change, so concurrent requests cannot
silently overbook a unit, award a batch twice, or overpay an order.

Runtime inserts put the Week-11 `seq_*_id.NEXTVAL` directly in their SQL, and
`RETURNING ... INTO` gives the generated value back to the service. `USERS`
retains one automatic-ID example in `trg_users_prepare`. The only
partial key, `STORAGE_UNIT.UnitNo`, is assigned per warehouse through
`pkg_krishi_rules.next_unit_no` while the warehouse is locked.

Cross-table validations are split between `pkg_krishi_rules` and the concise
guards in `database/02_trigger_layer.sql`. Oracle application errors in the
`ORA-20xxx` range are returned as readable HTTP 422 responses.

SSLCommerz remains available at every online-payment point: buyer sale
orders, farmer storage fees, and buyer storage fees. All three reserve a
`PENDING` payment before redirecting and validate the gateway response on the
server. Cash recorded by transport personnel is the separate on-delivery
workflow.

## Layout

```text
src/
  config/       environment, Thick-mode pool, transactions and cursors
  services/     SQL, ownership checks and atomic workflows
  routes/       HTTP routing and input hand-off
  middleware/   authentication, role checks and error handling
  utils/        shared API errors and validators
```

All 25 seeded users use the local demonstration password `Demo@1234`.
`abdul.karim@krishichain.bd` is a useful farmer account with seeded batches
and bids. This shared credential is only for disposable course data.
