#!/usr/bin/env node

/**
 * Script di verifica integrità database
 * Controlla la correttezza dei record di timbratura dopo operazioni di modifica/eliminazione
 */

const db = require('./db');

console.log('\n🔍 VERIFICA INTEGRITÀ DATABASE\n');
console.log('=' .repeat(60));

// 1. Verifica coppie IN/OUT
console.log('\n📊 Analisi coppie IN/OUT...\n');

db.all(`
  SELECT 
    employeeId,
    COUNT(*) as total_records,
    SUM(CASE WHEN type = 'in' THEN 1 ELSE 0 END) as total_in,
    SUM(CASE WHEN type = 'out' THEN 1 ELSE 0 END) as total_out
  FROM attendance_records
  GROUP BY employeeId
  ORDER BY employeeId
`, [], (err, rows) => {
  if (err) {
    console.error('❌ Errore query:', err.message);
    return;
  }

  console.log('┌─────────────┬───────────┬─────────┬──────────┬──────────┐');
  console.log('│ Dipendente  │ Tot. Rec. │ Tot. IN │ Tot. OUT │  Status  │');
  console.log('├─────────────┼───────────┼─────────┼──────────┼──────────┤');

  let totalWarnings = 0;
  let totalErrors = 0;

  rows.forEach(row => {
    const diff = row.total_in - row.total_out;
    let status = '✅ OK    ';
    
    if (diff > 1) {
      status = '❌ ERROR ';
      totalErrors++;
    } else if (diff === 1) {
      status = '⚠️  IN uso';
      totalWarnings++;
    } else if (diff < 0) {
      status = '❌ ERROR ';
      totalErrors++;
    }

    console.log(`│ ${String(row.employeeId).padEnd(11)} │ ${String(row.total_records).padEnd(9)} │ ${String(row.total_in).padEnd(7)} │ ${String(row.total_out).padEnd(8)} │ ${status} │`);
  });

  console.log('└─────────────┴───────────┴─────────┴──────────┴──────────┘');

  console.log(`\n📈 Riepilogo:`);
  console.log(`   ✅ Record validi: ${rows.length - totalWarnings - totalErrors}`);
  console.log(`   ⚠️  Dipendenti attualmente IN: ${totalWarnings}`);
  console.log(`   ❌ Anomalie rilevate: ${totalErrors}`);

  if (totalErrors > 0) {
    console.log('\n⚠️  ATTENZIONE: Rilevate anomalie nel database!');
    console.log('   Possibili cause:');
    console.log('   - Più IN consecutivi senza OUT');
    console.log('   - Più OUT consecutivi senza IN');
    console.log('   - OUT eliminato manualmente senza IN');
  }

  // 2. Verifica ordine cronologico
  console.log('\n\n⏰ Verifica ordine cronologico...\n');

  db.all(`
    SELECT 
      ar1.id as id1,
      ar1.employeeId,
      ar1.type as type1,
      ar1.timestamp as ts1,
      ar2.id as id2,
      ar2.type as type2,
      ar2.timestamp as ts2
    FROM attendance_records ar1
    JOIN attendance_records ar2 
      ON ar1.employeeId = ar2.employeeId 
      AND ar1.id < ar2.id
      AND ar1.type = 'in'
      AND ar2.type = 'out'
    WHERE ar2.timestamp <= ar1.timestamp
    ORDER BY ar1.employeeId, ar1.timestamp
  `, [], (err, chronoErrors) => {
    if (err) {
      console.error('❌ Errore query:', err.message);
      return;
    }

    if (chronoErrors.length === 0) {
      console.log('✅ Nessun errore di ordine cronologico rilevato');
    } else {
      console.log(`❌ Rilevati ${chronoErrors.length} errori di ordine cronologico:\n`);
      
      chronoErrors.forEach((error, idx) => {
        console.log(`${idx + 1}. Dipendente ${error.employeeId}:`);
        console.log(`   IN  [ID: ${error.id1}] → ${error.ts1}`);
        console.log(`   OUT [ID: ${error.id2}] → ${error.ts2}`);
        console.log(`   ⚠️  OUT è PRIMA di IN!\n`);
      });
    }

    // 3. Verifica record orfani
    console.log('\n🔍 Ricerca record orfani...\n');

    db.all(`
      WITH ordered_records AS (
        SELECT 
          id,
          employeeId,
          type,
          timestamp,
          LAG(type) OVER (PARTITION BY employeeId ORDER BY timestamp) as prev_type,
          LEAD(type) OVER (PARTITION BY employeeId ORDER BY timestamp) as next_type
        FROM attendance_records
        ORDER BY employeeId, timestamp
      )
      SELECT * FROM ordered_records
      WHERE 
        (type = 'in' AND prev_type = 'in') OR
        (type = 'out' AND prev_type = 'out') OR
        (type = 'out' AND prev_type IS NULL)
    `, [], (err, orphans) => {
      if (err) {
        console.error('❌ Errore query:', err.message);
        return;
      }

      if (orphans.length === 0) {
        console.log('✅ Nessun record orfano rilevato');
      } else {
        console.log(`⚠️  Rilevati ${orphans.length} record potenzialmente problematici:\n`);
        
        orphans.forEach((orphan, idx) => {
          const issue = orphan.type === 'out' && orphan.prev_type === null 
            ? 'OUT senza IN precedente'
            : `${orphan.type.toUpperCase()} consecutivo (doppio)`;
          
          console.log(`${idx + 1}. [ID: ${orphan.id}] Dipendente ${orphan.employeeId}`);
          console.log(`   Tipo: ${orphan.type.toUpperCase()}`);
          console.log(`   Timestamp: ${orphan.timestamp}`);
          console.log(`   Problema: ${issue}\n`);
        });
      }

      // 4. Statistiche generali
      console.log('\n📊 Statistiche Generali\n');

      db.get(`
        SELECT 
          COUNT(*) as total_records,
          COUNT(DISTINCT employeeId) as total_employees,
          SUM(CASE WHEN type = 'in' THEN 1 ELSE 0 END) as total_in,
          SUM(CASE WHEN type = 'out' THEN 1 ELSE 0 END) as total_out,
          SUM(CASE WHEN isForced = 1 THEN 1 ELSE 0 END) as total_forced
        FROM attendance_records
      `, [], (err, stats) => {
        if (err) {
          console.error('❌ Errore query:', err.message);
          return;
        }

        console.log(`   📝 Record totali: ${stats.total_records}`);
        console.log(`   👥 Dipendenti coinvolti: ${stats.total_employees}`);
        console.log(`   ➡️  Timbrature IN: ${stats.total_in}`);
        console.log(`   ⬅️  Timbrature OUT: ${stats.total_out}`);
        console.log(`   🔨 Timbrature forzate: ${stats.total_forced}`);
        console.log(`   📊 Rapporto IN/OUT: ${(stats.total_in / stats.total_out).toFixed(2)}`);

        const balance = stats.total_in - stats.total_out;
        if (balance === 0) {
          console.log('\n   ✅ Database bilanciato: IN = OUT');
        } else if (balance > 0) {
          console.log(`\n   ⚠️  ${balance} dipendenti attualmente IN servizio`);
        } else {
          console.log(`\n   ❌ ERRORE: Più OUT che IN (${Math.abs(balance)} record)`);
        }

        // 5. Conclusione
        console.log('\n' + '='.repeat(60));
        
        if (totalErrors === 0 && chronoErrors.length === 0) {
          console.log('\n✅ VERIFICA COMPLETATA: Database integro e corretto\n');
          console.log('   I calcoli delle ore lavorate risulteranno corretti.\n');
        } else {
          console.log('\n⚠️  VERIFICA COMPLETATA: Rilevate anomalie\n');
          console.log('   Raccomandazioni:');
          console.log('   1. Verificare manualmente i record segnalati');
          console.log('   2. Correggere le anomalie prima di generare report');
          console.log('   3. Considerare backup del database\n');
        }

        // Chiudi connessione
        db.close((err) => {
          if (err) {
            console.error('Errore chiusura DB:', err.message);
          }
          process.exit(totalErrors === 0 && chronoErrors.length === 0 ? 0 : 1);
        });
      });
    });
  });
});
