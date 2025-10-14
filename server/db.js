const sqlite3 = require('sqlite3');
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'database.db'));

// Crea le tabelle se non esistono
db.serialize(() => {
  // Tabella employees (già esistente)
  db.run(`CREATE TABLE IF NOT EXISTS employees (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    isAdmin INTEGER DEFAULT 0
  )`);

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
  
  // Aggiungi colonne per soft delete degli employees
  db.run(`ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding isActive column:', err);
    } else if (!err) {
      console.log('✓ Column isActive added to employees');
    }
  });
  
  db.run(`ALTER TABLE employees ADD COLUMN deletedAt DATETIME`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding deletedAt column:', err);
    } else if (!err) {
      console.log('✓ Column deletedAt added to employees');
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