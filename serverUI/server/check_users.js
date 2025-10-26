const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'database.db');
console.log('📁 Database path:', dbPath);

const db = new sqlite3.Database(dbPath);

console.log('\n=== VERIFICA UTENTI NEL DATABASE ===\n');

db.all('SELECT id, name, username, email, password, role, isAdmin, isActive FROM employees ORDER BY id', [], (err, rows) => {
  if (err) {
    console.error('❌ Errore:', err);
    return;
  }
  
  console.log(`📊 Trovati ${rows.length} utenti:\n`);
  
  rows.forEach(row => {
    console.log(`👤 ID: ${row.id}`);
    console.log(`   Nome: ${row.name}`);
    console.log(`   Username: ${row.username || '❌ NON IMPOSTATO'}`);
    console.log(`   Email: ${row.email || 'Nessuna'}`);
    console.log(`   Role: ${row.role || 'employee'}`);
    console.log(`   isAdmin: ${row.isAdmin}`);
    console.log(`   isActive: ${row.isActive}`);
    console.log(`   Password: "${row.password}"`);
    console.log('');
  });
  
  db.close();
});
