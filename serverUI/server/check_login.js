const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'database.db');
console.log('📁 Database path:', dbPath);
console.log('\n=== VERIFICA LOGIN ===\n');

const db = new sqlite3.Database(dbPath);

// Prova le credenziali che stai usando
const testCredentials = [
  { username: 'admin_1', password: 'admin123' },
  { username: 'admin', password: '123456' },
  { username: 'pippo', password: '123456' },
];

testCredentials.forEach(cred => {
  console.log(`\n🔐 Test login: username="${cred.username}" password="${cred.password}"`);
  
  // Query 1: cerca per username
  db.get(
    'SELECT * FROM employees WHERE username = ? AND password = ?',
    [cred.username, cred.password],
    (err, row) => {
      if (err) {
        console.error('  ❌ Errore query username:', err.message);
      } else if (row) {
        console.log(`  ✅ TROVATO con username! ID: ${row.id}, Nome: ${row.name}, Role: ${row.role}`);
      } else {
        console.log('  ❌ NON trovato con username');
        
        // Query 2: prova con email (fallback)
        db.get(
          'SELECT * FROM employees WHERE email = ? AND password = ?',
          [cred.username, cred.password],
          (err2, row2) => {
            if (err2) {
              console.error('  ❌ Errore query email:', err2.message);
            } else if (row2) {
              console.log(`  ✅ TROVATO con email! ID: ${row2.id}, Nome: ${row2.name}, Role: ${row2.role}`);
            } else {
              console.log('  ❌ NON trovato nemmeno con email');
              
              // Verifica se l'utente esiste con qualsiasi password
              db.get(
                'SELECT * FROM employees WHERE username = ? OR email = ?',
                [cred.username, cred.username],
                (err3, row3) => {
                  if (row3) {
                    console.log(`  ℹ️  Username/email esiste ma password diversa!`);
                    console.log(`     Password nel DB: "${row3.password}"`);
                    console.log(`     Password provata: "${cred.password}"`);
                  } else {
                    console.log('  ℹ️  Username/email non esiste nel database');
                  }
                }
              );
            }
          }
        );
      }
    }
  );
});

// Mostra tutti gli utenti dopo un breve delay
setTimeout(() => {
  console.log('\n\n📊 TUTTI GLI UTENTI NEL DATABASE:\n');
  db.all('SELECT id, name, username, email, password, role, isActive FROM employees', (err, rows) => {
    if (err) {
      console.error('❌ Errore:', err);
    } else {
      rows.forEach(r => {
        console.log(`👤 ID: ${r.id}`);
        console.log(`   Nome: ${r.name}`);
        console.log(`   Username: ${r.username}`);
        console.log(`   Email: ${r.email}`);
        console.log(`   Password: "${r.password}"`);
        console.log(`   Role: ${r.role}`);
        console.log(`   Active: ${r.isActive}\n`);
      });
    }
    db.close();
  });
}, 2000);
