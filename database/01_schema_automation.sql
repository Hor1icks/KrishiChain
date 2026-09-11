SET SQLBLANKLINES ON

PROMPT
PROMPT ============================================================
PROMPT  KrishiChain sequences and indexes
PROMPT ============================================================

-- IDs 1-1000 are reserved for the fixed demonstration data in
-- 03_insert_data.sql. Runtime rows begin at 1001, so rebuilding the seed
-- never consumes or conflicts with a sequence value.

CREATE SEQUENCE seq_users_id            START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_crop_category_id     START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_crop_id              START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_farm_id              START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_virtual_arat_id      START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_harvest_batch_id     START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_warehouse_id         START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_stores_id            START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_bid_id               START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_sale_order_id        START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_payment_id           START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_vehicle_id           START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_transport_request_id START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_assigned_to_id       START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_physical_bazar_id    START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_review_id            START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_complaint_id         START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_notification_id      START WITH 1001 INCREMENT BY 1 NOCACHE;

-- Primary-key and UNIQUE constraints already own their indexes. These are
-- the remaining foreign-key and common search paths used by the application.

CREATE INDEX ix_crop_category          ON CROP (CategoryID);
CREATE INDEX ix_farm_farmer            ON FARM (FarmerID);
CREATE INDEX ix_farm_verify_queue       ON FARM (VerificationStatus, VerificationRequestedAt);
CREATE INDEX ix_arat_parent            ON VIRTUAL_ARAT (ParentAratID);
CREATE INDEX ix_batch_farm             ON HARVEST_BATCH (FarmID);
CREATE INDEX ix_batch_crop             ON HARVEST_BATCH (CropID);
CREATE INDEX ix_batch_arat_status      ON HARVEST_BATCH (AratID, Status, BiddingEndTime);
CREATE INDEX ix_warehouse_manager      ON WAREHOUSE (ManagerID);

CREATE INDEX ix_stores_batch_status    ON STORES (BatchID, AllocationStatus);
CREATE INDEX ix_stores_unit_status     ON STORES (WarehouseID, UnitNo, AllocationStatus, DateOut);
CREATE INDEX ix_stores_manager         ON STORES (ManagerID);
CREATE INDEX ix_stores_farmer          ON STORES (RequestedByFarmerID);
CREATE INDEX ix_stores_buyer           ON STORES (RequestedByBuyerID);
CREATE INDEX ix_stores_order           ON STORES (SaleOrderID);

CREATE INDEX ix_bid_batch_status_price ON BID (BatchID, Status, BidPricePerKg);
CREATE INDEX ix_bid_buyer_time         ON BID (BuyerID, BidTime);
CREATE INDEX ix_bid_previous           ON BID (PreviousBidID);

CREATE INDEX ix_payment_order_status   ON PAYMENT (SaleOrderID, PaymentType, PaymentStatus);
CREATE INDEX ix_payment_buyer          ON PAYMENT (BuyerID);
CREATE INDEX ix_payment_farmer         ON PAYMENT (FarmerID);
CREATE INDEX ix_payment_alloc_status   ON PAYMENT (AllocationID, PaymentType, PaymentStatus);

CREATE INDEX ix_assigned_vehicle       ON ASSIGNED_TO (VehicleID);
CREATE INDEX ix_assigned_person_status ON ASSIGNED_TO (PersonnelID, AssignmentStatus);
CREATE INDEX ix_transport_type_status  ON TRANSPORT_REQUEST (RequestType, DeliveryStatus);

CREATE INDEX ix_dmp_arat_date          ON DAILY_MARKET_PRICE (AratID, PriceDate);
CREATE INDEX ix_dmp_admin              ON DAILY_MARKET_PRICE (LoggedBy);
CREATE INDEX ix_dmp_date_crop          ON DAILY_MARKET_PRICE (PriceDate, CropID);
CREATE INDEX ix_bdr_crop               ON BAZAR_DAILY_RECORD (CropID);
CREATE INDEX ix_complaint_order        ON COMPLAINT (SaleOrderID);
CREATE INDEX ix_complaint_admin        ON COMPLAINT (HandledByAdminID);
CREATE INDEX ix_notification_user_read ON NOTIFICATION (UserID, IsRead, CreatedAt);

PROMPT
PROMPT Created 18 sequences and 31 indexes.
PROMPT
