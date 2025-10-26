#!/usr/bin/env node

/**
 * Script di pulizia database
 * Corregge anomalie nei record di timbratura
 */

const db = require('./db');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('\n🔧 PULIZIA DATABASE TIMBRATURE\n');
console.log('=' .repeat(60));

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
  // 1. Trova record orfani
  console.log('\n🔍 Ricerca record orfani...\n');

  const orphans = await new Promise((resolve, reject) => {
    db.all(`
      WITH ordered_records AS (
        SELECT 
          id,
          employeeId,
          type,
          timestamp,
          LAG(type) OVER (PARTITION BY employeeId ORDER BY timestamp) as prev_type
        FROM attendance_records
        ORDER BY employeeId, timestamp
      )
      SELECT * FROM ordered_records
      WHERE 
        (type = 'in' AND prev_type = 'in') OR
        (type = 'out' AND prev_type = 'out') OR
        (type = 'out' AND prev_type IS NULL)
    `, [], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });

  if (orphans.length > 0) {
    console.log(`⚠️  Trovati ${orphans.length} record orfani:\n`);
    
    orphans.forEach((orphan, idx) => {
      const issue = orphan.type === 'out' && orphan.prev_type === null 
        ? 'OUT senza IN precedente'
        : `${orphan.type.toUpperCase()} doppio consecutivo`;
      
      console.log(`${idx + 1}. [ID: ${orphan.id}] Dipendente ${orphan.employeeId}`);
      console.log(`   Tipo: ${orphan.type.toUpperCase()}`);
      console.log(`   Timestamp: ${orphan.timestamp}`);
      console.log(`   Problema: ${issue}\n`);
    });

    const answer = await question('Vuoi eliminare questi record? (s/n): ');
    
    if (answer.toLowerCase() === 's') {
      const ids = orphans.map(o => o.id);
      
      await new Promise((resolve, reject) => {
        db.run(`DELETE FROM attendance_records WHERE id IN (${ids.join(',')})`, [], function(err) {
          if (err) reject(err);
          else {
            console.log(`\n✅ Eliminati ${this.changes} record orfani\n`);
            resolve();
          }
        });
      });
    } else {
      console.log('\n⏭️  Record orfani non eliminati\n');
    }
  } else {
    console.log('✅ Nessun record orfano trovato\n');
  }

  // 2. Trova coppie con ordine cronologico invertito
  console.log('\n⏰ Ricerca coppie con ordine invertito...\n');

  const chronoErrors = await new Promise((resolve, reject) => {
    db.all(`
      SELECT 
        ar1.id as in_id,
        ar1.employeeId,
        ar1.timestamp as in_timestamp,
        ar2.id as out_id,
        ar2.timestamp as out_timestamp
      FROM attendance_records ar1
      JOIN attendance_records ar2 
        ON ar1.employeeId = ar2.employeeId 
        AND ar1.type = 'in'
        AND ar2.type = 'out'
      WHERE ar2.timestamp < ar1.timestamp
      ORDER BY ar1.employeeId, ar1.timestamp
    `, [], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });

  if (chronoErrors.length > 0) {
    console.log(`⚠️  Trovate ${chronoErrors.length} coppie con ordine invertito:\n`);
    
    chronoErrors.forEach((error, idx) => {
      console.log(`${idx + 1}. Dipendente ${error.employeeId}:`);
      console.log(`   IN  [ID: ${error.in_id}]  → ${error.in_timestamp}`);
      console.log(`   OUT [ID: ${error.out_id}] → ${error.out_timestamp}`);
      console.log(`   ⚠️  Differenza: ${((new Date(error.in_timestamp) - new Date(error.out_timestamp)) / 1000 / 60).toFixed(0)} minuti\n`);
    });

    console.log('⚠️  ATTENZIONE: Questi record richiedono correzione MANUALE');
    console.log('   Non possono essere eliminati automaticamente perché potrebbero');
    console.log('   rappresentare turni notturni o errori di inserimento.\n');
    console.log('   Raccomandazioni:');
    console.log('   1. Verifica manualmente ogni coppia');
    console.log('   2. Usa la funzione "Modifica" dall\'app per correggere i timestamp');
    console.log('   3. Oppure elimina le coppie errate e reinserisci correttamente\n');
  } else {
    console.log('✅ Nessun errore di ordine cronologico\n');
  }

  // 3. Statistiche finali
  console.log('\n📊 Statistiche Database\n');

  const stats = await new Promise((resolve, reject) => {
    db.get(`
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN type = 'in' THEN 1 ELSE 0 END) as total_in,
        SUM(CASE WHEN type = 'out' THEN 1 ELSE 0 END) as total_out
      FROM attendance_records
    `, [], (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });

  console.log(`   📝 Record totali: ${stats.total}`);
  console.log(`   ➡️  IN: ${stats.total_in}`);
  console.log(`   ⬅️  OUT: ${stats.total_out}`);
  
  const balance = stats.total_in - stats.total_out;
  if (balance === 0) {
    console.log(`   ✅ Database bilanciato\n`);
  } else if (balance > 0) {
    console.log(`   ⚠️  ${balance} dipendenti attualmente IN\n`);
  } else {
    console.log(`   ❌ ${Math.abs(balance)} OUT in eccesso\n`);
  }

  console.log('=' .repeat(60));
  console.log('\n✅ Pulizia completata\n');
  
  rl.close();
  db.close();
}

main().catch(err => {
  console.error('❌ Errore:', err);
  rl.close();
  db.close();
  process.exit(1);
});
