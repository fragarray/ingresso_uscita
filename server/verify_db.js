// Script per verificare la struttura del database
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'database.db'));

console.log('=== Verifica Database ===\n');

// Verifica struttura work_sites
db.all(`PRAGMA table_info(work_sites)`, [], (err, columns) => {
  if (err) {
    console.error('Errore:', err);
    return;
  }
  
  console.log('Struttura tabella work_sites:');
  console.log('------------------------------');
  columns.forEach(col => {
    console.log(`${col.cid}. ${col.name.padEnd(15)} | ${col.type.padEnd(10)} | NOT NULL: ${col.notnull} | DEFAULT: ${col.dflt_value || 'NULL'}`);
  });
  
  const hasRadiusMeters = columns.some(col => col.name === 'radiusMeters');
  console.log('\n✓ Column radiusMeters exists:', hasRadiusMeters);
  
  // Mostra alcuni cantieri esistenti
  console.log('\n=== Cantieri esistenti ===');
  db.all(`SELECT id, name, radiusMeters FROM work_sites LIMIT 5`, [], (err, rows) => {
    if (err) {
      console.error('Errore:', err);
      db.close();
      return;
    }
    
    if (rows.length === 0) {
      console.log('Nessun cantiere nel database');
    } else {
      rows.forEach(row => {
        console.log(`ID: ${row.id}, Nome: ${row.name}, Raggio: ${row.radiusMeters || 'NULL'}m`);
      });
    }
    
    db.close();
  });
});
