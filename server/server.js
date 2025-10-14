const express = require('express');
const ExcelJS = require('exceljs');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const port = 3000;

// Database
const db = require('./db');

// Routes modules
const worksitesRoutes = require('./routes/worksites');

// Middleware
app.use(cors());
app.use(express.json());

// Mount routes
app.use('/api/worksites', worksitesRoutes);

// Insert default admin if not exists (after db initialization)
setTimeout(() => {
  db.get("SELECT * FROM employees WHERE email = 'admin@example.com'", (err, row) => {
    if (!row) {
      db.run(`INSERT INTO employees (name, email, password, isAdmin) VALUES (?, ?, ?, ?)`,
        ['Admin', 'admin@example.com', 'admin123', 1], (err) => {
          if (err) {
            console.error('Error creating admin:', err);
          } else {
            console.log('Admin user created');
          }
        });
    }
  });
}, 1000);

// Routes
app.post('/api/login', (req, res) => {
  const { email, password } = req.body;
  db.get('SELECT * FROM employees WHERE email = ? AND password = ?', [email, password], (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    if (!row) {
      res.status(401).json({ error: 'Credenziali non valide' });
      return;
    }
    
    // Non inviare la password al client
    const { password: _, ...employeeWithoutPassword } = row;
    res.json(employeeWithoutPassword);
  });
});

app.get('/api/attendance', (req, res) => {
  const { employeeId } = req.query;
  const query = employeeId 
    ? `SELECT 
        id,
        employeeId,
        workSiteId,
        timestamp,
        type,
        deviceInfo,
        CAST(latitude AS REAL) as latitude,
        CAST(longitude AS REAL) as longitude,
        isForced,
        forcedByAdminId
      FROM attendance_records 
      WHERE employeeId = ? 
      ORDER BY timestamp DESC, id DESC`
    : `SELECT 
        id,
        employeeId,
        workSiteId,
        timestamp,
        type,
        deviceInfo,
        CAST(latitude AS REAL) as latitude,
        CAST(longitude AS REAL) as longitude,
        isForced,
        forcedByAdminId
      FROM attendance_records 
      ORDER BY timestamp DESC, id DESC`;
  const params = employeeId ? [employeeId] : [];
  
  db.all(query, params, (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

app.post('/api/attendance', (req, res) => {
  const record = req.body;
  db.run(`INSERT INTO attendance_records 
    (employeeId, workSiteId, timestamp, type, deviceInfo, latitude, longitude, isForced, forcedByAdminId) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      record.employeeId, 
      record.workSiteId, 
      record.timestamp, 
      record.type, 
      record.deviceInfo, 
      record.latitude, 
      record.longitude,
      record.isForced || 0,
      record.forcedByAdminId || null
    ],
    async (err) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      // Aggiorna il report Excel
      try {
        await updateExcelReport();
        res.json({ success: true });
      } catch (error) {
        console.error('Error updating Excel report:', error);
        res.json({ success: true }); // La timbratura è comunque riuscita
      }
    });
});

// Endpoint per timbratura forzata
app.post('/api/attendance/force', (req, res) => {
  const { employeeId, workSiteId, type, adminId, notes } = req.body;
  
  if (!employeeId || !workSiteId || !type || !adminId) {
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }
  
  // Verifica che l'admin esista ed sia effettivamente admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    // Crea il deviceInfo con admin e note
    let deviceInfo = `Forzato da ${admin.name}`;
    if (notes && notes.trim()) {
      deviceInfo += ` | Note: ${notes.trim()}`;
    }
    
    // Crea timestamp in formato locale (non UTC) per consistenza con i record normali
    // I record normali arrivano da Flutter con DateTime.now() che è locale
    const now = new Date();
    const localTimestamp = new Date(now.getTime() - (now.getTimezoneOffset() * 60000)).toISOString().slice(0, -1);
    
    // Crea record di timbratura forzata
    db.run(`INSERT INTO attendance_records 
      (employeeId, workSiteId, timestamp, type, deviceInfo, latitude, longitude, isForced, forcedByAdminId) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        employeeId,
        workSiteId,
        localTimestamp,  // Usa timestamp locale invece di UTC
        type,
        deviceInfo,
        0.0, // Latitude 0 per timbrature forzate
        0.0, // Longitude 0 per timbrature forzate
        1,   // isForced = true
        adminId
      ],
      async (err) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        
        // Aggiorna il report Excel
        try {
          await updateExcelReport();
          res.json({ success: true, message: 'Forced attendance recorded' });
        } catch (error) {
          console.error('Error updating Excel report:', error);
          res.json({ success: true, message: 'Forced attendance recorded' });
        }
      });
  });
});

app.get('/api/employees', (req, res) => {
  // Parametro per includere dipendenti inattivi: ?includeInactive=true
  const includeInactive = req.query.includeInactive === 'true';
  
  const query = includeInactive 
    ? 'SELECT * FROM employees ORDER BY isActive DESC, name ASC'
    : 'SELECT * FROM employees WHERE isActive = 1 ORDER BY name ASC';
  
  db.all(query, [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

app.post('/api/employees', (req, res) => {
  const { name, email, password, isAdmin } = req.body;
  const isAdminValue = isAdmin === 1 || isAdmin === true ? 1 : 0;
  
  db.run('INSERT INTO employees (name, email, password, isAdmin) VALUES (?, ?, ?, ?)',
    [name, email, password, isAdminValue],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ id: this.lastID });
    });
});

app.put('/api/employees/:id', (req, res) => {
  const { name, email, password, isAdmin } = req.body;
  const isAdminValue = isAdmin === 1 || isAdmin === true ? 1 : 0;
  
  // Se la password è fornita, aggiorniamo anche quella
  let query, params;
  if (password && password.length > 0) {
    query = 'UPDATE employees SET name = ?, email = ?, password = ?, isAdmin = ? WHERE id = ?';
    params = [name, email, password, isAdminValue, req.params.id];
  } else {
    query = 'UPDATE employees SET name = ?, email = ?, isAdmin = ? WHERE id = ?';
    params = [name, email, isAdminValue, req.params.id];
  }
  
  db.run(query, params, function(err) {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json({ success: true, changes: this.changes });
  });
});

app.delete('/api/employees/:id', (req, res) => {
  // Soft delete: marca il dipendente come inattivo invece di eliminarlo
  // I controlli di sicurezza sono gestiti lato client:
  // - Non può eliminare se stesso
  // - Non può eliminare l'unico admin
  db.run('UPDATE employees SET isActive = 0, deletedAt = ? WHERE id = ?',
    [new Date().toISOString(), req.params.id],
    (err) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({ success: true });
    });
});

// Funzione per aggiornare il report Excel
const updateExcelReport = async (filters = {}) => {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('Registro Presenze');

  // Stile per l'intestazione
  const headerStyle = {
    font: { bold: true, color: { argb: 'FFFFFFFF' } },
    fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF4472C4' } },
    alignment: { vertical: 'middle', horizontal: 'center' },
    border: {
      top: { style: 'thin' },
      left: { style: 'thin' },
      bottom: { style: 'thin' },
      right: { style: 'thin' }
    }
  };

  // Add headers
  worksheet.columns = [
    { header: 'Nome Dipendente', key: 'employeeName', width: 25 },
    { header: 'Cantiere', key: 'workSiteName', width: 30 },
    { header: 'Tipo', key: 'type', width: 12 },
    { header: 'Data e Ora', key: 'timestamp', width: 20 },
    { header: 'Dispositivo', key: 'deviceInfo', width: 35 },
    { header: 'Latitudine', key: 'latitude', width: 15 },
    { header: 'Longitudine', key: 'longitude', width: 15 },
    { header: 'Google Maps', key: 'googleMaps', width: 20 },
    { header: 'ID Dipendente', key: 'employeeId', width: 15 }
  ];

  // Applica lo stile all'intestazione
  worksheet.getRow(1).eachCell((cell) => {
    cell.style = headerStyle;
  });

  return new Promise((resolve, reject) => {
    let query = `
      SELECT 
        ar.id,
        ar.employeeId,
        ar.workSiteId,
        ar.timestamp,
        ar.type,
        ar.deviceInfo,
        ar.latitude,
        ar.longitude,
        e.name as employeeName,
        e.isActive as employeeIsActive,
        ws.name as workSiteName
      FROM attendance_records ar
      JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      WHERE 1=1
    `;
    
    const params = [];
    
    // Filtra dipendenti inattivi se non esplicitamente richiesto
    if (!filters.includeInactive) {
      query += ' AND e.isActive = 1';
    }
    
    // Applica filtri se presenti
    if (filters.employeeId) {
      query += ' AND ar.employeeId = ?';
      params.push(filters.employeeId);
    }
    
    if (filters.workSiteId) {
      query += ' AND ar.workSiteId = ?';
      params.push(filters.workSiteId);
    }
    
    if (filters.startDate) {
      query += ' AND ar.timestamp >= ?';
      params.push(filters.startDate);
    }
    
    if (filters.endDate) {
      query += ' AND ar.timestamp <= ?';
      params.push(filters.endDate);
    }
    
    query += ' ORDER BY ar.timestamp DESC';

    db.all(query, params, async (err, rows) => {
      if (err) {
        reject(err);
        return;
      }

      // Add rows to worksheet
      rows.forEach(record => {
        const row = worksheet.addRow({
          employeeName: record.employeeName,
          workSiteName: record.workSiteName || 'Non specificato',
          type: record.type === 'in' ? 'Ingresso' : 'Uscita',
          timestamp: new Date(record.timestamp).toLocaleString('it-IT'),
          deviceInfo: record.deviceInfo,
          latitude: record.latitude ? record.latitude.toFixed(6) : 'N/D',
          longitude: record.longitude ? record.longitude.toFixed(6) : 'N/D',
          googleMaps: (record.latitude && record.longitude) ? 'Apri in Maps' : 'N/D',
          employeeId: record.employeeId
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

        // Colora le righe in base al tipo
        row.eachCell((cell, colNumber) => {
          if (colNumber === 3) { // Colonna Tipo
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

      // Aggiungi filtri automatici
      worksheet.autoFilter = {
        from: 'A1',
        to: `I1`
      };

      const reportPath = path.join(__dirname, 'reports');
      if (!fs.existsSync(reportPath)) {
        fs.mkdirSync(reportPath);
      }

      const timestamp = filters.employeeId || filters.workSiteId || filters.startDate || filters.endDate
        ? `_${Date.now()}`
        : '';
      const filePath = path.join(reportPath, `attendance_report${timestamp}.xlsx`);
      
      await workbook.xlsx.writeFile(filePath);
      resolve(filePath);
    });
  });
};

// Endpoint per scaricare il report
app.get('/api/attendance/report', async (req, res) => {
  try {
    const filters = {
      employeeId: req.query.employeeId,
      workSiteId: req.query.workSiteId,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
      includeInactive: req.query.includeInactive === 'true'
    };
    const filePath = await updateExcelReport(filters);
    res.download(filePath);
  } catch (error) {
    console.error('Error generating report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== BACKUP DATABASE ====================

// Directory per i backup
const backupDir = path.join(__dirname, 'backups');
if (!fs.existsSync(backupDir)) {
  fs.mkdirSync(backupDir);
}

// File per le impostazioni di backup
const backupSettingsFile = path.join(__dirname, 'backup_settings.json');

// Carica impostazioni backup
function loadBackupSettings() {
  try {
    if (fs.existsSync(backupSettingsFile)) {
      return JSON.parse(fs.readFileSync(backupSettingsFile, 'utf8'));
    }
  } catch (error) {
    console.error('Error loading backup settings:', error);
  }
  return {
    autoBackupEnabled: false,
    autoBackupDays: 7,
    lastBackupDate: null
  };
}

// Salva impostazioni backup
function saveBackupSettings(settings) {
  try {
    fs.writeFileSync(backupSettingsFile, JSON.stringify(settings, null, 2));
    return true;
  } catch (error) {
    console.error('Error saving backup settings:', error);
    return false;
  }
}

// Funzione per creare backup
async function createDatabaseBackup() {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  const backupFileName = `database_backup_${timestamp}.db`;
  const backupPath = path.join(backupDir, backupFileName);
  const dbPath = path.join(__dirname, 'database.db');
  
  return new Promise((resolve, reject) => {
    // Copia il file database
    fs.copyFile(dbPath, backupPath, (err) => {
      if (err) {
        reject(err);
      } else {
        console.log(`✓ Database backup created: ${backupFileName}`);
        resolve({
          fileName: backupFileName,
          filePath: backupPath,
          size: fs.statSync(backupPath).size,
          timestamp: new Date().toISOString()
        });
      }
    });
  });
}

// GET - Impostazioni backup
app.get('/api/backup/settings', (req, res) => {
  const settings = loadBackupSettings();
  res.json(settings);
});

// POST - Salva impostazioni backup
app.post('/api/backup/settings', (req, res) => {
  const { autoBackupEnabled, autoBackupDays } = req.body;
  
  const settings = {
    autoBackupEnabled: autoBackupEnabled || false,
    autoBackupDays: autoBackupDays || 7,
    lastBackupDate: loadBackupSettings().lastBackupDate
  };
  
  if (saveBackupSettings(settings)) {
    res.json({ success: true, settings });
  } else {
    res.status(500).json({ error: 'Failed to save settings' });
  }
});

// POST - Crea backup manuale
app.post('/api/backup/create', async (req, res) => {
  try {
    const backupInfo = await createDatabaseBackup();
    
    // Aggiorna data ultimo backup
    const settings = loadBackupSettings();
    settings.lastBackupDate = backupInfo.timestamp;
    saveBackupSettings(settings);
    
    res.json({
      success: true,
      backup: backupInfo
    });
  } catch (error) {
    console.error('Error creating backup:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET - Lista backup esistenti
app.get('/api/backup/list', (req, res) => {
  try {
    const files = fs.readdirSync(backupDir);
    const backups = files
      .filter(file => file.startsWith('database_backup_') && file.endsWith('.db'))
      .map(file => {
        const filePath = path.join(backupDir, file);
        const stats = fs.statSync(filePath);
        return {
          fileName: file,
          size: stats.size,
          createdAt: stats.birthtime.toISOString()
        };
      })
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.json(backups);
  } catch (error) {
    console.error('Error listing backups:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET - Scarica backup
app.get('/api/backup/download/:fileName', (req, res) => {
  try {
    const fileName = req.params.fileName;
    const filePath = path.join(backupDir, fileName);
    
    // Verifica che il file esista e sia nella directory corretta
    if (!fs.existsSync(filePath) || !fileName.startsWith('database_backup_')) {
      res.status(404).json({ error: 'Backup not found' });
      return;
    }
    
    res.download(filePath, fileName);
  } catch (error) {
    console.error('Error downloading backup:', error);
    res.status(500).json({ error: error.message });
  }
});

// DELETE - Elimina backup
app.delete('/api/backup/:fileName', (req, res) => {
  try {
    const fileName = req.params.fileName;
    const filePath = path.join(backupDir, fileName);
    
    // Verifica che il file esista e sia nella directory corretta
    if (!fs.existsSync(filePath) || !fileName.startsWith('database_backup_')) {
      res.status(404).json({ error: 'Backup not found' });
      return;
    }
    
    fs.unlinkSync(filePath);
    console.log(`✓ Backup deleted: ${fileName}`);
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting backup:', error);
    res.status(500).json({ error: error.message });
  }
});

// Controllo automatico backup all'avvio e ogni 24 ore
function checkAutoBackup() {
  const settings = loadBackupSettings();
  
  if (!settings.autoBackupEnabled) {
    return;
  }
  
  const now = new Date();
  const lastBackup = settings.lastBackupDate ? new Date(settings.lastBackupDate) : null;
  
  if (!lastBackup) {
    // Nessun backup precedente, crealo
    console.log('No previous backup found, creating one...');
    createDatabaseBackup().then(backupInfo => {
      settings.lastBackupDate = backupInfo.timestamp;
      saveBackupSettings(settings);
    }).catch(err => console.error('Auto-backup failed:', err));
    return;
  }
  
  const daysSinceLastBackup = (now - lastBackup) / (1000 * 60 * 60 * 24);
  
  if (daysSinceLastBackup >= settings.autoBackupDays) {
    console.log(`Auto-backup triggered (${daysSinceLastBackup.toFixed(1)} days since last backup)`);
    createDatabaseBackup().then(backupInfo => {
      settings.lastBackupDate = backupInfo.timestamp;
      saveBackupSettings(settings);
    }).catch(err => console.error('Auto-backup failed:', err));
  }
}

// Controlla backup all'avvio
setTimeout(checkAutoBackup, 5000);

// Controlla backup ogni 24 ore
setInterval(checkAutoBackup, 24 * 60 * 60 * 1000);

// ==================== END BACKUP ====================

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});