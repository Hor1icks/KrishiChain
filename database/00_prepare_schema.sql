-- Run this file as SYSTEM or SYSDBA before 01_create_tables.sql.
-- It fixes the common XE 11g mistake where a newly-created application
-- user defaults to the SYSTEM tablespace and every CREATE TABLE fails
-- with ORA-01950. The KRISHICHAIN user must already exist.

ALTER USER KRISHICHAIN
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

SELECT Username, Default_Tablespace, Temporary_Tablespace, Account_Status
  FROM DBA_USERS
 WHERE Username = 'KRISHICHAIN';

PROMPT Expected: KRISHICHAIN | USERS | TEMP | OPEN
