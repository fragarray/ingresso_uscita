const express = require('express');
const ExcelJS = require('exceljs');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const sqlite3 = require('sqlite3').verbose();
const cron = require('node-cron');
const nodemailer = require('nodemailer');

const app = express();
const port = 3000;

// ==================== CONFIGURAZIONE ORARIO REPORT GIORNALIERO ====================
// Formato: "HH:MM" (es: "00:05", "08:00", "18:30")
// Modifica questo valore per cambiare l'orario di invio del report giornaliero
const DAILY_REPORT_TIME = "00:05";
// =================================================================================

// Database
const db = require('./db');

// Routes modules
const worksitesRoutes = require('./routes/worksites');

// Middleware
app.use(cors());
app.use(express.json());

// ==================== LOGGING MIDDLEWARE ====================
// Middleware per log di tutte le richieste HTTP (DOPO express.json())
app.use((req, res, next) => {
  const timestamp = new Date().toLocaleString('it-IT');
  console.log(`\n📡 [${timestamp}] ${req.method} ${req.originalUrl}`);
  
  // Log body per POST/PUT (escludi password per sicurezza)
  if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body && Object.keys(req.body).length > 0) {
    const sanitizedBody = { ...req.body };
    if (sanitizedBody.password) sanitizedBody.password = '***';
    console.log(`   📦 Body:`, JSON.stringify(sanitizedBody, null, 2));
  }
  
  // Log query params se presenti
  if (req.query && Object.keys(req.query).length > 0) {
    console.log(`   🔍 Query:`, req.query);
  }
  
  next();
});

// ==================== AUDIT LOG HELPER ====================
/**
 * Funzione per registrare operazioni amministrative nell'audit log
 * @param {number} adminId - ID dell'amministratore che esegue l'azione
 * @param {string} action - Tipo di azione (FORCE_IN, FORCE_OUT, EDIT_ATTENDANCE, DELETE_ATTENDANCE, CREATE_EMPLOYEE, etc.)
 * @param {string} targetType - Tipo di entità target (ATTENDANCE, EMPLOYEE, WORKSITE, SETTING)
 * @param {number|null} targetId - ID dell'entità target
 * @param {string|null} targetName - Nome descrittivo del target
 * @param {object|null} oldValue - Valore precedente (per UPDATE)
 * @param {object|null} newValue - Nuovo valore
 * @param {string|null} details - Dettagli aggiuntivi
 * @param {string|null} ipAddress - Indirizzo IP del client
 */
const logAuditAction = (adminId, action, targetType, targetId = null, targetName = null, oldValue = null, newValue = null, details = null, ipAddress = null) => {
  const query = `
    INSERT INTO audit_log (
      adminId, action, targetType, targetId, targetName, 
      oldValue, newValue, details, ipAddress
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;
  
  const oldValueStr = oldValue ? JSON.stringify(oldValue) : null;
  const newValueStr = newValue ? JSON.stringify(newValue) : null;
  
  db.run(query, [
    adminId, 
    action, 
    targetType, 
    targetId, 
    targetName,
    oldValueStr,
    newValueStr,
    details,
    ipAddress
  ], (err) => {
    if (err) {
      console.error('❌ [AUDIT LOG] Error:', err.message);
    } else {
      console.log(`✅ [AUDIT LOG] ${action} by admin ${adminId} on ${targetType} ${targetId || ''}`);
    }
  });
};

// Mount routes
app.use('/api/worksites', worksitesRoutes);

// Server validation endpoint
app.get('/api/ping', (req, res) => {
  res.json({
    success: true,
    message: 'Ingresso/Uscita Server',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    serverIdentity: 'ingresso-uscita-server'
  });
});

// Insert default admin if not exists (after db initialization)
// AGGIORNATO per nuovo schema con username e role
// Timeout aumentato a 2000ms per assicurare che tutte le colonne siano state create
setTimeout(() => {
  db.get("SELECT * FROM employees WHERE username = 'admin' OR email = 'admin@example.com'", (err, row) => {
    if (err) {
      console.error('❌ Errore verifica admin esistente:', err.message);
      return;
    }
    
    if (!row) {
      console.log('🔧 Creazione utente amministratore di default...');
      db.run(
        `INSERT INTO employees (name, username, email, password, isAdmin, role, isActive) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        ['Admin', 'admin', 'admin@example.com', 'admin123', 1, 'admin', 1], 
        (err) => {
          if (err) {
            console.error('❌ Errore creazione admin:', err.message);
            console.log('💡 Suggerimento: Verifica che la tabella employees abbia tutte le colonne necessarie');
          } else {
            console.log('✅ Utente amministratore creato con successo!');
            console.log('📋 Credenziali di default:');
            console.log('   Username: admin');
            console.log('   Password: admin123');
            console.log('   Email: admin@example.com');
            console.log('⚠️  IMPORTANTE: Cambia la password al primo accesso!');
          }
        }
      );
    } else {
      console.log('ℹ️  Utente amministratore già presente nel database');
    }
  });
}, 2000);

// ==================== AUTO-TIMBRATURA USCITA A MEZZANOTTE ====================

/**
 * Funzione per timbrare automaticamente l'uscita dei dipendenti ancora IN a mezzanotte
 */
const autoForceCheckout = async () => {
  console.log('\n🕐 [AUTO-CHECKOUT] Avvio controllo timbrature aperte...');
  
  return new Promise((resolve, reject) => {
    // Trova tutti i dipendenti attualmente timbrati IN (ultima timbratura = IN)
    // ESCLUDI i dipendenti con allowNightShift = 1 (autorizzati ai turni notturni)
    const query = `
      WITH LastRecords AS (
        SELECT 
          employeeId,
          MAX(id) as lastId
        FROM attendance_records
        GROUP BY employeeId
      )
      SELECT 
        ar.employeeId,
        ar.workSiteId,
        e.name as employeeName,
        ws.name as workSiteName,
        ar.timestamp as lastInTimestamp
      FROM attendance_records ar
      INNER JOIN LastRecords lr ON ar.id = lr.lastId
      INNER JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      WHERE ar.type = 'in'
        AND e.isActive = 1
        AND (e.allowNightShift IS NULL OR e.allowNightShift = 0)
    `;
    
    db.all(query, [], async (err, employees) => {
      if (err) {
        console.error('❌ [AUTO-CHECKOUT] Errore durante la query:', err);
        reject(err);
        return;
      }
      
      if (employees.length === 0) {
        console.log('✓ [AUTO-CHECKOUT] Nessun dipendente da timbrare in uscita.');
        resolve(0);
        return;
      }
      
      console.log(`⚠️  [AUTO-CHECKOUT] Trovati ${employees.length} dipendenti ancora IN:`);
      
      // Trova un admin di sistema per la timbratura forzata
      db.get('SELECT id, name FROM employees WHERE isAdmin = 1 ORDER BY id LIMIT 1', [], async (err, admin) => {
        if (err || !admin) {
          console.error('❌ [AUTO-CHECKOUT] Nessun admin trovato per la timbratura automatica');
          reject(new Error('No admin found'));
          return;
        }
        
        let processed = 0;
        let failed = 0;
        
        // Timestamp di mezzanotte (23:59:59 del giorno APPENA TERMINATO)
        // Se siamo alle 00:01 del 22 ottobre, usiamo 23:59:59 del 21 ottobre
        const now = new Date();
        const midnight = new Date(now);
        midnight.setDate(midnight.getDate() - 1); // Torna al giorno prima
        midnight.setHours(23, 59, 59, 999); // Imposta 23:59:59.999
        const midnightTimestamp = midnight.toISOString().slice(0, -1);
        
        // Processa ogni dipendente
        for (const emp of employees) {
          await new Promise((resolveEmp) => {
            const deviceInfo = `AUTO-CHECKOUT MEZZANOTTE - Sistema`;
            const notes = 'USCITA FORZATA PER SUPERAMENTO ORARIO';
            
            db.run(`
              INSERT INTO attendance_records 
              (employeeId, workSiteId, timestamp, type, deviceInfo, latitude, longitude, isForced, forcedByAdminId, notes) 
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
              [
                emp.employeeId,
                emp.workSiteId,
                midnightTimestamp,
                'out',
                deviceInfo,
                0.0, // Latitude 0 per timbrature forzate
                0.0, // Longitude 0 per timbrature forzate
                1,   // isForced = true
                admin.id,
                notes
              ],
              (err) => {
                if (err) {
                  console.error(`   ❌ ${emp.employeeName}: ERRORE - ${err.message}`);
                  failed++;
                } else {
                  console.log(`   ✓ ${emp.employeeName} - ${emp.workSiteName || 'N/D'} - OUT automatico alle 23:59:59`);
                  processed++;
                }
                resolveEmp();
              }
            );
          });
        }
        
        console.log(`\n📊 [AUTO-CHECKOUT] Riepilogo:`);
        console.log(`   ✓ Processati: ${processed}`);
        console.log(`   ❌ Falliti: ${failed}`);
        console.log(`   📅 Timestamp: ${midnightTimestamp}\n`);
        
        // Aggiorna il report Excel
        try {
          await updateExcelReport();
          console.log('✓ [AUTO-CHECKOUT] Report Excel aggiornato');
        } catch (error) {
          console.error('⚠️  [AUTO-CHECKOUT] Errore aggiornamento report:', error.message);
        }
        
        resolve(processed);
      });
    });
  });
};

// Schedule: Esegui ogni giorno alle 00:01
cron.schedule('1 0 * * *', async () => {
  const now = new Date();
  console.log(`\n⏰ [CRON] Job auto-checkout avviato alle ${now.toLocaleString('it-IT', { timeZone: 'Europe/Rome' })}`);
  try {
    await autoForceCheckout();
  } catch (error) {
    console.error('❌ [CRON] Errore durante auto-checkout:', error);
  }
}, {
  timezone: "Europe/Rome"
});

const nextRun = new Date();
nextRun.setHours(0, 1, 0, 0);
if (nextRun <= new Date()) {
  nextRun.setDate(nextRun.getDate() + 1);
}
console.log('✓ Scheduler auto-checkout attivato (esegue alle 00:01 ogni giorno)');
console.log(`  → Prossima esecuzione prevista: ${nextRun.toLocaleString('it-IT', { timeZone: 'Europe/Rome' })}`);

// ==================== EMAIL CONFIGURATION ====================

const emailConfigFile = path.join(__dirname, 'email_config.json');

// Carica configurazione email
function loadEmailConfig() {
  try {
    if (fs.existsSync(emailConfigFile)) {
      return JSON.parse(fs.readFileSync(emailConfigFile, 'utf8'));
    }
  } catch (error) {
    console.error('❌ Error loading email config:', error);
  }
  return {
    emailEnabled: false,
    smtpHost: 'smtp.gmail.com',
    smtpPort: 587,
    smtpSecure: false,
    smtpUser: '',
    smtpPassword: '',
    fromEmail: '',
    fromName: 'Sistema Timbrature',
    dailyReportEnabled: true,
    dailyReportTime: '00:05'
  };
}

// Salva configurazione email
function saveEmailConfig(config) {
  try {
    fs.writeFileSync(emailConfigFile, JSON.stringify(config, null, 2));
    return true;
  } catch (error) {
    console.error('❌ Error saving email config:', error);
    return false;
  }
}

// Crea transporter nodemailer
function createEmailTransporter() {
  const config = loadEmailConfig();
  
  if (!config.emailEnabled || !config.smtpUser || !config.smtpPassword) {
    return null;
  }
  
  return nodemailer.createTransport({
    host: config.smtpHost,
    port: config.smtpPort,
    secure: config.smtpSecure,
    auth: {
      user: config.smtpUser,
      pass: config.smtpPassword
    }
  });
}

// Funzione per inviare report giornaliero a tutti gli admin
const sendDailyReportToAdmins = async () => {
  console.log('\n📧 [EMAIL] Avvio invio report giornaliero agli admin...');
  
  const config = loadEmailConfig();
  
  if (!config.emailEnabled || !config.dailyReportEnabled) {
    console.log('⚠️  [EMAIL] Invio email disabilitato nella configurazione');
    return;
  }
  
  try {
    // 1. Trova tutti gli admin
    const admins = await new Promise((resolve, reject) => {
      db.all('SELECT id, name, email FROM employees WHERE isAdmin = 1 AND isActive = 1', [], (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
    
    if (admins.length === 0) {
      console.log('⚠️  [EMAIL] Nessun admin trovato');
      return;
    }
    
    console.log(`📋 [EMAIL] Trovati ${admins.length} amministratori`);
    
    // 2. Calcola date (giorno precedente)
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    
    const startDate = yesterday.toISOString();
    
    const endOfYesterday = new Date(yesterday);
    endOfYesterday.setHours(23, 59, 59, 999);
    const endDate = endOfYesterday.toISOString();
    
    const dateStr = yesterday.toLocaleDateString('it-IT', { 
      day: '2-digit', 
      month: '2-digit', 
      year: 'numeric' 
    });
    
    console.log(`📅 [EMAIL] Generazione report per: ${dateStr}`);
    
    // 3. Genera report (tutti i cantieri, tutti i dipendenti, solo giorno precedente)
    const reportPath = await generateWorkSiteReport(null, null, startDate, endDate);
    
    if (!fs.existsSync(reportPath)) {
      console.error('❌ [EMAIL] File report non trovato:', reportPath);
      return;
    }
    
    const fileStats = fs.statSync(reportPath);
    console.log(`✓ [EMAIL] Report generato: ${path.basename(reportPath)} (${(fileStats.size / 1024).toFixed(2)} KB)`);
    
    // 4. Crea transporter
    const transporter = createEmailTransporter();
    
    if (!transporter) {
      console.error('❌ [EMAIL] Impossibile creare transporter (verifica configurazione SMTP)');
      return;
    }
    
    // 5. Invia email a ciascun admin
    let sent = 0;
    let failed = 0;
    
    for (const admin of admins) {
      try {
        const mailOptions = {
          from: `"${config.fromName}" <${config.fromEmail}>`,
          to: admin.email,
          subject: `Report Giornaliero Timbrature - ${dateStr}`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
              <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
                <h1 style="color: white; margin: 0; font-size: 24px;">📊 Report Timbrature</h1>
                <p style="color: white; margin: 10px 0 0 0; opacity: 0.9;">Riepilogo giornaliero automatico</p>
              </div>
              
              <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px;">
                <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
                  Gentile <strong>${admin.name}</strong>,
                </p>
                
                <p style="font-size: 14px; color: #666; line-height: 1.6; margin-bottom: 20px;">
                  In allegato trovi il report completo delle timbrature di <strong>tutti i cantieri</strong> 
                  e <strong>tutti i dipendenti</strong> per la giornata di <strong>${dateStr}</strong>.
                </p>
                
                <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #667eea; margin-bottom: 20px;">
                  <p style="margin: 0; color: #555; font-size: 14px;">
                    <strong style="color: #667eea;">📅 Data:</strong> ${dateStr}<br>
                    <strong style="color: #667eea;">📍 Cantieri:</strong> Tutti<br>
                    <strong style="color: #667eea;">👥 Dipendenti:</strong> Tutti<br>
                    <strong style="color: #667eea;">📎 Allegato:</strong> ${path.basename(reportPath)}
                  </p>
                </div>
                
                <p style="font-size: 13px; color: #999; line-height: 1.6; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
                  <em>Questa email è stata inviata automaticamente dal Sistema di Gestione Timbrature alle ore 00:05.</em><br>
                  <em>Report generato il ${new Date().toLocaleString('it-IT')}.</em>
                </p>
              </div>
            </div>
          `,
          attachments: [
            {
              filename: path.basename(reportPath),
              path: reportPath
            }
          ]
        };
        
        await transporter.sendMail(mailOptions);
        console.log(`   ✓ ${admin.name} (${admin.email})`);
        sent++;
      } catch (error) {
        console.error(`   ❌ ${admin.name} (${admin.email}): ${error.message}`);
        failed++;
      }
    }
    
    console.log(`\n📊 [EMAIL] Riepilogo invio:`);
    console.log(`   ✓ Inviati: ${sent}`);
    console.log(`   ❌ Falliti: ${failed}`);
    console.log(`   📎 Report: ${path.basename(reportPath)}\n`);
    
    // 6. Pulizia file temporaneo (opzionale - mantieni per debug)
    // fs.unlinkSync(reportPath);
    
  } catch (error) {
    console.error('❌ [EMAIL] Errore durante invio report giornaliero:', error);
  }
};

// Schedule: Report giornaliero (orario configurabile tramite DAILY_REPORT_TIME)
const [reportHour, reportMinute] = DAILY_REPORT_TIME.split(':').map(Number);
const cronExpression = `${reportMinute} ${reportHour} * * *`;

cron.schedule(cronExpression, async () => {
  console.log(`⏰ [CRON] Job report giornaliero avviato alle ${DAILY_REPORT_TIME}`);
  try {
    await sendDailyReportToAdmins();
  } catch (error) {
    console.error('❌ [CRON] Errore durante invio report giornaliero:', error);
  }
}, {
  timezone: "Europe/Rome"
});

console.log(`✓ Scheduler report giornaliero attivato (esegue alle ${DAILY_REPORT_TIME} ogni giorno)`);

// Endpoint DEBUG per verificare query auto-checkout (solo admin)
app.post('/api/admin/debug-auto-checkout', async (req, res) => {
  const { adminId } = req.body;
  
  // Verifica che sia un admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], async (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    const query = `
      WITH LastRecords AS (
        SELECT 
          employeeId,
          MAX(id) as lastId
        FROM attendance_records
        GROUP BY employeeId
      )
      SELECT 
        ar.employeeId,
        ar.workSiteId,
        e.name as employeeName,
        e.allowNightShift,
        ws.name as workSiteName,
        ar.timestamp as lastInTimestamp,
        ar.type as lastType
      FROM attendance_records ar
      INNER JOIN LastRecords lr ON ar.id = lr.lastId
      INNER JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      WHERE e.isActive = 1
    `;
    
    db.all(query, [], (err, allEmployees) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      
      const eligibleForAutoCheckout = allEmployees.filter(emp => 
        emp.lastType === 'in' && 
        (emp.allowNightShift === null || emp.allowNightShift === 0)
      );
      
      res.json({
        success: true,
        debug: {
          totalActiveEmployees: allEmployees.length,
          employeesWithLastIN: allEmployees.filter(e => e.lastType === 'in').length,
          employeesWithNightShiftEnabled: allEmployees.filter(e => e.allowNightShift === 1).length,
          eligibleForAutoCheckout: eligibleForAutoCheckout.length,
          details: allEmployees.map(emp => ({
            name: emp.employeeName,
            lastType: emp.lastType,
            lastTimestamp: emp.lastInTimestamp,
            allowNightShift: emp.allowNightShift,
            eligibleForCheckout: emp.lastType === 'in' && (emp.allowNightShift === null || emp.allowNightShift === 0)
          }))
        }
      });
    });
  });
});

// Endpoint manuale per testare l'auto-checkout (solo admin)
app.post('/api/admin/force-auto-checkout', async (req, res) => {
  const { adminId } = req.body;
  
  // Verifica che sia un admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], async (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    try {
      const count = await autoForceCheckout();
      res.json({ 
        success: true, 
        message: `Auto-checkout completato: ${count} dipendenti processati`,
        processedCount: count
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
});

// ==================== END AUTO-CHECKOUT ====================

// ==================== APP SETTINGS ROUTES ====================

// GET: Ottieni impostazione specifica
app.get('/api/settings/:key', (req, res) => {
  const { key } = req.params;
  
  db.get('SELECT value, updatedAt FROM app_settings WHERE key = ?', [key], (err, row) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!row) {
      res.status(404).json({ error: 'Setting not found' });
      return;
    }
    
    res.json({
      key: key,
      value: row.value,
      updatedAt: row.updatedAt
    });
  });
});

// GET: Ottieni tutte le impostazioni
app.get('/api/settings', (req, res) => {
  db.all('SELECT key, value, updatedAt FROM app_settings', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    const settings = {};
    rows.forEach(row => {
      settings[row.key] = {
        value: row.value,
        updatedAt: row.updatedAt
      };
    });
    
    res.json(settings);
  });
});

// PUT: Aggiorna impostazione (solo admin)
app.put('/api/settings/:key', (req, res) => {
  const { key } = req.params;
  const { value, adminId } = req.body;
  
  if (!adminId) {
    res.status(400).json({ error: 'adminId required' });
    return;
  }
  
  // Verifica che sia admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!admin) {
      res.status(403).json({ error: 'Unauthorized: Admin access required' });
      return;
    }
    
    // Aggiorna o inserisci impostazione
    db.run(`INSERT INTO app_settings (key, value, updatedAt) 
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET 
              value = excluded.value,
              updatedAt = CURRENT_TIMESTAMP`,
      [key, value],
      (err) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        
        console.log(`✓ Setting '${key}' updated to '${value}' by admin ${admin.name}`);
        res.json({ 
          success: true, 
          key: key, 
          value: value,
          updatedBy: admin.name
        });
      }
    );
  });
});

// ==================== END APP SETTINGS ====================

// Routes
app.post('/api/login', (req, res) => {
  const { username, email, password } = req.body;
  
  // Supporta sia username (nuovo) che email (legacy per compatibilità durante migrazione)
  const loginIdentifier = username || email;
  const loginField = username ? 'username' : 'email';
  
  console.log(`🔐 [LOGIN] Tentativo di login con ${loginField}: ${loginIdentifier}`);
  
  db.get(`SELECT * FROM employees WHERE ${loginField} = ? AND password = ?`, [loginIdentifier, password], (err, row) => {
    if (err) {
      console.error(`❌ [LOGIN] Errore database:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    if (!row) {
      console.log(`⛔ [LOGIN] Credenziali non valide per: ${loginIdentifier}`);
      res.status(401).json({ error: 'Credenziali non valide' });
      return;
    }
    
    // ⚠️ VALIDAZIONE CRITICA: Controlla se l'account è stato eliminato (soft delete)
    if (row.deleted === 1 || row.isActive === 0) {
      console.log(`🚫 [LOGIN] Account disattivato - ID: ${row.id}, Nome: ${row.name}, Username: ${row.username}`);
      res.status(403).json({ 
        error: 'Account non più attivo',
        message: 'Questo account è stato disattivato. Contatta l\'amministratore per maggiori informazioni.'
      });
      return;
    }
    
    // Determina ruolo per logging
    const roleDisplay = row.role === 'admin' ? 'Amministratore' 
                      : row.role === 'foreman' ? 'Capocantiere' 
                      : 'Dipendente';
    
    console.log(`✅ [LOGIN] Login riuscito - ID: ${row.id}, Nome: ${row.name}, Ruolo: ${roleDisplay}`);
    
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
  
  console.log(`⏱️  [TIMBRATURA] Nuova timbratura ricevuta`);
  console.log(`   👤 Dipendente ID: ${record.employeeId}`);
  console.log(`   🏗️  Cantiere ID: ${record.workSiteId}`);
  console.log(`   ⏰ Timestamp: ${record.timestamp}`);
  console.log(`   ${record.type === 'in' ? '➡️  Tipo: INGRESSO' : '⬅️  Tipo: USCITA'}`);
  console.log(`   📍 Coordinate: ${record.latitude}, ${record.longitude}`);
  console.log(`   📱 Dispositivo: ${record.deviceInfo}`);
  
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
    async function(err) {
      if (err) {
        console.error(`❌ [TIMBRATURA] Errore inserimento:`, err.message);
        res.status(500).json({ error: err.message });
        return;
      }
      
      console.log(`✅ [TIMBRATURA] Registrata con successo - Record ID: ${this.lastID}`);
      
      // Aggiorna il report Excel
      try {
        await updateExcelReport();
        console.log(`📊 [TIMBRATURA] Report Excel aggiornato`);
        res.json({ success: true });
      } catch (error) {
        console.error('⚠️  [TIMBRATURA] Errore aggiornamento report Excel:', error.message);
        res.json({ success: true }); // La timbratura è comunque riuscita
      }
    });
});

// Endpoint per timbratura forzata
app.post('/api/attendance/force', (req, res) => {
  const { employeeId, workSiteId, type, adminId, notes, timestamp } = req.body;
  
  console.log(`🔨 [TIMBRATURA FORZATA] Richiesta ricevuta`);
  console.log(`   👤 Dipendente ID: ${employeeId}`);
  console.log(`   🏗️  Cantiere ID: ${workSiteId}`);
  console.log(`   ${type === 'in' ? '➡️  Tipo: INGRESSO' : '⬅️  Tipo: USCITA'}`);
  console.log(`   👨‍💼 Admin ID: ${adminId}`);
  console.log(`   📝 Note: ${notes || 'Nessuna'}`);
  console.log(`   ⏰ Timestamp personalizzato: ${timestamp || 'No (usa ora corrente)'}`);
  
  if (!employeeId || !workSiteId || !type || !adminId) {
    console.error(`❌ [TIMBRATURA FORZATA] Parametri mancanti`);
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }
  
  // Verifica che l'admin esista ed sia effettivamente admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err) {
      console.error(`❌ [TIMBRATURA FORZATA] Errore verifica admin:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!admin) {
      console.error(`⛔ [TIMBRATURA FORZATA] Admin ID ${adminId} non autorizzato`);
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    console.log(`✅ [TIMBRATURA FORZATA] Admin verificato: ${admin.name} (${admin.email})`);
    
    // Crea il deviceInfo con admin e note
    let deviceInfo = `Forzato da ${admin.name}`;
    if (notes && notes.trim()) {
      deviceInfo += ` | Note: ${notes.trim()}`;
    }
    
    // Determina il timestamp da usare
    let finalTimestamp;
    if (timestamp && timestamp.trim()) {
      finalTimestamp = timestamp;
      console.log(`⏰ [TIMBRATURA FORZATA] Usando timestamp personalizzato: ${finalTimestamp}`);
    } else {
      const now = new Date();
      finalTimestamp = new Date(now.getTime() - (now.getTimezoneOffset() * 60000)).toISOString().slice(0, -1);
      console.log(`⏰ [TIMBRATURA FORZATA] Usando timestamp corrente: ${finalTimestamp}`);
    }
    
    // Crea record di timbratura forzata
    db.run(`INSERT INTO attendance_records 
      (employeeId, workSiteId, timestamp, type, deviceInfo, latitude, longitude, isForced, forcedByAdminId, notes) 
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        employeeId,
        workSiteId,
        finalTimestamp,
        type,
        deviceInfo,
        0.0, // Latitude 0 per timbrature forzate
        0.0, // Longitude 0 per timbrature forzate
        1,   // isForced = true
        adminId,
        notes && notes.trim() ? notes.trim() : null
      ],
      async function(err) {
        if (err) {
          console.error(`❌ [TIMBRATURA FORZATA] Errore inserimento:`, err.message);
          res.status(500).json({ error: err.message });
          return;
        }
        
        console.log(`✅ [TIMBRATURA FORZATA] Registrata con successo - Record ID: ${this.lastID}`);
        console.log(`   📋 DeviceInfo: ${deviceInfo}`);
        
        // 🔍 AUDIT LOG: Registra l'azione di timbratura forzata
        db.get('SELECT name FROM employees WHERE id = ?', [employeeId], (err, employee) => {
          if (!err && employee) {
            logAuditAction(
              adminId,
              type === 'in' ? 'FORCE_IN' : 'FORCE_OUT',
              'ATTENDANCE',
              this.lastID,
              employee.name,
              null,
              {
                employeeId,
                employeeName: employee.name,
                workSiteId,
                timestamp: finalTimestamp,
                type,
                notes: notes || null
              },
              `Timbratura forzata ${type.toUpperCase()} per ${employee.name}${notes ? ` - ${notes}` : ''}`,
              req.ip || req.connection.remoteAddress
            );
          }
        });
        
        // Aggiorna il report Excel
        try {
          await updateExcelReport();
          console.log(`📊 [TIMBRATURA FORZATA] Report Excel aggiornato`);
          res.json({ success: true, message: 'Forced attendance recorded' });
        } catch (error) {
          console.error('⚠️  [TIMBRATURA FORZATA] Errore aggiornamento report Excel:', error.message);
          res.json({ success: true, message: 'Forced attendance recorded' });
        }
      });
  });
});

// PUT endpoint per modificare una timbratura esistente
app.put('/api/attendance/:id', (req, res) => {
  const { id } = req.params;
  const { timestamp, workSiteId, notes, adminId } = req.body;
  
  console.log(`✏️ [MODIFICA TIMBRATURA] Richiesta modifica record ID: ${id}`);
  console.log(`   👨‍💼 Admin ID: ${adminId}`);
  console.log(`   ⏰ Nuovo timestamp: ${timestamp || 'non modificato'}`);
  console.log(`   🏗️  Nuovo cantiere: ${workSiteId || 'non modificato'}`);
  console.log(`   📝 Nuove note: ${notes || 'non modificate'}`);
  
  if (!adminId) {
    console.error(`❌ [MODIFICA TIMBRATURA] Admin ID mancante`);
    res.status(400).json({ error: 'Admin ID required' });
    return;
  }
  
  // Verifica che l'admin esista ed sia effettivamente admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err) {
      console.error(`❌ [MODIFICA TIMBRATURA] Errore verifica admin:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!admin) {
      console.error(`⛔ [MODIFICA TIMBRATURA] Admin ID ${adminId} non autorizzato`);
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    console.log(`✅ [MODIFICA TIMBRATURA] Admin verificato: ${admin.name}`);
    
    // Recupera il record esistente
    db.get('SELECT * FROM attendance_records WHERE id = ?', [id], (err, record) => {
      if (err) {
        console.error(`❌ [MODIFICA TIMBRATURA] Errore recupero record:`, err.message);
        res.status(500).json({ error: err.message });
        return;
      }
      
      if (!record) {
        console.error(`❌ [MODIFICA TIMBRATURA] Record ID ${id} non trovato`);
        res.status(404).json({ error: 'Attendance record not found' });
        return;
      }
      
      // Prepara i valori da aggiornare (usa valori esistenti se non forniti)
      const newTimestamp = timestamp || record.timestamp;
      const newWorkSiteId = workSiteId || record.workSiteId;
      const newNotes = notes !== undefined ? notes : record.notes;
      
      // Aggiungi info dell'admin al deviceInfo
      let deviceInfo = record.deviceInfo || '';
      if (!deviceInfo.includes('Modificato da')) {
        deviceInfo += ` | Modificato da ${admin.name}`;
      }
      
      // Aggiorna il record
      db.run(`UPDATE attendance_records 
        SET timestamp = ?, workSiteId = ?, notes = ?, deviceInfo = ?
        WHERE id = ?`,
        [newTimestamp, newWorkSiteId, newNotes, deviceInfo, id],
        async function(err) {
          if (err) {
            console.error(`❌ [MODIFICA TIMBRATURA] Errore aggiornamento:`, err.message);
            res.status(500).json({ error: err.message });
            return;
          }
          
          console.log(`✅ [MODIFICA TIMBRATURA] Record ID ${id} aggiornato con successo`);
          console.log(`   📋 DeviceInfo aggiornato: ${deviceInfo}`);
          
          // 🔍 AUDIT LOG: Registra la modifica
          db.get('SELECT name FROM employees WHERE id = ?', [record.employeeId], (err, employee) => {
            if (!err && employee) {
              logAuditAction(
                adminId,
                'EDIT_ATTENDANCE',
                'ATTENDANCE',
                id,
                employee.name,
                {
                  timestamp: record.timestamp,
                  workSiteId: record.workSiteId,
                  notes: record.notes
                },
                {
                  timestamp: newTimestamp,
                  workSiteId: newWorkSiteId,
                  notes: newNotes
                },
                `Modificata timbratura per ${employee.name}`,
                req.ip || req.connection.remoteAddress
              );
            }
          });
          
          // Aggiorna il report Excel
          try {
            await updateExcelReport();
            console.log(`📊 [MODIFICA TIMBRATURA] Report Excel aggiornato`);
            res.json({ success: true, message: 'Attendance record updated' });
          } catch (error) {
            console.error('⚠️  [MODIFICA TIMBRATURA] Errore aggiornamento report Excel:', error.message);
            res.json({ success: true, message: 'Attendance record updated' });
          }
        });
    });
  });
});

// DELETE endpoint per eliminare una timbratura esistente
app.delete('/api/attendance/:id', (req, res) => {
  const { id } = req.params;
  const { adminId, deleteOutToo } = req.body;
  
  console.log(`🗑️ [ELIMINA TIMBRATURA] Richiesta eliminazione record ID: ${id}`);
  console.log(`   👨‍💼 Admin ID: ${adminId}`);
  console.log(`   🔗 Elimina OUT associato: ${deleteOutToo ? 'Sì' : 'No'}`);
  
  if (!adminId) {
    console.error(`❌ [ELIMINA TIMBRATURA] Admin ID mancante`);
    res.status(400).json({ error: 'Admin ID required' });
    return;
  }
  
  // Verifica che l'admin esista ed sia effettivamente admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err) {
      console.error(`❌ [ELIMINA TIMBRATURA] Errore verifica admin:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    if (!admin) {
      console.error(`⛔ [ELIMINA TIMBRATURA] Admin ID ${adminId} non autorizzato`);
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    console.log(`✅ [ELIMINA TIMBRATURA] Admin verificato: ${admin.name}`);
    
    // Recupera il record per verificare tipo e ottenere info
    db.get('SELECT * FROM attendance_records WHERE id = ?', [id], (err, record) => {
      if (err) {
        console.error(`❌ [ELIMINA TIMBRATURA] Errore recupero record:`, err.message);
        res.status(500).json({ error: err.message });
        return;
      }
      
      if (!record) {
        console.error(`❌ [ELIMINA TIMBRATURA] Record ID ${id} non trovato`);
        res.status(404).json({ error: 'Attendance record not found' });
        return;
      }
      
      console.log(`📋 [ELIMINA TIMBRATURA] Record trovato: Tipo=${record.type}, Dipendente=${record.employeeId}`);
      
      // Se è un IN e deleteOutToo è true, cerca e elimina anche l'OUT corrispondente
      if (record.type === 'in' && deleteOutToo) {
        // Prima cerca OUT DOPO questo IN (caso normale)
        db.get(`SELECT id FROM attendance_records 
          WHERE employeeId = ? AND type = 'out' AND timestamp > ? 
          ORDER BY timestamp ASC LIMIT 1`,
          [record.employeeId, record.timestamp],
          (err, outAfter) => {
            if (err) {
              console.error(`⚠️  [ELIMINA TIMBRATURA] Errore ricerca OUT:`, err.message);
              return;
            }
            
            if (outAfter) {
              // OUT trovato DOPO l'IN (caso normale)
              db.run('DELETE FROM attendance_records WHERE id = ?', [outAfter.id], function(err) {
                if (err) {
                  console.error(`⚠️  [ELIMINA TIMBRATURA] Errore eliminazione OUT:`, err.message);
                } else {
                  console.log(`🗑️ [ELIMINA TIMBRATURA] Eliminato OUT [ID: ${outAfter.id}] successivo`);
                }
              });
            } else {
              // Nessun OUT dopo, cerca il più vicino in assoluto (gestisce timestamp invertiti)
              db.get(`SELECT id, timestamp FROM attendance_records 
                WHERE employeeId = ? AND type = 'out'
                ORDER BY ABS(CAST((julianday(timestamp) - julianday(?)) * 86400 AS INTEGER)) ASC 
                LIMIT 1`,
                [record.employeeId, record.timestamp],
                (err, nearestOut) => {
                  if (err) {
                    console.error(`⚠️  [ELIMINA TIMBRATURA] Errore ricerca OUT più vicino:`, err.message);
                    return;
                  }
                  
                  if (nearestOut) {
                    const timeDiff = Math.abs((new Date(nearestOut.timestamp) - new Date(record.timestamp)) / 1000 / 60);
                    console.log(`⚠️  [ELIMINA TIMBRATURA] OUT più vicino ha timestamp ${nearestOut.timestamp < record.timestamp ? 'PRECEDENTE' : 'SUCCESSIVO'}`);
                    console.log(`   Differenza: ${timeDiff.toFixed(0)} minuti`);
                    
                    // Elimina solo se la differenza è ragionevole (< 24 ore)
                    if (timeDiff < 1440) {
                      db.run('DELETE FROM attendance_records WHERE id = ?', [nearestOut.id], function(err) {
                        if (err) {
                          console.error(`⚠️  [ELIMINA TIMBRATURA] Errore eliminazione OUT:`, err.message);
                        } else {
                          console.log(`🗑️ [ELIMINA TIMBRATURA] Eliminato OUT [ID: ${nearestOut.id}] più vicino`);
                        }
                      });
                    } else {
                      console.log(`⚠️  [ELIMINA TIMBRATURA] OUT troppo distante (${timeDiff.toFixed(0)} min), non eliminato`);
                    }
                  } else {
                    console.log(`⚠️  [ELIMINA TIMBRATURA] Nessun OUT trovato per dipendente ${record.employeeId}`);
                  }
                }
              );
            }
          }
        );
      }
      
      // Elimina il record principale
      db.run('DELETE FROM attendance_records WHERE id = ?', [id], async function(err) {
        if (err) {
          console.error(`❌ [ELIMINA TIMBRATURA] Errore eliminazione:`, err.message);
          res.status(500).json({ error: err.message });
          return;
        }
        
        console.log(`✅ [ELIMINA TIMBRATURA] Record ID ${id} eliminato con successo`);
        
        // 🔍 AUDIT LOG: Registra l'eliminazione
        db.get('SELECT name FROM employees WHERE id = ?', [record.employeeId], (err, employee) => {
          if (!err && employee) {
            logAuditAction(
              adminId,
              'DELETE_ATTENDANCE',
              'ATTENDANCE',
              id,
              employee.name,
              {
                employeeId: record.employeeId,
                employeeName: employee.name,
                timestamp: record.timestamp,
                type: record.type,
                workSiteId: record.workSiteId,
                notes: record.notes
              },
              null,
              `Eliminata timbratura ${record.type.toUpperCase()} per ${employee.name}${deleteOutToo ? ' (con OUT associato)' : ''}`,
              req.ip || req.connection.remoteAddress
            );
          }
        });
        
        // Aggiorna il report Excel
        try {
          await updateExcelReport();
          console.log(`📊 [ELIMINA TIMBRATURA] Report Excel aggiornato`);
          res.json({ success: true, message: 'Attendance record deleted' });
        } catch (error) {
          console.error('⚠️  [ELIMINA TIMBRATURA] Errore aggiornamento report Excel:', error.message);
          res.json({ success: true, message: 'Attendance record deleted' });
        }
      });
    });
  });
});

// ==================== AUDIT LOG ENDPOINT ====================

/**
 * GET /api/audit-log
 * Recupera log delle operazioni amministrative
 * Query params:
 * - adminId: Filtra per ID amministratore
 * - startDate: Data inizio (YYYY-MM-DD)
 * - endDate: Data fine (YYYY-MM-DD)
 * - action: Filtra per tipo azione
 * - targetType: Filtra per tipo entità
 * - limit: Numero massimo risultati (default 1000)
 */
app.get('/api/audit-log', (req, res) => {
  const { adminId, startDate, endDate, action, targetType, limit = 1000 } = req.query;
  
  console.log(`📋 [AUDIT LOG] Richiesta log audit`);
  console.log(`   👨‍💼 Admin ID: ${adminId || 'Tutti'}`);
  console.log(`   📅 Periodo: ${startDate || 'Sempre'} → ${endDate || 'Ora'}`);
  console.log(`   🎯 Azione: ${action || 'Tutte'}`);
  console.log(`   📦 Tipo target: ${targetType || 'Tutti'}`);
  
  let query = `
    SELECT 
      al.*,
      e.name as adminName,
      e.email as adminEmail
    FROM audit_log al
    LEFT JOIN employees e ON al.adminId = e.id
    WHERE 1=1
  `;
  
  const params = [];
  
  if (adminId) {
    query += ' AND al.adminId = ?';
    params.push(adminId);
  }
  
  if (startDate) {
    query += ' AND DATE(al.timestamp) >= DATE(?)';
    params.push(startDate);
  }
  
  if (endDate) {
    query += ' AND DATE(al.timestamp) <= DATE(?)';
    params.push(endDate);
  }
  
  if (action) {
    query += ' AND al.action = ?';
    params.push(action);
  }
  
  if (targetType) {
    query += ' AND al.targetType = ?';
    params.push(targetType);
  }
  
  query += ' ORDER BY al.timestamp DESC LIMIT ?';
  params.push(parseInt(limit));
  
  db.all(query, params, (err, rows) => {
    if (err) {
      console.error(`❌ [AUDIT LOG] Errore query:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    console.log(`✅ [AUDIT LOG] Trovati ${rows.length} record`);
    
    // Parse JSON fields
    const parsedRows = rows.map(row => ({
      ...row,
      oldValue: row.oldValue ? JSON.parse(row.oldValue) : null,
      newValue: row.newValue ? JSON.parse(row.newValue) : null
    }));
    
    res.json(parsedRows);
  });
});

/**
 * GET /api/audit-log/summary
 * Riepilogo statistiche audit log per amministratore
 */
app.get('/api/audit-log/summary', (req, res) => {
  const { adminId, startDate, endDate } = req.query;
  
  console.log(`📊 [AUDIT SUMMARY] Richiesta riepilogo per admin ${adminId}`);
  
  let query = `
    SELECT 
      action,
      COUNT(*) as count
    FROM audit_log
    WHERE 1=1
  `;
  
  const params = [];
  
  if (adminId) {
    query += ' AND adminId = ?';
    params.push(adminId);
  }
  
  if (startDate) {
    query += ' AND DATE(timestamp) >= DATE(?)';
    params.push(startDate);
  }
  
  if (endDate) {
    query += ' AND DATE(timestamp) <= DATE(?)';
    params.push(endDate);
  }
  
  query += ' GROUP BY action ORDER BY count DESC';
  
  db.all(query, params, (err, rows) => {
    if (err) {
      console.error(`❌ [AUDIT SUMMARY] Errore:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    console.log(`✅ [AUDIT SUMMARY] Riepilogo generato: ${rows.length} tipi di azioni`);
    res.json(rows);
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
  const { name, username, email, password, isAdmin, role, allowNightShift } = req.body;
  
  // Validazione username (obbligatorio)
  if (!username || username.trim().length === 0) {
    console.error(`❌ [DIPENDENTE] Username obbligatorio`);
    return res.status(400).json({ error: 'Username obbligatorio' });
  }
  
  // Determina ruolo (priorità: role > isAdmin)
  let employeeRole = 'employee'; // Default
  if (role) {
    // Valida ruolo
    if (['admin', 'employee', 'foreman'].includes(role)) {
      employeeRole = role;
    } else {
      console.error(`❌ [DIPENDENTE] Ruolo non valido: ${role}`);
      return res.status(400).json({ error: 'Ruolo non valido. Usare: admin, employee, foreman' });
    }
  } else if (isAdmin === 1 || isAdmin === true) {
    employeeRole = 'admin';
  }
  
  // Valida email obbligatoria per admin
  if (employeeRole === 'admin' && (!email || email.trim().length === 0)) {
    console.error(`❌ [DIPENDENTE] Email obbligatoria per amministratori`);
    return res.status(400).json({ error: 'Email obbligatoria per amministratori (per report)' });
  }
  
  const isAdminValue = employeeRole === 'admin' ? 1 : 0;
  const allowNightShiftValue = allowNightShift === 1 || allowNightShift === true ? 1 : 0;
  
  console.log(`➕ [DIPENDENTE] Creazione nuovo dipendente`);
  console.log(`   👤 Nome: ${name}`);
  console.log(`   🆔 Username: ${username}`);
  console.log(`   � Email: ${email || '(non fornita)'}`);
  console.log(`   👥 Ruolo: ${employeeRole}`);
  console.log(`   🌙 Turni notturni: ${allowNightShiftValue ? 'Sì' : 'No'}`);
  
  // Query con username e role
  db.run(
    'INSERT INTO employees (name, username, email, password, isAdmin, role, allowNightShift) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [name, username, email || null, password, isAdminValue, employeeRole, allowNightShiftValue],
    function(err) {
      if (err) {
        if (err.message.includes('UNIQUE constraint failed: employees.username')) {
          console.error(`❌ [DIPENDENTE] Username già esistente: ${username}`);
          res.status(400).json({ error: 'Username già esistente' });
        } else {
          console.error(`❌ [DIPENDENTE] Errore creazione:`, err.message);
          res.status(500).json({ error: err.message });
        }
        return;
      }
      console.log(`✅ [DIPENDENTE] Creato con successo - ID: ${this.lastID}`);
      res.json({ id: this.lastID });
    }
  );
});

app.put('/api/employees/:id', (req, res) => {
  const { name, username, email, password, isAdmin, role, allowNightShift } = req.body;
  
  // Validazione username (obbligatorio)
  if (!username || username.trim().length === 0) {
    console.error(`❌ [DIPENDENTE] Username obbligatorio`);
    return res.status(400).json({ error: 'Username obbligatorio' });
  }
  
  // Determina ruolo (priorità: role > isAdmin)
  let employeeRole = 'employee'; // Default
  if (role) {
    // Valida ruolo
    if (['admin', 'employee', 'foreman'].includes(role)) {
      employeeRole = role;
    } else {
      console.error(`❌ [DIPENDENTE] Ruolo non valido: ${role}`);
      return res.status(400).json({ error: 'Ruolo non valido. Usare: admin, employee, foreman' });
    }
  } else if (isAdmin === 1 || isAdmin === true) {
    employeeRole = 'admin';
  }
  
  // Valida email obbligatoria per admin
  if (employeeRole === 'admin' && (!email || email.trim().length === 0)) {
    console.error(`❌ [DIPENDENTE] Email obbligatoria per amministratori`);
    return res.status(400).json({ error: 'Email obbligatoria per amministratori (per report)' });
  }
  
  const isAdminValue = employeeRole === 'admin' ? 1 : 0;
  const allowNightShiftValue = allowNightShift === 1 || allowNightShift === true ? 1 : 0;
  
  console.log(`✏️  [DIPENDENTE] Aggiornamento dipendente ID: ${req.params.id}`);
  console.log(`   👤 Nome: ${name}`);
  console.log(`   🆔 Username: ${username}`);
  console.log(`   � Email: ${email || '(non fornita)'}`);
  console.log(`   👥 Ruolo: ${employeeRole}`);
  console.log(`   🌙 Turni notturni: ${allowNightShiftValue ? 'Sì' : 'No'}`);
  console.log(`   🔑 Password: ${password && password.length > 0 ? 'Aggiornata' : 'Non modificata'}`);
  
  // Se la password è fornita, aggiorniamo anche quella
  let query, params;
  if (password && password.length > 0) {
    query = 'UPDATE employees SET name = ?, username = ?, email = ?, password = ?, isAdmin = ?, role = ?, allowNightShift = ? WHERE id = ?';
    params = [name, username, email || null, password, isAdminValue, employeeRole, allowNightShiftValue, req.params.id];
  } else {
    query = 'UPDATE employees SET name = ?, username = ?, email = ?, isAdmin = ?, role = ?, allowNightShift = ? WHERE id = ?';
    params = [name, username, email || null, isAdminValue, employeeRole, allowNightShiftValue, req.params.id];
  }
  
  db.run(query, params, function(err) {
    if (err) {
      if (err.message.includes('UNIQUE constraint failed: employees.username')) {
        console.error(`❌ [DIPENDENTE] Username già esistente: ${username}`);
        res.status(400).json({ error: 'Username già esistente' });
      } else {
        console.error(`❌ [DIPENDENTE] Errore aggiornamento:`, err.message);
        res.status(500).json({ error: err.message });
      }
      return;
    }
    console.log(`✅ [DIPENDENTE] Aggiornato con successo - Righe modificate: ${this.changes}`);
    res.json({ success: true, changes: this.changes });
  });
});

app.delete('/api/employees/:id', (req, res) => {
  const employeeId = req.params.id;
  
  console.log(`🗑️  [DIPENDENTE] Richiesta eliminazione dipendente ID: ${employeeId}`);
  
  // Step 1: Verifica se il dipendente ha timbrature
  db.get('SELECT COUNT(*) as count FROM attendance_records WHERE employeeId = ?', 
    [employeeId], 
    (err, result) => {
      if (err) {
        console.error(`❌ [DIPENDENTE] Errore verifica timbrature:`, err.message);
        res.status(500).json({ error: err.message });
        return;
      }
      
      const hasAttendance = result.count > 0;
      
      if (hasAttendance) {
        // SOFT DELETE: Dipendente con timbrature → marca come inattivo per preservare storico
        console.log(`🔒 [DIPENDENTE] SOFT DELETE - Dipendente ${employeeId} ha ${result.count} timbrature`);
        
        db.run('UPDATE employees SET isActive = 0, deletedAt = ? WHERE id = ?',
          [new Date().toISOString(), employeeId],
          function(err) {
            if (err) {
              console.error(`❌ [DIPENDENTE] Errore soft delete:`, err.message);
              res.status(500).json({ error: err.message });
              return;
            }
            console.log(`✅ [DIPENDENTE] Soft delete completato - Dipendente disattivato (${result.count} timbrature preservate)`);
            res.json({ 
              success: true, 
              deleted: false, // Soft delete
              message: `Dipendente disattivato (${result.count} timbrature preservate)` 
            });
          }
        );
      } else {
        // HARD DELETE: Dipendente senza timbrature → elimina completamente
        console.log(`🗑️  [DIPENDENTE] HARD DELETE - Dipendente ${employeeId} senza timbrature`);
        
        db.run('DELETE FROM employees WHERE id = ?', [employeeId], function(err) {
          if (err) {
            console.error(`❌ [DIPENDENTE] Errore hard delete:`, err.message);
            res.status(500).json({ error: err.message });
            return;
          }
          console.log(`✅ [DIPENDENTE] Hard delete completato - Dipendente eliminato definitivamente`);
          res.json({ 
            success: true, 
            deleted: true, // Hard delete
            message: 'Dipendente eliminato completamente (nessuna timbratura)' 
          });
        });
      }
    }
  );
});

// ==================== NUOVO REPORT TIMBRATURE PROFESSIONALE ====================
const generateAttendanceReport = async (filters = {}) => {
  const workbook = new ExcelJS.Workbook();

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
        COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
        COALESCE(e.isActive, 0) as employeeIsActive,
        ws.name as workSiteName
      FROM attendance_records ar
      LEFT JOIN employees e ON ar.employeeId = e.id
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

    db.all(query, params, async (err, records) => {
      if (err) {
        reject(err);
        return;
      }

      if (records.length === 0) {
        reject(new Error('Nessuna timbratura trovata per i filtri selezionati'));
        return;
      }

      // ==================== CALCOLO STATISTICHE ====================
      const stats = {
        totalRecords: records.length,
        totalIn: records.filter(r => r.type === 'in').length,
        totalOut: records.filter(r => r.type === 'out').length,
        uniqueEmployees: [...new Set(records.map(r => r.employeeId))],
        uniqueWorkSites: [...new Set(records.map(r => r.workSiteId).filter(id => id !== null))],
        uniqueDates: [...new Set(records.map(r => new Date(r.timestamp).toISOString().split('T')[0]))],
        minDate: new Date(Math.min(...records.map(r => new Date(r.timestamp)))),
        maxDate: new Date(Math.max(...records.map(r => new Date(r.timestamp))))
      };

      // Calcola ore lavorate per dipendente
      const employeeStats = {};
      stats.uniqueEmployees.forEach(empId => {
        const empRecords = records.filter(r => r.employeeId === empId);
        const empName = empRecords[0].employeeName;
        const { workSessions, dailySessions } = calculateWorkedHours(empRecords);
        
        let totalHours = 0;
        Object.values(workSessions).forEach(hours => totalHours += hours);
        
        // Conta SOLO i giorni con sessioni valide (senza errori)
        let daysWorked = 0;
        Object.keys(dailySessions).forEach(dateKey => {
          const hasValidSessions = dailySessions[dateKey].some(session => !session.hasError);
          if (hasValidSessions) {
            daysWorked++;
          }
        });
        
        const workSitesList = [...new Set(empRecords.map(r => r.workSiteName).filter(n => n))];
        
        employeeStats[empId] = {
          name: empName,
          totalRecords: empRecords.length,
          totalHours: totalHours,
          workSites: workSitesList,
          daysWorked: daysWorked,
          firstRecord: new Date(Math.min(...empRecords.map(r => new Date(r.timestamp)))),
          lastRecord: new Date(Math.max(...empRecords.map(r => new Date(r.timestamp)))),
          avgHoursPerDay: daysWorked > 0 ? totalHours / daysWorked : 0
        };
      });

      // Calcola statistiche per cantiere
      const workSiteStats = {};
      stats.uniqueWorkSites.forEach(wsId => {
        const wsRecords = records.filter(r => r.workSiteId === wsId);
        const wsName = wsRecords[0]?.workSiteName || 'Non specificato';
        const { workSessions, dailySessions } = calculateWorkedHours(wsRecords);
        
        let totalHours = 0;
        Object.values(workSessions).forEach(hours => totalHours += hours);
        
        // Conta SOLO i giorni con sessioni valide (senza errori)
        let daysActive = 0;
        Object.keys(dailySessions).forEach(dateKey => {
          const hasValidSessions = dailySessions[dateKey].some(session => !session.hasError);
          if (hasValidSessions) {
            daysActive++;
          }
        });
        
        const empList = [...new Set(wsRecords.map(r => r.employeeId))];
        
        workSiteStats[wsId] = {
          name: wsName,
          totalRecords: wsRecords.length,
          totalHours: totalHours,
          uniqueEmployees: empList.length,
          daysActive: daysActive
        };
      });

      // Ordina dipendenti per ore (per Top 3)
      const sortedEmployees = Object.entries(employeeStats)
        .sort(([, a], [, b]) => b.totalHours - a.totalHours);

      // ==================== FOGLIO 1: RIEPILOGO GENERALE ====================
      const summarySheet = workbook.addWorksheet('Riepilogo Generale');
      
      // Stili
      const titleStyle = {
        font: { bold: true, size: 16, color: { argb: 'FF1F4E78' } },
        alignment: { vertical: 'middle', horizontal: 'center' }
      };
      
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
      
      const statStyle = {
        font: { size: 11 },
        alignment: { vertical: 'middle', horizontal: 'left' },
        border: {
          top: { style: 'thin' },
          left: { style: 'thin' },
          bottom: { style: 'thin' },
          right: { style: 'thin' }
        }
      };

      const totalStyle = {
        font: { bold: true, size: 12 },
        fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } },
        alignment: { vertical: 'middle', horizontal: 'left' },
        border: {
          top: { style: 'medium' },
          left: { style: 'thin' },
          bottom: { style: 'medium' },
          right: { style: 'thin' }
        }
      };
      
      // Titolo
      summarySheet.mergeCells('A1:D1');
      const titleCell = summarySheet.getCell('A1');
      titleCell.value = 'REPORT GENERALE TIMBRATURE';
      titleCell.style = titleStyle;
      
      // Periodo
      summarySheet.mergeCells('A2:D2');
      const periodCell = summarySheet.getCell('A2');
      periodCell.value = `Periodo: ${stats.minDate.toLocaleDateString('it-IT')} - ${stats.maxDate.toLocaleDateString('it-IT')}`;
      periodCell.alignment = { horizontal: 'center' };
      periodCell.font = { italic: true, size: 11 };
      
      summarySheet.addRow([]);
      
      // STATISTICHE GENERALI
      summarySheet.addRow(['STATISTICHE GENERALI']).font = { bold: true, size: 12, color: { argb: 'FF1F4E78' } };
      summarySheet.addRow([]);
      
      summarySheet.columns = [
        { key: 'label', width: 35 },
        { key: 'value', width: 20 }
      ];
      
      const statsData = [
        ['📊 Totale Timbrature', stats.totalRecords],
        ['✅ Ingressi (IN)', stats.totalIn],
        ['❌ Uscite (OUT)', stats.totalOut],
        ['👥 Dipendenti Coinvolti', stats.uniqueEmployees.length],
        ['🏗️ Cantieri Coinvolti', stats.uniqueWorkSites.length],
        ['📅 Giorni con Timbrature', stats.uniqueDates.length]
      ];
      
      statsData.forEach(([label, value]) => {
        const row = summarySheet.addRow([label, value]);
        row.eachCell(cell => {
          cell.style = statStyle;
          if (cell.col === 2) {
            cell.alignment = { horizontal: 'center' };
            cell.font = { bold: true };
          }
        });
      });
      
      summarySheet.addRow([]);
      summarySheet.addRow([]);
      
      // TABELLA ORE PER DIPENDENTE
      summarySheet.addRow(['ORE LAVORATE PER DIPENDENTE']).font = { bold: true, size: 12, color: { argb: 'FF1F4E78' } };
      summarySheet.addRow([]);
      
      summarySheet.columns = [
        { key: 'employee', width: 30 },
        { key: 'hours', width: 15 },
        { key: 'days', width: 15 },
        { key: 'avg', width: 20 }
      ];
      
      const empHeaderRow = summarySheet.addRow(['Dipendente', 'Ore Totali', 'Giorni', 'Media Ore/Giorno']);
      empHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      let grandTotalHours = 0;
      sortedEmployees.forEach(([empId, stat]) => {
        grandTotalHours += stat.totalHours;
        const formatted = formatHoursMinutes(stat.totalHours);
        const avgFormatted = formatHoursMinutes(stat.avgHoursPerDay);
        
        const row = summarySheet.addRow([
          stat.name,
          formatted.formatted,
          stat.daysWorked,
          avgFormatted.formatted
        ]);
        
        row.eachCell((cell, colNumber) => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
          if (colNumber >= 2) {
            cell.alignment = { horizontal: 'center' };
          }
        });
      });
      
      // TOTALE GENERALE
      summarySheet.addRow([]);
      const totalFormatted = formatHoursMinutes(grandTotalHours);
      const totalRow = summarySheet.addRow(['TOTALE GENERALE', totalFormatted.formatted, '', '']);
      totalRow.eachCell(cell => cell.style = totalStyle);

      // ==================== FOGLIO 2: DETTAGLIO GIORNALIERO ====================
      const dailySheet = workbook.addWorksheet('Dettaglio Giornaliero');
      
      dailySheet.columns = [
        { key: 'date', width: 15 },
        { key: 'employee', width: 25 },
        { key: 'worksite', width: 30 },
        { key: 'timeIn', width: 12 },
        { key: 'timeOut', width: 12 },
        { key: 'hours', width: 15 }
      ];
      
      // Titolo
      dailySheet.mergeCells('A1:F1');
      const dailyTitleCell = dailySheet.getCell('A1');
      dailyTitleCell.value = 'DETTAGLIO GIORNALIERO SESSIONI LAVORO';
      dailyTitleCell.style = titleStyle;
      dailySheet.addRow([]);
      
      const dailyHeaderRow = dailySheet.addRow(['Data', 'Dipendente', 'Cantiere', 'Ingresso', 'Uscita', 'Ore Lavorate']);
      dailyHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      // Raggruppa per data
      const recordsByDate = {};
      records.forEach(rec => {
        const dateKey = new Date(rec.timestamp).toISOString().split('T')[0];
        if (!recordsByDate[dateKey]) recordsByDate[dateKey] = [];
        recordsByDate[dateKey].push(rec);
      });
      
      // Ordina date
      const sortedDates = Object.keys(recordsByDate).sort().reverse();
      
      sortedDates.forEach(dateKey => {
        const dateRecords = recordsByDate[dateKey];
        const { dailySessions } = calculateWorkedHours(dateRecords);
        
        let dailyTotal = 0;
        
        Object.entries(dailySessions).forEach(([employeeName, sessions]) => {
          sessions.forEach(session => {
            const row = dailySheet.addRow([
              new Date(dateKey).toLocaleDateString('it-IT'),
              employeeName,
              session.workSite,
              new Date(session.timeIn).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
              new Date(session.timeOut).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
              formatHoursMinutes(session.hours).formatted
            ]);
            
            dailyTotal += session.hours;
            
            row.eachCell((cell, colNumber) => {
              cell.border = {
                top: { style: 'thin' },
                left: { style: 'thin' },
                bottom: { style: 'thin' },
                right: { style: 'thin' }
              };
              if (colNumber >= 4) {
                cell.alignment = { horizontal: 'center' };
              }
            });
          });
        });
        
        // Totale giornaliero
        const dayTotalRow = dailySheet.addRow([
          '',
          '',
          '',
          '',
          'Totale Giorno:',
          formatHoursMinutes(dailyTotal).formatted
        ]);
        dayTotalRow.eachCell(cell => {
          cell.font = { bold: true };
          cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCE6F1' } };
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
        });
        
        dailySheet.addRow([]); // Riga vuota tra giorni
      });

      // ==================== FOGLIO 3: RIEPILOGO DIPENDENTI ====================
      const employeesSheet = workbook.addWorksheet('Riepilogo Dipendenti');
      
      employeesSheet.columns = [
        { key: 'rank', width: 8 },
        { key: 'name', width: 30 },
        { key: 'hours', width: 15 },
        { key: 'days', width: 12 },
        { key: 'avg', width: 18 },
        { key: 'worksites', width: 35 }
      ];
      
      // Titolo
      employeesSheet.mergeCells('A1:F1');
      const empTitleCell = employeesSheet.getCell('A1');
      empTitleCell.value = 'RIEPILOGO DIPENDENTI - CLASSIFICA ORE LAVORATE';
      empTitleCell.style = titleStyle;
      employeesSheet.addRow([]);
      
      const empSheetHeaderRow = employeesSheet.addRow(['#', 'Dipendente', 'Ore Totali', 'Giorni', 'Media/Giorno', 'Cantieri Visitati']);
      empSheetHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      sortedEmployees.forEach(([empId, stat], index) => {
        const formatted = formatHoursMinutes(stat.totalHours);
        const avgFormatted = formatHoursMinutes(stat.avgHoursPerDay);
        
        const row = employeesSheet.addRow([
          index + 1,
          stat.name,
          formatted.formatted,
          stat.daysWorked,
          avgFormatted.formatted,
          stat.workSites.join(', ')
        ]);
        
        // Top 3 colorati
        if (index === 0) {
          row.eachCell(cell => {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFD700' } }; // Oro
            cell.font = { bold: true };
          });
        } else if (index === 1) {
          row.eachCell(cell => {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFC0C0C0' } }; // Argento
            cell.font = { bold: true };
          });
        } else if (index === 2) {
          row.eachCell(cell => {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCD7F32' } }; // Bronzo
            cell.font = { bold: true };
          });
        }
        
        row.eachCell((cell, colNumber) => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
          if (colNumber === 1 || colNumber >= 3 && colNumber <= 5) {
            cell.alignment = { horizontal: 'center' };
          }
        });
      });

      // ==================== FOGLIO 4: RIEPILOGO CANTIERI ====================
      const worksitesSheet = workbook.addWorksheet('Riepilogo Cantieri');
      
      worksitesSheet.columns = [
        { key: 'name', width: 35 },
        { key: 'employees', width: 18 },
        { key: 'days', width: 15 },
        { key: 'hours', width: 15 },
        { key: 'records', width: 18 }
      ];
      
      // Titolo
      worksitesSheet.mergeCells('A1:E1');
      const wsTitleCell = worksitesSheet.getCell('A1');
      wsTitleCell.value = 'RIEPILOGO CANTIERI';
      wsTitleCell.style = titleStyle;
      worksitesSheet.addRow([]);
      
      const wsHeaderRow = worksitesSheet.addRow(['Cantiere', 'Dipendenti Unici', 'Giorni Attività', 'Ore Totali', 'Timbrature']);
      wsHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      // Ordina cantieri per ore
      const sortedWorksites = Object.entries(workSiteStats)
        .sort(([, a], [, b]) => b.totalHours - a.totalHours);
      
      sortedWorksites.forEach(([wsId, stat]) => {
        const formatted = formatHoursMinutes(stat.totalHours);
        
        const row = worksitesSheet.addRow([
          stat.name,
          stat.uniqueEmployees,
          stat.daysActive,
          formatted.formatted,
          stat.totalRecords
        ]);
        
        row.eachCell((cell, colNumber) => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
          if (colNumber >= 2) {
            cell.alignment = { horizontal: 'center' };
          }
        });
      });

      // ==================== FOGLIO 5: TIMBRATURE COMPLETE ====================
      const detailSheet = workbook.addWorksheet('Timbrature Complete');
      
      detailSheet.columns = [
        { key: 'employeeName', width: 25 },
        { key: 'workSiteName', width: 30 },
        { key: 'type', width: 12 },
        { key: 'timestamp', width: 20 },
        { key: 'deviceInfo', width: 35 },
        { key: 'googleMaps', width: 20 }
      ];
      
      // Titolo
      detailSheet.mergeCells('A1:F1');
      const detailTitleCell = detailSheet.getCell('A1');
      detailTitleCell.value = 'LISTA COMPLETA TIMBRATURE';
      detailTitleCell.style = titleStyle;
      detailSheet.addRow([]);
      
      const detailHeaderRow = detailSheet.addRow(['Dipendente', 'Cantiere', 'Tipo', 'Data e Ora', 'Dispositivo', 'Google Maps']);
      detailHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      records.forEach(record => {
        const row = detailSheet.addRow({
          employeeName: record.employeeName,
          workSiteName: record.workSiteName || 'Non specificato',
          type: record.type === 'in' ? 'Ingresso' : 'Uscita',
          timestamp: new Date(record.timestamp).toLocaleString('it-IT'),
          deviceInfo: record.deviceInfo,
          googleMaps: (record.latitude && record.longitude) ? 'Apri in Maps' : 'N/D'
        });

        // Link Google Maps
        if (record.latitude && record.longitude) {
          const mapsUrl = `https://www.google.com/maps?q=${record.latitude},${record.longitude}`;
          const mapsCell = row.getCell('googleMaps');
          mapsCell.value = {
            text: 'Apri in Maps',
            hyperlink: mapsUrl
          };
          mapsCell.font = { color: { argb: 'FF0563C1' }, underline: true };
        }

        // Colora le righe
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
      detailSheet.autoFilter = {
        from: 'A3',
        to: 'F3'
      };

      // ==================== SALVA FILE ====================
      const reportPath = path.join(__dirname, 'reports');
      if (!fs.existsSync(reportPath)) {
        fs.mkdirSync(reportPath);
      }

      const timestamp = Date.now();
      const filePath = path.join(reportPath, `attendance_report_${timestamp}.xlsx`);
      
      await workbook.xlsx.writeFile(filePath);
      resolve(filePath);
    });
  });
};

// Funzione legacy per retrocompatibilità (deprecata)
const updateExcelReport = async (filters = {}) => {
  // Redirige alla nuova funzione professionale
  return generateAttendanceReport(filters);
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

// ==================== REPORT ORE DIPENDENTE ====================

// Funzione per calcolare le ore lavorate da coppie di timbrature
const calculateWorkedHours = (records) => {
  const workSessions = {};
  const dailySessions = {};
  
  // Ordina per timestamp
  records.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
  
  let lastIn = null;
  
  records.forEach(record => {
    if (record.type === 'in') {
      lastIn = record;
    } else if (record.type === 'out' && lastIn) {
      const timeIn = new Date(lastIn.timestamp);
      const timeOut = new Date(record.timestamp);
      
      // VALIDAZIONE CRITICA: timeOut deve essere DOPO timeIn
      if (timeOut <= timeIn) {
        // Sessione con errore - la includiamo nel report ma NON nel calcolo ore
        console.warn(`Sessione con errore temporale ignorata dal calcolo: OUT (${timeOut.toLocaleString('it-IT')}) <= IN (${timeIn.toLocaleString('it-IT')})`);
        
        const workSiteInName = lastIn.workSiteName || 'Non specificato';
        const workSiteOutName = record.workSiteName || 'Non specificato';
        const isMixedWorkSite = workSiteInName !== workSiteOutName;
        let workSiteKey = isMixedWorkSite ? `[MISTE] ${workSiteInName} → ${workSiteOutName}` : workSiteInName;
        const dateKey = timeIn.toISOString().split('T')[0];
        
        // Aggiungi alla lista giornaliera con flag di errore
        if (!dailySessions[dateKey]) {
          dailySessions[dateKey] = [];
        }
        dailySessions[dateKey].push({
          workSite: workSiteKey + ' [ERRORE: OUT prima di IN]',
          workSiteIn: workSiteInName,
          workSiteOut: workSiteOutName,
          isMixed: isMixedWorkSite,
          timeIn: timeIn,
          timeOut: timeOut,
          hours: 0,
          hasError: true,
          errorType: 'TEMPORAL'
        });
        
        lastIn = null;
        return;
      }
      
      const millisecondsWorked = timeOut - timeIn;
      const hoursWorked = millisecondsWorked / (1000 * 60 * 60);
      
      // VALIDAZIONE: sessioni superiori a 24h sono probabilmente errori nei dati
      if (hoursWorked > 24) {
        console.warn(`Sessione superiore a 24h ignorata dal calcolo: ${hoursWorked.toFixed(2)}h (${timeIn.toLocaleString('it-IT')} - ${timeOut.toLocaleString('it-IT')})`);
        
        const workSiteInName = lastIn.workSiteName || 'Non specificato';
        const workSiteOutName = record.workSiteName || 'Non specificato';
        const isMixedWorkSite = workSiteInName !== workSiteOutName;
        let workSiteKey = isMixedWorkSite ? `[MISTE] ${workSiteInName} → ${workSiteOutName}` : workSiteInName;
        const dateKey = timeIn.toISOString().split('T')[0];
        
        // Aggiungi alla lista giornaliera con flag di errore
        if (!dailySessions[dateKey]) {
          dailySessions[dateKey] = [];
        }
        dailySessions[dateKey].push({
          workSite: workSiteKey + ' [ERRORE: Sessione > 24h]',
          workSiteIn: workSiteInName,
          workSiteOut: workSiteOutName,
          isMixed: isMixedWorkSite,
          timeIn: timeIn,
          timeOut: timeOut,
          hours: hoursWorked,
          hasError: true,
          errorType: 'EXCESSIVE_HOURS'
        });
        
        lastIn = null;
        return;
      }
      
      // Gestione cantieri: IN e OUT possono essere su cantieri diversi
      const workSiteInName = lastIn.workSiteName || 'Non specificato';
      const workSiteOutName = record.workSiteName || 'Non specificato';
      const isMixedWorkSite = workSiteInName !== workSiteOutName;
      
      // Determina la chiave per il cantiere
      let workSiteKey;
      if (isMixedWorkSite) {
        workSiteKey = `[MISTE] ${workSiteInName} → ${workSiteOutName}`;
      } else {
        workSiteKey = workSiteInName;
      }
      
      const dateKey = timeIn.toISOString().split('T')[0]; // YYYY-MM-DD
      
      // Accumula per cantiere
      if (!workSessions[workSiteKey]) {
        workSessions[workSiteKey] = 0;
      }
      workSessions[workSiteKey] += hoursWorked;
      
      // Accumula per giorno
      if (!dailySessions[dateKey]) {
        dailySessions[dateKey] = [];
      }
      dailySessions[dateKey].push({
        workSite: workSiteKey,
        workSiteIn: workSiteInName,
        workSiteOut: workSiteOutName,
        isMixed: isMixedWorkSite,
        timeIn: timeIn,
        timeOut: timeOut,
        hours: hoursWorked,
        hasError: false
      });
      
      lastIn = null;
    }
  });
  
  return { workSessions, dailySessions };
};

// Funzione per formattare ore e minuti
const formatHoursMinutes = (totalHours) => {
  const hours = Math.floor(totalHours);
  const minutes = Math.round((totalHours - hours) * 60);
  return { hours, minutes, formatted: `${hours}h ${minutes}m` };
};

// Funzione per generare report ore dipendente
const generateEmployeeHoursReport = async (employeeId, startDate, endDate) => {
  const workbook = new ExcelJS.Workbook();
  
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
        COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
        ws.name as workSiteName
      FROM attendance_records ar
      LEFT JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      WHERE ar.employeeId = ?
    `;
    
    const params = [employeeId];
    
    if (startDate) {
      query += ' AND ar.timestamp >= ?';
      params.push(startDate);
    }
    
    if (endDate) {
      query += ' AND ar.timestamp <= ?';
      params.push(endDate);
    }
    
    query += ' ORDER BY ar.timestamp ASC';

    db.all(query, params, async (err, records) => {
      if (err) {
        reject(err);
        return;
      }

      if (records.length === 0) {
        reject(new Error('Nessuna timbratura trovata per il periodo selezionato'));
        return;
      }

      const employeeName = records[0].employeeName;
      const { workSessions, dailySessions } = calculateWorkedHours(records);
      
      // ==================== FOGLIO 1: RIEPILOGO ====================
      const summarySheet = workbook.addWorksheet('Riepilogo Ore');
      
      // Stili
      const titleStyle = {
        font: { bold: true, size: 16, color: { argb: 'FF1F4E78' } },
        alignment: { vertical: 'middle', horizontal: 'center' }
      };
      
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
      
      const totalStyle = {
        font: { bold: true, size: 12 },
        fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } },
        alignment: { vertical: 'middle', horizontal: 'left' },
        border: {
          top: { style: 'medium' },
          left: { style: 'thin' },
          bottom: { style: 'medium' },
          right: { style: 'thin' }
        }
      };
      
      // Titolo
      summarySheet.mergeCells('A1:D1');
      const titleCell = summarySheet.getCell('A1');
      titleCell.value = `REPORT ORE LAVORATE - ${employeeName}`;
      titleCell.style = titleStyle;
      
      // Periodo
      summarySheet.mergeCells('A2:D2');
      const periodCell = summarySheet.getCell('A2');
      const startDateStr = startDate ? new Date(startDate).toLocaleDateString('it-IT') : 'Inizio';
      const endDateStr = endDate ? new Date(endDate).toLocaleDateString('it-IT') : 'Oggi';
      periodCell.value = `Periodo: ${startDateStr} - ${endDateStr}`;
      periodCell.alignment = { horizontal: 'center' };
      periodCell.font = { italic: true, size: 11 };
      
      summarySheet.addRow([]);
      
      // Sezione: ORE PER CANTIERE
      summarySheet.addRow(['ORE LAVORATE PER CANTIERE']).font = { bold: true, size: 12 };
      summarySheet.addRow([]);
      
      summarySheet.columns = [
        { key: 'workSite', width: 35 },
        { key: 'hours', width: 12 },
        { key: 'minutes', width: 12 },
        { key: 'total', width: 20 }
      ];
      
      const headerRow = summarySheet.addRow(['Cantiere', 'Ore', 'Minuti', 'Totale']);
      headerRow.eachCell(cell => cell.style = headerStyle);
      
      let totalHours = 0;
      Object.entries(workSessions).forEach(([workSite, hours]) => {
        totalHours += hours;
        const formatted = formatHoursMinutes(hours);
        const row = summarySheet.addRow([
          workSite,
          formatted.hours,
          formatted.minutes,
          formatted.formatted
        ]);
        
        row.eachCell((cell, colNumber) => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
          if (colNumber >= 2) {
            cell.alignment = { horizontal: 'center' };
          }
        });
      });
      
      summarySheet.addRow([]);
      
      // TOTALE GENERALE
      const totalFormatted = formatHoursMinutes(totalHours);
      const totalRow = summarySheet.addRow([
        'TOTALE ORE LAVORATE',
        totalFormatted.hours,
        totalFormatted.minutes,
        totalFormatted.formatted
      ]);
      totalRow.eachCell(cell => cell.style = totalStyle);
      
      summarySheet.addRow([]);
      
      // STATISTICHE
      // Conta SOLO i giorni con sessioni valide (senza errori)
      let workDays = 0;
      Object.keys(dailySessions).forEach(dateKey => {
        const hasValidSessions = dailySessions[dateKey].some(session => !session.hasError);
        if (hasValidSessions) {
          workDays++;
        }
      });
      
      const avgHoursPerDay = workDays > 0 ? totalHours / workDays : 0;
      const avgFormatted = formatHoursMinutes(avgHoursPerDay);
      
      summarySheet.addRow(['STATISTICHE']).font = { bold: true, size: 12 };
      summarySheet.addRow([]);
      
      const statsHeaderRow = summarySheet.addRow(['Metrica', 'Valore']);
      statsHeaderRow.eachCell(cell => cell.style = headerStyle);
      
      const statsData = [
        ['Giorni di lavoro', workDays],
        ['Ore medie al giorno', avgFormatted.formatted],
        ['Ore totali periodo', totalFormatted.formatted]
      ];
      
      statsData.forEach(([label, value]) => {
        const row = summarySheet.addRow([label, value]);
        row.eachCell(cell => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
        });
        row.getCell(2).alignment = { horizontal: 'center' };
        row.getCell(1).font = { bold: true };
      });
      
      summarySheet.addRow([]);
      summarySheet.addRow([]);
      
      // LEGENDA
      summarySheet.addRow(['LEGENDA']).font = { bold: true, size: 12 };
      summarySheet.addRow([]);
      
      const legendData = [
        ['[MISTE] Cantiere A → Cantiere B', 'Sessione con ingresso e uscita in cantieri diversi'],
        ['[ERRORE: OUT prima di IN]', 'Sessione con timestamp invalido - ESCLUSA dal totale'],
        ['[ERRORE: Sessione > 24h]', 'Sessione superiore a 24 ore - ESCLUSA dal totale']
      ];
      
      legendData.forEach(([label, description]) => {
        const row = summarySheet.addRow([label, description]);
        row.getCell(1).font = { bold: true, color: { argb: 'FF0070C0' } };
        row.getCell(2).font = { italic: true };
      });
      
      // ==================== FOGLIO 2: DETTAGLIO GIORNALIERO ====================
      const detailSheet = workbook.addWorksheet('Dettaglio Giornaliero');
      
      // Aggiungi nota importante in alto
      detailSheet.mergeCells('A1:F1');
      const noteCell = detailSheet.getCell('A1');
      noteCell.value = '⚠️ IMPORTANTE: Le righe con sfondo ROSSO contengono errori e sono ESCLUSE dal totale ore. Verificare e correggere.';
      noteCell.style = {
        font: { bold: true, size: 11, color: { argb: 'FF9C0006' } },
        fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFC7CE' } },
        alignment: { vertical: 'middle', horizontal: 'center' },
        border: {
          top: { style: 'medium', color: { argb: 'FF9C0006' } },
          left: { style: 'medium', color: { argb: 'FF9C0006' } },
          bottom: { style: 'medium', color: { argb: 'FF9C0006' } },
          right: { style: 'medium', color: { argb: 'FF9C0006' } }
        }
      };
      detailSheet.getRow(1).height = 30;
      
      detailSheet.addRow([]); // Riga vuota
      
      detailSheet.columns = [
        { header: 'Data', key: 'date', width: 15 },
        { header: 'Cantiere', key: 'workSite', width: 35 },
        { header: 'Ora Ingresso', key: 'timeIn', width: 18 },
        { header: 'Ora Uscita', key: 'timeOut', width: 18 },
        { header: 'Ore Lavorate', key: 'hours', width: 15 },
        { header: 'Totale Giorno', key: 'dailyTotal', width: 15 }
      ];
      
      detailSheet.getRow(3).eachCell(cell => cell.style = headerStyle);
      
      // Ordina le date
      const sortedDates = Object.keys(dailySessions).sort();
      
      sortedDates.forEach(dateKey => {
        const sessions = dailySessions[dateKey];
        const date = new Date(dateKey).toLocaleDateString('it-IT');
        
        // Calcola totale giorno SOLO per sessioni valide (senza errori)
        let dailyTotal = 0;
        let hasErrors = false;
        sessions.forEach(session => {
          if (!session.hasError) {
            dailyTotal += session.hours;
          } else {
            hasErrors = true;
          }
        });
        
        const dailyFormatted = formatHoursMinutes(dailyTotal);
        
        sessions.forEach((session, index) => {
          const sessionFormatted = formatHoursMinutes(session.hours);
          
          // Formattazione date con gestione cambio giorno
          let timeInStr, timeOutStr;
          const inDate = session.timeIn.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit' });
          const outDate = session.timeOut.toLocaleDateString('it-IT', { day: '2-digit', month: '2-digit' });
          
          timeInStr = session.timeIn.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
          timeOutStr = session.timeOut.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
          
          // Se OUT è in un giorno diverso da IN, aggiungi la data
          if (inDate !== outDate) {
            timeOutStr = `${timeOutStr} (${outDate})`;
          }
          
          const row = detailSheet.addRow({
            date: index === 0 ? date : '',
            workSite: session.workSite,
            timeIn: timeInStr,
            timeOut: timeOutStr,
            hours: session.hasError ? '⚠️ ESCLUSA' : sessionFormatted.formatted,
            dailyTotal: index === 0 ? dailyFormatted.formatted : ''
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            // Riga con errore: sfondo rosso chiaro
            if (session.hasError) {
              cell.fill = { 
                type: 'pattern', 
                pattern: 'solid', 
                fgColor: { argb: 'FFFFC7CE' } // Rosso chiaro
              };
              if (colNumber === 5) {
                cell.font = { bold: true, color: { argb: 'FF9C0006' } }; // Rosso scuro
              }
            }
            
            // Prima riga del giorno: data in grassetto
            if (colNumber === 1 && index === 0) {
              cell.font = { bold: true };
              if (!hasErrors) {
                cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } };
              }
            }
            
            // Totale giorno: sfondo verde se tutto ok
            if (colNumber === 6 && index === 0) {
              cell.font = { bold: true };
              if (!hasErrors && dailyTotal > 0) {
                cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } }; // Verde chiaro
              } else if (hasErrors) {
                cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFC7CE' } }; // Rosso chiaro
              }
            }
            
            // Allineamento
            if (colNumber >= 3) {
              cell.alignment = { horizontal: 'center' };
            }
          });
        });
        
        // Riga separatore tra giorni
        detailSheet.addRow([]);
      });
      
      // ==================== FOGLIO 3: VALIDAZIONE ERRORI ====================
      const validationSheet = workbook.addWorksheet('⚠️ Validazione');
      
      // Raccogli tutte le sessioni con errore
      const errorSessions = [];
      Object.keys(dailySessions).forEach(dateKey => {
        dailySessions[dateKey].forEach(session => {
          if (session.hasError) {
            errorSessions.push({ date: dateKey, ...session });
          }
        });
      });
      
      // Titolo
      validationSheet.mergeCells('A1:F1');
      const validationTitle = validationSheet.getCell('A1');
      if (errorSessions.length > 0) {
        validationTitle.value = `⚠️ ATTENZIONE: ${errorSessions.length} SESSIONI CON ERRORI TROVATE - VERIFICARE E CORREGGERE`;
        validationTitle.style = {
          font: { bold: true, size: 14, color: { argb: 'FFFFFFFF' } },
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE74C3C' } }, // Rosso
          alignment: { vertical: 'middle', horizontal: 'center' },
          border: {
            top: { style: 'medium' },
            left: { style: 'medium' },
            bottom: { style: 'medium' },
            right: { style: 'medium' }
          }
        };
      } else {
        validationTitle.value = '✅ NESSUN ERRORE RILEVATO - TUTTE LE SESSIONI SONO VALIDE';
        validationTitle.style = {
          font: { bold: true, size: 14, color: { argb: 'FFFFFFFF' } },
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF00B050' } }, // Verde
          alignment: { vertical: 'middle', horizontal: 'center' },
          border: {
            top: { style: 'medium' },
            left: { style: 'medium' },
            bottom: { style: 'medium' },
            right: { style: 'medium' }
          }
        };
      }
      validationSheet.getRow(1).height = 30;
      
      validationSheet.addRow([]);
      
      if (errorSessions.length > 0) {
        validationSheet.columns = [
          { header: 'Data', key: 'date', width: 15 },
          { header: 'Tipo Errore', key: 'errorType', width: 25 },
          { header: 'Cantiere IN', key: 'workSiteIn', width: 25 },
          { header: 'Cantiere OUT', key: 'workSiteOut', width: 25 },
          { header: 'Ora Ingresso', key: 'timeIn', width: 20 },
          { header: 'Ora Uscita', key: 'timeOut', width: 20 }
        ];
        
        const validationHeaderRow = validationSheet.getRow(3);
        validationHeaderRow.eachCell(cell => {
          cell.style = {
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
        });
        
        errorSessions.forEach(session => {
          const errorTypeText = session.errorType === 'TEMPORAL' 
            ? '🕒 OUT prima o uguale a IN' 
            : '⏰ Sessione > 24 ore';
          
          const row = validationSheet.addRow({
            date: new Date(session.date).toLocaleDateString('it-IT'),
            errorType: errorTypeText,
            workSiteIn: session.workSiteIn,
            workSiteOut: session.workSiteOut,
            timeIn: session.timeIn.toLocaleString('it-IT'),
            timeOut: session.timeOut.toLocaleString('it-IT')
          });
          
          row.eachCell(cell => {
            cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFC7CE' } };
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            cell.alignment = { vertical: 'middle', horizontal: 'center' };
          });
          
          row.getCell(2).font = { bold: true, color: { argb: 'FF9C0006' } };
        });
        
        validationSheet.addRow([]);
        validationSheet.addRow([]);
        
        // Istruzioni
        const instructionsRow = validationSheet.addRow(['ISTRUZIONI:']);
        instructionsRow.getCell(1).font = { bold: true, size: 12 };
        
        validationSheet.addRow(['1. Le sessioni sopra elencate sono ESCLUSE dal totale ore']);
        validationSheet.addRow(['2. Verificare le timbrature originali nel foglio "Timbrature Originali"']);
        validationSheet.addRow(['3. Correggere le timbrature errate nel database']);
        validationSheet.addRow(['4. Rigenerare il report dopo le correzioni']);
      } else {
        validationSheet.addRow(['Tutte le sessioni sono state validate correttamente.']);
        validationSheet.addRow(['Non sono stati rilevati errori temporali o sessioni eccessive.']);
      }
      
      // ==================== FOGLIO 4: TIMBRATURE ORIGINALI ====================
      const rawSheet = workbook.addWorksheet('Timbrature Originali');
      
      rawSheet.columns = [
        { header: 'Data e Ora', key: 'timestamp', width: 20 },
        { header: 'Tipo', key: 'type', width: 12 },
        { header: 'Cantiere', key: 'workSite', width: 30 },
        { header: 'Dispositivo', key: 'device', width: 35 }
      ];
      
      rawSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
      
      records.forEach(record => {
        const row = rawSheet.addRow({
          timestamp: new Date(record.timestamp).toLocaleString('it-IT'),
          type: record.type === 'in' ? 'Ingresso' : 'Uscita',
          workSite: record.workSiteName || 'Non specificato',
          device: record.deviceInfo
        });
        
        row.eachCell((cell, colNumber) => {
          cell.border = {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          };
          
          if (colNumber === 2) {
            cell.font = { 
              bold: true, 
              color: { argb: record.type === 'in' ? 'FF00B050' : 'FFE74C3C' }
            };
          }
        });
      });
      
      // Salva file
      const reportPath = path.join(__dirname, 'reports');
      if (!fs.existsSync(reportPath)) {
        fs.mkdirSync(reportPath);
      }

      const timestamp = Date.now();
      const filePath = path.join(reportPath, `ore_dipendente_${employeeId}_${timestamp}.xlsx`);
      
      await workbook.xlsx.writeFile(filePath);
      resolve(filePath);
    });
  });
};

// Endpoint per scaricare il report ore dipendente
app.get('/api/attendance/hours-report', async (req, res) => {
  try {
    const employeeId = req.query.employeeId;
    
    if (!employeeId) {
      return res.status(400).json({ error: 'employeeId è obbligatorio per questo report' });
    }
    
    const startDate = req.query.startDate;
    const endDate = req.query.endDate;
    
    const filePath = await generateEmployeeHoursReport(employeeId, startDate, endDate);
    res.download(filePath);
  } catch (error) {
    console.error('Error generating hours report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== REPORT CANTIERE AVANZATO ====================

// Funzione per generare report cantiere con statistiche
const generateWorkSiteReport = async (workSiteId, employeeId, startDate, endDate) => {
  const workbook = new ExcelJS.Workbook();
  
  return new Promise((resolve, reject) => {
    // Query per ottenere info cantiere
    const workSiteQuery = workSiteId 
      ? 'SELECT * FROM work_sites WHERE id = ?'
      : 'SELECT * FROM work_sites LIMIT 1'; // Placeholder per "tutti i cantieri"
    
    const workSiteParams = workSiteId ? [workSiteId] : [];
    
    db.get(workSiteQuery, workSiteParams, async (err, workSite) => {
      if (err) {
        reject(err);
        return;
      }
      
      // Query principale per timbrature
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
          COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
          ws.name as workSiteName,
          ws.address as workSiteAddress
        FROM attendance_records ar
        LEFT JOIN employees e ON ar.employeeId = e.id
        LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
        WHERE 1=1
      `;
      
      const params = [];
      
      if (workSiteId) {
        query += ' AND ar.workSiteId = ?';
        params.push(workSiteId);
      }
      
      if (employeeId) {
        query += ' AND ar.employeeId = ?';
        params.push(employeeId);
      }
      
      if (startDate) {
        query += ' AND ar.timestamp >= ?';
        params.push(startDate);
      }
      
      if (endDate) {
        query += ' AND ar.timestamp <= ?';
        params.push(endDate);
      }
      
      query += ' ORDER BY ar.timestamp ASC';

      db.all(query, params, async (err, records) => {
        if (err) {
          reject(err);
          return;
        }

        if (records.length === 0) {
          reject(new Error('Nessuna timbratura trovata per il periodo selezionato'));
          return;
        }

        // Calcola ore e statistiche
        const { workSessions, dailySessions } = calculateWorkedHours(records);
        
        // Calcola statistiche cantiere
        const uniqueEmployees = [...new Set(records.map(r => r.employeeId))];
        
        // Conta SOLO i giorni con sessioni valide (senza errori)
        let uniqueDays = 0;
        Object.keys(dailySessions).forEach(dateKey => {
          const hasValidSessions = dailySessions[dateKey].some(session => !session.hasError);
          if (hasValidSessions) {
            uniqueDays++;
          }
        });
        
        // Calcola ore totali
        let totalHours = 0;
        Object.values(workSessions).forEach(hours => totalHours += hours);
        
        const avgHoursPerDay = uniqueDays > 0 ? totalHours / uniqueDays : 0;
        const avgHoursPerEmployee = uniqueEmployees.length > 0 ? totalHours / uniqueEmployees.length : 0;
        
        const workSiteName = workSiteId && workSite 
          ? workSite.name 
          : 'Tutti i Cantieri';
        
        // ==================== FOGLIO 1: RIEPILOGO CANTIERE ====================
        const summarySheet = workbook.addWorksheet('Riepilogo Cantiere');
        
        // Stili
        const titleStyle = {
          font: { bold: true, size: 16, color: { argb: 'FF1F4E78' } },
          alignment: { vertical: 'middle', horizontal: 'center' }
        };
        
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
        
        const totalStyle = {
          font: { bold: true, size: 12 },
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } },
          alignment: { vertical: 'middle', horizontal: 'left' },
          border: {
            top: { style: 'medium' },
            left: { style: 'thin' },
            bottom: { style: 'medium' },
            right: { style: 'thin' }
          }
        };
        
        const infoStyle = {
          font: { size: 11 },
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } },
          alignment: { vertical: 'middle', horizontal: 'left' },
          border: {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          }
        };
        
        // Titolo
        summarySheet.mergeCells('A1:D1');
        const titleCell = summarySheet.getCell('A1');
        titleCell.value = `REPORT CANTIERE - ${workSiteName.toUpperCase()}`;
        titleCell.style = titleStyle;
        
        // Periodo
        summarySheet.mergeCells('A2:D2');
        const periodCell = summarySheet.getCell('A2');
        const startDateStr = startDate ? new Date(startDate).toLocaleDateString('it-IT') : 'Inizio';
        const endDateStr = endDate ? new Date(endDate).toLocaleDateString('it-IT') : 'Oggi';
        periodCell.value = `Periodo: ${startDateStr} - ${endDateStr}`;
        periodCell.alignment = { horizontal: 'center' };
        periodCell.font = { italic: true, size: 11 };
        
        summarySheet.addRow([]);
        
        // INFO CANTIERE
        if (workSiteId && workSite) {
          summarySheet.addRow(['INFORMAZIONI CANTIERE']).font = { bold: true, size: 12 };
          summarySheet.addRow([]);
          
          const infoRows = [
            ['Nome Cantiere:', workSite.name],
            ['Indirizzo:', workSite.address || 'Non specificato'],
            ['Coordinate:', workSite.latitude && workSite.longitude 
              ? `${workSite.latitude.toFixed(6)}, ${workSite.longitude.toFixed(6)}` 
              : 'Non disponibili']
          ];
          
          infoRows.forEach(([label, value]) => {
            const row = summarySheet.addRow([label, value]);
            row.getCell(1).font = { bold: true };
            row.getCell(1).style = infoStyle;
            row.getCell(2).style = infoStyle;
          });
          
          summarySheet.addRow([]);
        }
        
        // STATISTICHE PRINCIPALI
        summarySheet.addRow(['STATISTICHE CANTIERE']).font = { bold: true, size: 12 };
        summarySheet.addRow([]);
        
        summarySheet.columns = [
          { key: 'label', width: 35 },
          { key: 'value', width: 20 },
          { key: 'label2', width: 35 },
          { key: 'value2', width: 20 }
        ];
        
        const statsHeaderRow = summarySheet.addRow(['Metrica', 'Valore', 'Metrica', 'Valore']);
        statsHeaderRow.eachCell(cell => cell.style = headerStyle);
        
        const totalFormatted = formatHoursMinutes(totalHours);
        const avgDayFormatted = formatHoursMinutes(avgHoursPerDay);
        const avgEmpFormatted = formatHoursMinutes(avgHoursPerEmployee);
        
        const statsData = [
          ['Dipendenti Totali', uniqueEmployees.length, 'Ore Totali Lavorate', totalFormatted.formatted],
          ['Giorni di Apertura', uniqueDays, 'Media Ore per Giorno', avgDayFormatted.formatted],
          ['Timbrature Totali', records.length, 'Media Ore per Dipendente', avgEmpFormatted.formatted]
        ];
        
        statsData.forEach(([label1, value1, label2, value2]) => {
          const row = summarySheet.addRow([label1, value1, label2, value2]);
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            if (colNumber % 2 === 1) {
              cell.font = { bold: true };
            } else {
              cell.alignment = { horizontal: 'center' };
              cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } };
            }
          });
        });
        
        summarySheet.addRow([]);
        
        // ORE PER DIPENDENTE
        summarySheet.addRow(['ORE LAVORATE PER DIPENDENTE']).font = { bold: true, size: 12 };
        summarySheet.addRow([]);
        
        // Raggruppa ore per dipendente
        const employeeHours = {};
        records.forEach(record => {
          if (!employeeHours[record.employeeId]) {
            employeeHours[record.employeeId] = {
              name: record.employeeName,
              records: []
            };
          }
          employeeHours[record.employeeId].records.push(record);
        });
        
        // Calcola ore per dipendente
        const employeeStats = [];
        Object.entries(employeeHours).forEach(([empId, data]) => {
          const { workSessions: empSessions } = calculateWorkedHours(data.records);
          let empTotal = 0;
          Object.values(empSessions).forEach(h => empTotal += h);
          employeeStats.push({
            name: data.name,
            hours: empTotal,
            days: [...new Set(data.records.map(r => new Date(r.timestamp).toISOString().split('T')[0]))].length
          });
        });
        
        // Ordina per ore decrescenti
        employeeStats.sort((a, b) => b.hours - a.hours);
        
        const empHeaderRow = summarySheet.addRow(['Dipendente', 'Ore Lavorate', 'Giorni Presenti', 'Media Ore/Giorno']);
        empHeaderRow.eachCell(cell => cell.style = headerStyle);
        
        employeeStats.forEach(emp => {
          const empFormatted = formatHoursMinutes(emp.hours);
          const avgEmpDay = emp.days > 0 ? emp.hours / emp.days : 0;
          const avgEmpDayFormatted = formatHoursMinutes(avgEmpDay);
          
          const row = summarySheet.addRow([
            emp.name,
            empFormatted.formatted,
            emp.days,
            avgEmpDayFormatted.formatted
          ]);
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            if (colNumber >= 2) {
              cell.alignment = { horizontal: 'center' };
            }
          });
        });
        
        summarySheet.addRow([]);
        
        // TOTALE
        const totalRow = summarySheet.addRow([
          'TOTALE GENERALE',
          totalFormatted.formatted,
          uniqueDays + ' giorni',
          avgDayFormatted.formatted
        ]);
        totalRow.eachCell(cell => cell.style = totalStyle);
        
        // ==================== FOGLIO 2: DETTAGLIO GIORNALIERO ====================
        const detailSheet = workbook.addWorksheet('Dettaglio Giornaliero');
        
        detailSheet.columns = [
          { header: 'Data', key: 'date', width: 15 },
          { header: 'Dipendente', key: 'employee', width: 25 },
          { header: 'Ora Ingresso', key: 'timeIn', width: 15 },
          { header: 'Ora Uscita', key: 'timeOut', width: 15 },
          { header: 'Ore Lavorate', key: 'hours', width: 15 },
          { header: 'Totale Giorno', key: 'dailyTotal', width: 15 }
        ];
        
        detailSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        
        // Ordina le date
        const sortedDates = Object.keys(dailySessions).sort();
        
        sortedDates.forEach(dateKey => {
          const sessions = dailySessions[dateKey];
          const date = new Date(dateKey).toLocaleDateString('it-IT');
          
          let dailyTotal = 0;
          sessions.forEach(session => {
            dailyTotal += session.hours;
          });
          
          const dailyFormatted = formatHoursMinutes(dailyTotal);
          
          // Raggruppa per dipendente
          const empSessions = {};
          sessions.forEach(session => {
            const empName = records.find(r => 
              new Date(r.timestamp).getTime() === session.timeIn.getTime()
            )?.employeeName || 'Sconosciuto';
            
            if (!empSessions[empName]) {
              empSessions[empName] = [];
            }
            empSessions[empName].push(session);
          });
          
          let isFirstRow = true;
          Object.entries(empSessions).forEach(([empName, empSessionsList]) => {
            empSessionsList.forEach((session, index) => {
              const sessionFormatted = formatHoursMinutes(session.hours);
              const row = detailSheet.addRow({
                date: isFirstRow ? date : '',
                employee: empName,
                timeIn: session.timeIn.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
                timeOut: session.timeOut.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
                hours: sessionFormatted.formatted,
                dailyTotal: isFirstRow ? dailyFormatted.formatted : ''
              });
              
              row.eachCell((cell, colNumber) => {
                cell.border = {
                  top: { style: 'thin' },
                  left: { style: 'thin' },
                  bottom: { style: 'thin' },
                  right: { style: 'thin' }
                };
                
                if (colNumber === 1 && isFirstRow) {
                  cell.font = { bold: true };
                  cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF2F2F2' } };
                }
                
                if (colNumber === 6 && isFirstRow) {
                  cell.font = { bold: true };
                  cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2EFDA' } };
                }
                
                if (colNumber >= 3) {
                  cell.alignment = { horizontal: 'center' };
                }
              });
              
              isFirstRow = false;
            });
          });
          
          // Riga separatore tra giorni
          detailSheet.addRow([]);
        });
        
        // ==================== FOGLIO 3: LISTA DIPENDENTI ====================
        const employeesSheet = workbook.addWorksheet('Lista Dipendenti');
        
        employeesSheet.columns = [
          { header: 'Dipendente', key: 'name', width: 30 },
          { header: 'Ore Totali', key: 'totalHours', width: 15 },
          { header: 'Giorni Presenti', key: 'days', width: 15 },
          { header: 'Prima Timbratura', key: 'firstDate', width: 18 },
          { header: 'Ultima Timbratura', key: 'lastDate', width: 18 }
        ];
        
        employeesSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        
        employeeStats.forEach((emp, index) => {
          const empRecords = employeeHours[Object.keys(employeeHours).find(k => 
            employeeHours[k].name === emp.name
          )].records;
          
          const firstDate = new Date(Math.min(...empRecords.map(r => new Date(r.timestamp)))).toLocaleString('it-IT');
          const lastDate = new Date(Math.max(...empRecords.map(r => new Date(r.timestamp)))).toLocaleString('it-IT');
          
          const row = employeesSheet.addRow({
            name: emp.name,
            totalHours: formatHoursMinutes(emp.hours).formatted,
            days: emp.days,
            firstDate: firstDate,
            lastDate: lastDate
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            if (colNumber >= 2) {
              cell.alignment = { horizontal: 'center' };
            }
            
            // Evidenzia top 3
            if (index < 3) {
              cell.fill = { 
                type: 'pattern', 
                pattern: 'solid', 
                fgColor: { 
                  argb: index === 0 ? 'FFFFD700' : index === 1 ? 'FFC0C0C0' : 'FFCD7F32'
                } 
              };
            }
          });
        });
        
        // ==================== FOGLIO 4: TIMBRATURE ORIGINALI ====================
        const rawSheet = workbook.addWorksheet('Timbrature Originali');
        
        rawSheet.columns = [
          { header: 'Data e Ora', key: 'timestamp', width: 20 },
          { header: 'Dipendente', key: 'employee', width: 25 },
          { header: 'Tipo', key: 'type', width: 12 },
          { header: 'Dispositivo', key: 'device', width: 35 }
        ];
        
        rawSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        
        records.forEach(record => {
          const row = rawSheet.addRow({
            timestamp: new Date(record.timestamp).toLocaleString('it-IT'),
            employee: record.employeeName,
            type: record.type === 'in' ? 'Ingresso' : 'Uscita',
            device: record.deviceInfo
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            if (colNumber === 3) {
              cell.font = { 
                bold: true, 
                color: { argb: record.type === 'in' ? 'FF00B050' : 'FFE74C3C' }
              };
            }
          });
        });
        
        // Salva file
        const reportPath = path.join(__dirname, 'reports');
        if (!fs.existsSync(reportPath)) {
          fs.mkdirSync(reportPath);
        }

        const timestamp = Date.now();
        const cantiereId = workSiteId || 'tutti';
        const filePath = path.join(reportPath, `report_cantiere_${cantiereId}_${timestamp}.xlsx`);
        
        await workbook.xlsx.writeFile(filePath);
        resolve(filePath);
      });
    });
  });
};

// Endpoint per scaricare il report cantiere
app.get('/api/worksite/report', async (req, res) => {
  try {
    const workSiteId = req.query.workSiteId ? parseInt(req.query.workSiteId) : null;
    const employeeId = req.query.employeeId ? parseInt(req.query.employeeId) : null;
    const startDate = req.query.startDate;
    const endDate = req.query.endDate;
    
    const filePath = await generateWorkSiteReport(workSiteId, employeeId, startDate, endDate);
    res.download(filePath);
  } catch (error) {
    console.error('Error generating worksite report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== FOREMAN API ====================

// GET /api/foreman/active-employees/:workSiteId
// Ottiene la lista dei dipendenti attualmente timbrati IN per un cantiere specifico
app.get('/api/foreman/active-employees/:workSiteId', (req, res) => {
  const { workSiteId } = req.params;
  
  console.log(`👷 [FOREMAN] Richiesta dipendenti attivi per cantiere ID: ${workSiteId}`);
  
  // Query per trovare dipendenti con l'ultima timbratura di tipo 'in' per questo cantiere
  const query = `
    SELECT 
      e.id as employeeId,
      e.name as employeeName,
      ar.timestamp,
      ar.type,
      ar.workSiteId
    FROM employees e
    INNER JOIN (
      -- Trova l'ultima timbratura per ogni dipendente su questo cantiere
      SELECT 
        employeeId,
        MAX(timestamp) as lastTimestamp
      FROM attendance_records
      WHERE workSiteId = ?
      GROUP BY employeeId
    ) latest ON e.id = latest.employeeId
    INNER JOIN attendance_records ar 
      ON ar.employeeId = latest.employeeId 
      AND ar.timestamp = latest.lastTimestamp
      AND ar.workSiteId = ?
    WHERE ar.type = 'in'
      AND e.isActive = 1
    ORDER BY e.name ASC
  `;
  
  db.all(query, [workSiteId, workSiteId], (err, rows) => {
    if (err) {
      console.error(`❌ [FOREMAN] Errore query dipendenti attivi:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    console.log(`✅ [FOREMAN] Trovati ${rows.length} dipendenti attivi sul cantiere ${workSiteId}`);
    res.json(rows);
  });
});

// GET /api/foreman/worksite-history/:workSiteId
// Ottiene lo storico completo delle timbrature per un cantiere (con filtri data opzionali)
app.get('/api/foreman/worksite-history/:workSiteId', (req, res) => {
  const { workSiteId } = req.params;
  let { startDate, endDate } = req.query;
  
  console.log(`📋 [FOREMAN] Richiesta storico cantiere ID: ${workSiteId}`);
  if (startDate) console.log(`   📅 Data inizio: ${startDate}`);
  if (endDate) console.log(`   📅 Data fine (ricevuta): ${endDate}`);
  
  // Se endDate è fornita, estendila alla fine della giornata (23:59:59.999)
  // per includere tutte le timbrature di quel giorno
  if (endDate) {
    const endDateObj = new Date(endDate);
    endDateObj.setHours(23, 59, 59, 999);
    endDate = endDateObj.toISOString();
    console.log(`   📅 Data fine (corretta): ${endDate}`);
  }
  
  let query = `
    SELECT 
      ar.id,
      ar.employeeId,
      ar.workSiteId,
      ar.timestamp,
      ar.type,
      ar.isForced,
      ar.notes,
      COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
      e.isActive as employeeIsActive
    FROM attendance_records ar
    LEFT JOIN employees e ON ar.employeeId = e.id
    WHERE ar.workSiteId = ?
  `;
  
  const params = [workSiteId];
  
  if (startDate) {
    query += ' AND ar.timestamp >= ?';
    params.push(startDate);
  }
  
  if (endDate) {
    query += ' AND ar.timestamp <= ?';
    params.push(endDate);
  }
  
  query += ' ORDER BY ar.timestamp DESC';
  
  db.all(query, params, (err, rows) => {
    if (err) {
      console.error(`❌ [FOREMAN] Errore query storico:`, err.message);
      res.status(500).json({ error: err.message });
      return;
    }
    
    console.log(`✅ [FOREMAN] Trovate ${rows.length} timbrature nello storico`);
    res.json(rows);
  });
});

// GET /api/foreman/worksite-report/:workSiteId
// Genera e scarica report Excel per capocantiere (storico cantiere)
app.get('/api/foreman/worksite-report/:workSiteId', async (req, res) => {
  const { workSiteId } = req.params;
  let { startDate, endDate } = req.query;
  
  console.log(`📊 [FOREMAN] Generazione report Excel per cantiere ID: ${workSiteId}`);
  if (startDate) console.log(`   📅 Data inizio: ${startDate}`);
  if (endDate) console.log(`   📅 Data fine (ricevuta): ${endDate}`);
  
  // Se endDate è fornita, estendila alla fine della giornata (23:59:59.999)
  // per includere tutte le timbrature di quel giorno
  if (endDate) {
    const endDateObj = new Date(endDate);
    endDateObj.setHours(23, 59, 59, 999);
    endDate = endDateObj.toISOString();
    console.log(`   📅 Data fine (corretta): ${endDate}`);
  }
  
  try {
    // Recupera informazioni cantiere
    const workSite = await new Promise((resolve, reject) => {
      db.get('SELECT * FROM work_sites WHERE id = ?', [workSiteId], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
    
    if (!workSite) {
      return res.status(404).json({ error: 'Cantiere non trovato' });
    }
    
    // Query per recuperare timbrature
    let query = `
      SELECT 
        ar.id,
        ar.employeeId,
        ar.timestamp,
        ar.type,
        ar.isForced,
        ar.notes,
        COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
        e.isActive as employeeIsActive
      FROM attendance_records ar
      LEFT JOIN employees e ON ar.employeeId = e.id
      WHERE ar.workSiteId = ?
    `;
    
    const params = [workSiteId];
    
    if (startDate) {
      query += ' AND ar.timestamp >= ?';
      params.push(startDate);
    }
    
    if (endDate) {
      query += ' AND ar.timestamp <= ?';
      params.push(endDate);
    }
    
    query += ' ORDER BY ar.timestamp ASC';
    
    const records = await new Promise((resolve, reject) => {
      db.all(query, params, (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
    
    // Genera Excel
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Storico Cantiere');
    
    // Intestazione
    worksheet.columns = [
      { header: 'ID', key: 'id', width: 8 },
      { header: 'Dipendente', key: 'employeeName', width: 25 },
      { header: 'Data', key: 'date', width: 12 },
      { header: 'Ora', key: 'time', width: 10 },
      { header: 'Tipo', key: 'type', width: 10 },
      { header: 'Forzata', key: 'isForced', width: 10 },
      { header: 'Note', key: 'notes', width: 30 },
    ];
    
    // Stile intestazione
    worksheet.getRow(1).font = { bold: true, size: 12 };
    worksheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF4472C4' }
    };
    worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    
    // Aggiungi dati
    records.forEach(record => {
      const timestamp = new Date(record.timestamp);
      worksheet.addRow({
        id: record.id,
        employeeName: record.employeeName,
        date: timestamp.toLocaleDateString('it-IT'),
        time: timestamp.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
        type: record.type === 'in' ? 'ENTRATA' : 'USCITA',
        isForced: record.isForced ? 'SÌ' : 'NO',
        notes: record.notes || '',
      });
    });
    
    // Info cantiere in cima
    worksheet.insertRow(1, ['Report Cantiere:', workSite.name]);
    worksheet.insertRow(2, ['Indirizzo:', workSite.address]);
    worksheet.insertRow(3, ['Periodo:', startDate && endDate 
      ? `${new Date(startDate).toLocaleDateString('it-IT')} - ${new Date(endDate).toLocaleDateString('it-IT')}`
      : 'Tutti i record'
    ]);
    worksheet.insertRow(4, ['Totale timbrature:', records.length]);
    worksheet.insertRow(5, []); // Riga vuota
    
    worksheet.getRow(1).font = { bold: true, size: 14 };
    worksheet.getRow(2).font = { italic: true };
    worksheet.getRow(3).font = { italic: true };
    worksheet.getRow(4).font = { bold: true };
    
    // Salva file temporaneo
    const tempDir = path.join(__dirname, 'temp');
    if (!fs.existsSync(tempDir)) {
      fs.mkdirSync(tempDir);
    }
    
    const filename = `report_cantiere_${workSiteId}_${Date.now()}.xlsx`;
    const filepath = path.join(tempDir, filename);
    
    await workbook.xlsx.writeFile(filepath);
    
    console.log(`✅ [FOREMAN] Report generato: ${filename}`);
    
    // Invia file
    res.download(filepath, filename, (err) => {
      if (err) {
        console.error('Error sending file:', err);
      }
      // Elimina file temporaneo dopo l'invio
      fs.unlink(filepath, (unlinkErr) => {
        if (unlinkErr) console.error('Error deleting temp file:', unlinkErr);
      });
    });
    
  } catch (error) {
    console.error('❌ [FOREMAN] Errore generazione report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== END FOREMAN API ====================

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

// ==================== RESTORE DATABASE ====================

// Configurazione multer per upload file
const upload = multer({
  dest: path.join(__dirname, 'temp'),
  fileFilter: (req, file, cb) => {
    // Accetta solo file .db
    if (file.originalname.endsWith('.db')) {
      cb(null, true);
    } else {
      cb(new Error('Solo file .db sono accettati'));
    }
  },
  limits: {
    fileSize: 100 * 1024 * 1024 // Max 100MB
  }
});

// Crea directory temp se non esiste
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir);
}

// Valida struttura database
function validateDatabaseStructure(dbPath) {
  return new Promise((resolve, reject) => {
    const testDb = new sqlite3.Database(dbPath, sqlite3.OPEN_READONLY, (err) => {
      if (err) {
        reject(new Error('File database corrotto o non valido'));
        return;
      }
      
      // Verifica esistenza tabelle richieste
      const requiredTables = ['employees', 'work_sites', 'attendance_records'];
      let checkedTables = 0;
      
      testDb.serialize(() => {
        requiredTables.forEach(tableName => {
          testDb.get(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [tableName],
            (err, row) => {
              if (err) {
                testDb.close();
                reject(new Error(`Errore durante la validazione: ${err.message}`));
                return;
              }
              
              if (!row) {
                testDb.close();
                reject(new Error(`Tabella '${tableName}' mancante nel database`));
                return;
              }
              
              checkedTables++;
              
              if (checkedTables === requiredTables.length) {
                // Verifica colonne critiche in employees
                testDb.all("PRAGMA table_info(employees)", (err, columns) => {
                  testDb.close();
                  
                  if (err) {
                    reject(new Error(`Errore nella verifica colonne: ${err.message}`));
                    return;
                  }
                  
                  const columnNames = columns.map(col => col.name);
                  const requiredColumns = ['id', 'name', 'email', 'password', 'isAdmin'];
                  const missingColumns = requiredColumns.filter(col => !columnNames.includes(col));
                  
                  if (missingColumns.length > 0) {
                    reject(new Error(`Colonne mancanti in 'employees': ${missingColumns.join(', ')}`));
                    return;
                  }
                  
                  resolve(true);
                });
              }
            }
          );
        });
      });
    });
  });
}

// POST endpoint per restore database
app.post('/api/backup/restore', upload.single('database'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Nessun file caricato' });
    }
    
    const uploadedFilePath = req.file.path;
    const dbPath = path.join(__dirname, 'database.db');
    const backupBeforeRestore = path.join(__dirname, 'backups', `pre_restore_backup_${new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5)}.db`);
    
    console.log(`📤 Uploaded file: ${req.file.originalname}`);
    console.log(`🔍 Validating database structure...`);
    
    // Valida struttura del database caricato
    try {
      await validateDatabaseStructure(uploadedFilePath);
      console.log('✓ Database structure valid');
    } catch (validationError) {
      fs.unlinkSync(uploadedFilePath); // Elimina file non valido
      return res.status(400).json({ error: validationError.message });
    }
    
    // Crea backup del database corrente prima del restore
    console.log('💾 Creating backup of current database...');
    if (fs.existsSync(dbPath)) {
      fs.copyFileSync(dbPath, backupBeforeRestore);
      console.log(`✓ Current database backed up to: ${path.basename(backupBeforeRestore)}`);
    }
    
    // Chiudi connessione corrente al database
    console.log('🔌 Closing current database connection...');
    await new Promise((resolve, reject) => {
      db.close((err) => {
        if (err) {
          console.error('Error closing database:', err);
          // Continua comunque
        }
        resolve();
      });
    });
    
    // Sostituisci il database
    console.log('🔄 Replacing database...');
    fs.copyFileSync(uploadedFilePath, dbPath);
    
    // Elimina file temporaneo
    fs.unlinkSync(uploadedFilePath);
    
    console.log('✓ Database restored successfully');
    console.log('🔄 Server will restart to apply changes...');
    
    // Invia risposta prima di riavviare
    res.json({
      success: true,
      message: 'Database ripristinato con successo. Il server si riavvierà automaticamente.',
      backupCreated: path.basename(backupBeforeRestore)
    });
    
    // Riavvia il processo dopo un breve delay
    setTimeout(() => {
      console.log('🔄 Restarting server...');
      process.exit(0); // Il process manager (nodemon/pm2) riavvierà automaticamente
    }, 1000);
    
  } catch (error) {
    console.error('❌ Error during restore:', error);
    
    // Pulisci file temporaneo se esiste
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({ error: error.message });
  }
});

// ==================== END RESTORE ====================

// ==================== REPORT TIMBRATURE FORZATE ====================

// Funzione per generare report timbrature forzate
const generateForcedAttendanceReport = async (filters = {}) => {
  const workbook = new ExcelJS.Workbook();
  
  return new Promise((resolve, reject) => {
    let query = `
      SELECT 
        ar.id,
        ar.employeeId,
        ar.workSiteId,
        ar.timestamp,
        ar.type,
        ar.forcedByAdminId,
        ar.notes,
        COALESCE(e.name, '[DIPENDENTE ELIMINATO #' || ar.employeeId || ']') as employeeName,
        COALESCE(e.email, '') as employeeEmail,
        ws.name as workSiteName,
        admin.name as adminName,
        admin.email as adminEmail
      FROM attendance_records ar
      LEFT JOIN employees e ON ar.employeeId = e.id
      LEFT JOIN work_sites ws ON ar.workSiteId = ws.id
      LEFT JOIN employees admin ON ar.forcedByAdminId = admin.id
      WHERE ar.forcedByAdminId IS NOT NULL
    `;
    
    const params = [];
    
    // Applica filtri
    if (filters.employeeId) {
      query += ' AND ar.employeeId = ?';
      params.push(filters.employeeId);
    }
    
    if (filters.workSiteId) {
      query += ' AND ar.workSiteId = ?';
      params.push(filters.workSiteId);
    }
    
    if (filters.startDate) {
      query += ' AND DATE(ar.timestamp) >= DATE(?)';
      params.push(filters.startDate);
    }
    
    if (filters.endDate) {
      query += ' AND DATE(ar.timestamp) <= DATE(?)';
      params.push(filters.endDate);
    }
    
    query += ' ORDER BY ar.timestamp DESC';
    
    db.all(query, params, async (err, records) => {
      if (err) {
        console.error('Error fetching forced attendance records:', err);
        reject(err);
        return;
      }
      
      try {
        // ==================== FOGLIO 1: RIEPILOGO PER DIPENDENTE ====================
        const summarySheet = workbook.addWorksheet('Riepilogo per Dipendente');
        
        // Stili
        const headerStyle = {
          font: { bold: true, color: { argb: 'FFFFFFFF' }, size: 12 },
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFF6B35' } },
          alignment: { horizontal: 'center', vertical: 'middle' },
          border: {
            top: { style: 'thin' },
            left: { style: 'thin' },
            bottom: { style: 'thin' },
            right: { style: 'thin' }
          }
        };
        
        const warningStyle = {
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF3CD' } },
          font: { bold: true }
        };
        
        const criticalStyle = {
          fill: { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF8D7DA' } },
          font: { bold: true, color: { argb: 'FF721C24' } }
        };
        
        // Configurazione colonne
        summarySheet.columns = [
          { header: 'Dipendente', key: 'employee', width: 25 },
          { header: 'Totale Timbrature Forzate', key: 'total', width: 25 },
          { header: 'Ingressi Forzati', key: 'forcedIn', width: 20 },
          { header: 'Uscite Forzate', key: 'forcedOut', width: 20 },
          { header: 'Cantieri Coinvolti', key: 'worksites', width: 20 },
          { header: 'Livello Attenzione', key: 'alertLevel', width: 20 }
        ];
        
        summarySheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        summarySheet.getRow(1).height = 25;
        
        // Raggruppa per dipendente
        const employeeStats = {};
        records.forEach(record => {
          const empId = record.employeeId;
          if (!employeeStats[empId]) {
            employeeStats[empId] = {
              name: record.employeeName,
              total: 0,
              forcedIn: 0,
              forcedOut: 0,
              worksites: new Set(),
              admins: new Set()
            };
          }
          
          employeeStats[empId].total++;
          if (record.type === 'in') {
            employeeStats[empId].forcedIn++;
          } else {
            employeeStats[empId].forcedOut++;
          }
          
          if (record.workSiteName) {
            employeeStats[empId].worksites.add(record.workSiteName);
          }
          if (record.adminName) {
            employeeStats[empId].admins.add(record.adminName);
          }
        });
        
        // Ordina per numero di timbrature forzate (decrescente)
        const sortedEmployees = Object.values(employeeStats).sort((a, b) => b.total - a.total);
        
        // Aggiungi righe
        sortedEmployees.forEach(emp => {
          let alertLevel = 'NORMALE';
          let rowStyle = null;
          
          if (emp.total >= 20) {
            alertLevel = 'CRITICO';
            rowStyle = criticalStyle;
          } else if (emp.total >= 10) {
            alertLevel = 'ATTENZIONE';
            rowStyle = warningStyle;
          }
          
          const row = summarySheet.addRow({
            employee: emp.name,
            total: emp.total,
            forcedIn: emp.forcedIn,
            forcedOut: emp.forcedOut,
            worksites: emp.worksites.size,
            alertLevel: alertLevel
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            if (colNumber >= 2 && colNumber <= 6) {
              cell.alignment = { horizontal: 'center', vertical: 'middle' };
            }
            
            if (rowStyle && colNumber === 6) {
              cell.style = { ...cell.style, ...rowStyle };
            }
          });
        });
        
        // Aggiungi totale
        summarySheet.addRow([]);
        const totalRow = summarySheet.addRow({
          employee: 'TOTALE GENERALE',
          total: records.length,
          forcedIn: records.filter(r => r.type === 'in').length,
          forcedOut: records.filter(r => r.type === 'out').length,
          worksites: new Set(records.map(r => r.workSiteName).filter(Boolean)).size,
          alertLevel: ''
        });
        
        totalRow.eachCell(cell => {
          cell.font = { bold: true, size: 12 };
          cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE9ECEF' } };
          cell.border = {
            top: { style: 'medium' },
            left: { style: 'thin' },
            bottom: { style: 'medium' },
            right: { style: 'thin' }
          };
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
        });
        
        // ==================== FOGLIO 2: DETTAGLIO COMPLETO ====================
        const detailSheet = workbook.addWorksheet('Dettaglio Completo');
        
        detailSheet.columns = [
          { header: 'Data', key: 'date', width: 12 },
          { header: 'Ora', key: 'time', width: 10 },
          { header: 'Dipendente', key: 'employee', width: 25 },
          { header: 'Tipo', key: 'type', width: 12 },
          { header: 'Cantiere', key: 'worksite', width: 25 },
          { header: 'Forzato da', key: 'admin', width: 25 },
          { header: 'Note', key: 'notes', width: 40 }
        ];
        
        detailSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        detailSheet.getRow(1).height = 25;
        
        // Aggiungi i record
        records.forEach(record => {
          const timestamp = new Date(record.timestamp);
          const typeLabel = record.type === 'in' ? 'INGRESSO' : 'USCITA';
          const typeColor = record.type === 'in' ? 'FF28A745' : 'FFDC3545';
          
          const row = detailSheet.addRow({
            date: timestamp.toLocaleDateString('it-IT'),
            time: timestamp.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }),
            employee: record.employeeName,
            type: typeLabel,
            worksite: record.workSiteName || 'Non specificato',
            admin: record.adminName || 'Sconosciuto',
            notes: record.notes || ''
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            cell.alignment = { vertical: 'middle' };
            
            // Colora la cella "Tipo"
            if (colNumber === 4) {
              cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: typeColor } };
              cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
              cell.alignment = { horizontal: 'center', vertical: 'middle' };
            }
          });
        });
        
        // ==================== FOGLIO 3: STATISTICHE PER CANTIERE ====================
        const worksiteSheet = workbook.addWorksheet('Statistiche per Cantiere');
        
        worksiteSheet.columns = [
          { header: 'Cantiere', key: 'worksite', width: 30 },
          { header: 'Totale Timbrature Forzate', key: 'total', width: 25 },
          { header: 'Ingressi', key: 'forcedIn', width: 15 },
          { header: 'Uscite', key: 'forcedOut', width: 15 },
          { header: 'Dipendenti Coinvolti', key: 'employees', width: 22 }
        ];
        
        worksiteSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        worksiteSheet.getRow(1).height = 25;
        
        // Raggruppa per cantiere
        const worksiteStats = {};
        records.forEach(record => {
          const wsName = record.workSiteName || 'Non specificato';
          if (!worksiteStats[wsName]) {
            worksiteStats[wsName] = {
              total: 0,
              forcedIn: 0,
              forcedOut: 0,
              employees: new Set()
            };
          }
          
          worksiteStats[wsName].total++;
          if (record.type === 'in') {
            worksiteStats[wsName].forcedIn++;
          } else {
            worksiteStats[wsName].forcedOut++;
          }
          worksiteStats[wsName].employees.add(record.employeeName);
        });
        
        // Ordina per totale (decrescente)
        const sortedWorksites = Object.entries(worksiteStats).sort((a, b) => b[1].total - a[1].total);
        
        sortedWorksites.forEach(([wsName, stats]) => {
          const row = worksiteSheet.addRow({
            worksite: wsName,
            total: stats.total,
            forcedIn: stats.forcedIn,
            forcedOut: stats.forcedOut,
            employees: stats.employees.size
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            if (colNumber >= 2) {
              cell.alignment = { horizontal: 'center', vertical: 'middle' };
            }
          });
        });
        
        // ==================== FOGLIO 4: STATISTICHE PER AMMINISTRATORE ====================
        const adminSheet = workbook.addWorksheet('Statistiche per Amministratore');
        
        adminSheet.columns = [
          { header: 'Amministratore', key: 'admin', width: 30 },
          { header: 'Totale Timbrature Forzate', key: 'total', width: 25 },
          { header: 'Dipendenti Gestiti', key: 'employees', width: 22 },
          { header: 'Cantieri', key: 'worksites', width: 15 }
        ];
        
        adminSheet.getRow(1).eachCell(cell => cell.style = headerStyle);
        adminSheet.getRow(1).height = 25;
        
        // Raggruppa per admin
        const adminStats = {};
        records.forEach(record => {
          const adminName = record.adminName || 'Sconosciuto';
          if (!adminStats[adminName]) {
            adminStats[adminName] = {
              total: 0,
              employees: new Set(),
              worksites: new Set()
            };
          }
          
          adminStats[adminName].total++;
          adminStats[adminName].employees.add(record.employeeName);
          if (record.workSiteName) {
            adminStats[adminName].worksites.add(record.workSiteName);
          }
        });
        
        // Ordina per totale (decrescente)
        const sortedAdmins = Object.entries(adminStats).sort((a, b) => b[1].total - a[1].total);
        
        sortedAdmins.forEach(([adminName, stats]) => {
          const row = adminSheet.addRow({
            admin: adminName,
            total: stats.total,
            employees: stats.employees.size,
            worksites: stats.worksites.size
          });
          
          row.eachCell((cell, colNumber) => {
            cell.border = {
              top: { style: 'thin' },
              left: { style: 'thin' },
              bottom: { style: 'thin' },
              right: { style: 'thin' }
            };
            
            if (colNumber >= 2) {
              cell.alignment = { horizontal: 'center', vertical: 'middle' };
            }
          });
        });
        
        // Salva il file
        const reportsDir = path.join(__dirname, 'reports');
        if (!fs.existsSync(reportsDir)) {
          fs.mkdirSync(reportsDir, { recursive: true });
        }
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
        const fileName = `report_timbrature_forzate_${timestamp}.xlsx`;
        const filePath = path.join(reportsDir, fileName);
        
        await workbook.xlsx.writeFile(filePath);
        console.log('✓ Report timbrature forzate generato:', fileName);
        
        resolve(filePath);
      } catch (error) {
        console.error('Error creating forced attendance report:', error);
        reject(error);
      }
    });
  });
};

// Endpoint per scaricare il report timbrature forzate
app.get('/api/attendance/forced-report', async (req, res) => {
  try {
    const filters = {
      employeeId: req.query.employeeId,
      workSiteId: req.query.workSiteId,
      startDate: req.query.startDate,
      endDate: req.query.endDate
    };
    
    console.log('Generating forced attendance report with filters:', filters);
    const filePath = await generateForcedAttendanceReport(filters);
    res.download(filePath);
  } catch (error) {
    console.error('Error generating forced attendance report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== END FORCED ATTENDANCE REPORT ====================

// ==================== ADMIN AUDIT REPORT ====================

/**
 * Genera un report Excel completo delle operazioni amministrative
 * con statistiche e log dettagliato
 */
const generateAdminAuditReport = async (filters) => {
  const { adminId, startDate, endDate } = filters;
  
  console.log('🔍 [AUDIT REPORT] Generazione report audit amministratore');
  console.log(`   Admin ID: ${adminId}`);
  console.log(`   Periodo: ${startDate} → ${endDate}`);
  
  // Query per recuperare log audit
  let logQuery = `
    SELECT 
      al.*,
      e.name as adminName,
      e.email as adminEmail,
      te.name as targetEmployeeName
    FROM audit_log al
    LEFT JOIN employees e ON al.adminId = e.id
    LEFT JOIN employees te ON al.targetType = 'ATTENDANCE' AND 
      (json_extract(al.newValue, '$.employeeId') = te.id OR 
       json_extract(al.oldValue, '$.employeeId') = te.id)
    WHERE 1=1
  `;
  
  const params = [];
  
  if (adminId) {
    logQuery += ' AND al.adminId = ?';
    params.push(adminId);
  }
  
  if (startDate) {
    logQuery += ' AND DATE(al.timestamp) >= DATE(?)';
    params.push(startDate);
  }
  
  if (endDate) {
    logQuery += ' AND DATE(al.timestamp) <= DATE(?)';
    params.push(endDate);
  }
  
  logQuery += ' ORDER BY al.timestamp DESC';
  
  // Query per statistiche
  let statsQuery = `
    SELECT 
      action,
      COUNT(*) as count
    FROM audit_log
    WHERE 1=1
  `;
  
  const statsParams = [];
  
  if (adminId) {
    statsQuery += ' AND adminId = ?';
    statsParams.push(adminId);
  }
  
  if (startDate) {
    statsQuery += ' AND DATE(timestamp) >= DATE(?)';
    statsParams.push(startDate);
  }
  
  if (endDate) {
    statsQuery += ' AND DATE(timestamp) <= DATE(?)';
    statsParams.push(endDate);
  }
  
  statsQuery += ' GROUP BY action ORDER BY count DESC';
  
  return new Promise((resolve, reject) => {
    // Recupera log
    db.all(logQuery, params, async (err, logs) => {
      if (err) {
        reject(err);
        return;
      }
      
      // Recupera statistiche
      db.all(statsQuery, statsParams, async (err, stats) => {
        if (err) {
          reject(err);
          return;
        }
        
        // Recupera info admin se filtrato per adminId
        let adminInfo = null;
        if (adminId) {
          await new Promise((res, rej) => {
            db.get('SELECT * FROM employees WHERE id = ?', [adminId], (err, admin) => {
              if (!err && admin) adminInfo = admin;
              res();
            });
          });
        }
        
        try {
          const workbook = new ExcelJS.Workbook();
          
          // ===== FOGLIO 1: RIEPILOGO =====
          const summarySheet = workbook.addWorksheet('Riepilogo');
          
          // Titolo
          summarySheet.mergeCells('A1:F1');
          const titleCell = summarySheet.getCell('A1');
          titleCell.value = '📋 REPORT AUDIT OPERAZIONI AMMINISTRATIVE';
          titleCell.font = { size: 16, bold: true, color: { argb: 'FFFFFFFF' } };
          titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF2C3E50' } };
          titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
          summarySheet.getRow(1).height = 30;
          
          // Info report
          summarySheet.addRow([]);
          summarySheet.addRow(['📅 Data generazione:', new Date().toLocaleString('it-IT')]);
          
          if (adminInfo) {
            summarySheet.addRow(['👤 Amministratore:', adminInfo.name]);
            summarySheet.addRow(['📧 Email:', adminInfo.email]);
          } else {
            summarySheet.addRow(['👤 Amministratore:', 'TUTTI']);
          }
          
          summarySheet.addRow(['📆 Periodo:', `${startDate || 'Sempre'} → ${endDate || 'Oggi'}`]);
          summarySheet.addRow(['📊 Totale operazioni:', logs.length]);
          
          // Statistiche per tipo azione
          summarySheet.addRow([]);
          summarySheet.addRow(['🎯 STATISTICHE PER TIPO OPERAZIONE']);
          
          const statsHeaderRow = summarySheet.addRow(['Tipo Operazione', 'Numero', 'Percentuale']);
          statsHeaderRow.font = { bold: true };
          statsHeaderRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F4F8' } };
          
          const totalOps = logs.length;
          stats.forEach(stat => {
            const percentage = totalOps > 0 ? ((stat.count / totalOps) * 100).toFixed(1) : 0;
            summarySheet.addRow([
              getActionLabel(stat.action),
              stat.count,
              `${percentage}%`
            ]);
          });
          
          // Formattazione colonne riepilogo
          summarySheet.getColumn(1).width = 30;
          summarySheet.getColumn(2).width = 20;
          summarySheet.getColumn(3).width = 15;
          
          // ===== FOGLIO 2: LOG DETTAGLIATO =====
          const logSheet = workbook.addWorksheet('Log Operazioni');
          
          // Header
          const headerRow = logSheet.addRow([
            'ID',
            'Data/Ora',
            'Amministratore',
            'Operazione',
            'Tipo Target',
            'Target',
            'Dipendente Interessato',
            'Dettagli',
            'IP'
          ]);
          
          headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
          headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF3498DB' } };
          headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
          headerRow.height = 20;
          
          // Dati
          logs.forEach(log => {
            const newValue = log.newValue ? JSON.parse(log.newValue) : null;
            const oldValue = log.oldValue ? JSON.parse(log.oldValue) : null;
            
            const row = logSheet.addRow([
              log.id,
              new Date(log.timestamp).toLocaleString('it-IT'),
              log.adminName || `ID ${log.adminId}`,
              getActionLabel(log.action),
              getTargetTypeLabel(log.targetType),
              log.targetName || `ID ${log.targetId}`,
              log.targetEmployeeName || (newValue?.employeeName || oldValue?.employeeName || '-'),
              log.details || '-',
              log.ipAddress || '-'
            ]);
            
            // Colora in base al tipo azione
            if (log.action.includes('DELETE')) {
              row.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEBEE' } };
            } else if (log.action.includes('FORCE')) {
              row.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFF3E0' } };
            } else if (log.action.includes('EDIT')) {
              row.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F8E9' } };
            }
          });
          
          // Formattazione colonne log
          logSheet.getColumn(1).width = 8;  // ID
          logSheet.getColumn(2).width = 20; // Data/Ora
          logSheet.getColumn(3).width = 20; // Admin
          logSheet.getColumn(4).width = 20; // Operazione
          logSheet.getColumn(5).width = 15; // Tipo Target
          logSheet.getColumn(6).width = 20; // Target
          logSheet.getColumn(7).width = 20; // Dipendente
          logSheet.getColumn(8).width = 50; // Dettagli
          logSheet.getColumn(9).width = 15; // IP
          
          // ===== FOGLIO 3: DETTAGLI MODIFICHE =====
          const changesSheet = workbook.addWorksheet('Dettagli Modifiche');
          
          const changesHeaderRow = changesSheet.addRow([
            'ID',
            'Data/Ora',
            'Operazione',
            'Dipendente',
            'Campo Modificato',
            'Valore Precedente',
            'Nuovo Valore'
          ]);
          
          changesHeaderRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
          changesHeaderRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF9B59B6' } };
          changesHeaderRow.alignment = { horizontal: 'center', vertical: 'middle' };
          
          logs.forEach(log => {
            if (log.oldValue || log.newValue) {
              const oldVal = log.oldValue ? JSON.parse(log.oldValue) : {};
              const newVal = log.newValue ? JSON.parse(log.newValue) : {};
              
              // Trova campi modificati
              const allKeys = new Set([...Object.keys(oldVal), ...Object.keys(newVal)]);
              
              allKeys.forEach(key => {
                const oldValue = oldVal[key];
                const newValue = newVal[key];
                
                if (oldValue !== newValue) {
                  changesSheet.addRow([
                    log.id,
                    new Date(log.timestamp).toLocaleString('it-IT'),
                    getActionLabel(log.action),
                    log.targetName || log.targetEmployeeName || '-',
                    key,
                    formatValue(oldValue),
                    formatValue(newValue)
                  ]);
                }
              });
            }
          });
          
          changesSheet.getColumn(1).width = 8;
          changesSheet.getColumn(2).width = 20;
          changesSheet.getColumn(3).width = 20;
          changesSheet.getColumn(4).width = 20;
          changesSheet.getColumn(5).width = 20;
          changesSheet.getColumn(6).width = 30;
          changesSheet.getColumn(7).width = 30;
          
          // Salva file
          const fileName = `audit_report_${adminInfo ? adminInfo.name.replace(/\s+/g, '_') : 'ALL'}_${Date.now()}.xlsx`;
          const filePath = path.join(__dirname, 'reports', fileName);
          
          // Crea cartella reports se non esiste
          if (!fs.existsSync(path.join(__dirname, 'reports'))) {
            fs.mkdirSync(path.join(__dirname, 'reports'));
          }
          
          await workbook.xlsx.writeFile(filePath);
          
          console.log(`✅ [AUDIT REPORT] Report generato: ${fileName}`);
          resolve(filePath);
        } catch (error) {
          console.error('❌ [AUDIT REPORT] Errore generazione:', error);
          reject(error);
        }
      });
    });
  });
};

// Helper: Label operazioni
const getActionLabel = (action) => {
  const labels = {
    'FORCE_IN': '➡️ Timbratura IN Forzata',
    'FORCE_OUT': '⬅️ Timbratura OUT Forzata',
    'EDIT_ATTENDANCE': '✏️ Modifica Timbratura',
    'DELETE_ATTENDANCE': '🗑️ Elimina Timbratura',
    'CREATE_EMPLOYEE': '➕ Crea Dipendente',
    'EDIT_EMPLOYEE': '✏️ Modifica Dipendente',
    'DELETE_EMPLOYEE': '🗑️ Elimina Dipendente',
    'CREATE_WORKSITE': '🏗️ Crea Cantiere',
    'EDIT_WORKSITE': '✏️ Modifica Cantiere',
    'DELETE_WORKSITE': '🗑️ Elimina Cantiere'
  };
  return labels[action] || action;
};

// Helper: Label tipo target
const getTargetTypeLabel = (type) => {
  const labels = {
    'ATTENDANCE': '⏱️ Timbratura',
    'EMPLOYEE': '👤 Dipendente',
    'WORKSITE': '🏗️ Cantiere',
    'SETTING': '⚙️ Impostazione'
  };
  return labels[type] || type;
};

// Helper: Formatta valori
const formatValue = (value) => {
  if (value === null || value === undefined) return '-';
  if (typeof value === 'object') return JSON.stringify(value);
  if (typeof value === 'boolean') return value ? 'Sì' : 'No';
  return String(value);
};

// Endpoint per scaricare il report audit amministratore
app.get('/api/admin/audit-report', async (req, res) => {
  try {
    const filters = {
      adminId: req.query.adminId,
      startDate: req.query.startDate,
      endDate: req.query.endDate
    };
    
    console.log('📋 Generating admin audit report with filters:', filters);
    const filePath = await generateAdminAuditReport(filters);
    res.download(filePath);
  } catch (error) {
    console.error('❌ Error generating admin audit report:', error);
    res.status(500).json({ error: error.message });
  }
});

// ==================== END ADMIN AUDIT REPORT ====================

// ==================== EMAIL CONFIGURATION API ====================

// GET - Configurazione email (solo admin)
app.get('/api/email/config', (req, res) => {
  const { adminId } = req.query;
  
  // Verifica admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    const config = loadEmailConfig();
    // Non inviare la password al client
    const safeConfig = { ...config };
    delete safeConfig.smtpPassword;
    
    res.json(safeConfig);
  });
});

// PUT - Aggiorna configurazione email (solo admin)
app.put('/api/email/config', (req, res) => {
  const { adminId, config } = req.body;
  
  // Verifica admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    const success = saveEmailConfig(config);
    
    if (success) {
      res.json({ success: true, message: 'Configurazione email salvata' });
    } else {
      res.status(500).json({ error: 'Errore durante il salvataggio della configurazione' });
    }
  });
});

// POST - Test invio email (solo admin)
app.post('/api/email/test', async (req, res) => {
  const { adminId, testEmail } = req.body;
  
  // Verifica admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], async (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    const config = loadEmailConfig();
    
    if (!config.emailEnabled) {
      res.status(400).json({ error: 'Email non abilitate nella configurazione' });
      return;
    }
    
    try {
      const transporter = createEmailTransporter();
      
      if (!transporter) {
        res.status(400).json({ error: 'Configurazione SMTP non valida' });
        return;
      }
      
      const mailOptions = {
        from: `"${config.fromName}" <${config.fromEmail}>`,
        to: testEmail || admin.email,
        subject: 'Test Email - Sistema Timbrature',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
              <h1 style="color: white; margin: 0; font-size: 24px;">✅ Test Email Riuscito</h1>
            </div>
            
            <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px;">
              <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
                Gentile <strong>${admin.name}</strong>,
              </p>
              
              <p style="font-size: 14px; color: #666; line-height: 1.6; margin-bottom: 20px;">
                Questo è un messaggio di test per verificare il corretto funzionamento del sistema di invio email automatico.
              </p>
              
              <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #28a745; margin-bottom: 20px;">
                <p style="margin: 0; color: #555; font-size: 14px;">
                  <strong style="color: #28a745;">✓ Configurazione corretta</strong><br>
                  Il sistema è in grado di inviare email correttamente.
                </p>
              </div>
              
              <p style="font-size: 13px; color: #999; line-height: 1.6; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd;">
                <em>Email di test inviata il ${new Date().toLocaleString('it-IT')}.</em>
              </p>
            </div>
          </div>
        `
      };
      
      await transporter.sendMail(mailOptions);
      
      res.json({ 
        success: true, 
        message: `Email di test inviata a ${testEmail || admin.email}` 
      });
      
    } catch (error) {
      console.error('Error sending test email:', error);
      res.status(500).json({ error: error.message });
    }
  });
});

// POST - Invio manuale report giornaliero (solo admin)
app.post('/api/email/send-daily-report', async (req, res) => {
  const { adminId } = req.body;
  
  // Verifica admin
  db.get('SELECT * FROM employees WHERE id = ? AND isAdmin = 1', [adminId], async (err, admin) => {
    if (err || !admin) {
      res.status(403).json({ error: 'Unauthorized: Not an admin' });
      return;
    }
    
    try {
      await sendDailyReportToAdmins();
      res.json({ 
        success: true, 
        message: 'Report giornaliero inviato a tutti gli amministratori' 
      });
    } catch (error) {
      console.error('Error sending daily report:', error);
      res.status(500).json({ error: error.message });
    }
  });
});

// ==================== END EMAIL API ====================

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});