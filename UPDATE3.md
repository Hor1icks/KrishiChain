# Project Update-3 — sequence, trigger and indexing map

Update-3 adds the Week-11 topics from the CSE-302 work plan without changing
the existing user workflows.

| Topic | Implementation | Demonstration |
|---|---|---|
| Sequence | 18 table-specific sequences in `database/01_schema_automation.sql` | `user_sequences` in `database/08_update3_demo.sql` |
| Trigger | 9 preparation, validation, state-guard and notification triggers in `database/02_trigger_layer.sql` | Rollback-only checks in `database/11_trigger_demo.sql` |
| Indexing | 31 ordinary indexes cover common foreign-key joins and filters | `user_indexes` and `user_ind_columns` |
| View | `V_ORDER_DETAILS` and `V_STORAGE_DETAILS` centralize repeated joins | Farmer/buyer orders and storage allocation pages |

These additions stay within Weeks 8 and 11 of
`Work Plan CSE-302 Spring 2026.pdf`. The existing packages, procedures,
cursors, exception handling, functions, subqueries, joins and constraints
continue to cover the earlier syllabus weeks.

## The 9 triggers

| Trigger | Timing | Purpose |
|---|---|---|
| `trg_users_prepare` | Before user insert/email update | Generates the one example trigger-based ID and normalizes email |
| `trg_batch_listing_guard` | Before batch insert/update | Checks crop base price and listing window |
| `trg_bid_guard` | Before bid insert | Checks auction time, price, quantity, and self-bidding |
| `trg_stores_status_guard` | Before allocation status update | Allows only valid storage transitions and matching dates |
| `trg_transport_status_guard` | Before delivery status update | Allows only valid trip transitions and requires a delivery date |
| `trg_review_guard` | Before review insert | Requires a completed sale order |
| `trg_bid_notification` | After bid insert | Notifies the farmer |
| `trg_transport_notification` | After delivery status update | Notifies the farmer, buyer, and storage manager as applicable |
| `trg_farm_verify_notification` | After farm verification update | Notifies the farmer of the decision |

The authenticated `/api/notifications` endpoints and the navigation-bar bell
show these rows and let the current user mark one as read.

## Why the design stays simple

- Seed rows retain their readable IDs (`1`, `2`, `3`, ...).
- Runtime IDs begin at `1001`, outside the seed range.
- Services use `seq_*_id.NEXTVAL` in the INSERT and `RETURNING ... INTO` to
  read the generated value. This removes 17 repetitive ID-only triggers.
- `trg_users_prepare` is the one automatic-ID example and also normalizes email.
- `STORAGE_UNIT.UnitNo` remains a per-warehouse partial key and is therefore
  not assigned from a global sequence.
- Business workflows remain explicit transactions in the service layer.
  Triggers validate a row or create a notification; they do not create an
  order, take payment, allocate storage, or complete a delivery workflow.
- Concise cross-table checks protect batch listings, bids, and reviews.
- State guards protect storage and transport transitions.
- Notification triggers cover new bids, transport updates, and farm
  verification decisions without querying their own mutating table.
- Primary-key and UNIQUE indexes created by Oracle are not duplicated.
- Repeated order and storage joins now live in two ordinary views, leaving the
  service queries shorter without changing their response fields.
- Rows whose status, payment balance, capacity, or partial key is being
  changed are locked inside the existing transaction to preserve the same
  behavior when two requests arrive together.

## Build and demonstration

The build order is:

```text
00_reset.sql
01_create_tables.sql
01_schema_automation.sql
02_trigger_layer.sql
02_business_rules.sql
03_insert_data.sql
04_views.sql
05_plsql_layer.sql
```

After rebuilding, run:

```bash
./db.sh database/08_update3_demo.sql
./db.sh database/11_trigger_demo.sql
```

The first demonstration reports all sequences, triggers and application
indexes. The trigger demonstration exercises all 9 triggers and rolls every
temporary row or state change back.

On an existing Docker volume, normal `./start.sh` detects the missing
Update-3 objects and applies only the additive automation, trigger and view
scripts. `database/10_trigger_migration.sql` removes the old repetitive trigger
objects only; it does not alter tables or data. The startup check installs and
validates all 9 replacements before removing legacy triggers.
