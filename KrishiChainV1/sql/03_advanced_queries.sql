-- =====================================================================
-- KrishiChain V1 | 03_advanced_queries.sql
--
-- Ten advanced queries. Read-only: nothing here modifies data.
-- Run as `krishichain_demo`, AFTER 02_insert_data.sql.
--
-- HOW TO RUN: put the cursor inside a query and press Ctrl+Enter. That
-- runs that one statement and shows the result in a grid. Every query
-- below is self-contained, so any of them can be run in any order.
--
-- There are no PROMPT or COLUMN ... FORMAT lines. Those are SQL*Plus
-- display directives; they do nothing in the worksheet grid.
--
-- ---------------------------------------------------------------------
-- WHAT EACH ONE USES, AND WHAT IT SHOULD RETURN
--
--   Q1   five tables, joined on three columns                  5 rows
--   Q2   RANK() OVER (...) over an aggregate                   5 rows
--   Q3   GROUP BY with HAVING                                  3 rows
--   Q4   NOT EXISTS anti-join                                  1 row
--   Q5   LAG() OVER (...) — the previous month                 5 rows
--   Q6   self-join on the arat tree         [recursive #1]     5 rows
--   Q7   CONNECT BY on the outbid chain     [recursive #2]    15 rows
--   Q8   joins into a weak entity           [weak entity #2]   5 rows
--   Q9   the STORES ternary + its payments  [ternary #1]       7 rows
--   Q10  the ASSIGNED_TO ternary            [ternary #2]       5 rows
--
-- Every query joins at least two tables. Q6 and Q7 read the same kind of
-- self-referencing foreign key two different ways — a join for one level,
-- CONNECT BY for the whole chain — which is worth being able to contrast.
--
-- Q6 to Q10 are the ones that show off the ER design. Between them they
-- cover both recursive relationships, both weak entities, both ternary
-- relationships, the aggregation, and the specialization.
--
-- An empty result means the data was changed, not that the query is wrong.
--
-- ---------------------------------------------------------------------
-- One Oracle 11g limit worth knowing: there is no FETCH FIRST n ROWS.
-- Row-limiting has to use ROWNUM inside an inline view instead.
-- =====================================================================


-- =====================================================================
-- Q1 — DID THE FARMER BEAT THE MARKET?
--
-- For every completed sale: what the farmer got, against that day's
-- published arat price for the same crop, and against the crop's floor.
-- This is the whole reason the project exists — the middleman is meant
-- to stop being able to hide the market rate.
--
-- Note the join to DAILY_MARKET_PRICE matches on THREE columns: crop,
-- arat and date. The same crop is priced differently at different arats
-- on the same day, so all three are needed to find the right row.
-- =====================================================================
SELECT c.CropName             AS crop,
       so.OrderDate           AS sold_on,
       so.AcceptedPricePerKg  AS farmer_got,
       dmp.PricePerKg         AS market_price,
       c.BasePrice            AS floor_price,
       CASE WHEN so.AcceptedPricePerKg > dmp.PricePerKg
            THEN 'BEAT MARKET'
            ELSE 'BELOW MARKET'
       END                    AS verdict
FROM   SALE_ORDER so
JOIN   BID b            ON b.BidID    = so.BidID
JOIN   HARVEST_BATCH hb ON hb.BatchID = b.BatchID
JOIN   CROP c           ON c.CropID   = hb.CropID
JOIN   DAILY_MARKET_PRICE dmp ON  dmp.CropID    = hb.CropID
                             AND  dmp.AratID    = hb.AratID
                             AND  dmp.PriceDate = TRUNC(so.OrderDate)
ORDER  BY so.SaleOrderID;


-- =====================================================================
-- Q2 — WHICH FARMERS EARNED THE MOST
--
-- Total sales per farmer, ranked.
--
-- RANK() is a window function: it numbers the rows of the result without
-- collapsing them, and here it ranks on SUM(...) — an aggregate that the
-- GROUP BY has already worked out. Ties would share a rank.
-- =====================================================================
SELECT u.FirstName || ' ' || u.LastName  AS farmer,
       u.District                        AS district,
       COUNT(so.SaleOrderID)             AS orders,
       SUM(so.TotalAmount)               AS total_earned,
       RANK() OVER (ORDER BY SUM(so.TotalAmount) DESC) AS rank_by_earnings
FROM   SALE_ORDER so
JOIN   BID b            ON b.BidID    = so.BidID
JOIN   HARVEST_BATCH hb ON hb.BatchID = b.BatchID
JOIN   FARM f           ON f.FarmID   = hb.FarmID
JOIN   USERS u          ON u.UserID   = f.FarmerID
GROUP  BY u.FirstName, u.LastName, u.District
ORDER  BY rank_by_earnings;


-- =====================================================================
-- Q3 — WHICH CROPS ATTRACT THE MOST BIDDING
--
-- Bidding activity per crop, keeping only crops that drew three bids or
-- more. Two of the five crops are filtered out, so the HAVING clause is
-- visibly doing something.
--
-- WHERE cannot be used for this: it filters individual rows before they
-- are grouped, and the test here is on COUNT(*), which does not exist
-- until after grouping. That is what HAVING is for.
-- =====================================================================
SELECT c.CropName                      AS crop,
       COUNT(b.BidID)                  AS total_bids,
       ROUND(AVG(b.BidPricePerKg), 2)  AS average_bid,
       MAX(b.BidPricePerKg)            AS highest_bid
FROM   BID b
JOIN   HARVEST_BATCH hb ON hb.BatchID = b.BatchID
JOIN   CROP c           ON c.CropID   = hb.CropID
GROUP  BY c.CropName
HAVING COUNT(b.BidID) >= 3
ORDER  BY total_bids DESC;


-- =====================================================================
-- Q4 — LOTS NOBODY BID ON
--
-- Produce sitting listed with no interest at all, and whose farm it is
-- sitting on. The one an arat operator would actually act on.
--
-- NOT EXISTS is an anti-join: keep the batch only when the subquery finds
-- nothing. Batch 8 is in the seed specifically so this returns something
-- rather than an empty grid.
--
-- Reaching the farmer's name takes two hops, because a batch belongs to a
-- farm and the farm belongs to the farmer — there is no FarmerID on
-- HARVEST_BATCH, and there should not be. That would be the same fact
-- stored twice.
-- =====================================================================
SELECT hb.BatchID                       AS batch,
       c.CropName                       AS crop,
       u.FirstName || ' ' || u.LastName  AS farmer,
       f.FarmName                       AS farm,
       f.District                       AS district,
       hb.TotalQuantity                 AS quantity_kg,
       hb.MinimumPrice                  AS asking_price,
       hb.Status                        AS status
FROM   HARVEST_BATCH hb
JOIN   CROP c  ON c.CropID = hb.CropID
JOIN   FARM f  ON f.FarmID = hb.FarmID
JOIN   USERS u ON u.UserID = f.FarmerID
WHERE  NOT EXISTS (SELECT 1
                     FROM BID b
                    WHERE b.BatchID = hb.BatchID)
ORDER  BY hb.BatchID;


-- =====================================================================
-- Q5 — IS THIS CROP'S PRICE RISING OR FALLING?
--
-- The monthly average price for one crop at one arat, with the previous
-- month beside it. A farmer deciding whether to sell now or hold in
-- storage needs exactly this.
--
-- LAG() is a window function: it reaches back to the PREVIOUS row of the
-- result and returns a value from it, which is what turns a column of
-- monthly averages into a trend. The earliest month has no previous row,
-- so it comes back empty.
--
-- The WHERE clause pins this to one crop at one arat on purpose. Without
-- it, LAG would happily compare Potato's January to Onion's February,
-- because it just walks whatever order the rows are in.
--
-- Change 'Potato' to any of Aman Rice, Lentil, Onion or Mustard Seed to
-- see a different shape — the seed gives each crop its own trend.
-- =====================================================================
SELECT c.CropName                        AS crop,
       va.AratName                       AS arat,
       TO_CHAR(dmp.PriceDate, 'YYYY-MM') AS price_month,
       ROUND(AVG(dmp.PricePerKg), 2)     AS average_price,
       LAG(ROUND(AVG(dmp.PricePerKg), 2)) OVER (
           ORDER BY TO_CHAR(dmp.PriceDate, 'YYYY-MM')) AS previous_month
FROM   DAILY_MARKET_PRICE dmp
JOIN   CROP c          ON c.CropID  = dmp.CropID
JOIN   VIRTUAL_ARAT va ON va.AratID = dmp.AratID
WHERE  c.CropName = 'Potato'
  AND  va.AratID  = 1
GROUP  BY c.CropName, va.AratName, TO_CHAR(dmp.PriceDate, 'YYYY-MM')
ORDER  BY price_month;


-- =====================================================================
-- Q6 — WHICH ARAT REPORTS TO WHICH      [recursive relationship #1]
--
-- VIRTUAL_ARAT.ParentAratID is a foreign key pointing back at
-- VIRTUAL_ARAT itself, so an arat can report to another arat. One table,
-- holding a relationship between its own rows.
--
-- To read that relationship you join the table TO ITSELF, giving the two
-- copies different aliases so Oracle can tell them apart. Here `child` is
-- the arat and `parent` is the one above it. This is the standard way to
-- follow a self-referencing foreign key.
--
-- The join to the parent must be a LEFT JOIN. The top-level arat has no
-- parent, and an inner join would silently drop the root of the whole
-- hierarchy — which is exactly the row you least want to lose.
--
-- The second LEFT JOIN is for the same reason: an arat with no batches
-- yet should still appear, showing zero.
-- =====================================================================
SELECT child.AratName                  AS arat,
       child.District                  AS district,
       parent.AratName                 AS reports_to,
       COUNT(hb.BatchID)               AS batches_listed,
       NVL(SUM(hb.TotalQuantity), 0)   AS volume_kg
FROM   VIRTUAL_ARAT child
LEFT   JOIN VIRTUAL_ARAT parent ON parent.AratID = child.ParentAratID
LEFT   JOIN HARVEST_BATCH hb    ON hb.AratID     = child.AratID
GROUP  BY child.AratName, child.District, parent.AratName
ORDER  BY parent.AratName NULLS FIRST, child.AratName;


-- =====================================================================
-- Q7 — A BIDDING WAR, REPLAYED          [recursive relationship #2]
--
-- The second self-referencing table. When a bid is beaten, the new bid
-- records which bid it displaced in PreviousBidID, so a whole bidding war
-- is a chain living inside one table.
--
-- Q6 read its self-reference with a join, which shows one level: an arat
-- and its parent. This one uses CONNECT BY instead, which follows the
-- chain all the way down however long it is — you do not have to know the
-- depth in advance, and a join cannot do that.
--
--   START WITH  picks where each chain begins: a bid that displaced nothing
--   CONNECT BY  says how to step from one bid to the bid that beat it
--   LEVEL       is the round number — 1 is the opening bid
--   NOCYCLE     stops the query looping forever if the data ever
--               contained a loop
--
-- The three joins are all many-to-one, so each bid still appears exactly
-- once and the chain is unaffected. Joining a one-to-many table here would
-- duplicate rows and corrupt the walk.
--
-- The last row of each chain is the bid still standing — the one the
-- farmer can actually award.
-- =====================================================================
SELECT b.BatchID                        AS batch,
       c.CropName                       AS crop,
       LEVEL                            AS bid_round,
       u.FirstName || ' ' || u.LastName  AS bidder,
       b.BidPricePerKg                  AS price_per_kg,
       b.RequestedQuantity              AS quantity_kg,
       b.Status                         AS status
FROM   BID b
JOIN   USERS u          ON u.UserID  = b.BuyerID
JOIN   HARVEST_BATCH hb ON hb.BatchID = b.BatchID
JOIN   CROP c           ON c.CropID   = hb.CropID
START WITH b.PreviousBidID IS NULL
CONNECT BY NOCYCLE PRIOR b.BidID = b.PreviousBidID
ORDER  BY batch, bid_round;


-- =====================================================================
-- Q8 — THE PLATFORM AGAINST THE PHYSICAL MARKET    [weak entity #2]
--
-- What a crop fetched at a real bazar on a given day, beside the
-- platform's own published price for the same crop on the same day.
--
-- BAZAR_DAILY_RECORD is a weak entity: a row of it means nothing on its
-- own, because "the 14th of the month" is not a record until you say
-- which bazar it belongs to. Its primary key is therefore
-- (BazarID, RecordDate, CropID) — the owner, the date, and the crop.
-- CropID has to be in the key because a bazar trades several crops on
-- the same day; bazar 1 in the seed records three crops on one date,
-- which a two-column key would have made impossible.
-- =====================================================================
SELECT c.CropName      AS crop,
       pb.BazarName    AS bazar,
       pb.District     AS district,
       bdr.RecordDate  AS record_date,
       bdr.PricePerKg  AS bazar_price,
       dmp.PricePerKg  AS platform_price,
       bdr.Revenue     AS bazar_day_revenue
FROM   BAZAR_DAILY_RECORD bdr
JOIN   PHYSICAL_BAZAR pb ON pb.BazarID = bdr.BazarID
JOIN   CROP c            ON c.CropID   = bdr.CropID
JOIN   DAILY_MARKET_PRICE dmp ON  dmp.CropID    = bdr.CropID
                             AND  dmp.PriceDate = bdr.RecordDate
ORDER  BY c.CropName;


-- =====================================================================
-- Q9 — WHO IS STORING WHAT, AND HAS THE FEE BEEN PAID?   [ternary #1]
--
-- STORES is a ternary relationship: it ties together a batch, a storage
-- unit and the manager who authorised the allocation. All three at once,
-- in one table.
--
-- The manager column is the point. Split this into "batch is in unit"
-- plus "manager runs warehouse" and you lose the record of who agreed to
-- this particular allocation — the first thing anyone asks when stored
-- produce goes missing.
--
-- Two more things visible here:
--   * STORAGE_UNIT is a weak entity, so reaching a unit needs BOTH
--     WarehouseID and UnitNo — hence the two-column join condition.
--   * STORAGE_PAYMENT is a LEFT JOIN because a fee may be unpaid, and
--     it references the ALLOCATION, not the batch or the unit or the
--     manager. The fee is owed for the three-way arrangement as one
--     thing. That is the aggregation.
-- =====================================================================
SELECT s.AllocationID     AS alloc,
       w.WarehouseName    AS warehouse,
       s.UnitNo           AS unit,
       su.Capacity        AS unit_capacity,
       c.CropName         AS crop,
       u.FirstName || ' ' || u.LastName AS authorised_by,
       s.QuantityStored   AS stored_kg,
       s.StorageFee       AS fee_owed,
       sp.Amount          AS fee_paid
FROM   STORES s
JOIN   WAREHOUSE w      ON w.WarehouseID  = s.WarehouseID
JOIN   STORAGE_UNIT su  ON su.WarehouseID = s.WarehouseID
                       AND su.UnitNo      = s.UnitNo
JOIN   USERS u          ON u.UserID       = s.ManagerID
JOIN   HARVEST_BATCH hb ON hb.BatchID     = s.BatchID
JOIN   CROP c           ON c.CropID       = hb.CropID
LEFT   JOIN STORAGE_PAYMENT sp ON sp.AllocationID = s.AllocationID
ORDER  BY s.AllocationID;


-- =====================================================================
-- Q10 — WHO DROVE WHAT                                   [ternary #2]
--
-- The second ternary. ASSIGNED_TO ties a transport request to a vehicle
-- and to a driver — again, one fact about three things, not three
-- separate facts.
--
-- This also shows the specialization at work. A driver's details are
-- split across two tables: the person is a row in USERS, the
-- driver-specific columns are a row in TRANSPORT_PERSONNEL, and the two
-- share the same key. So joining USERS on tp.PersonnelID is correct —
-- PersonnelID and UserID are the same number by design.
--
-- Worth checking in the result: vehicle_capacity should be at least
-- load_kg on every row (BR-18). Nothing in the database enforces that,
-- because it compares two tables.
-- =====================================================================
SELECT tr.TransportID        AS trip,
       v.VehicleNo           AS vehicle,
       v.VehicleType         AS vehicle_type,
       v.Capacity            AS vehicle_capacity,
       so.AcceptedQuantity   AS load_kg,
       u.FirstName || ' ' || u.LastName AS driver,
       tp.LicenseNo          AS licence,
       tr.DeliveryStatus     AS status
FROM   ASSIGNED_TO a
JOIN   TRANSPORT_REQUEST tr   ON tr.TransportID = a.TransportID
JOIN   VEHICLE v              ON v.VehicleID    = a.VehicleID
JOIN   TRANSPORT_PERSONNEL tp ON tp.PersonnelID = a.PersonnelID
JOIN   USERS u                ON u.UserID       = tp.PersonnelID
JOIN   SALE_ORDER so          ON so.SaleOrderID = tr.SaleOrderID
ORDER  BY tr.TransportID;


-- =====================================================================
-- End of 03_advanced_queries.sql — ten queries, all returning rows,
-- nothing modified.
-- =====================================================================
