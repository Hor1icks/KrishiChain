SET LINESIZE 180
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ============================================================
PROMPT  UPDATE-3: SEQUENCE, TRIGGER AND INDEXING
PROMPT ============================================================

PROMPT
PROMPT === 1. Sequences used for surrogate primary keys ===
COLUMN sequence_name FORMAT A32
SELECT sequence_name, increment_by, cache_size, last_number
FROM   user_sequences
ORDER  BY sequence_name;

PROMPT
PROMPT === 2. Varied trigger layer ===
COLUMN trigger_name FORMAT A32
COLUMN table_name   FORMAT A24
COLUMN status       FORMAT A10
SELECT trigger_name, table_name, triggering_event, status
FROM   user_triggers
ORDER  BY table_name;

PROMPT
PROMPT === 3. Application indexes (PK/UQ indexes are not duplicated) ===
COLUMN index_name FORMAT A32
COLUMN columns    FORMAT A70
SELECT i.index_name,
       i.table_name,
       LISTAGG(ic.column_name, ', ') WITHIN GROUP (ORDER BY ic.column_position) AS columns
FROM   user_indexes i
JOIN   user_ind_columns ic ON ic.index_name = i.index_name
WHERE  i.index_name LIKE 'IX\_%' ESCAPE '\'
GROUP  BY i.index_name, i.table_name
ORDER  BY i.table_name, i.index_name;

PROMPT
PROMPT === 4. Direct sequence proof: generated ID, then rollback the row ===
SET SERVEROUTPUT ON
DECLARE
  v_farm_id FARM.FarmID%TYPE;
BEGIN
  INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, District)
  VALUES (seq_farm_id.NEXTVAL, 1, 'Update-3 Sequence Proof', 1, 'Bogura')
  RETURNING FarmID INTO v_farm_id;

  DBMS_OUTPUT.PUT_LINE('Generated FarmID = ' || v_farm_id);
  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('Rolled back: the demonstration row was not saved.');
END;
/

PROMPT
PROMPT === 5. Final object counts ===
SELECT object_type, status, COUNT(*) AS object_count
FROM   user_objects
WHERE  object_type IN ('SEQUENCE', 'TRIGGER', 'INDEX')
GROUP  BY object_type, status
ORDER  BY object_type;

PROMPT
PROMPT Update-3 demonstration complete.
PROMPT
