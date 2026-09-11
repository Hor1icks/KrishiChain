CREATE INDEX ix_farm_verify_queue ON FARM (VerificationStatus, VerificationRequestedAt);
CREATE INDEX ix_transport_type_status ON TRANSPORT_REQUEST (RequestType, DeliveryStatus);

PROMPT Added the two Update 4 lookup indexes.
