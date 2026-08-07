'use strict';
const { query, withTransaction } = require('../config/db');
const ApiError = require('../utils/ApiError');

async function getDashboard() {
  const result = await query(
    `SELECT (SELECT COUNT(*) FROM USERS) Users,
            (SELECT COUNT(*) FROM HARVEST_BATCH WHERE Status = 'ACTIVE') ActiveBatches,
            (SELECT COUNT(*) FROM SALE_ORDER WHERE Status <> 'CANCELLED') Orders,
            (SELECT COUNT(*) FROM COMPLAINT WHERE Status IN ('OPEN','IN_REVIEW')) OpenComplaints
       FROM dual`
  );
  return result.rows[0];
}
async function listUsers() {
  return (await query(
    `SELECT UserID, FirstName, LastName, Email, Role, Status, RegistrationDate
       FROM USERS ORDER BY RegistrationDate DESC, UserID DESC`
  )).rows;
}
async function setUserStatus(userId, status) {
  const value = String(status || '').toUpperCase();
  if (!['ACTIVE', 'BLOCKED', 'INACTIVE'].includes(value)) {
    throw ApiError.badRequest('Invalid account status.');
  }
  return withTransaction(async (connection) => {
    const result = await connection.execute(
      `UPDATE USERS SET Status = :status WHERE UserID = :userId`, { status: value, userId }
    );
    if (!result.rowsAffected) throw ApiError.notFound('User not found.');
    return { userId, status: value };
  });
}
async function listPrices() {
  return (await query(
    `SELECT * FROM (
       SELECT d.CropID, c.CropName, d.AratID, a.AratName, d.PriceDate,
              d.PricePerKg, d.MinPrice, d.MaxPrice
         FROM DAILY_MARKET_PRICE d JOIN CROP c ON c.CropID=d.CropID
         JOIN VIRTUAL_ARAT a ON a.AratID=d.AratID
        ORDER BY d.PriceDate DESC, c.CropName
     ) WHERE ROWNUM <= 100`
  )).rows;
}
async function addPrice(adminId, body) {
  const values = ['cropId','aratId','priceDate','pricePerKg','minPrice','maxPrice'];
  if (values.some((key) => body[key] === undefined || body[key] === '')) {
    throw ApiError.badRequest(`Required: ${values.join(', ')}.`);
  }
  return withTransaction(async (connection) => {
    await connection.execute(
      `INSERT INTO DAILY_MARKET_PRICE
       (CropID, AratID, PriceDate, PricePerKg, MinPrice, MaxPrice, LoggedBy)
       VALUES (:cropId,:aratId,TO_DATE(:priceDate,'YYYY-MM-DD'),:pricePerKg,:minPrice,:maxPrice,:adminId)`,
      { ...body, adminId }
    );
    return { created: true };
  });
}
async function listComplaints() {
  return (await query(
    `SELECT c.ComplaintID, c.SaleOrderID, c.ComplaintType, c.Description,
            c.Status, c.ResolutionDate, c.HandledByAdminID
       FROM COMPLAINT c
      ORDER BY CASE c.Status WHEN 'OPEN' THEN 0 WHEN 'IN_REVIEW' THEN 1 ELSE 2 END,
               c.ComplaintID DESC`
  )).rows;
}
async function resolveComplaint(adminId, complaintId, body) {
  const status = String(body.status || '').toUpperCase();
  if (!['IN_REVIEW','RESOLVED','REJECTED'].includes(status)) throw ApiError.badRequest('Invalid complaint status.');
  return withTransaction(async (connection) => {
    const result = await connection.execute(
      `UPDATE COMPLAINT SET Status=:status, HandledByAdminID=:adminId,
       ResolutionDate=CASE WHEN :status IN ('RESOLVED','REJECTED') THEN SYSDATE ELSE NULL END
       WHERE ComplaintID=:complaintId`,
      { status, adminId, complaintId }
    );
    if (!result.rowsAffected) throw ApiError.notFound('Complaint not found.');
    return { complaintId, status };
  });
}
async function getLogistics() {
  const [requests, vehicles, personnel] = await Promise.all([
    query(`SELECT TransportID, SaleOrderID, PickupLocation, DeliveryLocation, RequestDate
             FROM TRANSPORT_REQUEST WHERE DeliveryStatus = 'PENDING' ORDER BY RequestDate`),
    query(`SELECT VehicleID, VehicleNo, VehicleType, Capacity FROM VEHICLE
            WHERE Status = 'AVAILABLE' ORDER BY Capacity DESC`),
    query(`SELECT t.PersonnelID, u.FirstName || ' ' || u.LastName AS Name, t.LicenseNo
             FROM TRANSPORT_PERSONNEL t JOIN USERS u ON u.UserID=t.PersonnelID
            WHERE u.Status='ACTIVE' ORDER BY u.FirstName`),
  ]);
  return { requests: requests.rows, vehicles: vehicles.rows, personnel: personnel.rows };
}
async function assignTransport(body) {
  const transportId=Number(body.transportId), vehicleId=Number(body.vehicleId), personnelId=Number(body.personnelId);
  if (![transportId,vehicleId,personnelId].every(Number.isInteger)) throw ApiError.badRequest('Transport, vehicle and personnel are required.');
  return withTransaction(async(connection)=>{
    const request=await connection.execute(`SELECT TransportID FROM TRANSPORT_REQUEST WHERE TransportID=:transportId AND DeliveryStatus='PENDING' FOR UPDATE`,{transportId});
    if(!request.rows.length) throw ApiError.conflict('Transport request is no longer pending.');
    const vehicle=await connection.execute(`SELECT VehicleID FROM VEHICLE WHERE VehicleID=:vehicleId AND Status='AVAILABLE' FOR UPDATE`,{vehicleId});
    if(!vehicle.rows.length) throw ApiError.conflict('Vehicle is no longer available.');
    const person=await connection.execute(`SELECT PersonnelID FROM TRANSPORT_PERSONNEL WHERE PersonnelID=:personnelId`,{personnelId});
    if(!person.rows.length) throw ApiError.notFound('Transport personnel not found.');
    const inserted=await connection.execute(`INSERT INTO ASSIGNED_TO(TransportID,VehicleID,PersonnelID) VALUES(:transportId,:vehicleId,:personnelId) RETURNING AssignmentID INTO :assignmentId`,{transportId,vehicleId,personnelId,assignmentId:{dir:require('oracledb').BIND_OUT,type:require('oracledb').NUMBER}});
    await connection.execute(`UPDATE TRANSPORT_REQUEST SET DeliveryStatus='ASSIGNED' WHERE TransportID=:transportId`,{transportId});
    await connection.execute(`UPDATE VEHICLE SET Status='ASSIGNED' WHERE VehicleID=:vehicleId`,{vehicleId});
    return {assignmentId:inserted.outBinds.assignmentId[0]};
  });
}
module.exports={getDashboard,listUsers,setUserStatus,listPrices,addPrice,listComplaints,resolveComplaint,getLogistics,assignTransport};
