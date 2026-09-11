# Project Update-2 — where each technique lives

Every item below is reachable from the running application: a form writes
to the database, a query reads it back, the page shows the result. Nothing
is labelled on screen; this file is the map.

This document is retained as the Update-2 technique map. On the `update3`
branch, Week-11 sequences, triggers and indexes were added without removing
these features; see `UPDATE3.md` for that addition.

Start the system with `./start.sh`, then sign in. All seeded accounts use
the password `Demo@1234`.

| # | Technique | In the database | Reached from |
|---|---|---|---|
| 1 | Function | `pkg_krishi_metrics` — 5 functions | Farmer dashboard, buyer payments, warehouses, batch detail, allocations |
| 2 | Subquery | Correlated subqueries in views, dashboards and reports | Listings, dashboards and reports |
| 3 | View | 8 views | Profile, listings, bidding, earnings, orders, storage and admin dashboard |
| 4 | Abstract datatype | `t_address` object with `full_text()` / `short_text()` | Profile page |
| 5 | PL/SQL | 3 packages, 7 procedures, 5 functions | Admin → Reports |
| 6 | Cursor | `SYS_REFCURSOR` from all 6 report procedures | Admin → Reports |
| 7 | Exception handling | `ORA-20001` … `ORA-20004` | Bid below the minimum; pay before delivery |

`./db.sh database/07_update2_demo.sql` runs one worked example of each,
read-only, in the same order.

---

## Walking it in the browser

**1. Function.** Sign in as `abdul.karim@krishichain.bd`. The revenue figure
on the dashboard is `pkg_krishi_metrics.fn_farmer_revenue`, computed in
Oracle, not summed in JavaScript.

**2. Subquery.** Open Browse Listings or a batch detail page. The listing
views use correlated subqueries to calculate bid counts and the current
highest bid. Runtime key generation moved to the Week-11 sequence/trigger
implementation documented in `UPDATE3.md`.

```sql
SELECT COUNT(*)
FROM BID b
WHERE b.BatchID = hb.BatchID;
```

**3. View.** Sign in as `farhana.yasmin@krishichain.bd`. "Still in transit"
on the admin dashboard is `V_PENDING_DELIVERY`, one seven-table join the
application queries as if it were a table.

**4. Abstract datatype.** Click your name in the top-right on any account.
The address line is `Address.full_text()` — a member function of the object
type, executed in the database.

**5. PL/SQL and 6. Cursor.** Admin → Reports. Each of the six reports calls
a procedure in `pkg_krishi_reports` that opens a `SYS_REFCURSOR`; the API
streams it to the page rather than building an array first.

**7. Exception handling.** As a buyer, bid below a batch's minimum quantity.
`pkg_krishi_rules` raises `ORA-20003` and the exact message reaches the
screen. Trying to pay an `ON_DELIVERY` order before it is delivered raises
`ORA-20002` the same way.

---

## What changed from Update-1

Update-2 moved cross-table business rules into `pkg_krishi_rules`, called
from the service layer inside the same transaction. They raise the same
application error numbers, so nothing downstream changed. Update-3 retains
that design: its triggers only assign surrogate keys, while business rules
remain explicit and easy to demonstrate in the package.

BR-19 is simpler as a procedure than it was as a trigger. Summing `PAYMENT`
from a row trigger on `PAYMENT` raises `ORA-04091: table is mutating`, which
is why it had to be a compound trigger. A procedure has no such problem.

**All payment goes through SSLCommerz.** Sale orders and storage fees both
settle on the gateway's hosted checkout; the application never asks which
method you want, because bKash, Nagad, cards and internet banking are all
chosen on SSLCommerz's own screen. The one exception is cash physically
handed to a driver on delivery, which he records as a witness.

The payer sets how much to settle now — all of it, or part, with the rest
left outstanding for later. That figure is checked on the server, not in the
browser, and the same number is both reserved and sent to the gateway, so the
two can never disagree.

The amount is reserved as a `PENDING` payment before the session opens, so a
balance cannot be paid twice, and settlement is confirmed by calling the
gateway's validation API — the redirect body itself is never trusted.

**Notifications.** The bell is in the nav and opens to "Will be implemented".
The `NOTIFICATION` table and its seed rows exist; nothing is wired to them
yet, pending a decision on which events are worth notifying about.

**Build chain on Update-3.** `00_reset` → `01_create_tables` →
`01_schema_automation` → `02_business_rules` → `03_insert_data` → `04_views`
→ `05_plsql_layer`. `06_advanced_queries`, `07_update2_demo`, and
`08_update3_demo` are demonstrations rather than build steps.
