SET SQLBLANKLINES ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT
PROMPT ============================================================
PROMPT  Non-destructive checks for the 9-trigger layer
PROMPT ============================================================

DECLARE
  v_user_id USERS.UserID%TYPE;
  v_email   USERS.Email%TYPE;
BEGIN
  SAVEPOINT before_user_test;

  INSERT INTO USERS (
    FirstName, LastName, Email, PasswordHash, Gender,
    DateOfBirth, Address, Role
  ) VALUES (
    'Trigger', 'Test', '  TRIGGER.TEST@EXAMPLE.COM  ', 'not-a-login', 'O',
    DATE '1990-01-01', t_address(NULL, NULL, NULL, NULL, 'Dhaka', NULL), 'BUYER'
  )
  RETURNING UserID, Email INTO v_user_id, v_email;

  IF v_user_id < 1001 OR v_email <> 'trigger.test@example.com' THEN
    RAISE_APPLICATION_ERROR(-20991, 'USERS preparation trigger test failed.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('PASS: user ID generated and email normalized.');
  ROLLBACK TO before_user_test;
END;
/

DECLARE
  v_farm_id FARM.FarmID%TYPE;
BEGIN
  SAVEPOINT before_sequence_test;

  INSERT INTO FARM (FarmID, FarmerID, FarmName, Area, District)
  VALUES (seq_farm_id.NEXTVAL, 1, 'Sequence Test Farm', 1, 'Bogura')
  RETURNING FarmID INTO v_farm_id;

  IF v_farm_id < 1001 THEN
    RAISE_APPLICATION_ERROR(-20992, 'Direct sequence test failed.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('PASS: direct sequence ID returned without an ID trigger.');
  ROLLBACK TO before_sequence_test;
END;
/

BEGIN
  BEGIN
    UPDATE HARVEST_BATCH
       SET MinimumPrice = 1
     WHERE BatchID = 6;
    RAISE_APPLICATION_ERROR(-20998, 'Batch listing guard accepted a below-base price.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20011 THEN
        DBMS_OUTPUT.PUT_LINE('PASS: below-base batch price rejected.');
      ELSE
        RAISE;
      END IF;
  END;
END;
/

DECLARE
  v_before NUMBER;
  v_after  NUMBER;
  v_batch_id HARVEST_BATCH.BatchID%TYPE;
BEGIN
  SAVEPOINT before_bid_note;
  SELECT COUNT(*) INTO v_before FROM NOTIFICATION;

  INSERT INTO HARVEST_BATCH (
    BatchID, FarmID, CropID, AratID, HarvestDate, TotalQuantity,
    MinimumPrice, BiddingStartTime, BiddingEndTime, Status,
    MinimumBidQuantity
  ) VALUES (
    seq_harvest_batch_id.NEXTVAL, 1, 1, 1, TRUNC(SYSDATE), 1000,
    100, SYSTIMESTAMP - INTERVAL '1' HOUR,
    SYSTIMESTAMP + INTERVAL '1' HOUR, 'LISTED', 100
  ) RETURNING BatchID INTO v_batch_id;

  INSERT INTO BID (
    BidID, BatchID, BuyerID, BidPricePerKg,
    RequestedQuantity, Status, PreviousBidID
  ) VALUES (
    seq_bid_id.NEXTVAL, v_batch_id, 6, 110, 100, 'ACTIVE', NULL
  );

  SELECT COUNT(*) INTO v_after FROM NOTIFICATION;
  IF v_after <> v_before + 1 THEN
    RAISE_APPLICATION_ERROR(-20999, 'Bid notification trigger test failed.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('PASS: valid bid passed checks and notified the farmer.');
  ROLLBACK TO before_bid_note;
END;
/

BEGIN
  BEGIN
    UPDATE STORES
       SET AllocationStatus = 'IN_TRANSIT'
     WHERE AllocationID = 4;
    RAISE_APPLICATION_ERROR(-20993, 'Storage guard accepted an invalid transition.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20031 THEN
        DBMS_OUTPUT.PUT_LINE('PASS: invalid storage transition rejected.');
      ELSE
        RAISE;
      END IF;
  END;
END;
/

BEGIN
  BEGIN
    UPDATE TRANSPORT_REQUEST
       SET DeliveryStatus = 'PENDING'
     WHERE TransportID = 5;
    RAISE_APPLICATION_ERROR(-20994, 'Transport guard accepted an invalid transition.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20041 THEN
        DBMS_OUTPUT.PUT_LINE('PASS: invalid transport transition rejected.');
      ELSE
        RAISE;
      END IF;
  END;
END;
/

BEGIN
  BEGIN
    INSERT INTO REVIEW (ReviewID, SaleOrderID, Rating, ReviewComment)
    VALUES (seq_review_id.NEXTVAL, 5, 5, 'This row must be rejected.');
    RAISE_APPLICATION_ERROR(-20995, 'Review guard accepted an incomplete order.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20051 THEN
        DBMS_OUTPUT.PUT_LINE('PASS: premature review rejected.');
      ELSE
        RAISE;
      END IF;
  END;
END;
/

DECLARE
  v_before NUMBER;
  v_after  NUMBER;
BEGIN
  SAVEPOINT before_trip_note;
  SELECT COUNT(*) INTO v_before FROM NOTIFICATION;

  UPDATE TRANSPORT_REQUEST
     SET DeliveryStatus = 'PICKED_UP'
   WHERE TransportID = 5;

  SELECT COUNT(*) INTO v_after FROM NOTIFICATION;
  IF v_after <> v_before + 2 THEN
    RAISE_APPLICATION_ERROR(-20996, 'Transport notification trigger test failed.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('PASS: transport update notified farmer and buyer.');
  ROLLBACK TO before_trip_note;
END;
/

DECLARE
  v_before NUMBER;
  v_after  NUMBER;
BEGIN
  SAVEPOINT before_farm_note;
  SELECT COUNT(*) INTO v_before FROM NOTIFICATION;

  UPDATE FARM
     SET VerificationStatus = 'REJECTED',
         VerificationReviewedAt = TRUNC(SYSDATE),
         VerifiedByAdminID = 13
   WHERE FarmID = 3;

  SELECT COUNT(*) INTO v_after FROM NOTIFICATION;
  IF v_after <> v_before + 1 THEN
    RAISE_APPLICATION_ERROR(-20997, 'Farm notification trigger test failed.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('PASS: farm-verification result notified the farmer.');
  ROLLBACK TO before_farm_note;
END;
/

ROLLBACK;

PROMPT All trigger checks passed; test rows were rolled back.
PROMPT
