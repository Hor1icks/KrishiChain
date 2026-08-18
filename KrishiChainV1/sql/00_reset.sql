-- =====================================================================
-- KrishiChain V1 | 00_reset.sql
--
-- Drops all 28 tables, so 01_create_tables.sql can be run again from a
-- genuinely empty schema.
--
-- Run as `krishichain_demo`. In SQL Developer press F5 (Run Script).
--
-- ---------------------------------------------------------------------
-- ON A SCHEMA THAT IS ALREADY EMPTY, EVERY STATEMENT BELOW REPORTS
--
--   ORA-00942: table or view does not exist
--
-- and that is the correct, expected result — not a failure. There is
-- nothing to drop. Run 01_create_tables.sql next either way.
--
-- ---------------------------------------------------------------------
-- Two clauses on every DROP, both doing real work:
--
--   CASCADE CONSTRAINTS  also drops foreign keys in OTHER tables that
--                        point at this one. Without it, dropping a parent
--                        before its children fails with ORA-02449.
--   PURGE                skips the recycle bin, so the table is gone
--                        immediately rather than lingering as a BIN$...
--                        object that still holds its storage.
--
-- The order below is children-before-parents anyway, so the drops would
-- mostly succeed without CASCADE CONSTRAINTS. It is there so that a
-- partially-created schema — a create script that stopped halfway — still
-- resets cleanly.
-- =====================================================================

-- Leaves: nothing references these ------------------------------------
DROP TABLE NOTIFICATION        CASCADE CONSTRAINTS PURGE;
DROP TABLE COMPLAINT           CASCADE CONSTRAINTS PURGE;
DROP TABLE REVIEW              CASCADE CONSTRAINTS PURGE;

-- Price reference ------------------------------------------------------
DROP TABLE BAZAR_DAILY_RECORD  CASCADE CONSTRAINTS PURGE;
DROP TABLE PHYSICAL_BAZAR      CASCADE CONSTRAINTS PURGE;
DROP TABLE DAILY_MARKET_PRICE  CASCADE CONSTRAINTS PURGE;

-- Logistics ------------------------------------------------------------
DROP TABLE ASSIGNED_TO         CASCADE CONSTRAINTS PURGE;
DROP TABLE TRANSPORT_REQUEST   CASCADE CONSTRAINTS PURGE;
DROP TABLE VEHICLE             CASCADE CONSTRAINTS PURGE;

-- Money ----------------------------------------------------------------
DROP TABLE STORAGE_PAYMENT     CASCADE CONSTRAINTS PURGE;
DROP TABLE PAYMENT             CASCADE CONSTRAINTS PURGE;

-- Storage, bidding and sale -------------------------------------------
DROP TABLE STORES              CASCADE CONSTRAINTS PURGE;
DROP TABLE SALE_ORDER          CASCADE CONSTRAINTS PURGE;
DROP TABLE BID                 CASCADE CONSTRAINTS PURGE;
DROP TABLE STORAGE_UNIT        CASCADE CONSTRAINTS PURGE;
DROP TABLE WAREHOUSE           CASCADE CONSTRAINTS PURGE;

-- Production -----------------------------------------------------------
DROP TABLE HARVEST_BATCH       CASCADE CONSTRAINTS PURGE;
DROP TABLE VIRTUAL_ARAT        CASCADE CONSTRAINTS PURGE;
DROP TABLE FARM                CASCADE CONSTRAINTS PURGE;
DROP TABLE CROP                CASCADE CONSTRAINTS PURGE;
DROP TABLE CROP_CATEGORY       CASCADE CONSTRAINTS PURGE;

-- The specialization, then its superclass ------------------------------
DROP TABLE TRANSPORT_PERSONNEL CASCADE CONSTRAINTS PURGE;
DROP TABLE STORAGE_MANAGER     CASCADE CONSTRAINTS PURGE;
DROP TABLE ADMIN_STAFF         CASCADE CONSTRAINTS PURGE;
DROP TABLE BUYER               CASCADE CONSTRAINTS PURGE;
DROP TABLE FARMER              CASCADE CONSTRAINTS PURGE;
DROP TABLE USER_PHONE          CASCADE CONSTRAINTS PURGE;
DROP TABLE USERS               CASCADE CONSTRAINTS PURGE;

-- =====================================================================
-- VERIFICATION — both counts must be 0
-- =====================================================================

SELECT COUNT(*) AS tables_remaining FROM user_tables;

SELECT COUNT(*) AS recycle_bin_objects FROM user_recyclebin;

-- =====================================================================
-- End of 00_reset.sql — next: 01_create_tables.sql
-- =====================================================================
