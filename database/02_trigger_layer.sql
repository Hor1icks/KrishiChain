SET SQLBLANKLINES ON

PROMPT
PROMPT ============================================================
PROMPT  KrishiChain trigger layer (9 varied triggers)
PROMPT ============================================================

-- One trigger keeps the familiar automatic-ID example, while also
-- normalizing email addresses. Other application INSERT statements use
-- their sequence directly, which avoids repeating this trigger 18 times.
CREATE OR REPLACE TRIGGER trg_users_prepare
BEFORE INSERT OR UPDATE OF Email ON USERS
FOR EACH ROW
BEGIN
  IF INSERTING AND :NEW.UserID IS NULL THEN
    SELECT seq_users_id.NEXTVAL INTO :NEW.UserID FROM dual;
  END IF;

  :NEW.Email := LOWER(TRIM(:NEW.Email));
END;
/

-- A listed batch must respect the crop's official base price and have a
-- complete bidding window. This protects direct SQL as well as the API.
CREATE OR REPLACE TRIGGER trg_batch_listing_guard
BEFORE INSERT OR UPDATE OF CropID, MinimumPrice, BiddingStartTime,
  BiddingEndTime, Status ON HARVEST_BATCH
FOR EACH ROW
DECLARE
  v_base_price CROP.BasePrice%TYPE;
BEGIN
  SELECT BasePrice
    INTO v_base_price
    FROM CROP
   WHERE CropID = :NEW.CropID;

  IF :NEW.MinimumPrice IS NOT NULL AND :NEW.MinimumPrice < v_base_price THEN
    RAISE_APPLICATION_ERROR(-20011,
      'Batch minimum price cannot be below the crop base price.');
  END IF;

  IF :NEW.Status IN ('LISTED', 'BIDDING_OPEN') THEN
    IF :NEW.MinimumPrice IS NULL OR :NEW.BiddingStartTime IS NULL
       OR :NEW.BiddingEndTime IS NULL THEN
      RAISE_APPLICATION_ERROR(-20012,
        'A listed batch needs a minimum price and complete bidding window.');
    END IF;

    IF :NEW.BiddingEndTime <= :NEW.BiddingStartTime THEN
      RAISE_APPLICATION_ERROR(-20013,
        'Bidding end time must be after the start time.');
    END IF;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20014, 'The selected crop does not exist.');
END;
/

-- The fixed demonstration rows use IDs below 1001. Runtime IDs begin at
-- 1001, so current-time auction checks apply to new operational bids while
-- the historical teaching dataset remains reproducible.
CREATE OR REPLACE TRIGGER trg_bid_guard
BEFORE INSERT ON BID
FOR EACH ROW
DECLARE
  v_status       HARVEST_BATCH.Status%TYPE;
  v_min_price    HARVEST_BATCH.MinimumPrice%TYPE;
  v_min_qty      HARVEST_BATCH.MinimumBidQuantity%TYPE;
  v_available    HARVEST_BATCH.AvailableQuantity%TYPE;
  v_start_time   HARVEST_BATCH.BiddingStartTime%TYPE;
  v_end_time     HARVEST_BATCH.BiddingEndTime%TYPE;
  v_farmer_id    FARM.FarmerID%TYPE;
BEGIN
  IF :NEW.BidID IS NULL OR :NEW.BidID >= 1001 THEN
    SELECT hb.Status, hb.MinimumPrice, hb.MinimumBidQuantity,
           hb.AvailableQuantity, hb.BiddingStartTime, hb.BiddingEndTime,
           f.FarmerID
      INTO v_status, v_min_price, v_min_qty,
           v_available, v_start_time, v_end_time, v_farmer_id
      FROM HARVEST_BATCH hb
      JOIN FARM f ON f.FarmID = hb.FarmID
     WHERE hb.BatchID = :NEW.BatchID;

    IF v_status NOT IN ('LISTED', 'BIDDING_OPEN')
       OR v_start_time IS NULL OR v_end_time IS NULL
       OR SYSTIMESTAMP < v_start_time OR SYSTIMESTAMP >= v_end_time THEN
      RAISE_APPLICATION_ERROR(-20021, 'This batch is not open for bidding.');
    END IF;

    IF :NEW.BidPricePerKg < v_min_price THEN
      RAISE_APPLICATION_ERROR(-20022,
        'Bid price cannot be below the batch minimum price.');
    END IF;

    IF :NEW.RequestedQuantity < v_min_qty
       OR :NEW.RequestedQuantity > v_available THEN
      RAISE_APPLICATION_ERROR(-20023,
        'Bid quantity must meet the minimum and available quantity limits.');
    END IF;

    IF :NEW.BuyerID = v_farmer_id THEN
      RAISE_APPLICATION_ERROR(-20024, 'A farmer cannot bid on their own batch.');
    END IF;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20025, 'The selected batch does not exist.');
END;
/

-- Only recognized storage-allocation transitions are accepted. Extra shape
-- checks ensure arrival and completion dates match their states.
CREATE OR REPLACE TRIGGER trg_stores_status_guard
BEFORE UPDATE OF AllocationStatus ON STORES
FOR EACH ROW
BEGIN
  IF :OLD.AllocationStatus <> :NEW.AllocationStatus THEN
    IF NOT (
      (:OLD.AllocationStatus = 'PENDING_ACCEPT' AND
       :NEW.AllocationStatus IN ('COUNTERED', 'IN_TRANSIT', 'REJECTED', 'CANCELLED')) OR
      (:OLD.AllocationStatus = 'COUNTERED' AND
       :NEW.AllocationStatus IN ('IN_TRANSIT', 'REJECTED', 'CANCELLED')) OR
      (:OLD.AllocationStatus = 'IN_TRANSIT' AND
       :NEW.AllocationStatus IN ('ACTIVE', 'CANCELLED')) OR
      (:OLD.AllocationStatus = 'ACTIVE' AND
       :NEW.AllocationStatus IN ('PENDING_RELEASE', 'COMPLETED')) OR
      (:OLD.AllocationStatus = 'PENDING_RELEASE' AND
       :NEW.AllocationStatus IN ('ACTIVE', 'COMPLETED'))
    ) THEN
      RAISE_APPLICATION_ERROR(-20031,
        'Invalid storage transition: ' || :OLD.AllocationStatus ||
        ' to ' || :NEW.AllocationStatus || '.');
    END IF;

    IF :NEW.AllocationStatus = 'IN_TRANSIT' AND :NEW.DateIn IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20032,
        'An in-transit allocation cannot have an arrival date.');
    END IF;

    IF :NEW.AllocationStatus = 'ACTIVE' AND :NEW.DateIn IS NULL THEN
      RAISE_APPLICATION_ERROR(-20033,
        'An active allocation must have an arrival date.');
    END IF;

    IF :NEW.AllocationStatus = 'COMPLETED' AND :NEW.DateOut IS NULL THEN
      RAISE_APPLICATION_ERROR(-20034,
        'A completed allocation must have a release date.');
    END IF;
  END IF;
END;
/

-- Transport follows its operational stages. The direct DELIVERED paths are
-- retained because the current API supports completing an assigned/picked-up
-- trip in one action as well as advancing through every screen.
CREATE OR REPLACE TRIGGER trg_transport_status_guard
BEFORE UPDATE OF DeliveryStatus ON TRANSPORT_REQUEST
FOR EACH ROW
BEGIN
  IF :OLD.DeliveryStatus <> :NEW.DeliveryStatus THEN
    IF NOT (
      (:OLD.DeliveryStatus = 'PENDING' AND
       :NEW.DeliveryStatus IN ('ASSIGNED', 'FAILED')) OR
      (:OLD.DeliveryStatus = 'ASSIGNED' AND
       :NEW.DeliveryStatus IN ('PICKED_UP', 'DELIVERED', 'FAILED')) OR
      (:OLD.DeliveryStatus = 'PICKED_UP' AND
       :NEW.DeliveryStatus IN ('IN_TRANSIT', 'DELIVERED', 'FAILED')) OR
      (:OLD.DeliveryStatus = 'IN_TRANSIT' AND
       :NEW.DeliveryStatus IN ('DELIVERED', 'FAILED'))
    ) THEN
      RAISE_APPLICATION_ERROR(-20041,
        'Invalid transport transition: ' || :OLD.DeliveryStatus ||
        ' to ' || :NEW.DeliveryStatus || '.');
    END IF;

    IF :NEW.DeliveryStatus = 'DELIVERED' AND :NEW.DeliveryDate IS NULL THEN
      RAISE_APPLICATION_ERROR(-20042,
        'A delivered transport request must have a delivery date.');
    END IF;
  END IF;
END;
/

-- Reviews are an after-sale action. As with bid history, IDs 1-1000 remain
-- reserved for the fixed demonstration dataset.
CREATE OR REPLACE TRIGGER trg_review_guard
BEFORE INSERT ON REVIEW
FOR EACH ROW
DECLARE
  v_order_status SALE_ORDER.Status%TYPE;
BEGIN
  IF :NEW.ReviewID IS NULL OR :NEW.ReviewID >= 1001 THEN
    SELECT Status
      INTO v_order_status
      FROM SALE_ORDER
     WHERE SaleOrderID = :NEW.SaleOrderID;

    IF v_order_status <> 'COMPLETED' THEN
      RAISE_APPLICATION_ERROR(-20051,
        'A review can only be submitted after the order is completed.');
    END IF;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20052, 'The reviewed sale order does not exist.');
END;
/

-- Notify the farmer when a new operational bid is accepted by the database.
CREATE OR REPLACE TRIGGER trg_bid_notification
AFTER INSERT ON BID
FOR EACH ROW
DECLARE
  v_farmer_id FARM.FarmerID%TYPE;
  v_crop_name CROP.CropName%TYPE;
BEGIN
  IF :NEW.BidID >= 1001 THEN
    SELECT f.FarmerID, c.CropName
      INTO v_farmer_id, v_crop_name
      FROM HARVEST_BATCH hb
      JOIN FARM f ON f.FarmID = hb.FarmID
      JOIN CROP c ON c.CropID = hb.CropID
     WHERE hb.BatchID = :NEW.BatchID;

    INSERT INTO NOTIFICATION (
      NotificationID, UserID, Type, Title, Message,
      RelatedEntityType, RelatedEntityID
    ) VALUES (
      seq_notification_id.NEXTVAL, v_farmer_id, 'BID_PLACED',
      'New bid on ' || v_crop_name,
      'A buyer bid ' || TO_CHAR(:NEW.BidPricePerKg) || ' per kg for ' ||
        TO_CHAR(:NEW.RequestedQuantity) || ' kg.',
      'HARVEST_BATCH', :NEW.BatchID
    );
  END IF;
END;
/

-- A transport status change is relevant to the farmer and, where present,
-- the buyer and storage manager. Queries stay on related tables, avoiding a
-- mutating-table query on TRANSPORT_REQUEST itself.
CREATE OR REPLACE TRIGGER trg_transport_notification
AFTER UPDATE OF DeliveryStatus ON TRANSPORT_REQUEST
FOR EACH ROW
DECLARE
  v_farmer_id FARM.FarmerID%TYPE;
  v_buyer_id  BUYER.BuyerID%TYPE;
  v_manager_id STORAGE_MANAGER.ManagerID%TYPE;
  v_title     VARCHAR2(150);
  v_message   VARCHAR2(500);
BEGIN
  IF :OLD.DeliveryStatus <> :NEW.DeliveryStatus THEN
    v_buyer_id := NULL;
    v_manager_id := NULL;

    IF :NEW.RequestType = 'STORAGE_INBOUND' THEN
      SELECT f.FarmerID, s.RequestedByBuyerID, s.ManagerID
        INTO v_farmer_id, v_buyer_id, v_manager_id
        FROM STORES s
        JOIN HARVEST_BATCH hb ON hb.BatchID = s.BatchID
        JOIN FARM f ON f.FarmID = hb.FarmID
       WHERE s.AllocationID = :NEW.AllocationID;
    ELSE
      SELECT f.FarmerID, b.BuyerID
        INTO v_farmer_id, v_buyer_id
        FROM SALE_ORDER so
        JOIN BID b ON b.BidID = so.BidID
        JOIN HARVEST_BATCH hb ON hb.BatchID = b.BatchID
        JOIN FARM f ON f.FarmID = hb.FarmID
       WHERE so.SaleOrderID = :NEW.SaleOrderID;
    END IF;

    v_title := 'Transport ' || LOWER(REPLACE(:NEW.DeliveryStatus, '_', ' '));
    v_message := 'Transport request ' || :NEW.TransportID || ' changed from ' ||
      REPLACE(:OLD.DeliveryStatus, '_', ' ') || ' to ' ||
      REPLACE(:NEW.DeliveryStatus, '_', ' ') || '.';

    INSERT INTO NOTIFICATION (
      NotificationID, UserID, Type, Title, Message,
      RelatedEntityType, RelatedEntityID
    ) VALUES (
      seq_notification_id.NEXTVAL, v_farmer_id, 'TRANSPORT_STATUS',
      v_title, v_message, 'TRANSPORT_REQUEST', :NEW.TransportID
    );

    IF v_buyer_id IS NOT NULL THEN
      INSERT INTO NOTIFICATION (
        NotificationID, UserID, Type, Title, Message,
        RelatedEntityType, RelatedEntityID
      ) VALUES (
        seq_notification_id.NEXTVAL, v_buyer_id, 'TRANSPORT_STATUS',
        v_title, v_message, 'TRANSPORT_REQUEST', :NEW.TransportID
      );
    END IF;

    IF v_manager_id IS NOT NULL THEN
      INSERT INTO NOTIFICATION (
        NotificationID, UserID, Type, Title, Message,
        RelatedEntityType, RelatedEntityID
      ) VALUES (
        seq_notification_id.NEXTVAL, v_manager_id, 'TRANSPORT_STATUS',
        v_title, v_message, 'TRANSPORT_REQUEST', :NEW.TransportID
      );
    END IF;
  END IF;
END;
/

-- The farmer receives the result when an agriculture/admin officer reviews
-- the farm verification request.
CREATE OR REPLACE TRIGGER trg_farm_verify_notification
AFTER UPDATE OF VerificationStatus ON FARM
FOR EACH ROW
BEGIN
  IF :OLD.VerificationStatus <> :NEW.VerificationStatus THEN
    INSERT INTO NOTIFICATION (
      NotificationID, UserID, Type, Title, Message,
      RelatedEntityType, RelatedEntityID
    ) VALUES (
      seq_notification_id.NEXTVAL, :NEW.FarmerID, 'FARM_VERIFICATION',
      'Farm verification ' || LOWER(:NEW.VerificationStatus),
      'The verification status for ' || :NEW.FarmName || ' is now ' ||
        LOWER(:NEW.VerificationStatus) || '.',
      'FARM', :NEW.FarmID
    );
  END IF;
END;
/

DECLARE
  v_invalid NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_invalid
    FROM user_objects
   WHERE object_type = 'TRIGGER'
     AND object_name IN (
       'TRG_USERS_PREPARE', 'TRG_BATCH_LISTING_GUARD', 'TRG_BID_GUARD',
       'TRG_STORES_STATUS_GUARD', 'TRG_TRANSPORT_STATUS_GUARD',
       'TRG_REVIEW_GUARD', 'TRG_BID_NOTIFICATION',
       'TRG_TRANSPORT_NOTIFICATION', 'TRG_FARM_VERIFY_NOTIFICATION'
     )
     AND status <> 'VALID';

  IF v_invalid > 0 THEN
    RAISE_APPLICATION_ERROR(-20090,
      v_invalid || ' trigger(s) failed to compile. Check USER_ERRORS.');
  END IF;
END;
/

PROMPT Created 9 varied triggers.
PROMPT
