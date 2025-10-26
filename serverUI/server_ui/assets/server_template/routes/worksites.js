const express = require('express');
const db = require('../db');
const ExcelJS = require('exceljs');
const path = require('path');
const fs = require('fs');
const router = express.Router();

// Get all work sites
router.get('/', (req, res) => {
  console.log(`📋 [CANTIERI] Richiesta lista cantieri`);
  
  db.all(`SELECT 
    id,
    name,
    CAST(latitude AS REAL) as latitude,
    CAST(longitude AS REAL) as longitude,
    address,
    isActive,
    CAST(radiusMeters AS REAL) as radiusMeters,
    description,
    createdAt
    FROM work_sites 
    ORDER BY createdAt DESC`, [], (err, rows) => {
    if (err) {
      console.error(`❌ [CANTIERI] Errore recupero lista:`, err.message);
      res.status(500).json({ error: 'Internal server error' });
      return;
    }
    console.log(`✅ [CANTIERI] Restituiti ${rows.length} cantieri`);
    res.json(rows);
  });
});

// Add new work site
router.post('/', (req, res) => {
  const { name, latitude, longitude, address, isActive, radiusMeters, description } = req.body;

  console.log(`➕ [CANTIERE] Creazione nuovo cantiere`);
  console.log(`   🏗️  Nome: ${name}`);
  console.log(`   📍 Coordinate: ${latitude}, ${longitude}`);
  console.log(`   🗺️  Indirizzo: ${address}`);
  console.log(`   📏 Raggio: ${radiusMeters || 100}m`);
  console.log(`   ✅ Attivo: ${isActive !== false ? 'Sì' : 'No'}`);
  console.log(`   📝 Descrizione: ${description || 'Nessuna'}`);

  if (!name || !latitude || !longitude || !address) {
    console.error(`❌ [CANTIERE] Parametri mancanti per la creazione`);
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }

  // Imposta isActive a 1 se non fornito
  const activeValue = typeof isActive === 'boolean' ? (isActive ? 1 : 0) : 1;
  const radius = radiusMeters || 100.0;

  db.run(
    'INSERT INTO work_sites (name, latitude, longitude, address, isActive, radiusMeters, description) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [name, latitude, longitude, address, activeValue, radius, description || null],
    function(err) {
      if (err) {
        console.error(`❌ [CANTIERE] Errore creazione:`, err.message);
        res.status(500).json({ error: 'Internal server error' });
        return;
      }
      
      console.log(`✅ [CANTIERE] Creato con successo - ID: ${this.lastID}`);
      
      // Restituisco il cantiere appena creato
      db.get('SELECT * FROM work_sites WHERE id = ?', [this.lastID], (err, row) => {
        if (err) {
          console.error(`❌ [CANTIERE] Errore recupero dati appena creati:`, err.message);
          res.status(500).json({ error: 'Internal server error' });
          return;
        }
        res.json(row);
      });
    }
  );
});

// Update work site
router.put('/:id', (req, res) => {
  const { name, latitude, longitude, address, isActive, radiusMeters, description } = req.body;
  const id = req.params.id;

  console.log(`✏️  [CANTIERE] Aggiornamento cantiere ID: ${id}`);
  console.log(`   🏗️  Nome: ${name}`);
  console.log(`   📍 Coordinate: ${latitude}, ${longitude}`);
  console.log(`   🗺️  Indirizzo: ${address}`);
  console.log(`   📏 Raggio: ${radiusMeters}m`);
  console.log(`   ✅ Attivo: ${isActive ? 'Sì' : 'No'}`);
  console.log(`   📝 Descrizione: ${description || 'Nessuna'}`);

  if (!name || !latitude || !longitude || !address || (isActive === undefined && isActive === null)) {
    console.error(`❌ [CANTIERE] Parametri mancanti per l'aggiornamento`);
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }

  const activeValue = typeof isActive === 'boolean' ? (isActive ? 1 : 0) : (isActive ? 1 : 0);
  const radius = radiusMeters !== undefined ? radiusMeters : 100.0;

  db.run(
    'UPDATE work_sites SET name = ?, latitude = ?, longitude = ?, address = ?, isActive = ?, radiusMeters = ?, description = ? WHERE id = ?',
    [name, latitude, longitude, address, activeValue, radius, description || null, id],
    function(err) {
      if (err) {
        console.error(`❌ [CANTIERE] Errore aggiornamento:`, err.message);
        res.status(500).json({ error: 'Internal server error' });
        return;
      }
      console.log(`✅ [CANTIERE] Aggiornato con successo - Righe modificate: ${this.changes}`);
      res.json({ success: true, changes: this.changes });
    }
  );
});

// Delete work site with automatic backup
router.delete('/:id', async (req, res) => {
  const id = req.params.id;

  try {
    // Prima genera il backup Excel dello storico del cantiere
    const workSite = await new Promise((resolve, reject) => {
      db.get('SELECT * FROM work_sites WHERE id = ?', [id], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });

    if (!workSite) {
      res.status(404).json({ error: 'Work site not found' });
      return;
    }

    // Genera report Excel di backup
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet(`Storico ${workSite.name}`);

    // Stile header
    const headerStyle = {
      font: { bold: true, color: { argb: 'FFFFFFFF' } },
      fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE74C3C' } },
      alignment: { vertical: 'middle', horizontal: 'center' },
      border: {
        top: { style: 'thin' },
        left: { style: 'thin' },
        bottom: { style: 'thin' },
        right: { style: 'thin' }
      }
    };

    worksheet.columns = [
      { header: 'Dipendente', key: 'employeeName', width: 25 },
      { header: 'Tipo', key: 'type', width: 12 },
      { header: 'Data e Ora', key: 'timestamp', width: 20 },
      { header: 'Dispositivo', key: 'deviceInfo', width: 35 },
      { header: 'Latitudine', key: 'latitude', width: 15 },
      { header: 'Longitudine', key: 'longitude', width: 15 },
      { header: 'Google Maps', key: 'googleMaps', width: 20 },
      { header: 'ID Timbratura', key: 'id', width: 15 }
    ];

    worksheet.getRow(1).eachCell((cell) => {
      cell.style = headerStyle;
    });

    // Recupera tutti i record del cantiere
    const records = await new Promise((resolve, reject) => {
      db.all(
        `SELECT 
          ar.id,
          ar.timestamp,
          ar.type,
          ar.deviceInfo,
          ar.latitude,
          ar.longitude,
          e.name as employeeName
         FROM attendance_records ar
         JOIN employees e ON ar.employeeId = e.id
         WHERE ar.workSiteId = ?
         ORDER BY ar.timestamp DESC`,
        [id],
        (err, rows) => {
          if (err) reject(err);
          else resolve(rows);
        }
      );
    });

    // Aggiungi i dati al worksheet
    records.forEach(record => {
      const row = worksheet.addRow({
        employeeName: record.employeeName,
        type: record.type === 'in' ? 'Ingresso' : 'Uscita',
        timestamp: new Date(record.timestamp).toLocaleString('it-IT'),
        deviceInfo: record.deviceInfo,
        latitude: record.latitude ? record.latitude.toFixed(6) : 'N/D',
        longitude: record.longitude ? record.longitude.toFixed(6) : 'N/D',
        googleMaps: (record.latitude && record.longitude) ? 'Apri in Maps' : 'N/D',
        id: record.id
      });

      // Aggiungi link a Google Maps se coordinate disponibili
      if (record.latitude && record.longitude) {
        const mapsUrl = `https://www.google.com/maps?q=${record.latitude},${record.longitude}`;
        const mapsCell = row.getCell('googleMaps');
        mapsCell.value = {
          text: 'Apri in Maps',
          hyperlink: mapsUrl
        };
        mapsCell.font = { color: { argb: 'FF0563C1' }, underline: true };
      }

      row.eachCell((cell, colNumber) => {
        if (colNumber === 2) {
          cell.font = { 
            bold: true, 
            color: { argb: record.type === 'in' ? 'FF00B050' : 'FFE74C3C' }
          };
        }
        cell.border = {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' }
        };
      });
    });

    // Aggiungi info cantiere in fondo
    worksheet.addRow([]);
    worksheet.addRow(['INFORMAZIONI CANTIERE ELIMINATO']);
    worksheet.addRow(['Nome:', workSite.name]);
    worksheet.addRow(['Indirizzo:', workSite.address]);
    worksheet.addRow(['Coordinate:', `${workSite.latitude}, ${workSite.longitude}`]);
    worksheet.addRow(['Data Eliminazione:', new Date().toLocaleString('it-IT')]);
    worksheet.addRow(['Totale Timbrature:', records.length]);

    // Salva il file
    const reportPath = path.join(__dirname, '..', 'reports');
    if (!fs.existsSync(reportPath)) {
      fs.mkdirSync(reportPath);
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const fileName = `BACKUP_${workSite.name.replace(/[^a-z0-9]/gi, '_')}_${timestamp}.xlsx`;
    const filePath = path.join(reportPath, fileName);
    
    await workbook.xlsx.writeFile(filePath);
    console.log(`✓ Backup cantiere salvato: ${fileName}`);

    // Ora elimina il cantiere
    console.log(`🗑️  [CANTIERE] Eliminazione cantiere ID: ${id} (${workSite.name})`);
    console.log(`   📦 Backup creato: ${fileName}`);
    console.log(`   📊 Timbrature preservate: ${records.length}`);
    
    db.run('DELETE FROM work_sites WHERE id = ?', [id], function(err) {
      if (err) {
        console.error(`❌ [CANTIERE] Errore eliminazione:`, err.message);
        res.status(500).json({ error: 'Internal server error' });
        return;
      }
      console.log(`✅ [CANTIERE] Eliminato con successo - Backup: ${fileName}`);
      res.json({ 
        success: true, 
        backupFile: fileName,
        message: `Cantiere eliminato. Backup salvato: ${fileName}`
      });
    });
  } catch (error) {
    console.error('Error during work site deletion:', error);
    res.status(500).json({ error: 'Error during backup or deletion' });
  }
});

// Get attendance records for a specific work site
router.get('/:id/attendance', (req, res) => {
  const workSiteId = req.params.id;
  
  db.all(
    `SELECT 
      ar.id,
      ar.employeeId,
      ar.workSiteId,
      ar.timestamp,
      ar.type,
      ar.deviceInfo,
      CAST(ar.latitude AS REAL) as latitude,
      CAST(ar.longitude AS REAL) as longitude,
      e.name as employeeName
     FROM attendance_records ar
     JOIN employees e ON ar.employeeId = e.id
     WHERE ar.workSiteId = ?
     ORDER BY ar.timestamp DESC`,
    [workSiteId],
    (err, rows) => {
      if (err) {
        console.error(err);
        res.status(500).json({ error: 'Internal server error' });
        return;
      }
      res.json(rows);
    }
  );
});

// Get work site details with current employees count
router.get('/:id/details', (req, res) => {
  const workSiteId = req.params.id;
  
  // Prima ottieni i dettagli del cantiere
  db.get('SELECT * FROM work_sites WHERE id = ?', [workSiteId], (err, workSite) => {
    if (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
      return;
    }
    
    if (!workSite) {
      res.status(404).json({ error: 'Work site not found' });
      return;
    }
    
    // Poi conta i dipendenti attualmente timbrati (ultima timbratura è IN)
    db.all(
      `SELECT DISTINCT e.id, e.name
       FROM employees e
       WHERE e.id IN (
         SELECT ar.employeeId
         FROM attendance_records ar
         WHERE ar.workSiteId = ?
         AND ar.id IN (
           SELECT MAX(ar2.id)
           FROM attendance_records ar2
           WHERE ar2.employeeId = ar.employeeId
           GROUP BY ar2.employeeId
         )
         AND ar.type = 'in'
       )
       ORDER BY e.name`,
      [workSiteId],
      (err, employees) => {
        if (err) {
          console.error(err);
          res.status(500).json({ error: 'Internal server error' });
          return;
        }
        
        res.json({
          ...workSite,
          currentEmployees: employees,
          currentEmployeesCount: employees.length
        });
      }
    );
  });
});

module.exports = router;