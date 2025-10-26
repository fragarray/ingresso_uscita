/**
 * ========================================================
 * SCRIPT MIGRAZIONE: Autenticazione Username + Ruolo Capocantiere
 * ========================================================
 * 
 * Questo script migra il database da autenticazione email-based
 * a username-based e aggiunge il ruolo "capocantiere".
 * 
 * MODIFICHE:
 * 1. Aggiunge colonna 'username' UNIQUE a tabella employees
 * 2. Genera username da email esistenti (parte prima della @)
 * 3. Gestisce duplicati aggiungendo suffissi numerici
 * 4. Aggiunge colonna 'role' (admin/employee/foreman)
 * 5. Imposta ruolo 'admin' per account con isAdmin=1
 * 6. Rende email opzionale (rimuove vincolo UNIQUE)
 * 7. Valida integrità finale
 * 
 * SICUREZZA:
 * - Crea backup automatico prima di iniziare
 * - Usa transazioni per atomicità
 * - Verifica integrità prima del commit
 * 
 * USO:
 *   node migrate_username_auth.js
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const DB_PATH = path.join(__dirname, 'database.db');
const BACKUP_PATH = path.join(__dirname, `database_backup_${Date.now()}.db`);

console.log('========================================================');
console.log('📋 MIGRAZIONE USERNAME AUTH + RUOLO CAPOCANTIERE');
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

// Funzione per generare username univoco da email
function generateUsernameFromEmail(email, existingUsernames) {
  // Estrai parte prima della @ e sanitizza
  let baseUsername = email.split('@')[0]
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '_'); // Sostituisci caratteri non validi con _

  let username = baseUsername;
  let counter = 1;

  // Gestisci duplicati aggiungendo suffissi
  while (existingUsernames.has(username)) {
    username = `${baseUsername}_${counter}`;
    counter++;
  }

  existingUsernames.add(username);
  return username;
}

// Step 4: Inizia migrazione
db.serialize(() => {
  console.log('🔄 Inizio migrazione...\n');

  db.run('BEGIN TRANSACTION', (err) => {
    if (err) {
      console.error('❌ Errore inizio transazione:', err.message);
      db.close();
      process.exit(1);
    }

    // Step 4a: Aggiungi colonna username se non esiste
    db.run(`ALTER TABLE employees ADD COLUMN username TEXT`, (err) => {
      if (err && !err.message.includes('duplicate column')) {
        console.error('❌ Errore aggiunta colonna username:', err.message);
        db.run('ROLLBACK');
        db.close();
        process.exit(1);
      }
      console.log('✓ Colonna username aggiunta (o già esistente)');

      // Step 4b: Aggiungi colonna role se non esiste
      db.run(`ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee'`, (err) => {
        if (err && !err.message.includes('duplicate column')) {
          console.error('❌ Errore aggiunta colonna role:', err.message);
          db.run('ROLLBACK');
          db.close();
          process.exit(1);
        }
        console.log('✓ Colonna role aggiunta (o già esistente)');

        // Step 4c: Leggi tutti gli employees esistenti
        db.all('SELECT id, email, isAdmin FROM employees', [], (err, employees) => {
          if (err) {
            console.error('❌ Errore lettura employees:', err.message);
            db.run('ROLLBACK');
            db.close();
            process.exit(1);
          }

          console.log(`\n📊 Trovati ${employees.length} dipendenti da migrare\n`);

          const existingUsernames = new Set();
          const updates = [];

          // Step 4d: Genera username per ogni employee
          employees.forEach((emp) => {
            const username = generateUsernameFromEmail(emp.email, existingUsernames);
            const role = emp.isAdmin === 1 ? 'admin' : 'employee';
            
            updates.push({ id: emp.id, username, role, email: emp.email });
            console.log(`  👤 ID ${emp.id}: ${emp.email} → username: '${username}' | role: '${role}'`);
          });

          // Step 4e: Esegui aggiornamenti
          console.log('\n🔄 Aggiornamento records...\n');

          let completedUpdates = 0;
          const totalUpdates = updates.length;

          updates.forEach((update) => {
            db.run(
              'UPDATE employees SET username = ?, role = ? WHERE id = ?',
              [update.username, update.role, update.id],
              function (err) {
                if (err) {
                  console.error(`❌ Errore aggiornamento ID ${update.id}:`, err.message);
                  db.run('ROLLBACK');
                  db.close();
                  process.exit(1);
                }

                completedUpdates++;

                if (completedUpdates === totalUpdates) {
                  // Tutti gli aggiornamenti completati
                  console.log(`✅ Aggiornati ${completedUpdates}/${totalUpdates} dipendenti\n`);

                  // Step 5: Crea indice UNIQUE su username
                  console.log('🔐 Creazione indice UNIQUE su username...');
                  db.run('CREATE UNIQUE INDEX IF NOT EXISTS idx_employees_username ON employees(username)', (err) => {
                    if (err) {
                      console.error('❌ Errore creazione indice username:', err.message);
                      db.run('ROLLBACK');
                      db.close();
                      process.exit(1);
                    }
                    console.log('✓ Indice UNIQUE su username creato\n');

                    // Step 6: Rimuovi vincolo UNIQUE da email
                    // NOTA: SQLite non supporta ALTER COLUMN direttamente
                    // Creiamo una nuova tabella senza UNIQUE su email e copiamo i dati
                    console.log('🔄 Ricostruzione tabella employees (rimuovi UNIQUE da email)...');

                    // Crea tabella temporanea con la nuova struttura
                    db.run(`
                      CREATE TABLE employees_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name TEXT NOT NULL,
                        email TEXT,
                        password TEXT NOT NULL,
                        isAdmin INTEGER DEFAULT 0,
                        isActive INTEGER DEFAULT 1,
                        deletedAt DATETIME,
                        allowNightShift INTEGER DEFAULT 0,
                        username TEXT NOT NULL UNIQUE,
                        role TEXT DEFAULT 'employee'
                      )
                    `, (err) => {
                      if (err) {
                        console.error('❌ Errore creazione tabella temporanea:', err.message);
                        db.run('ROLLBACK');
                        db.close();
                        process.exit(1);
                      }

                      // Copia dati nella nuova tabella
                      db.run(`
                        INSERT INTO employees_new (id, name, email, password, isAdmin, isActive, deletedAt, allowNightShift, username, role)
                        SELECT id, name, email, password, isAdmin, 
                               COALESCE(isActive, 1), deletedAt, COALESCE(allowNightShift, 0), username, role
                        FROM employees
                      `, (err) => {
                        if (err) {
                          console.error('❌ Errore copia dati:', err.message);
                          db.run('ROLLBACK');
                          db.close();
                          process.exit(1);
                        }

                        // Elimina vecchia tabella
                        db.run('DROP TABLE employees', (err) => {
                          if (err) {
                            console.error('❌ Errore eliminazione tabella vecchia:', err.message);
                            db.run('ROLLBACK');
                            db.close();
                            process.exit(1);
                          }

                          // Rinomina nuova tabella
                          db.run('ALTER TABLE employees_new RENAME TO employees', (err) => {
                            if (err) {
                              console.error('❌ Errore rinomina tabella:', err.message);
                              db.run('ROLLBACK');
                              db.close();
                              process.exit(1);
                            }

                            console.log('✓ Tabella ricostruita (email ora opzionale)\n');

                            // Step 7: Verifica integrità finale
                            console.log('✅ Verifica integrità finale...');
                            db.all('SELECT id, name, username, email, role FROM employees', [], (err, rows) => {
                              if (err) {
                                console.error('❌ Errore verifica integrità:', err.message);
                                db.run('ROLLBACK');
                                db.close();
                                process.exit(1);
                              }

                              // Verifica che tutti abbiano username
                              const missingUsername = rows.filter(r => !r.username);
                              if (missingUsername.length > 0) {
                                console.error('❌ Errore: alcuni dipendenti senza username:', missingUsername);
                                db.run('ROLLBACK');
                                db.close();
                                process.exit(1);
                              }

                              console.log(`✓ Verifica OK: ${rows.length} dipendenti con username valido\n`);

                              // Step 8: Commit transazione
                              db.run('COMMIT', (err) => {
                                if (err) {
                                  console.error('❌ Errore commit transazione:', err.message);
                                  db.run('ROLLBACK');
                                  db.close();
                                  process.exit(1);
                                }

                                console.log('========================================================');
                                console.log('✅ MIGRAZIONE COMPLETATA CON SUCCESSO');
                                console.log('========================================================\n');
                                console.log('📋 Riepilogo:');
                                console.log(`  - ${rows.length} dipendenti migrati`);
                                console.log(`  - ${rows.filter(r => r.role === 'admin').length} amministratori`);
                                console.log(`  - ${rows.filter(r => r.role === 'employee').length} dipendenti`);
                                console.log(`  - Backup salvato: ${BACKUP_PATH}`);
                                console.log('\n🎯 Prossimi passi:');
                                console.log('  1. Testa il login con username invece di email');
                                console.log('  2. Verifica che tutti i dipendenti possano accedere');
                                console.log('  3. Se tutto OK, puoi eliminare il backup\n');

                                db.close();
                                process.exit(0);
                              });
                            });
                          });
                        });
                      });
                    });
                  });
                }
              }
            );
          });
        });
      });
    });
  });
});
