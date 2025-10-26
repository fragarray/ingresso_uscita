/**
 * ========================================================
 * SCRIPT RIPARAZIONE: Pulizia Password con Spazi
 * ========================================================
 * 
 * Questo script rimuove spazi iniziali e finali dalle password
 * degli utenti esistenti nel database.
 * 
 * PROBLEMA RISOLTO:
 * - Password salvate con spazi (es. "password123 ")
 * - Login fallito perché utente inserisce senza spazi
 * - Le password vengono trimmate e aggiornate
 * 
 * SICUREZZA:
 * - Crea backup automatico prima di iniziare
 * - Mostra preview delle modifiche prima di applicarle
 * - Logga tutti i cambiamenti
 * 
 * USO:
 *   node fix_passwords_trim.js
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');
const readline = require('readline');

const DB_PATH = path.join(__dirname, 'database.db');
const BACKUP_PATH = path.join(__dirname, `database_backup_password_trim_${Date.now()}.db`);

console.log('========================================================');
console.log('🔧 RIPARAZIONE PASSWORD - Rimuovi spazi bianchi');
console.log('========================================================\n');

// Step 1: Verifica esistenza database
if (!fs.existsSync(DB_PATH)) {
  console.error('❌ Database non trovato:', DB_PATH);
  process.exit(1);
}

// Step 2: Crea backup
console.log('📦 Creazione backup database...');
try {
  fs.copyFileSync(DB_PATH, BACKUP_PATH);
  console.log('✅ Backup creato:', BACKUP_PATH);
} catch (err) {
  console.error('❌ Errore creazione backup:', err.message);
  process.exit(1);
}

// Step 3: Apri database
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('❌ Errore apertura database:', err.message);
    process.exit(1);
  }
  console.log('✅ Database aperto\n');
});

// Step 4: Analizza password
db.all('SELECT id, name, username, password FROM employees', [], (err, employees) => {
  if (err) {
    console.error('❌ Errore lettura employees:', err.message);
    db.close();
    process.exit(1);
  }

  console.log(`📊 Trovati ${employees.length} dipendenti\n`);

  // Trova password che necessitano trim
  const needsTrim = employees.filter(emp => {
    const trimmed = emp.password?.trim();
    return trimmed !== emp.password;
  });

  if (needsTrim.length === 0) {
    console.log('✅ Nessuna password da correggere. Tutto OK!');
    db.close();
    process.exit(0);
  }

  console.log(`⚠️  Trovate ${needsTrim.length} password con spazi da rimuovere:\n`);

  needsTrim.forEach(emp => {
    const original = emp.password;
    const trimmed = emp.password?.trim();
    const prefix = original.startsWith(' ') || original.startsWith('\t') ? '(spazi iniziali) ' : '';
    const suffix = original.endsWith(' ') || original.endsWith('\t') ? ' (spazi finali)' : '';
    
    console.log(`  👤 ID ${emp.id}: ${emp.name} (${emp.username})`);
    console.log(`     ❌ Password attuale: "${original}" ${prefix}${suffix}`);
    console.log(`     ✅ Password corretta: "${trimmed}"`);
    console.log('');
  });

  // Step 5: Chiedi conferma
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  rl.question('\n🔍 Vuoi procedere con la correzione? (s/n): ', (answer) => {
    rl.close();

    if (answer.toLowerCase() !== 's') {
      console.log('\n❌ Operazione annullata.');
      db.close();
      process.exit(0);
    }

    console.log('\n🔄 Inizio correzione...\n');

    // Step 6: Aggiorna password
    let completed = 0;
    const total = needsTrim.length;

    needsTrim.forEach(emp => {
      const trimmedPassword = emp.password.trim();
      
      db.run(
        'UPDATE employees SET password = ? WHERE id = ?',
        [trimmedPassword, emp.id],
        function(err) {
          if (err) {
            console.error(`❌ Errore aggiornamento ID ${emp.id}:`, err.message);
            db.close();
            process.exit(1);
          }

          console.log(`✅ Aggiornato ID ${emp.id}: ${emp.name} - Password corretta`);
          completed++;

          if (completed === total) {
            // Tutti gli aggiornamenti completati
            console.log('\n========================================================');
            console.log('✅ RIPARAZIONE COMPLETATA CON SUCCESSO');
            console.log('========================================================\n');
            console.log('📋 Riepilogo:');
            console.log(`  - ${total} password corrette`);
            console.log(`  - Backup salvato: ${BACKUP_PATH}`);
            console.log('\n🎯 Prossimi passi:');
            console.log('  1. Testa il login con le password originali (senza spazi)');
            console.log('  2. Se tutto OK, puoi eliminare il backup');
            console.log('  3. Gli utenti possono ora accedere correttamente\n');
            
            db.close();
            process.exit(0);
          }
        }
      );
    });
  });
});
