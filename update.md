# KrishiChain update log

## Branch

`branch1`

This branch contains review-driven fixes only. The `master` branch was not modified.

## Bugs found and fixed

### 1. Concurrent bid awards could use stale state

- **Area:** Backend transaction correctness
- **Problem:** `awardBid()` read the bid and batch before locking the batch. A second request could wait for another award to finish and then continue using old `ACTIVE` and available-quantity values.
- **Impact:** Concurrent requests could create an extra sale order or oversell a batch.
- **Fix:** The authoritative bid/batch query now locks both rows with `SELECT ... FOR UPDATE` before validating their state.

### 2. Invalid route IDs reached Oracle

- **Area:** Backend validation
- **Problem:** Route parameters were converted with `Number(...)` without rejecting `NaN`, decimals, zero or negative values.
- **Impact:** Malformed URLs could produce Oracle errors and HTTP 500 responses.
- **Fix:** Added `positiveIntegerParam()` and applied it to farmer, buyer and storage identifier routes. Invalid IDs now return HTTP 400.

### 3. Non-JSON API responses broke frontend error reporting

- **Area:** Frontend API client
- **Problem:** The client always parsed non-empty responses as JSON. HTML or plain-text infrastructure responses hid the real HTTP error behind a parsing exception.
- **Fix:** JSON parsing is guarded and falls back to `Request failed (<status>)`.

### 4. Network failures had an unhelpful browser error

- **Area:** Frontend API client
- **Fix:** An unreachable API now produces `Cannot reach the KrishiChain server. Check that the API is running.`

### 5. Registration success state was discarded

- **Area:** Frontend authentication flow
- **Problem:** Registration navigated to login with `justRegistered: true`, but the login page did not use it.
- **Fix:** Login displays an accessible success message after registration.

### 6. Documentation no longer matched the implementation

- Client README said storage was not built although its routes and pages exist.
- Server README reported three implemented transactions instead of four.
- Schema documentation reported 26 tables although `STORAGE_PAYMENT` makes 27.
- The PRD definition of done still reported 24 core tables.
- Updated all affected documentation.

## Verification completed

- Client production build: passed.
- Client lint: passed with no warnings after separating the hook from the provider component.
- All server JavaScript files: passed `node --check`.
- Repository diff reviewed to ensure changes are limited to this branch.

## Still remaining

- Full Oracle integration and concurrency testing requires the configured Oracle 11g XE database and Instant Client.
- Add automated regression tests for simultaneous bid awards and invalid route parameters.
- Complete transaction #6 once payment-provider confirmation rules are resolved.

## Completion update — admin, logistics and setup reliability

- Added an administrator dashboard with totals, account controls, daily prices,
  complaint handling, and atomic transport assignment.
- Added a transport-personnel dashboard with route/vehicle details and delivery
  status transitions. Delivery releases the vehicle and completes the order.
- Added API root information and schema readiness to `/api/health`.
- Added `database/00_prepare_schema.sql` for XE's `ORA-01950` tablespace issue.
- Missing schema (`ORA-00942`) now returns an actionable HTTP 503 instead of an
  opaque server error.
- Admin and transport users now have protected functional routes and navigation.

Payment-provider confirmation is still TBD in the PRD, so no automatic money-
transfer rule was invented. Existing Oracle payment constraints remain active.

### Storage allocation integration fix

- Fixed the Allocations page calling removed endpoint `/api/storage/awaiting`.
- It now calls `/api/storage/awaiting/leg1` and submits the required
  `minimumStorageDays` field used by the manager-to-farmer consent workflow.
- Updated success messaging to describe a pending proposal and estimated fee,
  rather than incorrectly claiming an immediate allocation.
