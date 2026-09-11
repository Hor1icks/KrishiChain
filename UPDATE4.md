# Update 4 — Storage Transit, Unit Locations and Farm Verification

This update keeps `PAYMENT.PaymentMethod` unchanged and retains every SSLCommerz checkout path.

## Data model

- `STORAGE_MANAGER` now stores only `ManagerID`, `Designation`, and `ShiftSchedule`.
- Unverifiable `QualityGrade` and `MoisturePercentage` were removed from `HARVEST_BATCH`.
- `STORAGE_UNIT.LocationTag` identifies the exact location within a warehouse.
- `FARM` has a simple `PENDING` / `VERIFIED` / `REJECTED` ministry review status.
- `TRANSPORT_REQUEST` can represent either `SALE_DELIVERY` or `STORAGE_INBOUND` and can link to
  a storage allocation.

## Storage workflow

Accepting negotiated storage now changes `STORES.AllocationStatus` to `IN_TRANSIT` and creates or
redirects a transport request. Capacity is reserved, but `DateIn`, physical unit load, batch
`STORED` status, and storage-fee eligibility wait for driver-confirmed delivery. Storage arrival
does not collect COD or complete a sale order.

## Applying to an existing Update 3 database

`./start.sh` detects the old schema and runs `database/09_update4_migration.sql`, refreshes the
views and PL/SQL packages, and adds the two new indexes. A fresh `./start.sh --rebuild` receives
the same shape directly from the normal build chain.

## Admin verification

The Farm Verification page is an oldest-first waiting list. Admin staff can verify or reject a
pending farm. Pending farms can still create batches, list produce, and sell; a verified farm gets
a buyer-visible `Ministry verified` badge.
