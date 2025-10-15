const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'database.db');
const db = new sqlite3.Database(dbPath);

console.log('=== VERIFICA TIMBRATURE FORZATE ===\n');

db.all(`
  SELECT 
    ar.id,
    e.name as dipendente,
    ar.type,
    datetime(ar.timestamp, 'localtime') as timestamp,
    admin.name as forzato_da,
    ar.notes
  FROM attendance_records ar
  JOIN employees e ON ar.employeeId = e.id
  LEFT JOIN employees admin ON ar.forcedByAdminId = admin.id
  WHERE ar.forcedByAdminId IS NOT NULL
  ORDER BY ar.timestamp DESC
  LIMIT 20
`, [], (err, records) => {
  if (err) {
    console.error('Errore:', err);
    db.close();
    return;
  }
  
  console.log(`Trovate ${records.length} timbrature forzate:\n`);
  
  if (records.length === 0) {
    console.log('Nessuna timbratura forzata trovata nel database.');
  } else {
    records.forEach(record => {
      console.log(`[${record.id}] ${record.dipendente} - ${record.type.toUpperCase()} - ${record.timestamp}`);
      console.log(`    Forzato da: ${record.forzato_da || 'N/D'}`);
      if (record.notes) {
        console.log(`    Note: ${record.notes}`);
      }
      console.log('');
    });
  }
  
  db.close();
});
