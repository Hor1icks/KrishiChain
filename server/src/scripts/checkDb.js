'use strict';

const db = require('../config/db');

async function main() {
  try {
    await db.initialize();
    const objects = await db.query(`SELECT Object_Type, COUNT(*) AS Count
      FROM USER_OBJECTS GROUP BY Object_Type ORDER BY Object_Type`);
    console.table(objects.rows);
    const indexes = await db.query(`SELECT Index_Type, COUNT(*) AS Count
      FROM USER_INDEXES GROUP BY Index_Type ORDER BY Index_Type`);
    console.table(indexes.rows);
    const invalid = await db.query(`SELECT Object_Name, Object_Type FROM USER_OBJECTS WHERE Status <> 'VALID'`);
    const disabled = await db.query(`SELECT Trigger_Name FROM USER_TRIGGERS WHERE Status <> 'ENABLED'`);
    if (invalid.rows.length || disabled.rows.length) {
      console.table(invalid.rows);
      console.table(disabled.rows);
      throw new Error('Database has invalid objects or disabled triggers.');
    }
    console.log('Database connected; all objects valid and all triggers enabled. No data changed.');
  } finally { await db.close(); }
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
