/**
 * Script di migrazione per aggiornare i vecchi record forzati
 * Imposta forcedByAdminId basandosi sul deviceInfo "Forzato da [Nome Admin]"
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'database.db');
const db = new sqlite3.Database(dbPath);

console.log('=== MIGRAZIONE RECORD FORZATI ===\n');

// Step 1: Trova tutti i record con coordinate 0,0 (forzati) senza forcedByAdminId
db.all(`
  SELECT ar.id, ar.deviceInfo, e.id as adminId, e.name as adminName
  FROM attendance_records ar
  LEFT JOIN employees e ON ar.deviceInfo LIKE '%Forzato da ' || e.name || '%'
  WHERE ar.latitude = 0.0 
    AND ar.longitude = 0.0 
    AND ar.forcedByAdminId IS NULL
    AND e.id IS NOT NULL
`, [], (err, records) => {
  if (err) {
    console.error('Errore durante la ricerca dei record:', err);
    db.close();
    return;
  }
  
  console.log(`Trovati ${records.length} record forzati da aggiornare\n`);
  
  if (records.length === 0) {
    console.log('Nessun record da migrare. Database già aggiornato.');
    db.close();
    return;
  }
  
  // Step 2: Aggiorna ogni record
  let updated = 0;
  let errors = 0;
  
  records.forEach((record, index) => {
    db.run(`
      UPDATE attendance_records 
      SET forcedByAdminId = ?, isForced = 1
      WHERE id = ?
    `, [record.adminId, record.id], (err) => {
      if (err) {
        console.error(`❌ Errore aggiornamento record ${record.id}:`, err);
        errors++;
      } else {
        updated++;
        console.log(`✓ Record ${record.id} aggiornato: forcedByAdminId = ${record.adminId} (${record.adminName})`);
      }
      
      // Se è l'ultimo record, chiudi il database
      if (index === records.length - 1) {
        setTimeout(() => {
          console.log(`\n=== MIGRAZIONE COMPLETATA ===`);
          console.log(`✓ Record aggiornati: ${updated}`);
          console.log(`❌ Errori: ${errors}`);
          db.close();
        }, 100);
      }
    });
  });
});
