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
    let deviceInfo = `Forced by admin: ${admin.name}`;
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
  db.all('SELECT * FROM employees', [], (err, rows) => {
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
  // Rimuovi il dipendente (admin o normale)
  // I controlli di sicurezza sono gestiti lato client:
  // - Non può eliminare se stesso
  // - Non può eliminare l'unico admin
  db.run('DELETE FROM employees WHERE id = ?',
    [req.params.id],
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
        ws.name as workSiteName
      FROM attendance_records ar
      JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      WHERE 1=1
    `;
    
    const params = [];
    
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
      endDate: req.query.endDate
    };
    const filePath = await updateExcelReport(filters);
    res.download(filePath);
  } catch (error) {
    console.error('Error generating report:', error);
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});