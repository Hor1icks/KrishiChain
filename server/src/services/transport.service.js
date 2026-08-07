'use strict';

const { query, withTransaction } = require('../config/db');
const ApiError = require('../utils/ApiError');

async function getDashboard(personnelId) {
  const assignments = await query(
    `SELECT a.AssignmentID, a.AssignmentStatus, a.AssignedDate,
            tr.TransportID, tr.PickupLocation, tr.DeliveryLocation,
            tr.DeliveryStatus, tr.DeliveryDate,
            v.VehicleNo, v.VehicleType, v.Capacity,
            so.SaleOrderID, so.AcceptedQuantity
       FROM ASSIGNED_TO a
       JOIN TRANSPORT_REQUEST tr ON tr.TransportID = a.TransportID
       JOIN VEHICLE v ON v.VehicleID = a.VehicleID
       JOIN SALE_ORDER so ON so.SaleOrderID = tr.SaleOrderID
      WHERE a.PersonnelID = :personnelId
      ORDER BY CASE a.AssignmentStatus WHEN 'ACTIVE' THEN 0 ELSE 1 END,
               a.AssignedDate DESC`,
    { personnelId }
  );
  return { assignments: assignments.rows };
}

async function updateDelivery(personnelId, assignmentId, status) {
  const normalized = String(status || '').toUpperCase();
  const allowed = ['PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'FAILED'];
  if (!allowed.includes(normalized)) {
    throw ApiError.badRequest(`Status must be one of: ${allowed.join(', ')}.`);
  }

  return withTransaction(async (connection) => {
    const found = await connection.execute(
      `SELECT a.TransportID, a.VehicleID, tr.SaleOrderID
         FROM ASSIGNED_TO a
         JOIN TRANSPORT_REQUEST tr ON tr.TransportID = a.TransportID
        WHERE a.AssignmentID = :assignmentId
          AND a.PersonnelID = :personnelId
          AND a.AssignmentStatus = 'ACTIVE'
        FOR UPDATE`,
      { assignmentId, personnelId }
    );
    if (!found.rows.length) throw ApiError.notFound('Active assignment not found.');
    const row = found.rows[0];

    await connection.execute(
      `UPDATE TRANSPORT_REQUEST
          SET DeliveryStatus = :status,
              DeliveryDate = CASE WHEN :status = 'DELIVERED' THEN SYSDATE ELSE DeliveryDate END
        WHERE TransportID = :transportId`,
      { status: normalized, transportId: row.TRANSPORTID }
    );
    if (normalized === 'DELIVERED' || normalized === 'FAILED') {
      await connection.execute(
        `UPDATE ASSIGNED_TO SET AssignmentStatus = 'COMPLETED'
          WHERE AssignmentID = :assignmentId`,
        { assignmentId }
      );
      await connection.execute(
        `UPDATE VEHICLE SET Status = 'AVAILABLE' WHERE VehicleID = :vehicleId`,
        { vehicleId: row.VEHICLEID }
      );
    }
    if (normalized === 'DELIVERED') {
      await connection.execute(
        `UPDATE SALE_ORDER SET Status = 'COMPLETED' WHERE SaleOrderID = :saleOrderId`,
        { saleOrderId: row.SALEORDERID }
      );
    } else if (normalized === 'IN_TRANSIT') {
      await connection.execute(
        `UPDATE SALE_ORDER SET Status = 'IN_TRANSIT' WHERE SaleOrderID = :saleOrderId`,
        { saleOrderId: row.SALEORDERID }
      );
    }
    return { assignmentId, deliveryStatus: normalized };
  });
}

module.exports = { getDashboard, updateDelivery };
