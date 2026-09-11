# Verification and remaining acceptance checks

These checks do not rebuild the database or change its tables, attributes, relationships,
constraints, triggers or views. Do not run `start.sh --rebuild`, reset or seed scripts on
the working database to prepare a test.

## Run the checks

From the repository root, in Bash:

```bash
source /home/mushy/.nvm/nvm.sh
# Use your own Instant Client directory if it differs.
export LD_LIBRARY_PATH=/home/mushy/oracle/instantclient_19_26:${LD_LIBRARY_PATH:-}
cd client
npm ci
npm run build
npm run lint
cd ../server
npm ci
npm run check:db
npm run test:workflows
npm run test:browser
npm run check:sandbox -- --browser
```

Oracle must already be running, with `server/.env` configured. Start the existing container
with `docker start krishichain-oracle` if necessary; wait for its listener to become ready.
Browser checks use installed Google Chrome. For another compatible Chromium executable,
set `CHROME_PATH` to its absolute path. No existing API/UI process is stopped or replaced;
tests start their own API on a temporary loopback port.

## What each command proves

| Command | Coverage | Limit |
|---|---|---|
| `check:db` | Live object counts, invalid objects, disabled triggers | Read-only; not a business-workflow test |
| `test:workflows` | Real Express routes, Oracle SQL/packages/triggers, role access, fixtures and assertions | Gateway responses mocked; one serialized database session |
| `test:browser` | Workflow checks plus five-role login and navigation, all 29 page components, base-price hint, draft creation and publishing | Functional browser check, not a visual/accessibility audit or load test |
| `check:sandbox -- --browser` | Real credentials, sandbox session creation and hosted checkout loading | Opens one unpaid sandbox session; does not submit payment or create a database payment |

The workflow runner covers:

- Registration and profile retrieval for all five roles; unauthenticated and wrong-role rejection.
- Late registration failure and late award failure, with earlier changes rolled back.
- Draft scheduling, date validation, ownership, repeat publication rejection and direct-SQL base-price protection.
- Bid quantity/price limits, bid notification ownership and duplicate-award rejection.
- Invalid transport/storage transitions, driver assignment, pickup, transit and arrival.
- Farmer-only storage without a buyer and buyer storage linked to a sale order; exact notification recipients.
- Storage counteroffers, date-in only at arrival, unit location tags and publication after storage arrival.
- Sale and both storage checkout entry points; partial payments, duplicate callback, amount/currency/transaction mismatch,
  session-open failure, cancellation, and correct storage callback redirects.
- Pending payments cannot release storage or complete orders; paid orders complete only after delivery,
  including the buyer-storage delivery endpoint; cash-on-delivery still works.
- Completed-order reviews, farm verification, all role read endpoints and all six cursor reports.

## Fixture safety

`server/test/workflows.js` creates unique temporary users and records, reads existing crop/ARAT
reference data and uses real application SQL. Only its own process replaces service commits
with savepoints. A final Oracle rollback removes every test row, including trigger-generated
notifications. The script checks that its users are gone afterwards. It never calls the
running application's write endpoints or an external payment provider. The global
abandoned-checkout expiry sweep is disabled in this test process to avoid touching other
users' payments; that sweep is not covered by these fixtures.

Oracle sequences are not transactional: tests consume IDs and leave normal sequence gaps.
Run serially and preferably when the demo is idle. This harness is not a proof of concurrent
transaction behavior, and its savepoint adapter is not a test of the production commit helper.
The older SQL demo scripts assume particular seed states; use them on a disposable teaching
database, not arbitrary live records.

## Verification recorded on 12 September 2026

- Live inventory: 27 tables, 8 views, 18 sequences, 9 enabled/valid triggers, 3 packages,
  1 standalone procedure, 1 object type; no invalid objects.
- There are 31 explicit application indexes. `USER_INDEXES` lists 80 total entries:
  76 NORMAL indexes and 4 Oracle LOB indexes. Do not call all 80 application-created indexes.
- All 17 workflow groups passed; the additional five-role Chrome group passed as well.
  Checks ran against Oracle XE 11g, not an in-memory SQL substitute, and fixtures were rolled back.
- Production client builds successfully. Lint reports two existing warnings in Reports.jsx
  and AuthContext.jsx; neither is a build error.
- The real SSLCommerz sandbox accepted session initialization and its easyCheckout page loaded.
  No hosted payment was submitted by these checks.

## Remaining human acceptance checks

1. Use sandbox credentials only (`SSLCZ_SANDBOX=true`). Never use a real card for the demo.
2. In the normal application, create an ADVANCE sale order. Open the hosted checkout from
   the buyer's order page. Complete a sandbox test payment using the provider's test options.
3. Confirm the browser returns to buyer payments, PAYMENT becomes COMPLETED, and a second
   callback does not create another payment. A prepaid but undelivered order must remain incomplete.
4. Repeat for an ACTIVE farmer storage allocation and an ACTIVE buyer storage allocation.
   Confirm the return lands on the correct role's storage page. Test cancellation too.
5. If confirmation fails, retain the transaction reference and reconcile with the sandbox
   dashboard before trying again. An unconfirmed callback does not prove that no money moved.
6. Rehearse the presentation on the actual classroom machine. Check network access, readable
   SQL output and fresh bidding windows. Assign each section in PRESENTATION.md to a team member.

Localhost callbacks require checkout to run on the same machine as the API; SSLCommerz's
server-to-server IPN cannot reach localhost. A public deployment needs separately configured
public HTTPS callback/IPN URLs and reconciliation; those are not implemented by this testing pass.

Validation checks follow the provider's
[official integration documentation](https://developer.sslcommerz.com/doc/v4/index.html):
match the verified transaction ID, original currency and amount to the local payment record.
