const sqlite3 = require('sqlite3');
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'database.db'));

// Crea le tabelle se non esistono
db.serialize(() => {
  // Tabella employees con schema completo v1.2.0
  // Include username, role e tutti i campi necessari
  db.run(`CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    username TEXT UNIQUE,
    email TEXT,
    password TEXT NOT NULL,
    isAdmin INTEGER DEFAULT 0,
    role TEXT DEFAULT 'employee',
    isActive INTEGER DEFAULT 1,
    allowNightShift INTEGER DEFAULT 0,
    deleted INTEGER DEFAULT 0,
    deletedAt DATETIME,
    deletedByAdminId INTEGER,
    FOREIGN KEY (deletedByAdminId) REFERENCES employees (id)
  )`, (err) => {
    if (err) {
      console.error('❌ Error creating employees table:', err.message);
    } else {
      console.log('✓ Table employees ready');
    }
  });
  
  // ==================== MIGRAZIONE COLONNE PER DATABASE ESISTENTI ====================
  // Questi ALTER TABLE servono solo per database creati con vecchio schema
  // Se la tabella è nuova, le colonne esistono già e questi comandi non fanno nulla
  
  // Aggiungi colonna username (UNIQUE) per autenticazione
  db.run(`ALTER TABLE employees ADD COLUMN username TEXT UNIQUE`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding username column:', err);
    } else if (!err) {
      console.log('✓ Column username added to employees');
    }
  });
  
  // Aggiungi colonna role per gestire admin/employee/foreman
  // Values: 'admin', 'employee', 'foreman'
  db.run(`ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee'`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding role column:', err);
    } else if (!err) {
      console.log('✓ Column role added to employees');
    }
  });
  
  // Aggiungi colonna isActive per soft delete
  db.run(`ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding isActive column:', err);
    } else if (!err) {
      console.log('✓ Column isActive added to employees');
    }
  });
  
  // Aggiungi colonna allowNightShift
  db.run(`ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding allowNightShift column:', err);
    } else if (!err) {
      console.log('✓ Column allowNightShift added to employees');
    }
  });
  
  // Aggiungi colonna deleted per soft delete
  db.run(`ALTER TABLE employees ADD COLUMN deleted INTEGER DEFAULT 0`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding deleted column:', err);
    } else if (!err) {
      console.log('✓ Column deleted added to employees');
    }
  });
  
  // Aggiungi colonna deletedAt
  db.run(`ALTER TABLE employees ADD COLUMN deletedAt DATETIME`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding deletedAt column:', err);
    } else if (!err) {
      console.log('✓ Column deletedAt added to employees');
    }
  });
  
  // Aggiungi colonna deletedByAdminId
  db.run(`ALTER TABLE employees ADD COLUMN deletedByAdminId INTEGER`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding deletedByAdminId column:', err);
    } else if (!err) {
      console.log('✓ Column deletedByAdminId added to employees');
    }
  });

  // Tabella attendance_records (già esistente)
  db.run(`CREATE TABLE IF NOT EXISTS attendance_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employeeId INTEGER NOT NULL,
    workSiteId INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    type TEXT CHECK(type IN ('in', 'out')) NOT NULL,
    deviceInfo TEXT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    isForced INTEGER DEFAULT 0,
    forcedByAdminId INTEGER,
    FOREIGN KEY (employeeId) REFERENCES employees (id),
    FOREIGN KEY (workSiteId) REFERENCES work_sites (id),
    FOREIGN KEY (forcedByAdminId) REFERENCES employees (id)
  )`);
  
  // Aggiungi colonne per timbrature forzate se non esistono
  db.run(`ALTER TABLE attendance_records ADD COLUMN isForced INTEGER DEFAULT 0`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding isForced column:', err);
    } else if (!err) {
      console.log('✓ Column isForced added to attendance_records');
    }
  });
  
  db.run(`ALTER TABLE attendance_records ADD COLUMN forcedByAdminId INTEGER`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding forcedByAdminId column:', err);
    } else if (!err) {
      console.log('✓ Column forcedByAdminId added to attendance_records');
    }
  });
  
  db.run(`ALTER TABLE attendance_records ADD COLUMN notes TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding notes column:', err);
    } else if (!err) {
      console.log('✓ Column notes added to attendance_records');
    }
  });
  
  // Aggiungi colonne per soft delete degli employees
  db.run(`ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding isActive column:', err);
    } else if (!err) {
      console.log('✓ Column isActive added to employees');
    }
  });
  
  // Aggiungi colonna deletedAt per soft delete
  db.run(`ALTER TABLE employees ADD COLUMN deletedAt DATETIME`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding deletedAt column:', err);
    } else if (!err) {
      console.log('✓ Column deletedAt added to employees');
    }
  });
  
  // Aggiungi colonna allowNightShift per autorizzare turni notturni oltre mezzanotte
  db.run(`ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding allowNightShift column:', err);
    } else if (!err) {
      console.log('✓ Column allowNightShift added to employees');
    }
  });

  // Nuova tabella work_sites
  db.run(`CREATE TABLE IF NOT EXISTS work_sites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    address TEXT NOT NULL,
    isActive INTEGER DEFAULT 1,
    radiusMeters REAL DEFAULT 100.0,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
  
  // Aggiungi colonna radiusMeters se non esiste (per database esistenti)
  db.run(`ALTER TABLE work_sites ADD COLUMN radiusMeters REAL DEFAULT 100.0`, (err) => {
    // Ignora l'errore se la colonna esiste già
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding radiusMeters column:', err);
    } else if (!err) {
      console.log('✓ Column radiusMeters added to work_sites');
    } else {
      console.log('✓ Column radiusMeters already exists in work_sites');
    }
  });
  
  // Aggiungi colonna description per descrizione cantiere
  db.run(`ALTER TABLE work_sites ADD COLUMN description TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding description column:', err);
    } else if (!err) {
      console.log('✓ Column description added to work_sites');
    }
  });
  
  // Tabella app_settings per impostazioni globali
  db.run(`CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
  
  // Inserisci valore default per accuratezza GPS se non esiste
  db.run(`INSERT OR IGNORE INTO app_settings (key, value) VALUES ('minGpsAccuracyPercent', '75.0')`, (err) => {
    if (!err) {
      console.log('✓ Default GPS accuracy setting initialized');
    }
  });
  
  // 🔍 Tabella audit_log per tracciare TUTTE le operazioni amministrative
  db.run(`CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    adminId INTEGER NOT NULL,
    action TEXT NOT NULL,
    targetType TEXT NOT NULL,
    targetId INTEGER,
    targetName TEXT,
    oldValue TEXT,
    newValue TEXT,
    details TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    ipAddress TEXT,
    FOREIGN KEY (adminId) REFERENCES employees (id)
  )`, (err) => {
    if (!err) {
      console.log('✅ Table audit_log created successfully');
    } else {
      console.log('✓ Table audit_log already exists');
    }
  });
  
  // Crea indici per query veloci su audit_log
  db.run(`CREATE INDEX IF NOT EXISTS idx_audit_adminId ON audit_log (adminId)`, (err) => {
    if (!err) {
      console.log('✓ Index idx_audit_adminId created');
    }
  });
  
  db.run(`CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log (timestamp)`, (err) => {
    if (!err) {
      console.log('✓ Index idx_audit_timestamp created');
    }
  });
  
  db.run(`CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log (action)`, (err) => {
    if (!err) {
      console.log('✓ Index idx_audit_action created');
    }
  });
  
  // Verifica struttura tabella work_sites
  db.all(`PRAGMA table_info(work_sites)`, [], (err, columns) => {
    if (!err) {
      console.log('Work_sites table structure:');
      columns.forEach(col => {
        console.log(`  - ${col.name} (${col.type}) ${col.dflt_value ? `DEFAULT ${col.dflt_value}` : ''}`);
      });
    }
  });
  
  // Verifica struttura tabella attendance_records
  db.all(`PRAGMA table_info(attendance_records)`, [], (err, columns) => {
    if (!err) {
      console.log('Attendance_records table structure:');
      columns.forEach(col => {
        console.log(`  - ${col.name} (${col.type}) ${col.dflt_value ? `DEFAULT ${col.dflt_value}` : ''}`);
      });
    }
  });
});

module.exports = db;