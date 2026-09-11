# Presentation and demo guide

Suggested duration: 12–15 minutes. Split the five role sections among team members;
the person driving the demo should keep separate browser profiles for different roles.
These are narration notes, not a claim that a final team rehearsal has happened.

## Opening: one minute

“KrishiChain records a crop's journey from a farmer's harvest through bidding, sale,
transport and payment. Storage can happen before a buyer exists or after a buyer wins.
The interface uses React, the API uses Express, and the data and business checks run
on Oracle 11g XE. We kept the table design fixed during the final reliability pass.”

Current database inventory:

| Element | Count |
|---|---:|
| Tables / views | 27 / 8 |
| Sequences / varied triggers | 18 / 9 |
| Explicit application indexes | 31 |
| Packages | 3 |
| Procedures | 10: 9 packaged + 1 standalone |
| Packaged functions | 6: 5 metrics + next_unit_no |
| Object type / member functions | 1 / 2 |
| Ref-cursor reports | 6 |
| Named explicit cursors | 1 operational c_stale; 1 additional teaching c_open_batches |
| Virtual columns | 4 |

The 31 indexes are deliberate application indexes, not the total Oracle index count.
Use `npm run check:db` for the current live inventory. Package bodies are implementations
of the same packages, not three extra packages.

## Role 1: farmer — harvest and trustworthy listings

Screens: registration/login, profile, dashboard, farms, new batch, batch detail, orders,
payments and storage. Requirements: FR-AUTH, FR-FARM, FR-HARVEST, FR-BID, FR-STORE.

“Registration writes USERS, FARMER and USER_PHONE together. The address is a t_address
object; a profile reads its full_text member function. A farm enters the verification
queue but can still trade while waiting. Verification belongs to the farm, not a blanket
guarantee about everything a farmer sells.”

Create a batch without bidding dates. Point out the selected crop's base price and explain
why a lower minimum is rejected in both the application and Oracle. Open the saved batch,
set opening/closing dates, and publish it. A draft already delivered into storage can also
be published. Show HARVEST_BATCH and `trg_batch_listing_guard` in
`database/02_trigger_layer.sql`.

## Role 2: buyer — bids, sale and payment

Screens: dashboard, listings, batch detail, bids, orders, payments, storage and reviews.
Requirements: FR-BID, FR-ORDER, FR-PAY, FR-FEEDBACK.

“BID connects a buyer to a batch. A winning bid creates SALE_ORDER, so the order reaches
the harvest through BID; a second direct relationship is unnecessary. PreviousBidID
records which bid was displaced. AvailableQuantity and TotalAmount are derived values.”

Place a bid, demonstrate one rejected low-price or excessive-quantity bid, then return to
the farmer to award it. Explain the atomic updates to BID and HARVEST_BATCH plus the inserts
into SALE_ORDER and TRANSPORT_REQUEST. Show the farmer's bid notification.

Use ADVANCE terms for the online-payment demo. The payment page opens SSLCommerz; it does
not collect card details itself. Explain: “PENDING reserves the amount to prevent duplicate
checkout. Only a validated COMPLETED payment counts as paid. Delivery is also required
before the sale order becomes completed.” Show a review only after both are done.

## Role 3: storage manager — negotiation and real arrival

Screens: dashboard, warehouses/units, requests and allocations. Requirements: FR-STORE.

Create a warehouse unit with a specific location such as “Mirpur 12”. Explain its composite
key `(WarehouseID, UnitNo)`: the number alone is not a global identifier.

“STORES relates the batch, unit and authorizing manager. For farmer storage, RequestedByBuyerID
is NULL because there need not be a sale yet. For buyer storage it identifies the buyer.”

Request storage, counter the rate and accept. Point out IN_TRANSIT and the empty DateIn:
agreement reserves space; it does not mean the crop has arrived. After the driver delivers,
show ACTIVE, DateIn and the fee. Try release while unpaid, then settle through the appropriate
farmer/buyer SSLCommerz entry point. Early release needs the other party's approval.

## Role 4: driver — transport and notifications

Screen: assignment dashboard. Requirement: FR-TRANS.

Claim the trip with an available vehicle, then advance through pickup and transit to delivery.
“ASSIGNED_TO relates a request, vehicle and personnel. The service checks combined vehicle
capacity. Delivery, assignment completion and vehicle availability update together.”

Explain the two branches in `trg_transport_notification`:

- Storage inbound: STORES → HARVEST_BATCH → FARM gives the farmer; the allocation gives
  the optional buyer and manager. Notify the farmer and manager, plus the buyer when present.
- Sale delivery: SALE_ORDER → BID → HARVEST_BATCH → FARM gives the buyer and farmer.
  There is no storage manager to notify.

Use cash-on-delivery for a separate demonstration; do not describe an unconfirmed advance
checkout as paid. Storage inbound activates the allocation and does not collect sale cash.

## Role 5: admin — verification and PL/SQL reports

Screens: dashboard, users, farm verification, prices, complaints and reports.
Requirements: FR-AUTH, FR-FARM, FR-PRICE, FR-FEEDBACK, FR-REPORT.

Approve a pending farm and show its notification/badge. Enter a daily price; explain the
composite uniqueness of crop, ARAT and date. Open the six report choices and run at least
two with useful data. “The package opens a SYS_REFCURSOR; Node reads it in batches, closes
the cursor, and returns a bounded JSON array.”

## SQL to have open

| Course topic | Source to explain |
|---|---|
| Tables and constraints | `database/01_create_tables.sql` — inspect only; do not rerun on live data |
| Joins, grouping, subqueries, views | `database/04_views.sql`, `06_advanced_queries.sql` |
| Object type and methods | t_address in `01_create_tables.sql`; profile query in auth.service.js |
| PL/SQL, procedures, functions, cursors, exceptions | `02_business_rules.sql`, `05_plsql_layer.sql` |
| Sequences and indexes | `01_schema_automation.sql` |
| Before/after validation and notification triggers | `02_trigger_layer.sql` |
| Transaction boundaries and rollback | service modules; `server/test/workflows.js` |

These database topics match the supplied CSE-302 plan: queries/joins/constraints and
functions (Weeks 2–7), views/subqueries (8), object types/indexing (9), PL/SQL/procedures/
cursors/exceptions (10), and triggers/sequences/indexes (11). Do not present the JavaScript
test framework or external gateway as an additional Oracle syllabus requirement.

Show the existing guarded trigger queries rather than nine ID inserters. Most runtime
INSERTs now use sequence.NEXTVAL directly, with RETURNING to get the generated key. USERS
retains one combined key/email-preparation trigger. Multi-step workflows stay in service
transactions, avoiding a large trigger that tries to run the whole business process.

## Final rehearsal checklist

- [ ] Verify database health and run the tests in TESTING.md.
- [ ] Prepare fresh, in-window listings; old seed bidding dates may be closed.
- [ ] Prepare one farmer-storage and one buyer-storage example, each with a named unit.
- [ ] Complete a real hosted sandbox payment and verify return/record for all three payment entry points.
- [ ] Open the SQL files before presenting; never run reset, seed or migration scripts during the walkthrough.
- [ ] Have each member explain one query, one integrity rule and their screens without reading this guide.
- [ ] Rehearse once on the presentation machine and record any remaining issues.

Do not claim full production deployment, automated ministry verification, external SMS,
GPS tracking, load testing or completed hosted payments based solely on these regression tests.
