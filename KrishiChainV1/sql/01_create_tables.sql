-- =====================================================================
-- KrishiChain V1 | 01_create_tables.sql
--
-- All 28 relations of the Schema Diagram, with their constraints.
-- Run as the `krishichain_demo` user, on an empty schema.
--
-- Run order:  00_reset.sql -> 01_create_tables.sql
--                          -> 02_insert_data.sql
--                          -> 03_advanced_queries.sql
--
-- In SQL Developer press F5 (Run Script), not Ctrl+Enter — this file is a
-- script of many statements, not one statement.
--
-- ---------------------------------------------------------------------
-- WHAT IS AND IS NOT IN THIS FILE
--
-- Present: PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK, NOT NULL, DEFAULT,
-- and four derived (virtual) columns.
--
-- Deliberately absent: explicit CREATE INDEX, sequences, and triggers.
-- Every surrogate primary key is therefore supplied as a literal value by
-- 02_insert_data.sql rather than generated. Oracle still creates a unique
-- index behind each PRIMARY KEY and UNIQUE constraint automatically; what
-- is absent is the extra hand-built index on each foreign-key column.
--
-- Consequence worth knowing: three cross-table business rules have no
-- enforcement in this build, because each needs a trigger to read a
-- second table. 02_insert_data.sql satisfies all three by hand:
--   BR-09  HARVEST_BATCH.MinimumPrice >= CROP.BasePrice
--   BR-11  a bid must be >= the batch minimum and > the current highest
--   BR-18  VEHICLE.Capacity >= the load it is assigned
-- Single-table rules are all enforced, by CHECK constraints below.
--
-- Naming: PK_ / FK_ / UQ_ / CK_ prefixes throughout, so a violation names
-- itself in the error message.
--
-- Text columns that may hold Bengali are VARCHAR2(n CHAR) — character
-- semantics, not bytes, so a 3-byte Bengali glyph still counts as 1.
-- =====================================================================

-- =====================================================================
-- SECTION 1 — IDENTITY AND SPECIALIZATION
--
-- USERS is specialized into five subclasses, total and disjoint: every
-- user is exactly one of them. Implemented as shared-PK subclass tables —
-- each subclass PK is also a FK to USERS — rather than one wide table
-- with a discriminator column.
-- =====================================================================

CREATE TABLE USERS (
  UserID           NUMBER(10)          NOT NULL,
  FirstName        VARCHAR2(50 CHAR)   NOT NULL,
  MiddleName       VARCHAR2(50 CHAR),
  LastName         VARCHAR2(50 CHAR)   NOT NULL,
  Email            VARCHAR2(100 CHAR)  NOT NULL,
  PasswordHash     VARCHAR2(255 CHAR)  NOT NULL,
  Gender           CHAR(1)             NOT NULL,
  DateOfBirth      DATE                NOT NULL,
  HouseNo          VARCHAR2(30 CHAR),
  Road             VARCHAR2(60 CHAR),
  Village          VARCHAR2(100 CHAR),
  Upazila          VARCHAR2(100 CHAR),
  District         VARCHAR2(100 CHAR)  NOT NULL,
  PostalCode       VARCHAR2(10 CHAR),
  RegistrationDate DATE                DEFAULT SYSDATE NOT NULL,
  Status           VARCHAR2(10 CHAR)   DEFAULT 'ACTIVE' NOT NULL,
  Role             VARCHAR2(20 CHAR)   NOT NULL,
  CONSTRAINT PK_USERS PRIMARY KEY (UserID),
  CONSTRAINT UQ_USERS_EMAIL UNIQUE (Email),
  CONSTRAINT CK_USERS_GENDER CHECK (Gender IN ('M','F','O')),
  CONSTRAINT CK_USERS_STATUS CHECK (Status IN ('ACTIVE','BLOCKED','INACTIVE')),
  CONSTRAINT CK_USERS_ROLE CHECK (Role IN ('FARMER','BUYER','ADMIN','STORAGE_MANAGER','TRANSPORT_PERSONNEL'))
);

-- Multivalued attribute {PhoneNo} becomes its own table: one user may
-- have several numbers, so it cannot be a column on USERS.
CREATE TABLE USER_PHONE (
  UserID   NUMBER(10)        NOT NULL,
  PhoneNo  VARCHAR2(20 CHAR) NOT NULL,
  CONSTRAINT PK_USER_PHONE PRIMARY KEY (UserID, PhoneNo),
  CONSTRAINT FK_USERPHONE_USERS FOREIGN KEY (UserID)
    REFERENCES USERS (UserID) ON DELETE CASCADE,
  CONSTRAINT UQ_USER_PHONE_NO UNIQUE (PhoneNo)
);

CREATE TABLE FARMER (
  FarmerID         NUMBER(10)         NOT NULL,
  NID              VARCHAR2(20 CHAR)  NOT NULL,
  BankAccountNo    VARCHAR2(30 CHAR),
  MobileBankingNo  VARCHAR2(20 CHAR),
  ExperienceYears  NUMBER(3),
  CONSTRAINT PK_FARMER PRIMARY KEY (FarmerID),
  CONSTRAINT FK_FARMER_USERS FOREIGN KEY (FarmerID) REFERENCES USERS (UserID),
  CONSTRAINT UQ_FARMER_NID UNIQUE (NID),
  CONSTRAINT CK_FARMER_EXPERIENCE CHECK (ExperienceYears >= 0)
);

CREATE TABLE BUYER (
  BuyerID         NUMBER(10)          NOT NULL,
  BusinessName    VARCHAR2(150 CHAR),
  BuyerType       VARCHAR2(20 CHAR),
  TradeLicenseNo  VARCHAR2(30 CHAR),
  CONSTRAINT PK_BUYER PRIMARY KEY (BuyerID),
  CONSTRAINT FK_BUYER_USERS FOREIGN KEY (BuyerID) REFERENCES USERS (UserID),
  CONSTRAINT UQ_BUYER_LICENSE UNIQUE (TradeLicenseNo),
  CONSTRAINT CK_BUYER_TYPE CHECK (BuyerType IN ('WHOLESALER','RETAILER','EXPORTER','PROCESSOR'))
);

CREATE TABLE ADMIN_STAFF (
  AdminID      NUMBER(10)         NOT NULL,
  EmployeeID   VARCHAR2(20 CHAR)  NOT NULL,
  Designation  VARCHAR2(50 CHAR),
  CONSTRAINT PK_ADMIN_STAFF PRIMARY KEY (AdminID),
  CONSTRAINT FK_ADMIN_USERS FOREIGN KEY (AdminID) REFERENCES USERS (UserID),
  CONSTRAINT UQ_ADMIN_EMPLOYEEID UNIQUE (EmployeeID)
);

CREATE TABLE STORAGE_MANAGER (
  ManagerID   NUMBER(10)        NOT NULL,
  EmployeeID  VARCHAR2(20 CHAR) NOT NULL,
  CONSTRAINT PK_STORAGE_MANAGER PRIMARY KEY (ManagerID),
  CONSTRAINT FK_MANAGER_USERS FOREIGN KEY (ManagerID) REFERENCES USERS (UserID),
  CONSTRAINT UQ_MANAGER_EMPLOYEEID UNIQUE (EmployeeID)
);

CREATE TABLE TRANSPORT_PERSONNEL (
  PersonnelID      NUMBER(10)         NOT NULL,
  LicenseNo        VARCHAR2(30 CHAR)  NOT NULL,
  ExperienceYears  NUMBER(3),
  CONSTRAINT PK_TRANSPORT_PERSONNEL PRIMARY KEY (PersonnelID),
  CONSTRAINT FK_PERSONNEL_USERS FOREIGN KEY (PersonnelID) REFERENCES USERS (UserID),
  CONSTRAINT UQ_PERSONNEL_LICENSE UNIQUE (LicenseNo),
  CONSTRAINT CK_PERSONNEL_EXPERIENCE CHECK (ExperienceYears >= 0)
);

-- =====================================================================
-- SECTION 2 — PRODUCTION AND MARKET LISTING
-- =====================================================================

CREATE TABLE CROP_CATEGORY (
  CategoryID    NUMBER(10)          NOT NULL,
  CategoryName  VARCHAR2(80 CHAR)   NOT NULL,
  Description   CLOB,
  CONSTRAINT PK_CROP_CATEGORY PRIMARY KEY (CategoryID),
  CONSTRAINT UQ_CROP_CATEGORY_NAME UNIQUE (CategoryName)
);

CREATE TABLE CROP (
  CropID         NUMBER(10)          NOT NULL,
  CropName       VARCHAR2(100 CHAR)  NOT NULL,
  CategoryID     NUMBER(10)          NOT NULL,
  Unit           VARCHAR2(20 CHAR)   NOT NULL,
  BasePrice      NUMBER(12,2)        NOT NULL,
  ShelfLifeDays  NUMBER(5),
  Description    CLOB,
  CONSTRAINT PK_CROP PRIMARY KEY (CropID),
  CONSTRAINT FK_CROP_CATEGORY FOREIGN KEY (CategoryID) REFERENCES CROP_CATEGORY (CategoryID),
  CONSTRAINT UQ_CROP_NAME UNIQUE (CropName),
  CONSTRAINT CK_CROP_BASEPRICE CHECK (BasePrice > 0),
  CONSTRAINT CK_CROP_SHELFLIFE CHECK (ShelfLifeDays >= 0)
);

CREATE TABLE FARM (
  FarmID          NUMBER(10)          NOT NULL,
  FarmerID        NUMBER(10)          NOT NULL,
  FarmName        VARCHAR2(100 CHAR)  NOT NULL,
  Area            NUMBER(10,2)        NOT NULL,
  SoilType        VARCHAR2(50 CHAR),
  IrrigationType  VARCHAR2(50 CHAR),
  Location        VARCHAR2(150 CHAR),
  District        VARCHAR2(100 CHAR)  NOT NULL,
  Status          VARCHAR2(15 CHAR)   DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT PK_FARM PRIMARY KEY (FarmID),
  CONSTRAINT FK_FARM_FARMER FOREIGN KEY (FarmerID) REFERENCES FARMER (FarmerID),
  CONSTRAINT CK_FARM_AREA CHECK (Area > 0),
  CONSTRAINT CK_FARM_STATUS CHECK (Status IN ('ACTIVE','INACTIVE'))
);

-- Recursive relationship #1: supervises. An arat may report to a parent
-- arat, so the FK points back at this same table. CK_ARAT_NOT_OWN_PARENT
-- stops the one-node cycle; deeper cycles are avoided by the seed and by
-- querying with CONNECT BY NOCYCLE (see Q7 in 03_advanced_queries.sql).
CREATE TABLE VIRTUAL_ARAT (
  AratID        NUMBER(10)          NOT NULL,
  AratName      VARCHAR2(100 CHAR)  NOT NULL,
  Region        VARCHAR2(80 CHAR),
  District      VARCHAR2(100 CHAR)  NOT NULL,
  Address       VARCHAR2(200 CHAR),
  ContactNo     VARCHAR2(20 CHAR),
  ParentAratID  NUMBER(10),
  CONSTRAINT PK_VIRTUAL_ARAT PRIMARY KEY (AratID),
  CONSTRAINT FK_ARAT_PARENT FOREIGN KEY (ParentAratID) REFERENCES VIRTUAL_ARAT (AratID),
  CONSTRAINT CK_ARAT_NOT_OWN_PARENT CHECK (ParentAratID <> AratID)
);

-- There is no AUCTION entity: the bidding-window attributes live here on
-- the batch being auctioned, and BID references the batch directly.
--
-- AvailableQuantity is a DERIVED attribute, implemented as an Oracle
-- virtual column: it is computed on read, never stored, so it cannot
-- drift out of step with the three quantities it is derived from.
CREATE TABLE HARVEST_BATCH (
  BatchID             NUMBER(10)          NOT NULL,
  FarmID              NUMBER(10)          NOT NULL,
  CropID              NUMBER(10)          NOT NULL,
  AratID              NUMBER(10)          NOT NULL,
  HarvestDate         DATE                NOT NULL,
  TotalQuantity       NUMBER(12,3)        NOT NULL,
  ReservedQuantity    NUMBER(12,3)        DEFAULT 0 NOT NULL,
  SoldQuantity        NUMBER(12,3)        DEFAULT 0 NOT NULL,
  AvailableQuantity   NUMBER(12,3) GENERATED ALWAYS AS (TotalQuantity - ReservedQuantity - SoldQuantity) VIRTUAL,
  QualityGrade        CHAR(1),
  MoisturePercentage  NUMBER(5,2),
  MinimumPrice        NUMBER(12,2),
  BiddingStartTime    TIMESTAMP,
  BiddingEndTime      TIMESTAMP,
  Status              VARCHAR2(20 CHAR)   DEFAULT 'CREATED' NOT NULL,
  -- The farmer's floor on any single bid's quantity, so a 2,000 kg lot
  -- cannot be nibbled away 5 kg at a time. CK_BATCH_MINBIDQTY catches the
  -- typo that would otherwise soft-lock a batch: a minimum set above the
  -- total quantity, which no bid could ever satisfy.
  MinimumBidQuantity  NUMBER(12,3)        NOT NULL,
  CONSTRAINT PK_HARVEST_BATCH PRIMARY KEY (BatchID),
  CONSTRAINT FK_BATCH_FARM FOREIGN KEY (FarmID) REFERENCES FARM (FarmID),
  CONSTRAINT FK_BATCH_CROP FOREIGN KEY (CropID) REFERENCES CROP (CropID),
  CONSTRAINT FK_BATCH_ARAT FOREIGN KEY (AratID) REFERENCES VIRTUAL_ARAT (AratID),
  CONSTRAINT CK_BATCH_TOTALQTY CHECK (TotalQuantity > 0),
  CONSTRAINT CK_BATCH_RESERVEDQTY CHECK (ReservedQuantity >= 0),
  CONSTRAINT CK_BATCH_SOLDQTY CHECK (SoldQuantity >= 0),
  CONSTRAINT CK_BATCH_AVAILABLE CHECK (TotalQuantity - ReservedQuantity - SoldQuantity >= 0),
  CONSTRAINT CK_BATCH_GRADE CHECK (QualityGrade IN ('A','B','C')),
  CONSTRAINT CK_BATCH_MOISTURE CHECK (MoisturePercentage BETWEEN 0 AND 100),
  CONSTRAINT CK_BATCH_MINPRICE CHECK (MinimumPrice > 0),
  CONSTRAINT CK_BATCH_BIDWINDOW CHECK (BiddingStartTime IS NULL OR BiddingEndTime IS NULL OR BiddingEndTime > BiddingStartTime),
  CONSTRAINT CK_BATCH_STATUS CHECK (Status IN ('CREATED','STORED','LISTED','BIDDING_OPEN','BIDDING_CLOSED','SOLD','DELIVERED','EXPIRED')),
  CONSTRAINT CK_BATCH_MINBIDQTY CHECK (MinimumBidQuantity > 0 AND MinimumBidQuantity <= TotalQuantity)
);

-- =====================================================================
-- SECTION 3 — STORAGE
-- =====================================================================

CREATE TABLE WAREHOUSE (
  WarehouseID          NUMBER(10)          NOT NULL,
  WarehouseName        VARCHAR2(100 CHAR)  NOT NULL,
  Address              VARCHAR2(200 CHAR),
  District             VARCHAR2(100 CHAR)  NOT NULL,
  Capacity             NUMBER(12,3)        NOT NULL,
  ManagerID            NUMBER(10)          NOT NULL,
  -- Bangladesh cold storage charges a flat per-kg, per-season fee at
  -- intake (about BDT 7-8/kg for potato), not a daily rent. This is that
  -- rate, set by the warehouse's own manager.
  StorageFeePerKgRate  NUMBER(10,2),
  CONSTRAINT PK_WAREHOUSE PRIMARY KEY (WarehouseID),
  CONSTRAINT FK_WAREHOUSE_MANAGER FOREIGN KEY (ManagerID) REFERENCES STORAGE_MANAGER (ManagerID),
  CONSTRAINT CK_WAREHOUSE_CAPACITY CHECK (Capacity > 0),
  CONSTRAINT CK_WAREHOUSE_FEE_RATE CHECK (StorageFeePerKgRate IS NULL OR StorageFeePerKgRate > 0)
);

-- WEAK ENTITY #1, identified by WAREHOUSE.
--
-- UnitNo is a PARTIAL key: "unit 3" means nothing on its own, because
-- every warehouse has a unit 3. Identity comes from the owner, so the
-- full primary key is (WarehouseID, UnitNo) and the FK to the owner
-- carries ON DELETE CASCADE — a unit cannot outlive its warehouse.
CREATE TABLE STORAGE_UNIT (
  WarehouseID  NUMBER(10)        NOT NULL,
  UnitNo       NUMBER(5)         NOT NULL,
  Capacity     NUMBER(12,3)      NOT NULL,
  Status       VARCHAR2(15 CHAR) DEFAULT 'EMPTY' NOT NULL,
  CONSTRAINT PK_STORAGE_UNIT PRIMARY KEY (WarehouseID, UnitNo),
  CONSTRAINT FK_UNIT_WAREHOUSE FOREIGN KEY (WarehouseID)
    REFERENCES WAREHOUSE (WarehouseID) ON DELETE CASCADE,
  CONSTRAINT CK_UNIT_CAPACITY CHECK (Capacity > 0),
  CONSTRAINT CK_UNIT_STATUS CHECK (Status IN ('EMPTY','PARTIAL','FULL','MAINTENANCE'))
);

-- TERNARY RELATIONSHIP #1: HARVEST_BATCH x STORAGE_UNIT x STORAGE_MANAGER
--
-- Kept as ONE table with three FK sets, not split into binary
-- relationships. Splitting it would lose the accountability link — which
-- manager authorised this particular allocation — and that is exactly the
-- fact a storage dispute turns on.
--
-- It also carries its own surrogate key, AllocationID, which is what
-- makes the aggregation in Section 4 possible: STORAGE_PAYMENT settles
-- the allocation as one whole fact, not the batch or the unit or the
-- manager separately.
--
-- A batch can sit in storage twice over its life — same table, same
-- ternary, a second row:
--   LEG 1 (pre-sale)  the farmer's storage.  BatchID set, SaleOrderID NULL.
--   LEG 2 (post-sale) the buyer's storage.   BatchID and SaleOrderID set.
-- Exactly one of RequestedByFarmerID / RequestedByBuyerID is set
-- (CK_STORES_CUSTOMER) — that is the party whose consent is required.
--
-- DateIn is nullable on purpose: a PENDING_ACCEPT row is a proposal, and
-- nothing is physically stored until the customer accepts.
--   PENDING_ACCEPT -> ACTIVE -> PENDING_RELEASE -> COMPLETED
--                  \-> COUNTERED  (one negotiation round)
--                  \-> REJECTED   (customer declined)
--                  \-> CANCELLED  (manager withdrew)
CREATE TABLE STORES (
  AllocationID            NUMBER(10)        NOT NULL,
  BatchID                 NUMBER(10)        NOT NULL,
  WarehouseID             NUMBER(10)        NOT NULL,
  UnitNo                  NUMBER(5)         NOT NULL,
  ManagerID               NUMBER(10)        NOT NULL,
  QuantityStored          NUMBER(12,3)      NOT NULL,
  DateIn                  DATE,
  DateOut                 DATE,
  AllocationStatus        VARCHAR2(15 CHAR) DEFAULT 'PENDING_ACCEPT' NOT NULL,
  RequestedByFarmerID     NUMBER(10),
  RequestedByBuyerID      NUMBER(10),
  SaleOrderID             NUMBER(10),
  MinimumStorageDays      NUMBER(5),
  -- Two more derived attributes as virtual columns.
  MinimumReleaseDate      DATE GENERATED ALWAYS AS (DateIn + MinimumStorageDays) VIRTUAL,
  StorageFeePerKgSnapshot NUMBER(10,2),
  StorageFee              NUMBER(12,2) GENERATED ALWAYS AS (QuantityStored * StorageFeePerKgSnapshot) VIRTUAL,
  ReleaseRequestedBy      VARCHAR2(10),
  -- ProposedBy records who opened the negotiation, because the OTHER side
  -- is the one who must answer. One counter-offer round is allowed:
  -- CounterRatePerKg / CounteredBy are set when either side counters, and
  -- only the original proposer may then accept or reject it.
  ProposedBy              VARCHAR2(10)      NOT NULL,
  CounterRatePerKg        NUMBER(10,2),
  CounteredBy             VARCHAR2(10),
  CONSTRAINT PK_STORES PRIMARY KEY (AllocationID),
  CONSTRAINT FK_STORES_BATCH FOREIGN KEY (BatchID) REFERENCES HARVEST_BATCH (BatchID),
  CONSTRAINT FK_STORES_UNIT FOREIGN KEY (WarehouseID, UnitNo) REFERENCES STORAGE_UNIT (WarehouseID, UnitNo),
  CONSTRAINT FK_STORES_MANAGER FOREIGN KEY (ManagerID) REFERENCES STORAGE_MANAGER (ManagerID),
  CONSTRAINT FK_STORES_REQ_FARMER FOREIGN KEY (RequestedByFarmerID) REFERENCES FARMER (FarmerID),
  CONSTRAINT FK_STORES_REQ_BUYER FOREIGN KEY (RequestedByBuyerID) REFERENCES BUYER (BuyerID),
  -- FK_STORES_SALE_ORDER is added by ALTER TABLE further down: SALE_ORDER
  -- does not exist yet at this point in the script.
  CONSTRAINT UQ_STORES_ALLOCATION UNIQUE (BatchID, WarehouseID, UnitNo, DateIn),
  CONSTRAINT CK_STORES_QTY CHECK (QuantityStored > 0),
  CONSTRAINT CK_STORES_DATES CHECK (DateOut IS NULL OR DateOut >= DateIn),
  CONSTRAINT CK_STORES_STATUS CHECK (AllocationStatus IN
    ('PENDING_ACCEPT','ACTIVE','PENDING_RELEASE','COMPLETED','REJECTED','CANCELLED','COUNTERED')),
  CONSTRAINT CK_STORES_CUSTOMER CHECK (
    (RequestedByFarmerID IS NOT NULL AND RequestedByBuyerID IS NULL) OR
    (RequestedByFarmerID IS NULL AND RequestedByBuyerID IS NOT NULL)),
  CONSTRAINT CK_STORES_MINDAYS CHECK (MinimumStorageDays IS NULL OR MinimumStorageDays > 0),
  CONSTRAINT CK_STORES_RELEASE_BY CHECK (ReleaseRequestedBy IS NULL OR ReleaseRequestedBy IN ('FARMER','BUYER','MANAGER')),
  CONSTRAINT CK_STORES_PROPOSEDBY CHECK (ProposedBy IN ('MANAGER','CUSTOMER')),
  CONSTRAINT CK_STORES_COUNTERRATE CHECK (CounterRatePerKg IS NULL OR CounterRatePerKg > 0),
  CONSTRAINT CK_STORES_COUNTEREDBY CHECK (CounteredBy IS NULL OR CounteredBy IN ('MANAGER','CUSTOMER'))
);

-- =====================================================================
-- SECTION 4 — BIDDING, SALE AND PAYMENT
-- =====================================================================

-- Recursive relationship #2: outbids. When a bid is beaten, the new bid
-- points at the one it displaced, so the whole bidding war is one chain
-- walkable with CONNECT BY (see Q8 in 03_advanced_queries.sql).
CREATE TABLE BID (
  BidID              NUMBER(10)        NOT NULL,
  BatchID            NUMBER(10)        NOT NULL,
  BuyerID            NUMBER(10)        NOT NULL,
  BidPricePerKg      NUMBER(12,2)      NOT NULL,
  RequestedQuantity  NUMBER(12,3)      NOT NULL,
  BidTime            TIMESTAMP         DEFAULT SYSTIMESTAMP NOT NULL,
  Status             VARCHAR2(15 CHAR) DEFAULT 'ACTIVE' NOT NULL,
  PreviousBidID      NUMBER(10),
  CONSTRAINT PK_BID PRIMARY KEY (BidID),
  CONSTRAINT FK_BID_BATCH FOREIGN KEY (BatchID) REFERENCES HARVEST_BATCH (BatchID),
  CONSTRAINT FK_BID_BUYER FOREIGN KEY (BuyerID) REFERENCES BUYER (BuyerID),
  CONSTRAINT FK_BID_PREVIOUS FOREIGN KEY (PreviousBidID) REFERENCES BID (BidID),
  CONSTRAINT CK_BID_PRICE CHECK (BidPricePerKg > 0),
  CONSTRAINT CK_BID_QTY CHECK (RequestedQuantity > 0),
  CONSTRAINT CK_BID_STATUS CHECK (Status IN ('ACTIVE','OUTBID','WON','WITHDRAWN')),
  CONSTRAINT CK_BID_NOT_OWN_PREVIOUS CHECK (PreviousBidID <> BidID)
);

-- AGGREGATION. A sale order is not created by a buyer, nor by a bid, nor
-- by a batch — it is created by the whole fact "this buyer placed this
-- bid on this batch" taken as one unit. That composite is what SALE_ORDER
-- relates to, and it is realised here by referencing BID with a UNIQUE
-- constraint on it, which is what makes it one order per winning bid.
--
-- TotalAmount is a derived attribute (virtual column).
CREATE TABLE SALE_ORDER (
  SaleOrderID         NUMBER(10)        NOT NULL,
  BidID               NUMBER(10)        NOT NULL,
  AcceptedQuantity    NUMBER(12,3)      NOT NULL,
  AcceptedPricePerKg  NUMBER(12,2)      NOT NULL,
  TotalAmount         NUMBER(14,2) GENERATED ALWAYS AS (AcceptedQuantity * AcceptedPricePerKg) VIRTUAL,
  OrderDate           DATE              DEFAULT SYSDATE NOT NULL,
  Status              VARCHAR2(15 CHAR) DEFAULT 'CONFIRMED' NOT NULL,
  PaymentTerms        VARCHAR2(15 CHAR) DEFAULT 'ON_DELIVERY' NOT NULL,
  -- Winning a bid raises a transport request immediately, but at that
  -- moment nobody knows where the load is going: straight to the buyer,
  -- or into a warehouse first. Until the buyer settles that, the trip has
  -- no real address and is not offered to drivers.
  DeliveryPreference  VARCHAR2(15 CHAR) DEFAULT 'PENDING' NOT NULL,
  CONSTRAINT PK_SALE_ORDER PRIMARY KEY (SaleOrderID),
  CONSTRAINT FK_ORDER_BID FOREIGN KEY (BidID) REFERENCES BID (BidID),
  CONSTRAINT UQ_ORDER_BID UNIQUE (BidID),
  CONSTRAINT CK_ORDER_QTY CHECK (AcceptedQuantity > 0),
  CONSTRAINT CK_ORDER_PRICE CHECK (AcceptedPricePerKg > 0),
  CONSTRAINT CK_ORDER_STATUS CHECK (Status IN ('CONFIRMED','IN_TRANSIT','COMPLETED','CANCELLED')),
  CONSTRAINT CK_ORDER_TERMS CHECK (PaymentTerms IN ('ADVANCE','ON_DELIVERY')),
  CONSTRAINT CK_ORDER_DELIVERY_PREF CHECK (DeliveryPreference IN ('PENDING','DIRECT','VIA_STORAGE'))
);

-- Deferred from STORES above, which was created before SALE_ORDER existed.
ALTER TABLE STORES ADD CONSTRAINT FK_STORES_SALE_ORDER
  FOREIGN KEY (SaleOrderID) REFERENCES SALE_ORDER (SaleOrderID);

-- Payment is direct, buyer to farmer: no ARAT commission, no escrow.
-- That is the point of the platform, so both parties appear here.
CREATE TABLE PAYMENT (
  PaymentID             NUMBER(10)        NOT NULL,
  SaleOrderID           NUMBER(10)        NOT NULL,
  BuyerID               NUMBER(10)        NOT NULL,
  FarmerID              NUMBER(10)        NOT NULL,
  Amount                NUMBER(12,2)      NOT NULL,
  PaymentMethod         VARCHAR2(20 CHAR) NOT NULL,
  PaymentDate           DATE              DEFAULT SYSDATE NOT NULL,
  TransactionReference  VARCHAR2(50 CHAR) NOT NULL,
  PaymentStatus         VARCHAR2(15 CHAR) DEFAULT 'PENDING' NOT NULL,
  CONSTRAINT PK_PAYMENT PRIMARY KEY (PaymentID),
  CONSTRAINT FK_PAYMENT_ORDER FOREIGN KEY (SaleOrderID) REFERENCES SALE_ORDER (SaleOrderID),
  CONSTRAINT FK_PAYMENT_BUYER FOREIGN KEY (BuyerID) REFERENCES BUYER (BuyerID),
  CONSTRAINT FK_PAYMENT_FARMER FOREIGN KEY (FarmerID) REFERENCES FARMER (FarmerID),
  CONSTRAINT UQ_PAYMENT_REFERENCE UNIQUE (TransactionReference),
  CONSTRAINT CK_PAYMENT_AMOUNT CHECK (Amount > 0),
  CONSTRAINT CK_PAYMENT_STATUS CHECK (PaymentStatus IN ('PENDING','COMPLETED','FAILED','REFUNDED'))
);

-- THE SECOND AGGREGATION, made concrete. A storage fee is not owed for a
-- batch, or for a unit, or to a manager — it is owed for the allocation,
-- the three-way fact as a whole. So this references AllocationID and
-- nothing else; the payer (farmer for leg 1, buyer for leg 2) is
-- derivable through STORES, so there is no FarmerID/BuyerID column here.
--
-- Kept separate from PAYMENT rather than sharing one table with a type
-- flag: sale money and storage fees obey independent rules.
CREATE TABLE STORAGE_PAYMENT (
  StoragePaymentID      NUMBER(10)        NOT NULL,
  AllocationID          NUMBER(10)        NOT NULL,
  Amount                NUMBER(12,2)      NOT NULL,
  PaymentMethod         VARCHAR2(20 CHAR) NOT NULL,
  PaymentDate           DATE              DEFAULT SYSDATE NOT NULL,
  TransactionReference  VARCHAR2(50 CHAR) NOT NULL,
  PaymentStatus         VARCHAR2(15 CHAR) DEFAULT 'PENDING' NOT NULL,
  CONSTRAINT PK_STORAGE_PAYMENT PRIMARY KEY (StoragePaymentID),
  CONSTRAINT FK_STORAGE_PAYMENT_ALLOC FOREIGN KEY (AllocationID) REFERENCES STORES (AllocationID),
  CONSTRAINT UQ_STORAGE_PAYMENT_REF UNIQUE (TransactionReference),
  CONSTRAINT CK_STORAGE_PAYMENT_AMOUNT CHECK (Amount > 0),
  CONSTRAINT CK_STORAGE_PAYMENT_STATUS CHECK (PaymentStatus IN ('PENDING','COMPLETED','FAILED','REFUNDED'))
);

-- =====================================================================
-- SECTION 5 — LOGISTICS
-- =====================================================================

CREATE TABLE VEHICLE (
  VehicleID    NUMBER(10)        NOT NULL,
  VehicleNo    VARCHAR2(20 CHAR) NOT NULL,
  VehicleType  VARCHAR2(30 CHAR),
  Capacity     NUMBER(12,3)      NOT NULL,
  Status       VARCHAR2(15 CHAR) DEFAULT 'AVAILABLE' NOT NULL,
  CONSTRAINT PK_VEHICLE PRIMARY KEY (VehicleID),
  CONSTRAINT UQ_VEHICLE_NO UNIQUE (VehicleNo),
  CONSTRAINT CK_VEHICLE_CAPACITY CHECK (Capacity > 0),
  CONSTRAINT CK_VEHICLE_STATUS CHECK (Status IN ('AVAILABLE','ASSIGNED','MAINTENANCE'))
);

CREATE TABLE TRANSPORT_REQUEST (
  TransportID       NUMBER(10)        NOT NULL,
  SaleOrderID       NUMBER(10)        NOT NULL,
  PickupLocation    VARCHAR2(200 CHAR),
  DeliveryLocation  VARCHAR2(200 CHAR),
  RequestDate       DATE              DEFAULT SYSDATE NOT NULL,
  DeliveryDate      DATE,
  DeliveryStatus    VARCHAR2(15 CHAR) DEFAULT 'PENDING' NOT NULL,
  CONSTRAINT PK_TRANSPORT_REQUEST PRIMARY KEY (TransportID),
  CONSTRAINT FK_TRANSPORT_ORDER FOREIGN KEY (SaleOrderID) REFERENCES SALE_ORDER (SaleOrderID),
  CONSTRAINT UQ_TRANSPORT_ORDER UNIQUE (SaleOrderID),
  CONSTRAINT CK_TRANSPORT_STATUS CHECK (DeliveryStatus IN ('PENDING','ASSIGNED','PICKED_UP','IN_TRANSIT','DELIVERED','FAILED'))
);

-- TERNARY RELATIONSHIP #2: TRANSPORT_REQUEST x VEHICLE x TRANSPORT_PERSONNEL
--
-- Again one table with three FK sets, and UQ_ASSIGNED_TRIPLE so the same
-- triple cannot be recorded twice. Decomposing this into "vehicle for
-- request" plus "driver for request" would allow the two halves to
-- disagree about who drove what.
CREATE TABLE ASSIGNED_TO (
  AssignmentID      NUMBER(10)        NOT NULL,
  TransportID       NUMBER(10)        NOT NULL,
  VehicleID         NUMBER(10)        NOT NULL,
  PersonnelID       NUMBER(10)        NOT NULL,
  AssignedDate      DATE              DEFAULT SYSDATE NOT NULL,
  AssignmentStatus  VARCHAR2(15 CHAR) DEFAULT 'ACTIVE' NOT NULL,
  CONSTRAINT PK_ASSIGNED_TO PRIMARY KEY (AssignmentID),
  CONSTRAINT FK_ASSIGNED_TRANSPORT FOREIGN KEY (TransportID) REFERENCES TRANSPORT_REQUEST (TransportID),
  CONSTRAINT FK_ASSIGNED_VEHICLE FOREIGN KEY (VehicleID) REFERENCES VEHICLE (VehicleID),
  CONSTRAINT FK_ASSIGNED_PERSONNEL FOREIGN KEY (PersonnelID) REFERENCES TRANSPORT_PERSONNEL (PersonnelID),
  CONSTRAINT UQ_ASSIGNED_TRIPLE UNIQUE (TransportID, VehicleID, PersonnelID),
  CONSTRAINT CK_ASSIGNED_STATUS CHECK (AssignmentStatus IN ('ACTIVE','COMPLETED','CANCELLED'))
);

-- =====================================================================
-- SECTION 6 — PRICE REFERENCE
-- =====================================================================

-- The virtual marketplace's own published price per crop per arat per
-- day. This figure is computed by the platform from its own trading
-- activity, so no admin is recorded against it — the point of the system
-- is that the middleman cannot set this number by hand.
CREATE TABLE DAILY_MARKET_PRICE (
  CropID      NUMBER(10)    NOT NULL,
  AratID      NUMBER(10)    NOT NULL,
  PriceDate   DATE          NOT NULL,
  PricePerKg  NUMBER(12,2)  NOT NULL,
  MinPrice    NUMBER(12,2)  NOT NULL,
  MaxPrice    NUMBER(12,2)  NOT NULL,
  CONSTRAINT PK_DAILY_MARKET_PRICE PRIMARY KEY (CropID, AratID, PriceDate),
  CONSTRAINT FK_DMP_CROP FOREIGN KEY (CropID) REFERENCES CROP (CropID),
  CONSTRAINT FK_DMP_ARAT FOREIGN KEY (AratID) REFERENCES VIRTUAL_ARAT (AratID),
  CONSTRAINT CK_DMP_RANGE CHECK (MinPrice <= PricePerKg AND PricePerKg <= MaxPrice)
);

CREATE TABLE PHYSICAL_BAZAR (
  BazarID    NUMBER(10)          NOT NULL,
  BazarName  VARCHAR2(100 CHAR)  NOT NULL,
  Address    VARCHAR2(200 CHAR),
  District   VARCHAR2(100 CHAR)  NOT NULL,
  ContactNo  VARCHAR2(20 CHAR),
  CONSTRAINT PK_PHYSICAL_BAZAR PRIMARY KEY (BazarID),
  CONSTRAINT UQ_BAZAR_NAME_DISTRICT UNIQUE (BazarName, District)
);

-- WEAK ENTITY #2, identified by PHYSICAL_BAZAR.
--
-- The bazar's daily figures cannot be plain columns on PHYSICAL_BAZAR:
-- each night would overwrite the last and all history would be lost.
-- Splitting them into this weak entity is what preserves the history.
--
-- RecordDate is the partial key, and the key is a TRIPLE:
-- (BazarID, RecordDate, CropID). CropID has to be in the key, not merely
-- an ordinary column — a bazar trades several crops on the same day, and
-- a key of (BazarID, RecordDate) alone would permit only one of them,
-- which would defeat the entire purpose of keeping the history.
--
-- Unlike DAILY_MARKET_PRICE above, LoggedBy IS recorded here: these
-- figures are collected from a physical marketplace by a person, so who
-- entered them is part of the record.
CREATE TABLE BAZAR_DAILY_RECORD (
  BazarID            NUMBER(10)    NOT NULL,
  RecordDate         DATE          NOT NULL,
  CropID             NUMBER(10)    NOT NULL,
  PricePerKg         NUMBER(12,2)  NOT NULL,
  TransactionVolume  NUMBER(12,3)  DEFAULT 0 NOT NULL,
  Revenue            NUMBER(14,2)  DEFAULT 0 NOT NULL,
  LoggedBy           NUMBER(10)    NOT NULL,
  CONSTRAINT PK_BAZAR_DAILY_RECORD PRIMARY KEY (BazarID, RecordDate, CropID),
  CONSTRAINT FK_BDR_BAZAR FOREIGN KEY (BazarID)
    REFERENCES PHYSICAL_BAZAR (BazarID) ON DELETE CASCADE,
  CONSTRAINT FK_BDR_CROP FOREIGN KEY (CropID) REFERENCES CROP (CropID),
  CONSTRAINT FK_BDR_ADMIN FOREIGN KEY (LoggedBy) REFERENCES ADMIN_STAFF (AdminID),
  CONSTRAINT CK_BDR_PRICE CHECK (PricePerKg > 0),
  CONSTRAINT CK_BDR_VOLUME CHECK (TransactionVolume >= 0),
  CONSTRAINT CK_BDR_REVENUE CHECK (Revenue >= 0)
);

-- =====================================================================
-- SECTION 7 — FEEDBACK
-- =====================================================================

CREATE TABLE REVIEW (
  ReviewID      NUMBER(10)   NOT NULL,
  SaleOrderID   NUMBER(10)   NOT NULL,
  Rating        NUMBER(1)    NOT NULL,
  ReviewComment CLOB,
  ReviewDate    DATE         DEFAULT SYSDATE NOT NULL,
  CONSTRAINT PK_REVIEW PRIMARY KEY (ReviewID),
  CONSTRAINT FK_REVIEW_ORDER FOREIGN KEY (SaleOrderID) REFERENCES SALE_ORDER (SaleOrderID),
  CONSTRAINT UQ_REVIEW_ORDER UNIQUE (SaleOrderID),
  CONSTRAINT CK_REVIEW_RATING CHECK (Rating BETWEEN 1 AND 5)
);

CREATE TABLE COMPLAINT (
  ComplaintID       NUMBER(10)        NOT NULL,
  SaleOrderID       NUMBER(10)        NOT NULL,
  ComplaintType     VARCHAR2(50 CHAR),
  Description       CLOB,
  Status            VARCHAR2(15 CHAR) DEFAULT 'OPEN' NOT NULL,
  ResolutionDate    DATE,
  HandledByAdminID  NUMBER(10),
  CONSTRAINT PK_COMPLAINT PRIMARY KEY (ComplaintID),
  CONSTRAINT FK_COMPLAINT_ORDER FOREIGN KEY (SaleOrderID) REFERENCES SALE_ORDER (SaleOrderID),
  CONSTRAINT FK_COMPLAINT_ADMIN FOREIGN KEY (HandledByAdminID) REFERENCES ADMIN_STAFF (AdminID),
  CONSTRAINT CK_COMPLAINT_STATUS CHECK (Status IN ('OPEN','IN_REVIEW','RESOLVED','REJECTED'))
);

-- =====================================================================
-- SECTION 8 — NOTIFICATIONS
--
-- The only table whose FK points at USERS generically rather than at one
-- role's table. That is deliberate: a notification's recipient can be any
-- of the five roles, and USERS is the total, disjoint superclass every
-- one of them resolves to.
-- =====================================================================

CREATE TABLE NOTIFICATION (
  NotificationID     NUMBER(10)         NOT NULL,
  UserID             NUMBER(10)         NOT NULL,
  Type               VARCHAR2(30 CHAR)  NOT NULL,
  Title              VARCHAR2(150 CHAR) NOT NULL,
  Message            VARCHAR2(500 CHAR) NOT NULL,
  RelatedEntityType  VARCHAR2(30 CHAR),
  RelatedEntityID    NUMBER(10),
  IsRead             CHAR(1)            DEFAULT 'N' NOT NULL,
  CreatedAt          TIMESTAMP          DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT PK_NOTIFICATION PRIMARY KEY (NotificationID),
  CONSTRAINT FK_NOTIFICATION_USER FOREIGN KEY (UserID) REFERENCES USERS (UserID),
  CONSTRAINT CK_NOTIFICATION_READ CHECK (IsRead IN ('Y','N'))
);

-- =====================================================================
-- VERIFICATION — 28 tables expected
-- =====================================================================

SELECT COUNT(*) AS tables_created FROM user_tables;

SELECT table_name FROM user_tables ORDER BY table_name;

-- Constraint census, by type:
--   P = primary key, R = foreign key, U = unique, C = check + NOT NULL
SELECT constraint_type, COUNT(*) AS how_many
FROM   user_constraints
GROUP  BY constraint_type
ORDER  BY constraint_type;

-- No triggers in this build.
SELECT COUNT(*) AS triggers_created FROM user_triggers;

-- =====================================================================
-- End of 01_create_tables.sql — next: 02_insert_data.sql
-- =====================================================================
