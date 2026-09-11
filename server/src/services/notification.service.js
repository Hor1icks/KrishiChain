'use strict';

const { query, withTransaction } = require('../config/db');
const ApiError = require('../utils/ApiError');

async function listForUser(userId) {
  const [items, unread] = await Promise.all([
    query(
      `SELECT * FROM (
         SELECT NotificationID    AS "notificationId",
                Type              AS "type",
                Title             AS "title",
                Message           AS "message",
                RelatedEntityType AS "relatedEntityType",
                RelatedEntityID   AS "relatedEntityId",
                IsRead            AS "isRead",
                CreatedAt         AS "createdAt"
           FROM NOTIFICATION
          WHERE UserID = :userId
          ORDER BY CreatedAt DESC, NotificationID DESC
       ) WHERE ROWNUM <= 20`,
      { userId }
    ),
    query(
      `SELECT COUNT(*) AS "unreadCount"
         FROM NOTIFICATION
        WHERE UserID = :userId AND IsRead = 'N'`,
      { userId }
    ),
  ]);

  return {
    notifications: items.rows,
    unreadCount: unread.rows[0].unreadCount,
  };
}

async function markRead(userId, notificationId) {
  return withTransaction(async (connection) => {
    const result = await connection.execute(
      `UPDATE NOTIFICATION
          SET IsRead = 'Y'
        WHERE NotificationID = :notificationId AND UserID = :userId`,
      { notificationId, userId }
    );
    if (!result.rowsAffected) throw ApiError.notFound('No such notification.');
    return { notificationId, isRead: 'Y' };
  });
}

module.exports = { listForUser, markRead };
