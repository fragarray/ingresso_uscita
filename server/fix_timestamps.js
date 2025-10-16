/**
 * Script per correggere i timestamp errati nel database
 * 
 * PROBLEMA: Quando si forzava un'uscita dopo mezzanotte, il timestamp
 * usava la data dell'ingresso invece del giorno successivo.
 * 
 * SOLUZIONE: Questo script rileva coppie IN/OUT dove OUT < IN e 
 * corregge aggiungendo 1 giorno al timestamp OUT.
 * 
 * USO: node fix_timestamps.js
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'database.db');
const db = new sqlite3.Database(dbPath);

console.log('='.repeat(60));
console.log('SCRIPT DI CORREZIONE TIMESTAMP');
console.log('='.repeat(60));
console.log('');

// Funzione per ottenere tutte le timbrature ordinate
function getAllRecords() {
  return new Promise((resolve, reject) => {
    db.all(
      `SELECT 
        ar.id,
        ar.employeeId,
        ar.workSiteId,
        ar.timestamp,
        ar.type,
        ar.isForced,
        e.name as employeeName,
        ws.name as workSiteName
      FROM attendance_records ar
      LEFT JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      ORDER BY ar.employeeId, ar.timestamp ASC`,
      (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      }
    );
  });
}

// Funzione per aggiornare un timestamp
function updateTimestamp(id, newTimestamp) {
  return new Promise((resolve, reject) => {
    db.run(
      'UPDATE attendance_records SET timestamp = ? WHERE id = ?',
      [newTimestamp, id],
      (err) => {
        if (err) reject(err);
        else resolve();
      }
    );
  });
}

// Funzione principale
async function fixTimestamps() {
  try {
    const records = await getAllRecords();
    console.log(`Trovate ${records.length} timbrature totali\n`);

    // DEBUG: Mostra tutte le timbrature per verifica
    console.log('DEBUG - Prime 10 timbrature:');
    console.log('-'.repeat(100));
    records.slice(0, 10).forEach(r => {
      console.log(`ID: ${r.id} | ${r.employeeName} | ${r.type.toUpperCase().padEnd(4)} | ${new Date(r.timestamp).toLocaleString('it-IT')} | ${r.workSiteName}`);
    });
    console.log('-'.repeat(100));
    console.log('');

    const corrections = [];
    let lastIn = null;

    // Analizza le timbrature per trovare coppie IN/OUT problematiche
    for (const record of records) {
      if (record.type === 'in') {
        lastIn = record;
      } else if (record.type === 'out' && lastIn) {
        const timeIn = new Date(lastIn.timestamp);
        const timeOut = new Date(record.timestamp);

        // DEBUG: Mostra ogni coppia analizzata
        console.log(`\nAnalisi coppia:`);
        console.log(`  IN:  ${timeIn.toLocaleString('it-IT')} (${lastIn.timestamp})`);
        console.log(`  OUT: ${timeOut.toLocaleString('it-IT')} (${record.timestamp})`);
        console.log(`  Stesso dipendente: ${record.employeeId === lastIn.employeeId}`);
        console.log(`  OUT <= IN: ${timeOut <= timeIn}`);

        // Se OUT è prima o uguale a IN dello stesso dipendente
        if (timeOut <= timeIn && record.employeeId === lastIn.employeeId) {
          // Calcola la differenza in ore
          const hoursDiff = (timeOut.getTime() - timeIn.getTime()) / (1000 * 60 * 60);
          
          console.log(`  ⚠️ ERRORE RILEVATO! Differenza ore: ${hoursDiff.toFixed(2)}h`);

          // Se la differenza è negativa ma piccola (< -12h), è probabile un errore di giorno
          // Oppure se è esattamente 8h negative (caso tipico)
          if (hoursDiff < 0 && hoursDiff > -18) {
            // Aggiungi 1 giorno all'OUT
            const correctedOut = new Date(timeOut);
            correctedOut.setDate(correctedOut.getDate() + 1);

            const newHoursDiff = (correctedOut.getTime() - timeIn.getTime()) / (1000 * 60 * 60);

            corrections.push({
              id: record.id,
              employeeName: record.employeeName,
              workSiteName: record.workSiteName,
              inTimestamp: lastIn.timestamp,
              oldOutTimestamp: record.timestamp,
              newOutTimestamp: correctedOut.toISOString(),
              oldHours: hoursDiff.toFixed(2),
              newHours: newHoursDiff.toFixed(2)
            });
            
            console.log(`  ✅ Correzione proposta: +1 giorno → ${newHoursDiff.toFixed(2)}h`);
          } else {
            console.log(`  ⚠️ Differenza troppo grande (${hoursDiff.toFixed(2)}h), ignorata`);
          }
        }

        lastIn = null;
      }
    }

    if (corrections.length === 0) {
      console.log('✅ Nessuna correzione necessaria. Tutti i timestamp sono corretti.');
      db.close();
      return;
    }

    console.log(`\n⚠️  Trovate ${corrections.length} timbrature da correggere:\n`);
    console.log('-'.repeat(100));

    corrections.forEach((corr, index) => {
      console.log(`${index + 1}. ${corr.employeeName} - ${corr.workSiteName}`);
      console.log(`   IN:  ${new Date(corr.inTimestamp).toLocaleString('it-IT')}`);
      console.log(`   OUT: ${new Date(corr.oldOutTimestamp).toLocaleString('it-IT')} → ${new Date(corr.newOutTimestamp).toLocaleString('it-IT')}`);
      console.log(`   ORE: ${corr.oldHours}h → ${corr.newHours}h`);
      console.log('');
    });

    console.log('-'.repeat(100));
    console.log('\n');

    // Chiedi conferma (in produzione, rimuovere questo e applicare direttamente)
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    readline.question('Vuoi applicare queste correzioni? (s/n): ', async (answer) => {
      readline.close();

      if (answer.toLowerCase() === 's' || answer.toLowerCase() === 'si' || answer.toLowerCase() === 'sì') {
        console.log('\n🔧 Applicazione correzioni...\n');

        for (const corr of corrections) {
          await updateTimestamp(corr.id, corr.newOutTimestamp);
          console.log(`✅ Corretto record ID ${corr.id}`);
        }

        console.log('\n✅ Tutte le correzioni sono state applicate con successo!');
        console.log('⚠️  Ricorda di rigenerare i report per vedere i calcoli corretti.\n');
      } else {
        console.log('\n❌ Correzioni annullate. Nessuna modifica al database.\n');
      }

      db.close();
    });

  } catch (error) {
    console.error('❌ Errore durante l\'esecuzione:', error);
    db.close();
  }
}

// Avvia lo script
fixTimestamps();
