# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

KrishiChain is a university DBMS course project (CSE-302, Military Institute of Science and
Technology) — an agricultural supply-chain system (Farm → Virtual ARAT → Buyer) built to
demonstrate an advanced Oracle relational design through a real React/Express front end.

The full spec lives in `KrishiChain_PRD_v3.md` — treat it as the source of truth for schema,
business rules, and scope. Read it (or the relevant section) before making design decisions;
don't re-derive things it already answers. Key sections: §0 Design Decisions, §7 ER constructs,
§8 Business Rules, §9 Relational Schema + Oracle 11g standards, §11 Architecture/front-end plan.

**Current change boundary:** do not add, remove, or alter database tables, columns, keys,
relationships, or ER-diagram content. Trigger definitions and application queries may be
improved as long as current workflows remain compatible.

**This is the `update3` branch.** It retains every Update-2 feature and adds the Week-11
sequence, trigger and indexing topics from the CSE-302 work plan. Read `UPDATE2.md` for the
earlier technique map and `UPDATE3.md` for the new schema-automation map.

**Current state:** 29 application page components, eight views, three PL/SQL packages, one object type,
18 sequences, 9 varied triggers, 31 application indexes, and SSLCommerz card payment.
`Phase1/` contains the environment proof, `database/` contains the schema and demonstrations,
`server/` is the Express API, and `client/` is the React + Vite application. **Still
outstanding:** a human-hosted sandbox payment/return and final team presentation rehearsal.
`docs/PRESENTATION.md` contains the narration and demonstration checklist.

All six PRD §9.10 transactions are implemented: Registration, Storage
Allocation, Place Bid, Award Winning Bid, Assign Transport, Delivery+Payment.

`server/test/workflows.js` exercises these workflows using uncommitted Oracle fixtures.
It checks registration rollback with a duplicate phone and award rollback with an injected
late execution failure. Do not add temporary constraints for testing: the schema is frozen.
The harness replaces service commits with savepoints, then rolls the entire run back.

## Update-3 database automation

- `database/01_schema_automation.sql` defines the 18 surrogate-key sequences and 31 ordinary
  indexes. IDs 1–1000 remain available for readable seed data; runtime IDs begin at 1001.
- Runtime inserts use their table sequence directly and read the value with `RETURNING ... INTO`.
  `USERS` deliberately retains one automatic-ID example in `trg_users_prepare`.
  `STORAGE_UNIT.UnitNo` is the exception because it is a per-warehouse weak-entity partial key;
  `pkg_krishi_rules.next_unit_no` assigns it while the warehouse row is locked.
- The 31 `IX_` indexes cover foreign-key joins and common filters without duplicating indexes
  Oracle already creates for primary-key and unique constraints.
- `database/02_trigger_layer.sql` contains 9 varied row triggers: preparation, validation,
  state-transition guards, and notifications. Large multi-step workflows remain explicit
  service transactions.

A rebuild must end with 18 valid sequences, 9 enabled triggers, 31 `IX_` indexes, and zero
invalid objects. `database/11_trigger_demo.sql` tests the trigger layer and rolls back its rows.

**SSLCommerz card payment** (`server/src/services/sslcommerz.service.js`) reserves the amount as a
`PENDING` payment *before* opening the checkout session, so BR-19 counts the attempt and a balance
cannot be paid twice; cancellation, decline or session-open failure marks it `FAILED` and frees it. The
gateway redirects the browser back with a form POST, so **that body is attacker-controlled and is
never trusted** — settlement is confirmed by calling the gateway's validation API and comparing
transaction ID, BDT currency and amount. Failed validation leaves the reservation pending for
retry; do not assume the customer was not charged. Only COMPLETED payments authorize storage
release or order completion, and an order also requires delivery. Don't "simplify" that away.
Their server-to-server IPN cannot reach localhost, which
is why confirmation happens on the redirect. Blank `SSLCZ_STORE_ID` hides the feature entirely.

## Commands

There is no root `package.json`; `server/` and `client/` are separate npm projects.

```
cd server && npm install && cp .env.example .env && npm start   # API on :5000
cd client && npm install && npm run dev                         # UI on :5173
cd client && npm run build                                      # production compile check
cd client && npm run lint                                       # Oxlint static checks
```

Run `npm run check:db`, `npm run test:workflows`, or `npm run test:browser` from `server/`.
Browser checks require a built client and Google Chrome (or `CHROME_PATH`). See
`docs/TESTING.md` for prerequisites, rollback safety and the distinction between mocked
gateway tests and real sandbox connectivity. Never run reset/seed scripts against live data.

`server/.env` gotcha: **quote the password if it contains a `#`.** Unquoted, `#` starts a comment
in a `.env` file, so e.g. `DB_PASSWORD=Example#2026` parses as `Example` and yields `ORA-01017`.

SQL files are run in SQL Developer (F5 = Run Script, not Ctrl+Enter — several files contain
PL/SQL blocks terminated with `/`), through `./db.sh` (reads the connection out of `server/.env`,
nothing hardcoded), or SQL*Plus directly with whatever password `krishichain` actually has:

```
./db.sh database/99_inspect_data.sql
```

The build chain is `00_reset` → `01_create_tables` → `01_schema_automation` →
`02_trigger_layer` → `02_business_rules` → `03_insert_data` → `04_views` →
`05_plsql_layer`, which is exactly what `./start.sh --rebuild` runs.

Normal `./start.sh` also detects an older persistent Docker volume and adds
the missing Update-3 automation and views without running reset or seed. It
stops rather than modifying data if it detects a partially applied automation set.

- `database/00_reset.sql` — drops all 27 tables, all sequences, then all types. On an
  already-empty schema, table-drop statements report `ORA-00942`; that is expected.
- `database/01_create_tables.sql` — the whole schema, including everything the old 06, 07, 09,
  10 and 12 migrations used to add. Re-running it against a live schema yields `ORA-00955`.
- `database/01_schema_automation.sql` — 18 sequences and 31 ordinary indexes.
  Run it once after table creation; reset drops its objects during a clean rebuild.
- `database/02_trigger_layer.sql` — 9 varied triggers. Safe to re-run with `CREATE OR REPLACE`.
- `database/02_business_rules.sql` — `pkg_krishi_rules`, the cross-table rules. `CREATE OR
  REPLACE`, safe to re-run.
- `database/03_insert_data.sql` — **wipes every table before re-seeding.** Idempotent by design,
  but never run it just to look at data.
- `database/04_views.sql` — eight views, all `CREATE OR REPLACE`, safe to re-run.
- `database/05_plsql_layer.sql` — 2 packages, 5 functions, 7 procedures. All `CREATE OR REPLACE`,
  safe to re-run, unaffected by a re-seed. **The six PRD §9.10 transactions are deliberately NOT
  in here** — they need the authenticated user's identity and stay in the service layer.
- `database/06_advanced_queries.sql`, `07_update2_demo.sql`, `08_update3_demo.sql`,
  `11_trigger_demo.sql`, and
  `99_inspect_data.sql` — demonstrations and inspection scripts. The Update-3 demo temporarily
  inserts a proof row and rolls it back; it does not retain data.

`Phase1/00_environment_check.sql` is one-time-per-machine setup: run as SYSTEM (checks 1–4,
creates the `krishichain` app user), then reconnect as `krishichain` for Check 5.
`Phase1/test_connection.js` proves Thick-mode connectivity; edit `INSTANT_CLIENT_DIR` at the top
first — it must point at the unzipped Instant Client 19c directory, not a OneDrive-synced path.

## Architecture and non-obvious constraints

**Database is Oracle 11gR2 XE (11.2.0.2.0) — this drives almost every backend decision:**

- **node-oracledb must run in Thick mode.** The default Thin mode requires Database 12.1+ and
  cannot connect to 11.2 at all. `oracledb.initOracleClient({ libDir: ... })` must execute before
  any `getConnection()`/`createPool()` call, using Oracle Instant Client 19c.
- **No `IDENTITY` columns.** Oracle 11g runtime keys normally use `sequence.NEXTVAL` directly,
  and `RETURNING` reads the assigned key:

  ```sql
  INSERT INTO BID (BidID, BatchID, ...)
  VALUES (seq_bid_id.NEXTVAL, :batchId, ...)
  RETURNING BidID INTO :bidId
  ```

  `STORAGE_UNIT.UnitNo` is the one exception: it is a per-warehouse partial key, so it comes
  from `pkg_krishi_rules.next_unit_no(:warehouseId)` while that warehouse is locked.
- **No `FETCH FIRST n ROWS`.** Row-limiting must use `ROWNUM` inside an inline view.
- **Self-referencing FKs break seed order**: `VIRTUAL_ARAT.ParentAratID` and `BID.PreviousBidID`
  must be inserted NULL first, then `UPDATE`d to link — see the insert order in PRD §14.
- **Bengali text**: every column that may hold Bengali must be `VARCHAR2(n CHAR)` (character, not
  byte, semantics) — verify `NLS_CHARACTERSET` is `AL32UTF8` first (Check 2 in
  `00_environment_check.sql`). If it's `WE8MSWIN1252`, Bengali can't be stored — seed in English.
- **Virtual columns** (`GENERATED ALWAYS AS (...) VIRTUAL`) are used for derived fields
  (`TotalAmount`, `AvailableQuantity`, etc.) but must be verified against the actual XE build
  first (Check 5) — fall back to computing in the view/SELECT if they error.
- **XE's bundled APEX occupies port 8080** — Express must run on a different port (5000 planned).
- **Architecture bitness must match everywhere**: XE install (Win32 vs Win64), Instant Client, and
  Node.js all need the same bitness, or Thick-mode init fails with a misleading `DPI-1047`.
- Never develop as `SYS`/`SYSTEM` — use the dedicated `krishichain` app user created by
  `00_environment_check.sql` (`CONNECT, RESOURCE` + `CREATE VIEW/SEQUENCE/TRIGGER/PROCEDURE`).

**Data model shape** (PRD §7/§9, `Phase1/ER_BLUEPRINT.md`): 27 tables built
around five graded ER constructs that any schema or query work must preserve:

1. **Total, disjoint specialization** — `USERS` → `FARMER`/`BUYER`/`ADMIN_STAFF`/
   `STORAGE_MANAGER`/`TRANSPORT_PERSONNEL`, using shared-PK subclass tables (subclass PK is also
   FK → `USERS`), not a discriminator column.
2. **Aggregation** — `(BUYER —places— BID —on— HARVEST_BATCH)` as a whole is what `SALE_ORDER`
   relates to, not any one of the three independently (`UQ(BID.SaleOrderID... )` / `UQ(SALE_ORDER.BidID)` enforces 1:1).
   The second aggregation is `PAYMENT.AllocationID` → `STORES`: a storage fee is owed for the
   three-way allocation as a whole, not for the batch, the unit or the manager separately.
3. **Two ternary relationships** — `STORES` (HARVEST_BATCH × STORAGE_UNIT × STORAGE_MANAGER) and
   `ASSIGNED_TO` (TRANSPORT_REQUEST × VEHICLE × TRANSPORT_PERSONNEL). Keep these as single
   junction tables with three FK sets, not decomposed into binary relationships — decomposing
   loses the accountability link (e.g. which manager authorized an allocation).
4. **Two weak entities** — `STORAGE_UNIT` (partial key `UnitNo`, identified by `WarehouseID`) and
   `BAZAR_DAILY_RECORD` (partial key `RecordDate`, identified by `BazarID`); both need
   `ON DELETE CASCADE` from their owning strong entity.
5. **Two recursive relationships** — `VIRTUAL_ARAT.ParentAratID` (ARAT hierarchy, query with
   `CONNECT BY NOCYCLE`) and `BID.PreviousBidID` (outbid chain).

Note: **there is no `AUCTION` entity** — it was deliberately removed (D-4); its bidding-window
attributes (`MinimumPrice`, `BiddingStartTime`, `BiddingEndTime`) live directly on
`HARVEST_BATCH`, and `BID` references the batch directly. Don't reintroduce it.

**Schema notes** (all of this is folded into `01_create_tables.sql`; the old 06, 07, 09, 10 and
12 migration files are gone from this branch):

- **`STORAGE_PAYMENT` no longer exists.** It was merged into `PAYMENT` behind a
  `PaymentType IN ('SALE','STORAGE')` discriminator. `SaleOrderID`/`BuyerID`/`FarmerID` are now
  nullable and `AllocationID` was added; `CK_PAYMENT_TYPE_SHAPE` enforces that exactly the right
  columns are populated per subtype. Any storage-fee query needs `PaymentType = 'STORAGE'`.
  BR-19 and BR-20 apply to `SALE` rows only.
- **`USERS` has no flat address columns.** The six became one `Address t_address` object column,
  with `full_text()` / `short_text()` member functions. **Attribute
  access requires a table alias**: `u.Address.District` is legal, `Address.District` is not.
  `NVL2` is SQL-only and cannot be used inside the type body (`PLS-00201`).
- **`ON DELETE` on 23 of 41 FKs** — 20 `CASCADE`, 3 `SET NULL`. The other 18 are deliberately
  left restricting: deleting a crop with sales history, or a farmer who has been paid, *should*
  fail. Don't "fix" them.
- **`STORAGE_MANAGER`** contains `Designation` and `ShiftSchedule`; employee ID, hire date and
  certification number were removed in Update 4.
- **Storage acceptance is not arrival.** An accepted `STORES` row becomes `IN_TRANSIT`; driver
  delivery sets `DateIn` and `ACTIVE`. `STORAGE_UNIT.LocationTag` is the exact destination.
- **Farm verification is advisory.** New farms enter an oldest-first `PENDING` ministry queue,
  but pending farmers may still list and sell. `VERIFIED` is a farm-level badge, not a trust tier.
- **`database/00_reset.sql`** drops all 27 tables, every sequence, then every type, so the full
  build chain above recreates the schema from empty with zero errors.

**Payment model (D-2):** direct buyer → farmer, no ARAT commission, no escrow. **Payment timing
(BR-20):** `ON_DELIVERY` payment is allowed only after transport status is `DELIVERED`; an
`ADVANCE` preference may be paid earlier.

**Six workflows require multi-statement atomic transactions** (PRD §9.10) — always wrap these in
explicit `COMMIT`/`ROLLBACK`, never issue the statements independently: Registration (USERS +
subclass + phone rows), Storage allocation, Place bid (new bid + previous-highest → OUTBID), Award
winning bid (bid → WON + batch → SOLD + sale order + transport request — "the demo centrepiece"),
Assign transport, Delivery + payment.

**In Delivery+payment (#6), `TRANSPORT_REQUEST → DELIVERED` must be written BEFORE
`pkg_krishi_rules.check_payment_allowed` is called.** That procedure reads `TRANSPORT_REQUEST` to
enforce BR-20, and within one transaction it sees the uncommitted value. Reordering makes every
on-delivery payment fail with `ORA-20002`. See `server/src/services/transport.service.js`.

Use `withTransaction()` from `server/src/config/db.js` for all six — it commits on return and
rolls back on throw. `oracledb.autoCommit` is set to `false` globally there; leave it that way.
Registration (`server/src/services/auth.service.js`) is the implemented reference example.

**Business rules (PRD §8, BR-01..BR-25)** are enforced in the database, not only in application
code. Anything comparable within one row is a `CHECK` constraint — bid ≥ batch `MinimumPrice`
(BR-11), one `ACTIVE` bid per buyer per batch (BR-14), `MinimumPrice ≥ Crop.BasePrice` (BR-09).

**Rules that read a second table live in `pkg_krishi_rules`** (`02_business_rules.sql`), called
from the service layer inside the same transaction, before the statement they guard:
`check_bid_min_qty`, `check_payment_allowed` (BR-19 and BR-20), `check_one_personnel`, and
`next_unit_no`. They raise `ORA-20001`..`ORA-20004`, which `errorHandler.js` maps to a status code
and surfaces verbatim. When adding app logic, don't make the app the *only* enforcement — a
friendly early check in the service is fine, but the package call is the backstop.

**Naming conventions**: `PK_`, `FK_`, `UQ_`, `CK_` prefixes on all constraints, so violations are
readable during the viva.

**A SQL*Plus line ending in `-` is a line continuation.** A `PROMPT ---- heading ----` line
therefore swallows the statement on the next line, which then fails with a baffling `SP2-0734`
naming a fragment of that statement. Never end a `PROMPT` (or any line) with a hyphen.

**Bind variable names are parsed as identifiers, so a reserved word breaks the statement before it
runs.** `:comment` fails with `ORA-01745: invalid host/bind variable name`, and the error names
neither the column nor the offending word. Avoid reserved words (`COMMENT`, `LEVEL`, `SIZE`,
`DATE`, …) as bind names — prefix them instead (`:reviewComment`).

**Seed data** (`database/03_insert_data.sql`, already applied): narratively consistent — the same
5 farmers, 5 crops and 7 batches thread through bids → orders → transport → payments. Random or
independent seed rows break the advanced queries (PRD §10) and are called out as the most common
demo failure mode. Six tables exceed "5 rows" on purpose (5 sale orders need 5 finished auctions
upstream; `USERS` is 25 because the specialization is total; `DAILY_MARKET_PRICE` is ~495 so `LAG`
has a real trend). All dates are `TRUNC(SYSDATE) - n`, so the data stays current on re-seed.

Three cross-table rules have **no DB backstop** and the seed satisfies them by hand: BR-09
(`MinimumPrice >= Crop.BasePrice`), BR-11 (bid ≥ minimum and > current highest), BR-18 (vehicle
capacity ≥ load). Check the pairings before editing any price or quantity in the seed file.

**Several seed values exist only to keep the Phase 4 queries non-empty** — changing them
silently breaks `05_advanced_queries.sql`. `DAILY_MARKET_PRICE` covers 12 specific (crop, arat)
series because Q1 joins on the batch's *own* arat; moving a batch to another arat drops that sale
from Q1 unless you add the series. Batch 8 exists solely to give Q4's `NOT EXISTS` anti-join a
batch with no bids. Each crop has its own price amplitude/period/phase/drift so Q5's `LAG` shows
five different trends rather than five identical ones. The seed file comments say which query
depends on what — read them before trimming.

**Seeded users all share the password `Demo@1234`** (real bcrypt hash in the seed). Sign in as
`abdul.karim@krishichain.bd` for a farmer with an open auction and awardable bids.
