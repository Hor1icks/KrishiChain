-- =====================================================================
-- KrishiChain V1 | 02_insert_data.sql
--
-- Demo data for all 28 tables. Every table gets at least 5 rows.
--
-- Run as `krishichain_demo`, AFTER 01_create_tables.sql.
-- In SQL Developer press F5 (Run Script), not Ctrl+Enter.
--
-- Safe to re-run: Section 0 clears every table first, in reverse
-- foreign-key order.
--
-- ---------------------------------------------------------------------
-- WHY THE DATA LOOKS LIKE THIS
--
-- The same five farmers, five crops and eight batches thread all the way
-- through bids -> sale orders -> transport -> payments -> reviews. That
-- is deliberate. Rows generated independently of each other would make
-- the advanced queries in 03_advanced_queries.sql return empty results,
-- which is the single most common way a demo like this goes wrong.
--
-- THE STORY
--   Five farmers in Bogura, Rangpur, Munshiganj, Pabna and Faridpur list
--   eight harvest batches through a three-level Virtual ARAT hierarchy.
--   Batches 1-5 have finished bidding: each has an outbid chain ending in
--   a WON bid, which became a sale order, which was transported and
--   (mostly) paid. Batches 6-7 are still BIDDING_OPEN with live bids.
--   Batch 8 has no bids at all, on purpose -- Q4's anti-join needs one.
--
-- ---------------------------------------------------------------------
-- EVERY PRIMARY KEY BELOW IS A LITERAL VALUE
--
-- This build has no sequences and no triggers, so nothing is generated:
-- each ID is written out, and every foreign key downstream refers to it
-- by that number. That is also what makes the file readable as a story.
--
-- ---------------------------------------------------------------------
-- ROW COUNTS ABOVE FIVE, AND WHY
--
--   USERS               25   the specialization is total: 5 per subclass
--   USER_PHONE          29   several users hold two numbers -- the whole
--                            point of splitting the multivalued attribute
--   DAILY_MARKET_PRICE  30   a five-month series per crop, so Q5's LAG
--                            has a trend to measure
--   BAZAR_DAILY_RECORD  21   several crops per bazar per day, which is
--                            exactly what the three-column key allows
--   HARVEST_BATCH        8   5 finished auctions + 2 live + 1 with no bids
--   BID                 15   each finished batch has an outbid chain
--   STORAGE_UNIT        11   several units per warehouse (the weak entity)
--   STORES               7   leg-1 and leg-2 allocations
--
-- ---------------------------------------------------------------------
-- THREE RULES THIS FILE SATISFIES BY HAND
--
-- Each needs to read a second table, so none can be a CHECK constraint
-- and this build has no triggers. Check these before editing any price
-- or quantity below:
--   BR-09  HARVEST_BATCH.MinimumPrice >= CROP.BasePrice
--   BR-11  every bid >= its batch minimum and > the bid it outbids
--   BR-18  VEHICLE.Capacity >= the load assigned to it
--
-- ---------------------------------------------------------------------
-- DATES are all TRUNC(SYSDATE) - n, so the data stays current whenever
-- this is re-run. Only dates of birth are absolute.
--
-- DEMO LOGIN: every seeded user shares the password  Demo@1234
-- PasswordHash holds a real bcrypt hash of it, so all 25 accounts can be
-- signed into. One shared password across every account is exactly what
-- you are taught not to do -- it is here because this is throwaway demo
-- data for a local project, and nowhere else.
-- =====================================================================

SET DEFINE OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON

-- =====================================================================
-- SECTION 0 — CLEAR EXISTING DATA (reverse FK order, so re-runs work)
-- =====================================================================

-- The two self-referencing FKs must be broken before their table can be
-- emptied in one statement (ParentAratID -> AratID, PreviousBidID -> BidID).
UPDATE BID          SET PreviousBidID = NULL;
UPDATE VIRTUAL_ARAT SET ParentAratID  = NULL;

-- Added with the feedback-batch migration: NOTIFICATION.UserID FKs to
-- USERS, so any app-generated notifications must be cleared before USERS
-- can be, or the final DELETE FROM USERS hits ORA-02292.
DELETE FROM NOTIFICATION;
DELETE FROM COMPLAINT;
DELETE FROM REVIEW;
DELETE FROM BAZAR_DAILY_RECORD;
DELETE FROM PHYSICAL_BAZAR;
DELETE FROM DAILY_MARKET_PRICE;
DELETE FROM PAYMENT;
-- STORAGE_PAYMENT and STORES must both come before SALE_ORDER: STORES has
-- a nullable SaleOrderID FK (leg 2), so as soon as a live database has
-- ever had one leg-2 allocation or one storage payment (both only
-- reachable via the app, never seeded), the old order here
-- (SALE_ORDER deleted before STORES) hits ORA-02292 on FK_STORES_SALE_ORDER
-- / FK_STORAGE_PAYMENT_ALLOC. A pristine, never-used database never
-- exercises this path, which is why it went unnoticed.
DELETE FROM STORAGE_PAYMENT;
DELETE FROM ASSIGNED_TO;
DELETE FROM TRANSPORT_REQUEST;
DELETE FROM VEHICLE;
DELETE FROM STORES;
DELETE FROM SALE_ORDER;
DELETE FROM BID;
DELETE FROM STORAGE_UNIT;
DELETE FROM WAREHOUSE;
DELETE FROM HARVEST_BATCH;
DELETE FROM VIRTUAL_ARAT;
DELETE FROM FARM;
DELETE FROM CROP;
DELETE FROM CROP_CATEGORY;
DELETE FROM TRANSPORT_PERSONNEL;
DELETE FROM STORAGE_MANAGER;
DELETE FROM ADMIN_STAFF;
DELETE FROM BUYER;
DELETE FROM FARMER;
DELETE FROM USER_PHONE;
DELETE FROM USERS;

COMMIT;

-- =====================================================================
-- SECTION 1 — USERS  (25 rows: 5 per subclass)
--
-- IDs are literal values. Every downstream foreign key in this file
-- refers to them by number, which is what lets the file be read as one
-- continuous story rather than a pile of unrelated inserts.
--
-- The subclass tables have no ID of their own to generate: a farmer's
-- FarmerID IS their UserID. That is the shared-PK specialization -- the
-- subclass primary key is simultaneously a foreign key to USERS, so the
-- two can never disagree about who a user is.
--
-- ID BLOCKS:  1-5 farmers | 6-10 buyers | 11-15 admin
--            16-20 storage managers | 21-25 transport personnel
-- This is the total, disjoint specialization from PRD 7: every USERS row
-- appears in exactly one subclass table, and all 25 are covered.
-- =====================================================================

-- --- FARMERS (1-5) ---------------------------------------------------
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (1, 'Abdul', NULL, 'Karim', 'abdul.karim@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1978-04-12', '12', 'Station Road', 'Kahaloo', 'Kahaloo', 'Bogura', '5710', TRUNC(SYSDATE) - 420, 'ACTIVE', 'FARMER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (2, 'Rahima', NULL, 'Begum', 'rahima.begum@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1985-09-30', '7', 'College Road', 'Mithapukur', 'Mithapukur', 'Rangpur', '5460', TRUNC(SYSDATE) - 405, 'ACTIVE', 'FARMER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (3, 'Jamal', 'Uddin', 'Sarkar', 'jamal.sarkar@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1972-01-18', '45', 'Ferry Ghat Road', 'Tongibari', 'Tongibari', 'Munshiganj', '1510', TRUNC(SYSDATE) - 398, 'ACTIVE', 'FARMER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (4, 'Shafiqul', NULL, 'Islam', 'shafiqul.islam@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1981-07-25', '3', 'Hat Road', 'Sujanagar', 'Sujanagar', 'Pabna', '6600', TRUNC(SYSDATE) - 372, 'ACTIVE', 'FARMER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (5, 'Nurjahan', NULL, 'Akter', 'nurjahan.akter@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1989-11-05', '21', 'Baitul Aman Road', 'Nagarkanda', 'Nagarkanda', 'Faridpur', '7800', TRUNC(SYSDATE) - 340, 'ACTIVE', 'FARMER');

-- --- BUYERS (6-10) ---------------------------------------------------
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (6, 'Tanvir', NULL, 'Hossain', 'tanvir.hossain@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1983-02-14', '104', 'Kazi Nazrul Islam Ave', NULL, 'Tejgaon', 'Dhaka', '1215', TRUNC(SYSDATE) - 380, 'ACTIVE', 'BUYER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (7, 'Mizanur', NULL, 'Rahman', 'mizanur.rahman@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1976-06-08', '58', 'Agrabad C/A', NULL, 'Double Mooring', 'Chattogram', '4100', TRUNC(SYSDATE) - 365, 'ACTIVE', 'BUYER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (8, 'Sultana', NULL, 'Parvin', 'sultana.parvin@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1990-12-22', '9/B', 'Mirpur Road', NULL, 'Dhanmondi', 'Dhaka', '1205', TRUNC(SYSDATE) - 310, 'ACTIVE', 'BUYER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (9, 'Kamrul', NULL, 'Hasan', 'kamrul.hasan@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1987-03-19', '77', 'BSCIC Industrial Area', NULL, 'Fatullah', 'Narayanganj', '1420', TRUNC(SYSDATE) - 295, 'ACTIVE', 'BUYER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (10, 'Anisur', NULL, 'Rahman', 'anisur.rahman@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1980-08-11', '16', 'Zindabazar', NULL, 'Sylhet Sadar', 'Sylhet', '3100', TRUNC(SYSDATE) - 288, 'ACTIVE', 'BUYER');

-- --- ADMIN STAFF (11-15) ---------------------------------------------
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (11, 'Farhana', NULL, 'Yasmin', 'farhana.yasmin@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1991-05-02', '31', 'Bijoy Sarani', NULL, 'Tejgaon', 'Dhaka', '1215', TRUNC(SYSDATE) - 500, 'ACTIVE', 'ADMIN');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (12, 'Rezaul', NULL, 'Karim', 'rezaul.karim@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1988-10-16', '31', 'Bijoy Sarani', NULL, 'Tejgaon', 'Dhaka', '1215', TRUNC(SYSDATE) - 500, 'ACTIVE', 'ADMIN');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (13, 'Shamima', NULL, 'Nasrin', 'shamima.nasrin@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1993-07-09', '31', 'Bijoy Sarani', NULL, 'Tejgaon', 'Dhaka', '1215', TRUNC(SYSDATE) - 470, 'ACTIVE', 'ADMIN');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (14, 'Habibur', NULL, 'Rahman', 'habibur.rahman@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1979-04-27', '12', 'Station Road', NULL, 'Bogura Sadar', 'Bogura', '5800', TRUNC(SYSDATE) - 455, 'ACTIVE', 'ADMIN');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (15, 'Nazmul', NULL, 'Haque', 'nazmul.haque@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1994-01-30', '31', 'Bijoy Sarani', NULL, 'Tejgaon', 'Dhaka', '1215', TRUNC(SYSDATE) - 500, 'ACTIVE', 'ADMIN');

-- --- STORAGE MANAGERS (16-20) ----------------------------------------
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (16, 'Ashraful', NULL, 'Alam', 'ashraful.alam@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1982-09-14', '6', 'Sherpur Road', NULL, 'Bogura Sadar', 'Bogura', '5800', TRUNC(SYSDATE) - 440, 'ACTIVE', 'STORAGE_MANAGER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (17, 'Delwar', NULL, 'Hossain', 'delwar.hossain@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1986-02-03', '19', 'Jail Road', NULL, 'Rangpur Sadar', 'Rangpur', '5400', TRUNC(SYSDATE) - 435, 'ACTIVE', 'STORAGE_MANAGER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (18, 'Salma', NULL, 'Khatun', 'salma.khatun@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1990-06-21', '2', 'Munshiganj Bazar Road', NULL, 'Munshiganj Sadar', 'Munshiganj', '1500', TRUNC(SYSDATE) - 430, 'ACTIVE', 'STORAGE_MANAGER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (19, 'Mahbub', NULL, 'Alam', 'mahbub.alam@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1984-11-11', '8', 'Rupkatha Road', NULL, 'Pabna Sadar', 'Pabna', '6600', TRUNC(SYSDATE) - 425, 'ACTIVE', 'STORAGE_MANAGER');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (20, 'Ruma', NULL, 'Akter', 'ruma.akter@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'F', DATE '1992-03-08', '14', 'Mujib Road', NULL, 'Faridpur Sadar', 'Faridpur', '7800', TRUNC(SYSDATE) - 420, 'ACTIVE', 'STORAGE_MANAGER');

-- --- TRANSPORT PERSONNEL (21-25) -------------------------------------
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (21, 'Sohel', NULL, 'Rana', 'sohel.rana@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1987-12-01', '33', 'Truck Stand Road', NULL, 'Bogura Sadar', 'Bogura', '5800', TRUNC(SYSDATE) - 410, 'ACTIVE', 'TRANSPORT_PERSONNEL');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (22, 'Babul', NULL, 'Mia', 'babul.mia@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1983-05-17', '5', 'Modern Mor', NULL, 'Rangpur Sadar', 'Rangpur', '5400', TRUNC(SYSDATE) - 400, 'ACTIVE', 'TRANSPORT_PERSONNEL');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (23, 'Rafiqul', NULL, 'Sheikh', 'rafiqul.sheikh@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1991-09-23', '61', 'Postogola', NULL, 'Shyampur', 'Dhaka', '1204', TRUNC(SYSDATE) - 390, 'ACTIVE', 'TRANSPORT_PERSONNEL');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (24, 'Jasim', 'Uddin', 'Bhuiyan', 'jasim.bhuiyan@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1979-02-28', '18', 'Chashara', NULL, 'Narayanganj Sadar', 'Narayanganj', '1400', TRUNC(SYSDATE) - 385, 'ACTIVE', 'TRANSPORT_PERSONNEL');
INSERT INTO USERS (UserID, FirstName, MiddleName, LastName, Email, PasswordHash, Gender, DateOfBirth, HouseNo, Road, Village, Upazila, District, PostalCode, RegistrationDate, Status, Role) VALUES
 (25, 'Alamgir', NULL, 'Hossain', 'alamgir.hossain@krishichain.bd', '$2b$10$z36cm2.3eH0SfqSyT/TLbuG0ZmUbPWe7YFCO4NxG6rj8VF1zRRiTy', 'M', DATE '1985-07-04', '40', 'Pabna Bus Terminal', NULL, 'Pabna Sadar', 'Pabna', '6600', TRUNC(SYSDATE) - 380, 'ACTIVE', 'TRANSPORT_PERSONNEL');

-- --- USER_PHONE: the multivalued attribute {PhoneNo}. -----------------
-- Users 1, 3, 6 and 7 carry two numbers each -- that is the whole point
-- of the separate table, so the demo needs at least a few rows proving
-- one user can hold more than one.
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (1,  '01711000001');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (1,  '01911000001');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (2,  '01711000002');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (3,  '01711000003');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (3,  '01811000003');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (4,  '01711000004');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (5,  '01711000005');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (6,  '01712000006');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (6,  '01612000006');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (7,  '01712000007');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (7,  '01912000007');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (8,  '01712000008');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (9,  '01712000009');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (10, '01712000010');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (11, '01713000011');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (12, '01713000012');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (13, '01713000013');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (14, '01713000014');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (15, '01713000015');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (16, '01714000016');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (17, '01714000017');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (18, '01714000018');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (19, '01714000019');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (20, '01714000020');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (21, '01715000021');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (22, '01715000022');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (23, '01715000023');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (24, '01715000024');
INSERT INTO USER_PHONE (UserID, PhoneNo) VALUES (25, '01715000025');

-- --- ISA SUBCLASSES: PK = the parent USERS.UserID ---------------------
INSERT INTO FARMER (FarmerID, NID, BankAccountNo, MobileBankingNo, ExperienceYears) VALUES (1, '1990123456781', '1051234567801', '01711000001', 22);
INSERT INTO FARMER (FarmerID, NID, BankAccountNo, MobileBankingNo, ExperienceYears) VALUES (2, '1990123456782', '1051234567802', '01711000002', 14);
INSERT INTO FARMER (FarmerID, NID, BankAccountNo, MobileBankingNo, ExperienceYears) VALUES (3, '1990123456783', '1051234567803', '01711000003', 28);
INSERT INTO FARMER (FarmerID, NID, BankAccountNo, MobileBankingNo, ExperienceYears) VALUES (4, '1990123456784', NULL,            '01711000004', 17);
INSERT INTO FARMER (FarmerID, NID, BankAccountNo, MobileBankingNo, ExperienceYears) VALUES (5, '1990123456785', '1051234567805', '01711000005', 9);

INSERT INTO BUYER (BuyerID, BusinessName, BuyerType, TradeLicenseNo) VALUES (6,  'Hossain Traders',        'WHOLESALER', 'TRAD-DHK-2019-0061');
INSERT INTO BUYER (BuyerID, BusinessName, BuyerType, TradeLicenseNo) VALUES (7,  'Bengal Agro Exports',    'EXPORTER',   'TRAD-CTG-2016-0072');
INSERT INTO BUYER (BuyerID, BusinessName, BuyerType, TradeLicenseNo) VALUES (8,  'Parvin Fresh Mart',      'RETAILER',   'TRAD-DHK-2021-0083');
INSERT INTO BUYER (BuyerID, BusinessName, BuyerType, TradeLicenseNo) VALUES (9,  'Hasan Food Processing',  'PROCESSOR',  'TRAD-NGJ-2018-0094');
INSERT INTO BUYER (BuyerID, BusinessName, BuyerType, TradeLicenseNo) VALUES (10, 'Anisur Bazar Supply',    'WHOLESALER', 'TRAD-SYL-2020-0105');

INSERT INTO ADMIN_STAFF (AdminID, EmployeeID, Designation) VALUES (11, 'KC-EMP-0011', 'Market Analyst');
INSERT INTO ADMIN_STAFF (AdminID, EmployeeID, Designation) VALUES (12, 'KC-EMP-0012', 'Price Officer');
INSERT INTO ADMIN_STAFF (AdminID, EmployeeID, Designation) VALUES (13, 'KC-EMP-0013', 'Compliance Officer');
INSERT INTO ADMIN_STAFF (AdminID, EmployeeID, Designation) VALUES (14, 'KC-EMP-0014', 'Regional Coordinator');
INSERT INTO ADMIN_STAFF (AdminID, EmployeeID, Designation) VALUES (15, 'KC-EMP-0015', 'System Administrator');

INSERT INTO STORAGE_MANAGER (ManagerID, EmployeeID) VALUES (16, 'KC-SM-0016');
INSERT INTO STORAGE_MANAGER (ManagerID, EmployeeID) VALUES (17, 'KC-SM-0017');
INSERT INTO STORAGE_MANAGER (ManagerID, EmployeeID) VALUES (18, 'KC-SM-0018');
INSERT INTO STORAGE_MANAGER (ManagerID, EmployeeID) VALUES (19, 'KC-SM-0019');
INSERT INTO STORAGE_MANAGER (ManagerID, EmployeeID) VALUES (20, 'KC-SM-0020');

INSERT INTO TRANSPORT_PERSONNEL (PersonnelID, LicenseNo, ExperienceYears) VALUES (21, 'DK-HV-2011-0021', 13);
INSERT INTO TRANSPORT_PERSONNEL (PersonnelID, LicenseNo, ExperienceYears) VALUES (22, 'RG-HV-2013-0022', 11);
INSERT INTO TRANSPORT_PERSONNEL (PersonnelID, LicenseNo, ExperienceYears) VALUES (23, 'DK-HV-2016-0023', 8);
INSERT INTO TRANSPORT_PERSONNEL (PersonnelID, LicenseNo, ExperienceYears) VALUES (24, 'NG-HV-2009-0024', 16);
INSERT INTO TRANSPORT_PERSONNEL (PersonnelID, LicenseNo, ExperienceYears) VALUES (25, 'PB-HV-2014-0025', 10);

COMMIT;

-- =====================================================================
-- SECTION 2 — CROPS AND FARMS
-- =====================================================================

INSERT INTO CROP_CATEGORY (CategoryID, CategoryName, Description) VALUES (1, 'Cereal',  'Staple grain crops -- rice, wheat, maize.');
INSERT INTO CROP_CATEGORY (CategoryID, CategoryName, Description) VALUES (2, 'Tuber',   'Root and tuber crops stored in cold storage.');
INSERT INTO CROP_CATEGORY (CategoryID, CategoryName, Description) VALUES (3, 'Pulse',   'Protein legumes -- lentil, chickpea, mung bean.');
INSERT INTO CROP_CATEGORY (CategoryID, CategoryName, Description) VALUES (4, 'Spice',   'Culinary spice crops -- onion, garlic, chilli.');
INSERT INTO CROP_CATEGORY (CategoryID, CategoryName, Description) VALUES (5, 'Oilseed', 'Oil-bearing seed crops -- mustard, sesame, groundnut.');

-- BasePrice is the floor for BR-09: every batch MinimumPrice below must
-- be >= its crop's BasePrice. That rule has no DB backstop yet (it is
-- cross-table -- Phase 4 service layer owns it), so the seed enforces it
-- by hand. Check the pairing before editing any price here.
INSERT INTO CROP (CropID, CropName, CategoryID, Unit, BasePrice, ShelfLifeDays, Description) VALUES (1, 'Aman Rice',    1, 'kg', 32.00, 365, 'Rain-fed monsoon paddy, harvested Nov-Dec.');
INSERT INTO CROP (CropID, CropName, CategoryID, Unit, BasePrice, ShelfLifeDays, Description) VALUES (2, 'Potato',       2, 'kg', 18.00, 120, 'Cold-storage tuber; Munshiganj is the main belt.');
INSERT INTO CROP (CropID, CropName, CategoryID, Unit, BasePrice, ShelfLifeDays, Description) VALUES (3, 'Lentil',       3, 'kg', 95.00, 300, 'Masur dal; premium pulse crop.');
INSERT INTO CROP (CropID, CropName, CategoryID, Unit, BasePrice, ShelfLifeDays, Description) VALUES (4, 'Onion',        4, 'kg', 45.00,  90, 'Highly price-volatile; Pabna and Faridpur belt.');
INSERT INTO CROP (CropID, CropName, CategoryID, Unit, BasePrice, ShelfLifeDays, Description) VALUES (5, 'Mustard Seed', 5, 'kg', 68.00, 240, 'Crushed for edible oil; winter crop.');

INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, SoilType, IrrigationType, Location, District, Status) VALUES (1, 1, 'Karim Krishi Khamar',  12.50, 'Loam',       'Deep Tubewell',    'Kahaloo, Bogura',        'Bogura',     'ACTIVE');
INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, SoilType, IrrigationType, Location, District, Status) VALUES (2, 2, 'Rahima Agro Field',     8.75, 'Clay Loam',  'Canal',            'Mithapukur, Rangpur',    'Rangpur',    'ACTIVE');
INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, SoilType, IrrigationType, Location, District, Status) VALUES (3, 3, 'Jamal Potato Farm',    15.00, 'Silt Loam',  'Surface Pump',     'Tongibari, Munshiganj',  'Munshiganj', 'ACTIVE');
INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, SoilType, IrrigationType, Location, District, Status) VALUES (4, 4, 'Shafiq Onion Field',    6.25, 'Sandy Loam', 'Shallow Tubewell', 'Sujanagar, Pabna',       'Pabna',      'ACTIVE');
INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, SoilType, IrrigationType, Location, District, Status) VALUES (5, 5, 'Nurjahan Oilseed Farm',10.00, 'Alluvial',   'Rainfed',          'Nagarkanda, Faridpur',   'Faridpur',   'ACTIVE');

COMMIT;

-- =====================================================================
-- SECTION 3 — VIRTUAL ARAT (recursive relationship #1)
--
-- All five rows go in with ParentAratID NULL, then a second pass links
-- them. Doing it in one pass would fail: FK_ARAT_PARENT cannot resolve a
-- parent that has not been inserted yet (PRD 15, self-referencing FK
-- risk). The result is a genuine 3-level tree, so Phase 4's
-- CONNECT BY NOCYCLE query has real depth to walk:
--
--   1 KrishiChain Central Arat (root)
--   +-- 2 North Bengal Regional Arat
--   |    +-- 4 Bogura Zonal Arat
--   +-- 3 Central Regional Arat
--        +-- 5 Munshiganj Zonal Arat
-- =====================================================================

INSERT INTO VIRTUAL_ARAT (AratID, AratName, Region, District, Address, ContactNo, ParentAratID) VALUES (1, 'KrishiChain Central Arat',    'National',    'Dhaka',      '31 Bijoy Sarani, Tejgaon',   '029110001', NULL);
INSERT INTO VIRTUAL_ARAT (AratID, AratName, Region, District, Address, ContactNo, ParentAratID) VALUES (2, 'North Bengal Regional Arat',  'North Bengal','Rangpur',    'Jail Road, Rangpur Sadar',   '052162002', NULL);
INSERT INTO VIRTUAL_ARAT (AratID, AratName, Region, District, Address, ContactNo, ParentAratID) VALUES (3, 'Central Regional Arat',       'Central',     'Dhaka',      'Karwan Bazar, Tejgaon',      '029110003', NULL);
INSERT INTO VIRTUAL_ARAT (AratID, AratName, Region, District, Address, ContactNo, ParentAratID) VALUES (4, 'Bogura Zonal Arat',           'North Bengal','Bogura',     'Station Road, Bogura Sadar', '051266004', NULL);
INSERT INTO VIRTUAL_ARAT (AratID, AratName, Region, District, Address, ContactNo, ParentAratID) VALUES (5, 'Munshiganj Zonal Arat',       'Central',     'Munshiganj', 'Bazar Road, Munshiganj Sadar','069162005', NULL);

-- Second pass: link the hierarchy now that every AratID exists.
UPDATE VIRTUAL_ARAT SET ParentAratID = 1 WHERE AratID IN (2, 3);
UPDATE VIRTUAL_ARAT SET ParentAratID = 2 WHERE AratID = 4;
UPDATE VIRTUAL_ARAT SET ParentAratID = 3 WHERE AratID = 5;

COMMIT;

-- =====================================================================
-- SECTION 4 — HARVEST BATCH (7 rows)
--
-- AvailableQuantity is a VIRTUAL column -- never insert it, Oracle
-- computes TotalQuantity - ReservedQuantity - SoldQuantity itself.
--
-- Batches 1-5 : bidding finished, SOLD, SoldQuantity matches the sale
--               order accepted below. Bidding window is in the past.
-- Batches 6-7 : BIDDING_OPEN with a live window straddling SYSDATE, so
--               the demo can place a real bid on screen.
--
-- MinimumBidQuantity (feedback-batch migration): 10% of TotalQuantity per
-- batch, chosen against the actual seeded BID.RequestedQuantity values in
-- Section 6 below so every already-seeded bid clears its batch's floor --
-- the lowest RequestedQuantity ever bid per batch is 4000/1500/6000/3000/
-- 2000/2500/1800 for batches 1-7, all comfortably above the floor here.
-- =====================================================================

INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (1, 1, 1, 4, TRUNC(SYSDATE) - 60, 5000.000, 0.000, 4000.000, 'A', 13.50, 34.00, TRUNC(SYSDATE) - 58, TRUNC(SYSDATE) - 52, 'SOLD', 500.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (2, 2, 3, 2, TRUNC(SYSDATE) - 55, 2000.000, 0.000, 1500.000, 'A', 10.20, 98.00, TRUNC(SYSDATE) - 53, TRUNC(SYSDATE) - 47, 'SOLD', 200.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (3, 3, 2, 5, TRUNC(SYSDATE) - 50, 8000.000, 0.000, 6000.000, 'B', 78.40, 19.50, TRUNC(SYSDATE) - 48, TRUNC(SYSDATE) - 42, 'SOLD', 800.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (4, 4, 4, 3, TRUNC(SYSDATE) - 30, 3500.000, 0.000, 3000.000, 'A', 12.80, 47.00, TRUNC(SYSDATE) - 28, TRUNC(SYSDATE) - 22, 'SOLD', 350.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (5, 5, 5, 3, TRUNC(SYSDATE) - 18, 2500.000, 0.000, 2000.000, 'B', 8.90, 70.00, TRUNC(SYSDATE) - 16, TRUNC(SYSDATE) - 10, 'SOLD', 250.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (6, 1, 2, 4, TRUNC(SYSDATE) - 10, 4000.000, 0.000, 0.000, 'A', 76.10, 20.00, TRUNC(SYSDATE) - 3, TRUNC(SYSDATE) + 4, 'BIDDING_OPEN', 400.000);
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (7, 3, 4, 5, TRUNC(SYSDATE) - 7,  3000.000, 0.000, 0.000, 'B', 13.10, 48.00, TRUNC(SYSDATE) - 2, TRUNC(SYSDATE) + 5, 'BIDDING_OPEN', 300.000);
-- Batch 8 is LISTED with bidding not yet open, and deliberately receives
-- NO bids. Without it the anti-join half of Q5-candidate Q4 ("batches
-- that attracted no bids at all") matches nothing and the UNION branch
-- reports a meaningless zero.
INSERT INTO HARVEST_BATCH (BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity, ReservedQuantity, SoldQuantity, QualityGrade, MoisturePercentage, MinimumPrice, BiddingStartTime, BiddingEndTime, Status, MinimumBidQuantity) VALUES
 (8, 2, 1, 2, TRUNC(SYSDATE) - 5,  1800.000, 0.000, 0.000, 'A', 12.90, 35.00, TRUNC(SYSDATE) + 1, TRUNC(SYSDATE) + 6, 'LISTED', 180.000);

COMMIT;

-- =====================================================================
-- SECTION 5 — STORAGE (warehouse, weak-entity units, ternary STORES)
-- =====================================================================

-- StorageFeePerKgRate is the flat per-kg, per-season intake fee (see the
-- rationale in 06_storage_workflow.sql). Cold stores charge more than dry
-- warehouses; the potato cold store sits at the top of the 2024-25 band.
INSERT INTO WAREHOUSE (WarehouseID, WarehouseName, Address, District, Capacity, ManagerID, StorageFeePerKgRate) VALUES (1, 'Bogura Cold Storage',           'Sherpur Road, Bogura Sadar',    'Bogura',     500000.000, 16, 7.50);
INSERT INTO WAREHOUSE (WarehouseID, WarehouseName, Address, District, Capacity, ManagerID, StorageFeePerKgRate) VALUES (2, 'Rangpur Agro Warehouse',        'Jail Road, Rangpur Sadar',      'Rangpur',    300000.000, 17, 6.00);
INSERT INTO WAREHOUSE (WarehouseID, WarehouseName, Address, District, Capacity, ManagerID, StorageFeePerKgRate) VALUES (3, 'Munshiganj Potato Cold Store',  'Bazar Road, Munshiganj Sadar',  'Munshiganj', 800000.000, 18, 8.00);
INSERT INTO WAREHOUSE (WarehouseID, WarehouseName, Address, District, Capacity, ManagerID, StorageFeePerKgRate) VALUES (4, 'Pabna Central Warehouse',       'Rupkatha Road, Pabna Sadar',    'Pabna',      250000.000, 19, 5.50);
INSERT INTO WAREHOUSE (WarehouseID, WarehouseName, Address, District, Capacity, ManagerID, StorageFeePerKgRate) VALUES (5, 'Faridpur Grain Store',          'Mujib Road, Faridpur Sadar',    'Faridpur',   200000.000, 20, 5.00);

-- Weak entity #1. UnitNo is the PARTIAL key: it restarts at 1 inside
-- every warehouse, which is exactly why (WarehouseID, UnitNo) is the PK
-- and why there is no global sequence for it.
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (1, 1, 60000.000, 'EMPTY');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (1, 2, 60000.000, 'PARTIAL');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (2, 1, 40000.000, 'EMPTY');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (2, 2, 40000.000, 'EMPTY');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (3, 1, 90000.000, 'EMPTY');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (3, 2, 90000.000, 'PARTIAL');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (4, 1, 35000.000, 'PARTIAL');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (4, 2, 35000.000, 'EMPTY');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (5, 1, 25000.000, 'PARTIAL');
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (5, 2, 25000.000, 'MAINTENANCE');

-- A third unit for warehouse 1. Warehouses 2-5 stop at unit 2, so unit
-- numbering plainly does not come from one global counter -- warehouse 2's
-- unit 1 and warehouse 1's unit 1 are different places that share a
-- number. That is what makes UnitNo a partial key, and why the primary
-- key has to be the pair. Nothing references this row.
INSERT INTO STORAGE_UNIT (WarehouseID, UnitNo, Capacity, Status) VALUES (1, 3, 45000.000, 'EMPTY');

-- Ternary #1: HARVEST_BATCH x STORAGE_UNIT x STORAGE_MANAGER. The
-- manager column is the accountability link -- who authorized the
-- allocation -- and is the reason this stays one table rather than being
-- split into binary relationships.
-- All seven are LEG 1 (pre-sale): the batch is in the farmer's own local
-- storage before it sells, so the consenting customer is the FARMER who
-- owns the batch — RequestedByFarmerID set, RequestedByBuyerID NULL
-- (CK_STORES_CUSTOMER). The farmer here is the owner of the batch's farm:
--   batch 1->farmer 1, 2->2, 3->3, 4->4, 5->5, 6->1, 7->3.
--
-- StorageFeePerKgSnapshot copies the warehouse's rate as it stood at
-- allocation time, which is the whole point of snapshotting it — a later
-- rate change must not reach back into a finished allocation.
--
-- MinimumStorageDays is chosen so the release fork is demonstrable:
-- allocations 4 and 5 are past MinimumReleaseDate (either party may
-- release directly), 6 and 7 are still inside their committed term (the
-- other party has to approve early release).
-- ProposedBy='MANAGER' on all seven: the storage-consent workflow (and
-- now the negotiation feature, feedback-batch migration) has only ever
-- had the manager initiate here -- these predate customer-initiated
-- requests (ProposedBy='CUSTOMER'), which only exist via the app.
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (1, 1, 1, 1, 16, 5000.000, TRUNC(SYSDATE) - 59, TRUNC(SYSDATE) - 45, 'COMPLETED', 1, 10, 7.50, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (2, 2, 2, 1, 17, 2000.000, TRUNC(SYSDATE) - 54, TRUNC(SYSDATE) - 40, 'COMPLETED', 2, 10, 6.00, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (3, 3, 3, 1, 18, 8000.000, TRUNC(SYSDATE) - 49, TRUNC(SYSDATE) - 35, 'COMPLETED', 3, 10, 8.00, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (4, 4, 4, 1, 19, 3500.000, TRUNC(SYSDATE) - 29, NULL,                  'ACTIVE',    4, 10, 5.50, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (5, 5, 5, 1, 20, 2500.000, TRUNC(SYSDATE) - 17, NULL,                  'ACTIVE',    5, 15, 5.00, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (6, 6, 1, 2, 16, 4000.000, TRUNC(SYSDATE) - 9,  NULL,                  'ACTIVE',    1, 30, 7.50, 'MANAGER');
INSERT INTO STORES (AllocationID, BatchID, WarehouseID, UnitNo, ManagerID, QuantityStored, DateIn, DateOut, AllocationStatus, RequestedByFarmerID, MinimumStorageDays, StorageFeePerKgSnapshot, ProposedBy) VALUES (7, 7, 3, 2, 18, 3000.000, TRUNC(SYSDATE) - 6,  NULL,                  'ACTIVE',    3, 20, 8.00, 'MANAGER');

-- ---------------------------------------------------------------------
-- STORAGE_PAYMENT — the aggregation made concrete.
--
-- These reference the STORES *allocation* (AllocationID), not the batch,
-- the unit or the manager: the fee is owed for the allocation as one
-- fact, which is exactly why the ternary had to be aggregated before
-- anything could point at it.
--
-- Amounts equal the StorageFee virtual column
-- (QuantityStored * StorageFeePerKgSnapshot) for that allocation, so the
-- ledger reconciles:
--   alloc 1  5000 x 7.50 = 37500      alloc 4  3500 x 5.50 = 19250
--   alloc 2  2000 x 6.00 = 12000      alloc 5  2500 x 5.00 = 12500
--   alloc 3  8000 x 8.00 = 64000
--
-- The three COMPLETED allocations were settled on release; allocation 4
-- was paid up front while still ACTIVE; allocation 5 is still owed, so
-- there is one PENDING row for the storage-fee screens to show.
-- ---------------------------------------------------------------------
INSERT INTO STORAGE_PAYMENT (StoragePaymentID, AllocationID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (1, 1, 37500.00, 'BANK_TRANSFER',  TRUNC(SYSDATE) - 45, 'TRX-STG-20240001', 'COMPLETED');
INSERT INTO STORAGE_PAYMENT (StoragePaymentID, AllocationID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (2, 2, 12000.00, 'MOBILE_BANKING', TRUNC(SYSDATE) - 40, 'TRX-STG-20240002', 'COMPLETED');
INSERT INTO STORAGE_PAYMENT (StoragePaymentID, AllocationID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (3, 3, 64000.00, 'BANK_TRANSFER',  TRUNC(SYSDATE) - 35, 'TRX-STG-20240003', 'COMPLETED');
INSERT INTO STORAGE_PAYMENT (StoragePaymentID, AllocationID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (4, 4, 19250.00, 'MOBILE_BANKING', TRUNC(SYSDATE) - 28, 'TRX-STG-20240004', 'COMPLETED');
INSERT INTO STORAGE_PAYMENT (StoragePaymentID, AllocationID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (5, 5, 12500.00, 'MOBILE_BANKING', TRUNC(SYSDATE) - 3,  'TRX-STG-20240005', 'PENDING');

COMMIT;

-- =====================================================================
-- SECTION 6 — BID (recursive relationship #2: the outbid chain)
--
-- Same NULL-first-then-UPDATE pattern as VIRTUAL_ARAT: PreviousBidID
-- points at a BidID that may not exist yet at insert time.
--
-- Every chain below satisfies BR-11 by construction (each bid is >= the
-- batch MinimumPrice AND strictly greater than the one it supersedes)
-- and BR-14 (no buyer holds two ACTIVE bids on the same batch).
--
--   Batch 1: 34.50 -> 35.25 -> 36.00 (WON)   <- 3-deep chain
--   Batch 2: 99.00 -> 102.50 (WON)
--   Batch 3: 20.00 -> 21.75 (WON)
--   Batch 4: 48.00 -> 50.25 (WON)
--   Batch 5: 71.00 -> 74.00 (WON)
--   Batch 6: 20.50 -> 22.00 (ACTIVE, live)
--   Batch 7: 49.00 -> 51.50 (ACTIVE, live)
-- =====================================================================

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 1, 1, 6,  34.50, 4000.000, TRUNC(SYSDATE) - 57 + 10/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 2, 1, 7,  35.25, 4000.000, TRUNC(SYSDATE) - 56 + 14/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 3, 1, 10, 36.00, 4000.000, TRUNC(SYSDATE) - 53 + 11/24, 'WON',    NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 4, 2, 9,   99.00, 1500.000, TRUNC(SYSDATE) - 52 + 9/24,  'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 5, 2, 6,  102.50, 1500.000, TRUNC(SYSDATE) - 48 + 16/24, 'WON',    NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 6, 3, 8,  20.00, 6000.000, TRUNC(SYSDATE) - 47 + 12/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 7, 3, 7,  21.75, 6000.000, TRUNC(SYSDATE) - 43 + 15/24, 'WON',    NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 8, 4, 9,  48.00, 3000.000, TRUNC(SYSDATE) - 27 + 10/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES ( 9, 4, 8,  50.25, 3000.000, TRUNC(SYSDATE) - 23 + 13/24, 'WON',    NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (10, 5, 10, 71.00, 2000.000, TRUNC(SYSDATE) - 15 + 11/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (11, 5, 9,  74.00, 2000.000, TRUNC(SYSDATE) - 11 + 17/24, 'WON',    NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (12, 6, 6,  20.50, 2500.000, TRUNC(SYSDATE) - 2  + 10/24, 'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (13, 6, 10, 22.00, 2500.000, TRUNC(SYSDATE) - 1  + 12/24, 'ACTIVE', NULL);

INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (14, 7, 7,  49.00, 1800.000, TRUNC(SYSDATE) - 1  + 9/24,  'OUTBID', NULL);
INSERT INTO BID (BidID, BatchID, BuyerID, BidPricePerKg, RequestedQuantity, BidTime, Status, PreviousBidID) VALUES (15, 7, 8,  51.50, 2000.000, TRUNC(SYSDATE) - 1  + 18/24, 'ACTIVE', NULL);

-- Second pass: link each bid to the one it outbid.
UPDATE BID SET PreviousBidID =  1 WHERE BidID =  2;
UPDATE BID SET PreviousBidID =  2 WHERE BidID =  3;
UPDATE BID SET PreviousBidID =  4 WHERE BidID =  5;
UPDATE BID SET PreviousBidID =  6 WHERE BidID =  7;
UPDATE BID SET PreviousBidID =  8 WHERE BidID =  9;
UPDATE BID SET PreviousBidID = 10 WHERE BidID = 11;
UPDATE BID SET PreviousBidID = 12 WHERE BidID = 13;
UPDATE BID SET PreviousBidID = 14 WHERE BidID = 15;

COMMIT;

-- =====================================================================
-- SECTION 7 — SALE ORDER (the aggregation)
--
-- SALE_ORDER hangs off the WHOLE (BUYER -places- BID -on- HARVEST_BATCH)
-- relationship, not off any one of the three -- that is the aggregation
-- construct, and UQ_ORDER_BID is what makes it 1:1 with the winning bid.
-- TotalAmount is VIRTUAL: never inserted, always AcceptedQuantity x
-- AcceptedPricePerKg.
--
-- PaymentTerms exercises BOTH branches of the revised BR-20 (see
-- context.md): orders 1, 3 and 5 are ON_DELIVERY (payment blocked until
-- transport is DELIVERED), orders 2 and 4 are ADVANCE (payment allowed
-- immediately). Order 5 is ON_DELIVERY and NOT yet delivered, so it
-- deliberately has no PAYMENT row: paying for an undelivered
-- ON_DELIVERY order is precisely what BR-20 forbids.
--
--   SO 1: 4000 x  36.00 = 144,000.00
--   SO 2: 1500 x 102.50 = 153,750.00
--   SO 3: 6000 x  21.75 = 130,500.00
--   SO 4: 3000 x  50.25 = 150,750.00
--   SO 5: 2000 x  74.00 = 148,000.00
--
-- DeliveryPreference (feedback-batch migration): all five backfilled to
-- DIRECT, not left at the column default PENDING. None of the seven
-- seeded STORES rows is leg-2 (all seven are pre-sale, farmer-owned --
-- see Section 5), and every one of these five already has a
-- TRANSPORT_REQUEST past PENDING (DELIVERED/IN_TRANSIT/ASSIGNED, Section
-- 8) -- transport.service.js's new DeliveryPreference gate only applies
-- going forward at claim() time, but leaving these at PENDING would look
-- inconsistent sitting next to already-moving transport rows.
-- =====================================================================

INSERT INTO SALE_ORDER (SaleOrderID, BidID, AcceptedQuantity, AcceptedPricePerKg, OrderDate, Status, PaymentTerms, DeliveryPreference) VALUES (1,  3, 4000.000,  36.00, TRUNC(SYSDATE) - 52, 'COMPLETED',  'ON_DELIVERY', 'DIRECT');
INSERT INTO SALE_ORDER (SaleOrderID, BidID, AcceptedQuantity, AcceptedPricePerKg, OrderDate, Status, PaymentTerms, DeliveryPreference) VALUES (2,  5, 1500.000, 102.50, TRUNC(SYSDATE) - 47, 'COMPLETED',  'ADVANCE', 'DIRECT');
INSERT INTO SALE_ORDER (SaleOrderID, BidID, AcceptedQuantity, AcceptedPricePerKg, OrderDate, Status, PaymentTerms, DeliveryPreference) VALUES (3,  7, 6000.000,  21.75, TRUNC(SYSDATE) - 42, 'COMPLETED',  'ON_DELIVERY', 'DIRECT');
INSERT INTO SALE_ORDER (SaleOrderID, BidID, AcceptedQuantity, AcceptedPricePerKg, OrderDate, Status, PaymentTerms, DeliveryPreference) VALUES (4,  9, 3000.000,  50.25, TRUNC(SYSDATE) - 22, 'IN_TRANSIT', 'ADVANCE', 'DIRECT');
INSERT INTO SALE_ORDER (SaleOrderID, BidID, AcceptedQuantity, AcceptedPricePerKg, OrderDate, Status, PaymentTerms, DeliveryPreference) VALUES (5, 11, 2000.000,  74.00, TRUNC(SYSDATE) - 10, 'CONFIRMED',  'ON_DELIVERY', 'DIRECT');

COMMIT;

-- =====================================================================
-- SECTION 8 — LOGISTICS (vehicles, transport requests, ternary #2)
--
-- Vehicle capacity is checked against the order quantity by hand here
-- (BR-18) for the same reason as BR-09 -- it is cross-table and the
-- Phase 4 service layer owns it, so the seed must not violate it:
--   T1 4000kg -> V1 8000  | T2 1500kg -> V2 5000 | T3 6000kg -> V1 8000
--   T4 3000kg -> V5 6000  | T5 2000kg -> V4 2500
-- =====================================================================

INSERT INTO VEHICLE (VehicleID, VehicleNo, VehicleType, Capacity, Status) VALUES (1, 'DHK-METRO-TA-11-1234', 'Truck',              8000.000, 'AVAILABLE');
INSERT INTO VEHICLE (VehicleID, VehicleNo, VehicleType, Capacity, Status) VALUES (2, 'RANGPUR-TA-12-5678',     'Truck',              5000.000, 'AVAILABLE');
INSERT INTO VEHICLE (VehicleID, VehicleNo, VehicleType, Capacity, Status) VALUES (3, 'DHK-METRO-TA-13-9012', 'Covered Van',        3000.000, 'MAINTENANCE');
INSERT INTO VEHICLE (VehicleID, VehicleNo, VehicleType, Capacity, Status) VALUES (4, 'BOGURA-TA-14-3456',      'Pickup',             2500.000, 'ASSIGNED');
INSERT INTO VEHICLE (VehicleID, VehicleNo, VehicleType, Capacity, Status) VALUES (5, 'DHK-METRO-TA-15-7890', 'Refrigerated Truck', 6000.000, 'ASSIGNED');

INSERT INTO TRANSPORT_REQUEST (TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate, DeliveryDate, DeliveryStatus) VALUES
 (1, 1, 'Bogura Cold Storage, Sherpur Road, Bogura',        'Hossain Traders Depot, Tejgaon, Dhaka',        TRUNC(SYSDATE) - 51, TRUNC(SYSDATE) - 45, 'DELIVERED');
INSERT INTO TRANSPORT_REQUEST (TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate, DeliveryDate, DeliveryStatus) VALUES
 (2, 2, 'Rangpur Agro Warehouse, Jail Road, Rangpur',       'Bengal Agro Exports, Agrabad, Chattogram',     TRUNC(SYSDATE) - 46, TRUNC(SYSDATE) - 40, 'DELIVERED');
INSERT INTO TRANSPORT_REQUEST (TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate, DeliveryDate, DeliveryStatus) VALUES
 (3, 3, 'Munshiganj Potato Cold Store, Munshiganj',         'Parvin Fresh Mart, Dhanmondi, Dhaka',          TRUNC(SYSDATE) - 41, TRUNC(SYSDATE) - 35, 'DELIVERED');
INSERT INTO TRANSPORT_REQUEST (TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate, DeliveryDate, DeliveryStatus) VALUES
 (4, 4, 'Pabna Central Warehouse, Rupkatha Road, Pabna',    'Hasan Food Processing, Fatullah, Narayanganj', TRUNC(SYSDATE) - 21, NULL,                'IN_TRANSIT');
INSERT INTO TRANSPORT_REQUEST (TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate, DeliveryDate, DeliveryStatus) VALUES
 (5, 5, 'Faridpur Grain Store, Mujib Road, Faridpur',       'Anisur Bazar Supply, Zindabazar, Sylhet',      TRUNC(SYSDATE) - 9,  NULL,                'ASSIGNED');

-- Ternary #2: TRANSPORT_REQUEST x VEHICLE x TRANSPORT_PERSONNEL. Vehicle
-- 1 legitimately appears twice -- it finished trip 1 before starting
-- trip 3, which is why the triple (not the vehicle alone) is unique.
INSERT INTO ASSIGNED_TO (AssignmentID, TransportID, VehicleID, PersonnelID, AssignedDate, AssignmentStatus) VALUES (1, 1, 1, 21, TRUNC(SYSDATE) - 50, 'COMPLETED');
INSERT INTO ASSIGNED_TO (AssignmentID, TransportID, VehicleID, PersonnelID, AssignedDate, AssignmentStatus) VALUES (2, 2, 2, 22, TRUNC(SYSDATE) - 45, 'COMPLETED');
INSERT INTO ASSIGNED_TO (AssignmentID, TransportID, VehicleID, PersonnelID, AssignedDate, AssignmentStatus) VALUES (3, 3, 1, 23, TRUNC(SYSDATE) - 40, 'COMPLETED');
INSERT INTO ASSIGNED_TO (AssignmentID, TransportID, VehicleID, PersonnelID, AssignedDate, AssignmentStatus) VALUES (4, 4, 5, 24, TRUNC(SYSDATE) - 20, 'ACTIVE');
INSERT INTO ASSIGNED_TO (AssignmentID, TransportID, VehicleID, PersonnelID, AssignedDate, AssignmentStatus) VALUES (5, 5, 4, 25, TRUNC(SYSDATE) - 8,  'ACTIVE');

COMMIT;

-- =====================================================================
-- SECTION 9 — PAYMENT (direct buyer -> farmer, D-2: no ARAT commission)
--
-- BR-19 (payments must never exceed the order total) and BR-20 (an
-- ON_DELIVERY order cannot be paid before it is delivered) both compare
-- rows across tables, so neither can be a CHECK constraint. The rows
-- below satisfy both by hand; the check at the end of this file proves
-- BR-19 holds. The verdict for each row:
--
--   P1  SO1  144,000.00  ON_DELIVERY, delivered  -> allowed
--   P2  SO2  153,750.00  ADVANCE, pre-delivery   -> allowed (the whole
--                                                   point of the revised
--                                                   BR-20)
--   P3  SO3  130,500.00  ON_DELIVERY, delivered  -> allowed
--   P4  SO4   75,000.00  ADVANCE instalment 1    -> allowed
--   P5  SO4   50,000.00  ADVANCE instalment 2, PENDING
--                        running total 125,000 <= 150,750 -> allowed
--
-- SO5 has no payment on purpose: ON_DELIVERY terms, transport still
-- ASSIGNED. Trying to insert one is the live BR-20 demo.
-- =====================================================================

INSERT INTO PAYMENT (PaymentID, SaleOrderID, BuyerID, FarmerID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (1, 1, 10, 1, 144000.00, 'BANK_TRANSFER', TRUNC(SYSDATE) - 44, 'TRX-BNK-20240001', 'COMPLETED');
INSERT INTO PAYMENT (PaymentID, SaleOrderID, BuyerID, FarmerID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (2, 2, 6,  2, 153750.00, 'BANK_TRANSFER', TRUNC(SYSDATE) - 46, 'TRX-BNK-20240002', 'COMPLETED');
INSERT INTO PAYMENT (PaymentID, SaleOrderID, BuyerID, FarmerID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (3, 3, 7,  3, 130500.00, 'MOBILE_BANKING',TRUNC(SYSDATE) - 34, 'TRX-MFS-20240003', 'COMPLETED');
INSERT INTO PAYMENT (PaymentID, SaleOrderID, BuyerID, FarmerID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (4, 4, 8,  4,  75000.00, 'BANK_TRANSFER', TRUNC(SYSDATE) - 21, 'TRX-BNK-20240004', 'COMPLETED');
INSERT INTO PAYMENT (PaymentID, SaleOrderID, BuyerID, FarmerID, Amount, PaymentMethod, PaymentDate, TransactionReference, PaymentStatus) VALUES
 (5, 4, 8,  4,  50000.00, 'MOBILE_BANKING',TRUNC(SYSDATE) - 5,  'TRX-MFS-20240005', 'PENDING');

COMMIT;

-- =====================================================================
-- SECTION 10 — DAILY MARKET PRICE (30 rows)
--
-- The virtual marketplace's own published price, per crop per arat per
-- day. No LoggedBy column: this figure is derived by the platform from
-- its own trading activity, not typed in by an administrator. That is the
-- whole point -- the middleman cannot set it by hand. Compare
-- BAZAR_DAILY_RECORD in Section 11, which a person does fill in and which
-- therefore does record who did.
-- =====================================================================

-- Aman Rice at the central arat -- steady rise.
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 1, TRUNC(SYSDATE) - 124, 32.40, 30.46, 34.67);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 1, TRUNC(SYSDATE) - 93, 33.10, 31.11, 35.42);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 1, TRUNC(SYSDATE) - 62, 34.20, 32.15, 36.59);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 1, TRUNC(SYSDATE) - 31, 35.30, 33.18, 37.77);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 1, TRUNC(SYSDATE), 36.40, 34.22, 38.95);

-- Potato at the central arat -- post-harvest slide.
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 1, TRUNC(SYSDATE) - 124, 22.50, 21.15, 24.08);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 1, TRUNC(SYSDATE) - 93, 21.40, 20.12, 22.90);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 1, TRUNC(SYSDATE) - 62, 20.10, 18.89, 21.51);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 1, TRUNC(SYSDATE) - 31, 19.20, 18.05, 20.54);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 1, TRUNC(SYSDATE), 18.40, 17.30, 19.69);

-- Lentil at the central arat -- least volatile.
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 1, TRUNC(SYSDATE) - 124, 93.50, 87.89, 100.05);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 1, TRUNC(SYSDATE) - 93, 94.80, 89.11, 101.44);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 1, TRUNC(SYSDATE) - 62, 96.20, 90.43, 102.93);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 1, TRUNC(SYSDATE) - 31, 97.50, 91.65, 104.33);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 1, TRUNC(SYSDATE), 99.10, 93.15, 106.04);

-- Onion at the central arat -- volatile, sharp late rise.
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 1, TRUNC(SYSDATE) - 124, 41.00, 38.54, 43.87);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 1, TRUNC(SYSDATE) - 93, 47.50, 44.65, 50.83);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 1, TRUNC(SYSDATE) - 62, 43.20, 40.61, 46.22);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 1, TRUNC(SYSDATE) - 31, 49.80, 46.81, 53.29);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 1, TRUNC(SYSDATE), 52.60, 49.44, 56.28);

-- Mustard Seed at the central arat -- climbs late.
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 1, TRUNC(SYSDATE) - 124, 66.20, 62.23, 70.83);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 1, TRUNC(SYSDATE) - 93, 67.10, 63.07, 71.80);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 1, TRUNC(SYSDATE) - 62, 69.40, 65.24, 74.26);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 1, TRUNC(SYSDATE) - 31, 73.80, 69.37, 78.97);
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 1, TRUNC(SYSDATE), 78.20, 73.51, 83.67);

-- One row per sale order, at the batch's own arat on the order date.
-- These five are what Q1 joins to; the verdict each produces is in
-- the comment. Mustard is deliberately unflattering -- it proves Q1
-- can report against the platform, not only for it.
-- SO 1  rice   got 36.00 vs 34.50  BEAT MARKET
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (1, 4, TRUNC(SYSDATE) - 52, 34.50, 32.43, 36.91);
-- SO 2  lentil got 102.50 vs 99.00 BEAT MARKET
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (3, 2, TRUNC(SYSDATE) - 47, 99.00, 93.06, 105.93);
-- SO 3  potato got 21.75 vs 20.80  BEAT MARKET
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (2, 5, TRUNC(SYSDATE) - 42, 20.80, 19.55, 22.26);
-- SO 4  onion  got 50.25 vs 48.60  BEAT MARKET
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (4, 3, TRUNC(SYSDATE) - 22, 48.60, 45.68, 52.00);
-- SO 5  mustard got 74.00 vs 76.50 BELOW MARKET
INSERT INTO DAILY_MARKET_PRICE (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice) VALUES (5, 3, TRUNC(SYSDATE) - 10, 76.50, 71.91, 81.86);

COMMIT;

-- =====================================================================
-- SECTION 11 — PHYSICAL BAZAR, REVIEWS, COMPLAINTS
-- =====================================================================

INSERT INTO PHYSICAL_BAZAR (BazarID, BazarName, Address, District, ContactNo) VALUES (1, 'Karwan Bazar',       'Karwan Bazar, Tejgaon',        'Dhaka',      '029110101');
INSERT INTO PHYSICAL_BAZAR (BazarID, BazarName, Address, District, ContactNo) VALUES (2, 'Shyambazar',         'Shyambazar, Kotwali',          'Dhaka',      '029110102');
INSERT INTO PHYSICAL_BAZAR (BazarID, BazarName, Address, District, ContactNo) VALUES (3, 'Bogura Hat',         'Station Road, Bogura Sadar',   'Bogura',     '051266103');
INSERT INTO PHYSICAL_BAZAR (BazarID, BazarName, Address, District, ContactNo) VALUES (4, 'Rangpur City Bazar', 'Jail Road, Rangpur Sadar',     'Rangpur',    '052162104');
INSERT INTO PHYSICAL_BAZAR (BazarID, BazarName, Address, District, ContactNo) VALUES (5, 'Khatunganj',         'Khatunganj, Kotwali',          'Chattogram', '031262105');

-- WEAK ENTITY #2, and the reason CropID belongs in its primary key.
--
-- A bazar trades several crops on the same day. Bazar 1 below records
-- three crops on one date -- which a key of (BazarID, RecordDate) alone
-- would have made impossible, allowing only one crop per bazar per day
-- and defeating the point of keeping the history at all.
--
-- Revenue is always PricePerKg * TransactionVolume, so the stored price
-- and the price implied by the revenue agree (checked at the end of this
-- file). LoggedBy is the admin who covers that district: these figures
-- are collected from a physical marketplace by a person, so who entered
-- them is part of the record.
--
-- Bazar prices sit just BELOW the platform's accepted prices. That gap is
-- the comparison Q6 reports, and the argument the whole project makes.
-- matches SO 1 -- Karwan Bazar rice below Abdul 36.00
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (1, TRUNC(SYSDATE) - 52, 1, 33.72, 18500.000, 623820.00, 11);
-- same bazar, same day, different crop
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (1, TRUNC(SYSDATE) - 52, 2, 18.56, 24200.000, 449152.00, 11);
-- and a third -- impossible under a 2-column key
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (1, TRUNC(SYSDATE) - 52, 3, 96.10, 4300.000, 413230.00, 11);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (1, TRUNC(SYSDATE) - 20, 1, 35.10, 17200.000, 603720.00, 11);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (1, TRUNC(SYSDATE) - 20, 2, 19.20, 22400.000, 430080.00, 11);

-- matches SO 2 -- below Rahima 102.50
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (2, TRUNC(SYSDATE) - 47, 3, 98.40, 4100.000, 403440.00, 13);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (2, TRUNC(SYSDATE) - 47, 1, 33.10, 15600.000, 516360.00, 13);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (2, TRUNC(SYSDATE) - 12, 4, 46.90, 8800.000, 412720.00, 13);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (2, TRUNC(SYSDATE) - 12, 3, 97.20, 3900.000, 379080.00, 13);

-- matches SO 3 -- below Jamal 21.75
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (3, TRUNC(SYSDATE) - 42, 2, 20.10, 12750.000, 256275.00, 14);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (3, TRUNC(SYSDATE) - 42, 1, 33.90, 14100.000, 477990.00, 14);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (3, TRUNC(SYSDATE) - 5, 1, 36.10, 13400.000, 483740.00, 14);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (3, TRUNC(SYSDATE) - 5, 2, 18.90, 15900.000, 300510.00, 14);

-- matches SO 4 -- below Shafiqul 50.25
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (4, TRUNC(SYSDATE) - 22, 4, 47.80, 6100.000, 291580.00, 12);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (4, TRUNC(SYSDATE) - 22, 2, 19.40, 11200.000, 217280.00, 12);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (4, TRUNC(SYSDATE) - 8, 1, 35.60, 12900.000, 459240.00, 12);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (4, TRUNC(SYSDATE) - 8, 4, 49.10, 5800.000, 284780.00, 12);

-- matches SO 5 -- Nurjahan beat the bazar, lost to the arat
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (5, TRUNC(SYSDATE) - 10, 5, 72.50, 3200.000, 232000.00, 15);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (5, TRUNC(SYSDATE) - 10, 3, 97.80, 3600.000, 352080.00, 15);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (5, TRUNC(SYSDATE) - 3, 4, 50.90, 7400.000, 376660.00, 15);
INSERT INTO BAZAR_DAILY_RECORD (BazarID, RecordDate, CropID, PricePerKg, TransactionVolume, Revenue, LoggedBy) VALUES (5, TRUNC(SYSDATE) - 3, 5, 74.80, 2900.000, 216920.00, 15);

-- P2 tables: seeded so the schema is demonstrably complete, no UI in
-- Update-1. UQ_REVIEW_ORDER means one review per sale order.
INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment, ReviewDate) VALUES (1, 1, 5, 'Grade A Aman rice, moisture exactly as listed. Delivered to Tejgaon two days early.',              TRUNC(SYSDATE) - 43);
INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment, ReviewDate) VALUES (2, 2, 4, 'Good lentil quality. Advance payment terms worked well, though loading at Rangpur was slow.',        TRUNC(SYSDATE) - 38);
INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment, ReviewDate) VALUES (3, 3, 3, 'Potato lot had roughly 4 percent spoilage on arrival. Cold chain held, but the grading was optimistic.', TRUNC(SYSDATE) - 33);
INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment, ReviewDate) VALUES (4, 4, 4, 'Onion quality is good so far. Consignment still in transit at the time of writing.',                 TRUNC(SYSDATE) - 15);
INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment, ReviewDate) VALUES (5, 5, 4, 'Mustard seed sample matched the listing. Awaiting dispatch from Faridpur.',                          TRUNC(SYSDATE) - 6);

INSERT INTO COMPLAINT (ComplaintID, SaleOrderID, ComplaintType, Description, Status, ResolutionDate, HandledByAdminID) VALUES
 (1, 3, 'QUALITY',        'Buyer reports ~4% spoilage in the potato consignment; requests partial credit.', 'RESOLVED',  TRUNC(SYSDATE) - 30, 13);
INSERT INTO COMPLAINT (ComplaintID, SaleOrderID, ComplaintType, Description, Status, ResolutionDate, HandledByAdminID) VALUES
 (2, 1, 'DOCUMENTATION',  'Weighbridge slip missing from the delivery paperwork at Tejgaon depot.',          'RESOLVED',  TRUNC(SYSDATE) - 42, 11);
INSERT INTO COMPLAINT (ComplaintID, SaleOrderID, ComplaintType, Description, Status, ResolutionDate, HandledByAdminID) VALUES
 (3, 4, 'DELAY',          'Consignment has been in transit past the expected delivery window.',              'IN_REVIEW', NULL,                14);
INSERT INTO COMPLAINT (ComplaintID, SaleOrderID, ComplaintType, Description, Status, ResolutionDate, HandledByAdminID) VALUES
 (4, 2, 'PAYMENT',        'Farmer queried the advance settlement date shown on the order.',                  'RESOLVED',  TRUNC(SYSDATE) - 44, 12);
INSERT INTO COMPLAINT (ComplaintID, SaleOrderID, ComplaintType, Description, Status, ResolutionDate, HandledByAdminID) VALUES
 (5, 5, 'LOGISTICS',      'Pickup from Faridpur Grain Store not yet scheduled after vehicle assignment.',    'OPEN',      NULL,                NULL);

-- ---------------------------------------------------------------------
-- NOTIFICATION — one per role, so every branch of the specialization has
-- something in its bell. UserID references USERS directly rather than a
-- subclass, since all five roles are notified the same way.
--
-- RelatedEntityType / RelatedEntityID point at rows that actually exist
-- above, so following a notification lands on real data:
--   batch 6 (bidding open), batch 1 (sold), allocation 6 (ACTIVE),
--   complaint 3 (IN_REVIEW, handled by admin 14), transport request 4.
-- CreatedAt uses INTERVAL arithmetic because the column is TIMESTAMP.
-- ---------------------------------------------------------------------
INSERT INTO NOTIFICATION (NotificationID, UserID, Type, Title, Message, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
 (1,  1, 'BID_PLACED',         'New bid on your Aman Rice',        'A buyer has bid on batch 6. Review the standing bids before the window closes.',     'HARVEST_BATCH',     6, 'N', SYSTIMESTAMP - INTERVAL '4'  HOUR);
INSERT INTO NOTIFICATION (NotificationID, UserID, Type, Title, Message, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
 (2, 10, 'BID_OUTBID',         'You have been outbid',             'Your bid on batch 1 was superseded by a higher one. Place a new bid to stay in.',     'HARVEST_BATCH',     1, 'Y', SYSTIMESTAMP - INTERVAL '3'  DAY);
INSERT INTO NOTIFICATION (NotificationID, UserID, Type, Title, Message, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
 (3, 16, 'STORAGE_ACCEPTED',   'Allocation 6 accepted',            'The customer accepted your storage terms. Unit 2 at Bogura Cold Storage is now ACTIVE.', 'STORES',          6, 'N', SYSTIMESTAMP - INTERVAL '9'  DAY);
INSERT INTO NOTIFICATION (NotificationID, UserID, Type, Title, Message, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
 (4, 14, 'COMPLAINT_RAISED',   'Complaint 3 is awaiting review',   'A delivery-delay complaint is open against sale order 4 and is assigned to you.',    'COMPLAINT',         3, 'N', SYSTIMESTAMP - INTERVAL '2'  DAY);
INSERT INTO NOTIFICATION (NotificationID, UserID, Type, Title, Message, RelatedEntityType, RelatedEntityID, IsRead, CreatedAt) VALUES
 (5, 21, 'TRANSPORT_ASSIGNED', 'You are assigned to trip 4',       'Collect from the farm gate and update the delivery status as the trip progresses.',   'TRANSPORT_REQUEST', 4, 'Y', SYSTIMESTAMP - INTERVAL '20' DAY);

COMMIT;

-- =====================================================================
-- VERIFICATION
-- =====================================================================

PROMPT
PROMPT ============ ROW COUNTS (every table must be 5 or more) ============
SELECT 'USERS' AS table_name, COUNT(*) AS rows_seeded FROM USERS
UNION ALL SELECT 'USER_PHONE',          COUNT(*) FROM USER_PHONE
UNION ALL SELECT 'FARMER',              COUNT(*) FROM FARMER
UNION ALL SELECT 'BUYER',               COUNT(*) FROM BUYER
UNION ALL SELECT 'ADMIN_STAFF',         COUNT(*) FROM ADMIN_STAFF
UNION ALL SELECT 'STORAGE_MANAGER',     COUNT(*) FROM STORAGE_MANAGER
UNION ALL SELECT 'TRANSPORT_PERSONNEL', COUNT(*) FROM TRANSPORT_PERSONNEL
UNION ALL SELECT 'CROP_CATEGORY',       COUNT(*) FROM CROP_CATEGORY
UNION ALL SELECT 'CROP',                COUNT(*) FROM CROP
UNION ALL SELECT 'FARM',                COUNT(*) FROM FARM
UNION ALL SELECT 'VIRTUAL_ARAT',        COUNT(*) FROM VIRTUAL_ARAT
UNION ALL SELECT 'HARVEST_BATCH',       COUNT(*) FROM HARVEST_BATCH
UNION ALL SELECT 'WAREHOUSE',           COUNT(*) FROM WAREHOUSE
UNION ALL SELECT 'STORAGE_UNIT',        COUNT(*) FROM STORAGE_UNIT
UNION ALL SELECT 'STORES',              COUNT(*) FROM STORES
UNION ALL SELECT 'BID',                 COUNT(*) FROM BID
UNION ALL SELECT 'SALE_ORDER',          COUNT(*) FROM SALE_ORDER
UNION ALL SELECT 'PAYMENT',             COUNT(*) FROM PAYMENT
UNION ALL SELECT 'STORAGE_PAYMENT',     COUNT(*) FROM STORAGE_PAYMENT
UNION ALL SELECT 'VEHICLE',             COUNT(*) FROM VEHICLE
UNION ALL SELECT 'TRANSPORT_REQUEST',   COUNT(*) FROM TRANSPORT_REQUEST
UNION ALL SELECT 'ASSIGNED_TO',         COUNT(*) FROM ASSIGNED_TO
UNION ALL SELECT 'DAILY_MARKET_PRICE',  COUNT(*) FROM DAILY_MARKET_PRICE
UNION ALL SELECT 'PHYSICAL_BAZAR',      COUNT(*) FROM PHYSICAL_BAZAR
UNION ALL SELECT 'BAZAR_DAILY_RECORD',  COUNT(*) FROM BAZAR_DAILY_RECORD
UNION ALL SELECT 'REVIEW',              COUNT(*) FROM REVIEW
UNION ALL SELECT 'COMPLAINT',           COUNT(*) FROM COMPLAINT
UNION ALL SELECT 'NOTIFICATION',        COUNT(*) FROM NOTIFICATION
ORDER  BY 1;

PROMPT
PROMPT ============ VIRTUAL COLUMNS COMPUTE THEMSELVES ============
PROMPT AvailableQuantity and TotalAmount were never inserted.
SELECT BatchID, TotalQuantity, SoldQuantity, AvailableQuantity FROM HARVEST_BATCH ORDER BY BatchID;
SELECT SaleOrderID, AcceptedQuantity, AcceptedPricePerKg, TotalAmount FROM SALE_ORDER ORDER BY SaleOrderID;
SELECT AllocationID, QuantityStored, StorageFeePerKgSnapshot, StorageFee, DateIn, MinimumStorageDays, MinimumReleaseDate
FROM   STORES ORDER BY AllocationID;

PROMPT
PROMPT ============ WEAK ENTITY 1: units are numbered per warehouse ============
PROMPT Every warehouse restarts at unit 1 -- UnitNo alone identifies nothing.
SELECT WarehouseID, UnitNo, Capacity, Status FROM STORAGE_UNIT ORDER BY WarehouseID, UnitNo;

PROMPT
PROMPT ============ WEAK ENTITY 2: several crops per bazar per day ============
PROMPT This is what needs CropID inside the primary key. Bazar 1 has three
PROMPT crops on one date; a 2-column key would have allowed only one.
SELECT BazarID, TO_CHAR(RecordDate,'DD-MON-YY') AS record_date, COUNT(*) AS crops_recorded
FROM   BAZAR_DAILY_RECORD
GROUP  BY BazarID, RecordDate
HAVING COUNT(*) > 1
ORDER  BY BazarID, 2;

PROMPT
PROMPT ============ BAZAR PRICE RECONCILES WITH ITS OWN REVENUE ============
PROMPT stored_price and implied_price must match on every row.
SELECT BazarID, CropID, PricePerKg AS stored_price,
       ROUND(Revenue / TransactionVolume, 2) AS implied_price,
       CASE WHEN PricePerKg = ROUND(Revenue / TransactionVolume, 2)
            THEN 'MATCH' ELSE '*** MISMATCH ***' END AS check_result
FROM   BAZAR_DAILY_RECORD ORDER BY BazarID, RecordDate, CropID;

PROMPT
PROMPT ============ TWO RECURSIVE RELATIONSHIPS ARE LINKED ============
SELECT AratID, AratName, ParentAratID FROM VIRTUAL_ARAT ORDER BY NVL(ParentAratID, 0), AratID;
SELECT BidID, BatchID, BuyerID, BidPricePerKg, Status, PreviousBidID
FROM   BID WHERE PreviousBidID IS NOT NULL ORDER BY BidID;

PROMPT
PROMPT ============ Q1 WILL FIND A PRICE FOR ALL 5 SALE ORDERS ============
PROMPT price_found must be 'YES' on every row, or that sale drops out of Q1.
SELECT so.SaleOrderID, c.CropName, hb.AratID,
       so.AcceptedPricePerKg AS got,
       (SELECT dmp.PricePerKg FROM DAILY_MARKET_PRICE dmp
         WHERE dmp.CropID = hb.CropID AND dmp.AratID = hb.AratID
           AND dmp.PriceDate = TRUNC(so.OrderDate)) AS market,
       CASE WHEN EXISTS (SELECT 1 FROM DAILY_MARKET_PRICE dmp
                          WHERE dmp.CropID = hb.CropID AND dmp.AratID = hb.AratID
                            AND dmp.PriceDate = TRUNC(so.OrderDate))
            THEN 'YES' ELSE '*** NO ***' END AS price_found
FROM   SALE_ORDER so
JOIN   BID b            ON b.BidID    = so.BidID
JOIN   HARVEST_BATCH hb ON hb.BatchID = b.BatchID
JOIN   CROP c           ON c.CropID   = hb.CropID
ORDER  BY so.SaleOrderID;

PROMPT
PROMPT ============ Q5 NEEDS SEVERAL MONTHS PER CROP ============
PROMPT Each crop should show 5 months, so LAG has something to compare.
SELECT c.CropName, COUNT(DISTINCT TO_CHAR(dmp.PriceDate,'YYYY-MM')) AS months_of_history
FROM   DAILY_MARKET_PRICE dmp JOIN CROP c ON c.CropID = dmp.CropID
GROUP  BY c.CropName ORDER BY c.CropName;

PROMPT
PROMPT ============ BR-09 BY HAND: batch minimum >= crop base price ============
SELECT hb.BatchID, c.CropName, c.BasePrice, hb.MinimumPrice,
       CASE WHEN hb.MinimumPrice >= c.BasePrice THEN 'OK' ELSE '*** BREACH ***' END AS br09
FROM   HARVEST_BATCH hb JOIN CROP c ON c.CropID = hb.CropID ORDER BY hb.BatchID;

PROMPT
PROMPT ============ BR-19 BY HAND: payments never exceed the order ============
SELECT so.SaleOrderID, so.PaymentTerms, so.TotalAmount,
       NVL(SUM(p.Amount), 0) AS paid_so_far,
       so.TotalAmount - NVL(SUM(p.Amount), 0) AS outstanding
FROM   SALE_ORDER so
LEFT   JOIN PAYMENT p ON p.SaleOrderID = so.SaleOrderID
                     AND p.PaymentStatus IN ('PENDING','COMPLETED')
GROUP  BY so.SaleOrderID, so.PaymentTerms, so.TotalAmount
ORDER  BY so.SaleOrderID;

PROMPT
PROMPT ============ NO TRIGGERS, NO SEQUENCES IN THIS BUILD ============
SELECT COUNT(*) AS triggers_present  FROM user_triggers;
SELECT COUNT(*) AS sequences_present FROM user_sequences;

-- =====================================================================
-- End of 02_insert_data.sql — next: 03_advanced_queries.sql
--
-- OPTIONAL, BENGALI TEXT. NLS_CHARACTERSET here is AL32UTF8, so every
-- VARCHAR2(n CHAR) column stores Bengali correctly. The seed is English
-- because the risk is on the CLIENT side: a SQL*Plus session without
-- NLS_LANG set turns Bengali into '?' on the way in, silently and with no
-- error. To demonstrate the support, set NLS_LANG first, then:
--
--   UPDATE CROP SET CropName = '<bengali>' WHERE CropID = 1;
--   COMMIT;
--   SELECT CropID, CropName, LENGTH(CropName) AS chars,
--          LENGTHB(CropName) AS bytes FROM CROP;
--
-- chars < bytes is the proof that CHAR semantics are doing their job.
-- =====================================================================
