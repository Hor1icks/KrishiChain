SET SQLBLANKLINES ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ============================================================
PROMPT  Trigger-only migration: remove repetitive ID triggers
PROMPT ============================================================

-- This migration changes trigger objects only. It does not alter a table,
-- column, key, constraint, sequence, index, view, or ER definition.
BEGIN
  FOR r IN (
    SELECT trigger_name
      FROM user_triggers
     WHERE trigger_name IN (
       'TRG_USERS_ID', 'TRG_CROP_CATEGORY_ID', 'TRG_CROP_ID',
       'TRG_FARM_ID', 'TRG_VIRTUAL_ARAT_ID', 'TRG_HARVEST_BATCH_ID',
       'TRG_WAREHOUSE_ID', 'TRG_STORES_ID', 'TRG_BID_ID',
       'TRG_SALE_ORDER_ID', 'TRG_PAYMENT_ID', 'TRG_VEHICLE_ID',
       'TRG_TRANSPORT_REQUEST_ID', 'TRG_ASSIGNED_TO_ID',
       'TRG_PHYSICAL_BAZAR_ID', 'TRG_REVIEW_ID',
       'TRG_COMPLAINT_ID', 'TRG_NOTIFICATION_ID'
     )
  ) LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER ' || r.trigger_name;
  END LOOP;
END;
/

PROMPT Repetitive ID triggers removed. The 9-trigger layer remains active.
PROMPT
