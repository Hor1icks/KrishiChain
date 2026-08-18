# KrishiChain V1 — Project Update-1

Everything needed for the WK-8 assessment, in one folder that depends on
nothing else in the repository.

Two halves, shown separately:

| Half | What it needs running |
|---|---|
| `demo-client/` — the front end, all 27 pages | Node. **No server, no database.** |
| `sql/` — schema, data, queries | SQL Developer + the Oracle container |

The front end reads data recorded from the live API and bundled into it, so
it cannot fail because a database is down, a port is taken, or the Oracle
client did not load. The SQL half runs in a **separate, empty schema**, so
`CREATE TABLE` genuinely executes in front of the examiners instead of
reporting that all 28 tables already exist.

---

## Deliverables, and where each one is

| Required | Where |
|---|---|
| 50% of front-end pages ready, navigable, explainable | `demo-client/` — **27 of 27** pages, all five role modules. Page-by-page table below. |
| All tables created per the Schema Diagram, with constraints | `sql/01_create_tables.sql` — 28 tables, 28 PK, 41 FK, 18 UNIQUE, 198 CHECK/NOT NULL |
| 5 rows minimum of demo data in each table | `sql/02_insert_data.sql` — every table ≥ 5, verified at the end of the file |
| Sample advanced queries | `sql/03_advanced_queries.sql` — **10**, all returning rows |

---

## Running the front end

```
cd KrishiChainV1/demo-client
npm install
npm run dev
```

Open <http://localhost:5173>. Sign in with one of the five buttons on the
sign-in page — one per role, no typing. Every account's password is
`Demo@1234`.

| Role | Account | Lands on |
|---|---|---|
| Farmer | Abdul Karim | 5 batches, 3 with live bidding, one awardable |
| Buyer | Tanvir Hossain | 5 listings, 4 bids incl. an outbid-then-rebid chain |
| Storage manager | Ashraful Alam | Bogura Cold Storage, 3 units, 5 allocations |
| Transport | Sohel Rana | 1 active trip, 1 unclaimed job |
| Admin | Farhana Yasmin | 25 users, 100 price rows, 5 complaints |

`npm run build && npm run preview` also works and is the fallback if the dev
server misbehaves. Neither needs a backend.

**It is read-only.** Pages all render real data, but buttons that would
write say so plainly instead of pretending:

> This is the front-end demo build, so actions are switched off — there is
> no database behind it to save to. The full build writes this straight to
> Oracle.

Worth saying out loud when demonstrating, because it is a deliberate choice,
not a missing feature: the write paths exist in the full build, and this
copy exists so the front end can be shown without any of it running.

### How it is decoupled

Every page reaches the network through one function, `api()` in
`demo-client/src/api/client.js`. Replacing that single file is the whole
change — no page component was modified to make this work. `GET` requests
are answered from `src/demo/fixtures/responses.json`; everything else is
refused with the message above.

Those fixtures were **recorded** from the running API by
`tools/record-fixtures.mjs`, 82 endpoints across the five roles, rather than
written by hand. That matters: a single service aliases 60+ camelCase
fields, and a hand-written fixture with one field name wrong renders as a
permanently blank page rather than an error.

Fonts are bundled in `demo-client/public/fonts/` rather than fetched from
Google's CDN, so a room with no internet cannot silently drop the page to
system fonts.

---

## Running the SQL

### One-time setup

The demo schema owner has to exist first. **This has already been done on
this machine** — it is recorded here so it can be repeated elsewhere. It is
the only step needing a privileged connection, so it is not part of `sql/`.

Connect as `SYSTEM` (password `KrishiSys#2026`) and run:

```sql
CREATE USER krishichain_demo IDENTIFIED BY KrishiDemo2026
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO krishichain_demo;
GRANT CREATE VIEW      TO krishichain_demo;
GRANT CREATE SEQUENCE  TO krishichain_demo;
GRANT CREATE TRIGGER   TO krishichain_demo;
GRANT CREATE PROCEDURE TO krishichain_demo;
```

The same grants the existing `krishichain` user holds. `RESOURCE` covers
`CREATE TABLE` and the storage quota; the other four are separate privileges
in 11g and are not included in it.

Then add **one** connection in SQL Developer — same settings as the existing
`krishichain-oracle` connection, different credentials:

| | |
|---|---|
| Name | `krishichain-demo` |
| Username | `krishichain_demo` |
| Password | `KrishiDemo2026` |
| Host / Port / SID | `localhost` / `1521` / `xe` |

### Then, in that connection

Open each file and press **F5** (Run Script), in order:

| File | What it does |
|---|---|
| `sql/00_reset.sql` | Drops all 28 tables. On an empty schema every statement reports `ORA-00942` — that is correct, there is nothing to drop. |
| `sql/01_create_tables.sql` | Creates all 28 tables with their constraints, then counts them back. |
| `sql/02_insert_data.sql` | Loads the demo data, then verifies it. |
| `sql/03_advanced_queries.sql` | The ten queries. Use **Ctrl+Enter** here, one query at a time. |

`00_reset.sql` is what makes creation demonstrable on demand: run it and the
schema is empty again, so `01` can be run live from nothing as many times as
asked.

**F5 for the first three files, Ctrl+Enter for the queries.** F5 runs a whole
file as a script; Ctrl+Enter runs the one statement under the cursor and puts
the result in a grid. Every query in `03` is self-contained so Ctrl+Enter
works on any of them, in any order.

### What is deliberately not in the SQL

No indexes, no sequences, no triggers, no PL/SQL — none of it has been
covered in the course yet, so nothing here runs ahead of it. Consequences
worth being ready to explain:

- **Every primary key is a literal value** in the insert file, rather than
  generated. Oracle 11g has no `IDENTITY` column, so the full build pairs a
  sequence with a `BEFORE INSERT` trigger for each of them.
- Oracle still builds a unique index behind every `PRIMARY KEY` and
  `UNIQUE` constraint automatically. What is absent is the extra hand-made
  index on each foreign-key column.
- **Three business rules have no enforcement here**, because each compares
  two tables and so needs a trigger: BR-09 (a batch's minimum price must
  clear the crop's base price), BR-11 (a bid must beat the minimum and the
  current highest), BR-18 (a vehicle's capacity must cover its load). The
  seed satisfies all three by hand, and the verification block at the end of
  `02_insert_data.sql` proves BR-09 and BR-19 hold. Check those pairings
  before editing any price or quantity.

Four **virtual columns** are kept — `AvailableQuantity`, `TotalAmount`,
`StorageFee`, `MinimumReleaseDate`. They are derived attributes computed on
read, not triggers, and the queries read them.

---

## The 27 pages

Numbers are a sensible demo order. "Reads" names the tables behind the
screen, which is the question most likely to follow "what does this page do".

### Public — 3

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 1 | Sign in | `/login` | Five role buttons, one per branch of the specialization | `USERS` |
| 2 | Register | `/register` | New account. One submission writes three tables, because the specialization is total | `USERS`, subclass, `USER_PHONE` |
| 3 | Role home | `/dashboard` | Sends each role to its own module | — |

### Farmer — 8

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 4 | Farmer dashboard | `/farmer` | Batches listed, sold, earned, outstanding | `HARVEST_BATCH`, `SALE_ORDER`, `PAYMENT` |
| 5 | My Farms | `/farmer/farms` | The farmer's land, and how many batches came off each | `FARM` |
| 6 | My Batches | `/farmer/batches` | Every lot with its status, available quantity and highest bid | `HARVEST_BATCH`, `CROP`, `FARM`, `VIRTUAL_ARAT`, `BID` |
| 7 | New Batch | `/farmer/batches/new` | List a lot: crop, arat, quantity, floor price, bidding window, minimum bid size | writes `HARVEST_BATCH` |
| 8 | Batch detail | `/farmer/batches/:id` | Every bid on one lot, and the award button. **The demo centrepiece** — awarding writes four tables in one transaction | `BID`, `BUYER`, `USERS` |
| 9 | My Orders | `/farmer/orders` | Sales made, and where each consignment is | `SALE_ORDER`, `TRANSPORT_REQUEST` |
| 10 | Payment History | `/farmer/payments` | Money received, per order | `PAYMENT` |
| 11 | Storage Requests | `/farmer/storage` | Pre-sale storage: offers to accept, reject or counter; fees owed | `STORES`, `WAREHOUSE`, `STORAGE_UNIT`, `STORAGE_PAYMENT` |

### Buyer — 8

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 12 | Buyer dashboard | `/buyer` | Active bids, orders won, amount outstanding | `BID`, `SALE_ORDER`, `PAYMENT` |
| 13 | Browse Listings | `/buyer/browse` | Open auctions, filterable by crop | `HARVEST_BATCH`, `CROP`, `VIRTUAL_ARAT` |
| 14 | My Bids | `/buyer/bids` | One row per lot, latest bid, with a rebid count | `BID`, `HARVEST_BATCH` |
| 15 | Batch detail | `/buyer/batches/:id` | Place a bid, against the floor price and the standing highest | `HARVEST_BATCH`, `BID` |
| 16 | My Orders | `/buyer/orders` | Orders won; pay, or choose direct delivery | `SALE_ORDER`, `TRANSPORT_REQUEST` |
| 17 | Payments | `/buyer/payments` | What has been paid and what is left | `PAYMENT`, `SALE_ORDER` |
| 18 | My Storage | `/buyer/storage` | Post-sale storage, the same workflow from the buyer's side | `STORES`, `WAREHOUSE`, `STORAGE_PAYMENT` |
| 19 | Reviews | `/buyer/reviews` | Rate a completed order — one review per order | `REVIEW`, `SALE_ORDER` |

### Storage manager — 3

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 20 | Storage dashboard | `/storage` | Units held, space free, fees outstanding | `WAREHOUSE`, `STORAGE_UNIT`, `STORES` |
| 21 | Warehouses | `/storage/warehouses` | Warehouses and their units, with load and utilisation | `WAREHOUSE`, `STORAGE_UNIT` |
| 22 | Allocations | `/storage/allocations` | The ternary in use: propose space, answer requests, handle releases. Four queues on one page | `STORES`, `HARVEST_BATCH`, `SALE_ORDER` |

### Transport — 1

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 23 | Assignments | `/transport` | Unclaimed jobs and this driver's trips; claim a job, advance its status, deliver | `TRANSPORT_REQUEST`, `ASSIGNED_TO`, `VEHICLE` |

### Admin — 4

| # | Page | Route | What it does | Reads |
|---|---|---|---|---|
| 24 | Admin dashboard | `/admin` | Platform totals and unpaid balances | most tables |
| 25 | Manage Users | `/admin/users` | All 25 users across the five subclasses; block or reinstate | `USERS` + all five subclasses |
| 26 | Daily Prices | `/admin/prices` | The published arat price series | `DAILY_MARKET_PRICE`, `CROP`, `VIRTUAL_ARAT` |
| 27 | Complaints | `/admin/complaints` | Disputes against orders, and their resolution | `COMPLAINT`, `SALE_ORDER` |

**Cross-cutting:** the notification bell in the navigation bar appears on
every signed-in page, with per-role unread counts (`NOTIFICATION`).

---

## The 10 queries

Each is one self-contained statement — put the cursor in it and press
**Ctrl+Enter**. Q6 to Q10 are the ones that show off the ER design; between
them they cover all five graded constructs.

| # | Query | Technique | Rows | Demonstrates |
|---|---|---|---|---|
| Q1 | Did the farmer beat the market? | five-table join, joined on three columns | 5 | the project's whole purpose |
| Q2 | Which farmers earned the most | `RANK() OVER (…)` over an aggregate | 5 | window function |
| Q3 | Which crops attract the most bidding | `GROUP BY` with `HAVING` | 3 | filtering after grouping |
| Q4 | Lots nobody bid on | `NOT EXISTS`, three joins | 1 | anti-join |
| Q5 | Is this crop's price rising or falling? | `LAG() OVER (…)` | 5 | window function |
| Q6 | Which arat reports to which | self-join, two `LEFT JOIN`s | 5 | **recursive relationship 1** |
| Q7 | A bidding war, replayed | `CONNECT BY`, `START WITH`, `LEVEL`, `NOCYCLE` | 15 | **recursive relationship 2** |
| Q8 | The platform against the physical market | join into a weak entity through its owner | 5 | **weak entity 2** |
| Q9 | Who is storing what, and has the fee been paid? | six tables, composite key, `LEFT JOIN` | 7 | **ternary 1** + **weak entity 1** + the **aggregation** |
| Q10 | Who drove what | six tables across a ternary | 5 | **ternary 2** + the **specialization** |

**Deliberately kept simple.** An earlier version ran to 12-table joins,
nested inline views and stacked window functions. It worked, but nobody could
explain it under questioning, which is the only thing that matters in a viva.
These do the same job with one technique per query. The complex set is kept in
`~/Downloads/KrishiChainV1-extras/03_advanced_queries_COMPLEX.sql` if a harder
example is ever wanted.

**Every query joins at least two tables, and none uses `PARTITION BY`.**

**Q6 and Q7 are worth contrasting**, because they read the same kind of
self-referencing foreign key two different ways. A join gets you one level —
an arat and its parent — and that is all a join can ever do, because you have
to write one join per level and you do not know how many there are. `CONNECT
BY` follows the chain the whole way down regardless of depth. If asked why
both are in here, that is the answer.

One Oracle 11g limit is worth having ready, because it is a standard
follow-up: there is no `FETCH FIRST n ROWS`, so row-limiting has to use
`ROWNUM` inside an inline view.

### Three results worth knowing before you are asked

**Q1 does not flatter the platform.** Four of the five sales beat the market;
the mustard seed sale came in **below** the arat price. That row is in the
seed on purpose — it shows the query can return a negative verdict instead of
only ever congratulating the system, and it illustrates the real risk the
platform exists to expose: selling without knowing where the price is
heading.

**Q4 returns exactly one row**, batch 8 — Rahima Begum's Aman Rice in Rangpur.
That is correct, not a bug: it is the only listed lot with no bids, and it is
in the seed specifically so this query has something to find.

**Q5 covers one crop at one arat**, Potato at the central arat, and shows it
sliding from ৳22.50 to ৳18.40 over five months. The `WHERE` clause is not
decoration — without it `LAG` would compare one crop's month to another
crop's, since it simply reads the previous row of whatever it is given.

**Q10 is where BR-18 is checkable by eye.** Vehicle capacity should be at
least the load on every row. Nothing in the database enforces it, because it
compares two tables and this build has no triggers.

---

## Two changes from the older `database/` scripts

Both make the tables match the Schema Diagram, which the older scripts did
not.

**`BAZAR_DAILY_RECORD`** now has the primary key
`(BazarID, RecordDate, CropID)`, plus `PricePerKg` and `LoggedBy`. The old
two-column key allowed only **one crop per bazar per day**, which made the
entity unable to do the one job it exists for. The old seed silently obeyed
that limit — no bazar ever repeated a date. Here bazar 1 records three crops
on a single date, and Q6 depends on being able to.

**`DAILY_MARKET_PRICE`** has lost `LoggedBy`. The arat price is computed by
the platform from its own trading activity; no administrator types it in,
and the whole point is that the middleman cannot set it by hand. Contrast
`BAZAR_DAILY_RECORD`, where a person does collect the figure from a physical
market — which is why that table gained the column the other one lost.

---

## Also in this folder

- `tools/record-fixtures.mjs` — regenerates the front end's data by
  replaying the live API. Needs the full stack running; not needed for the
  demo.
- `tools/run-sql.sh` — runs a `sql/` file against the demo schema from the
  command line, using `sqlplus` inside the container. For checking a file
  still runs clean; SQL Developer is the demo path.
