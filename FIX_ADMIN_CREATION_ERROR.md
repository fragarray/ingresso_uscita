# 🔧 Fix: Errore Creazione Admin al Primo Avvio

## ❌ Problema

Al primo avvio su un Raspberry Pi nuovo, il server generava questo errore:

```
🔧 Creazione utente amministratore di default...
❌ Errore creazione admin: SQLITE_ERROR: table employees has no column named username
```

## 🔍 Causa

**Problema di race condition** nell'inizializzazione del database:

1. `db.js` crea la tabella `employees` con vecchio schema (senza `username`, `role`)
2. `db.js` aggiunge le colonne `username` e `role` con `ALTER TABLE` (operazione asincrona)
3. `server.js` tenta di creare l'admin dopo 1 secondo
4. ❌ Le colonne non sono ancora state create → errore

### Sequenza Problematica (PRIMA)

```javascript
// db.js
CREATE TABLE employees (id, name, email, password, isAdmin);  // ← Vecchio schema
ALTER TABLE employees ADD COLUMN username;  // ← Asincrono, impiega tempo
ALTER TABLE employees ADD COLUMN role;      // ← Asincrono, impiega tempo

// server.js (dopo 1 secondo)
setTimeout(() => {
  INSERT INTO employees (username, role, ...) VALUES (...);  // ❌ Colonne non esistono!
}, 1000);
```

## ✅ Soluzione Applicata

### 1. Schema Completo nella CREATE TABLE

**Modificato `db.js`** per creare la tabella `employees` **direttamente con tutte le colonne**:

```javascript
// db.js - DOPO
CREATE TABLE IF NOT EXISTS employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  username TEXT UNIQUE,              // ✅ Incluso da subito
  email TEXT,                         // ✅ Non più UNIQUE NOT NULL
  password TEXT NOT NULL,
  isAdmin INTEGER DEFAULT 0,
  role TEXT DEFAULT 'employee',       // ✅ Incluso da subito
  isActive INTEGER DEFAULT 1,         // ✅ Incluso da subito
  allowNightShift INTEGER DEFAULT 0,  // ✅ Incluso da subito
  deleted INTEGER DEFAULT 0,
  deletedAt DATETIME,
  deletedByAdminId INTEGER
);
```

### 2. ALTER TABLE come Fallback

Gli `ALTER TABLE` rimangono per **compatibilità con database esistenti**:

```javascript
// Questi comandi servono solo per aggiornamenti da vecchie versioni
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;  // Se esiste già, viene ignorato
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';
// ... altri campi
```

### 3. Timeout Aumentato

**Modificato `server.js`** aumentando il timeout da 1000ms a 2000ms:

```javascript
// server.js - DOPO
setTimeout(() => {
  // Creazione admin di default
}, 2000);  // ✅ Da 1000ms a 2000ms per maggiore sicurezza
```

### 4. Gestione Errori Migliorata

Aggiunta gestione errore nella query di verifica:

```javascript
db.get("SELECT * FROM employees WHERE username = 'admin'...", (err, row) => {
  if (err) {
    console.error('❌ Errore verifica admin esistente:', err.message);
    return;  // ✅ Evita di continuare se c'è un errore
  }
  // ... resto del codice
});
```

## 🎯 Risultato

### Prima (ERRORE):
```
🔧 Creazione utente amministratore di default...
❌ Errore creazione admin: SQLITE_ERROR: table employees has no column named username
```

### Dopo (SUCCESSO):
```
✓ Table employees ready
🔧 Creazione utente amministratore di default...
✅ Utente amministratore creato con successo!
📋 Credenziali di default:
   Username: admin
   Password: admin123
   Email: admin@example.com
⚠️  IMPORTANTE: Cambia la password al primo accesso!
```

## 🔄 Impatto su Database Esistenti

La modifica è **retrocompatibile**:

### Nuova Installazione (Database Vuoto)
- ✅ Tabella creata direttamente con schema completo
- ✅ Admin creato correttamente
- ✅ Nessun errore

### Aggiornamento (Database Esistente)
- ✅ `CREATE TABLE IF NOT EXISTS` → Non fa nulla (tabella esiste già)
- ✅ `ALTER TABLE ADD COLUMN` → Aggiunge solo colonne mancanti
- ✅ Nessun dato perso
- ✅ Compatibilità totale

## 📋 Test Effettuati

### Test 1: Nuova Installazione
```bash
# Raspberry Pi pulito
rm -f database.db
node server.js
```
**Risultato:** ✅ Admin creato correttamente

### Test 2: Database Esistente con Vecchio Schema
```bash
# Database con solo (id, name, email, password, isAdmin)
node server.js
```
**Risultato:** ✅ Colonne aggiunte, nessun errore

### Test 3: Database Già Aggiornato
```bash
# Database già con username e role
node server.js
```
**Risultato:** ✅ Nessuna modifica, funziona normalmente

## 🛠️ Come Applicare il Fix sul Raspberry

### ⚡ Fix Rapido (1 comando)

Se ricevi l'errore `no such column: username`, esegui questo sul Raspberry:

```bash
cd ~/ingresso_uscita_server
bash <(wget -qO- https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/quick_fix.sh)
```

Oppure:

```bash
cd ~/ingresso_uscita_server
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/quick_fix.sh
bash quick_fix.sh
sudo systemctl restart ingresso-uscita
```

### 📋 Fix Completo (Script Interattivo)

```bash
cd ~
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/fix_database_schema.sh
bash fix_database_schema.sh
```

Questo script:
- ✅ Crea backup automatico del database
- ✅ Aggiunge tutte le colonne mancanti
- ✅ Crea admin di default se non esiste
- ✅ Mostra elenco utenti
- ✅ Fornisce istruzioni per riavvio

### 🔧 Fix Manuale (Se Preferisci)

```bash
# 1. Ferma il servizio
sudo systemctl stop ingresso-uscita

# 2. Entra nella directory
cd ~/ingresso_uscita_server

# 3. Backup database
cp database.db database_backup_$(date +%Y%m%d_%H%M%S).db

# 4. Applica le modifiche
sqlite3 database.db << 'EOF'
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';
ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1;
ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0;
ALTER TABLE employees ADD COLUMN deleted INTEGER DEFAULT 0;
ALTER TABLE employees ADD COLUMN deletedAt DATETIME;
ALTER TABLE employees ADD COLUMN deletedByAdminId INTEGER;

-- Crea admin di default
INSERT INTO employees (name, username, email, password, isAdmin, role, isActive) 
VALUES ('Admin', 'admin', 'admin@example.com', 'admin123', 1, 'admin', 1);
EOF

# 5. Riavvia il servizio
sudo systemctl start ingresso-uscita

# 6. Verifica
sudo journalctl -u ingresso-uscita -f
```

### Metodo 1: Aggiornamento (Consigliato)
```bash
cd ~
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/update_server.sh
bash update_server.sh
```

### Metodo 2: Manuale
```bash
cd ~/ingresso_uscita_server

# Backup database
cp database.db database.db.backup

# Scarica file aggiornati
wget -O db.js https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/db.js
wget -O server.js https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/server.js

# Se il database è completamente vuoto (nessun dato da preservare)
rm database.db

# Riavvia server
sudo systemctl restart ingresso-uscita
```

### Metodo 3: Fix Database Esistente (Se Admin Non Creato)
```bash
cd ~/ingresso_uscita_server

# Aggiungi colonne manualmente
sqlite3 database.db << 'EOF'
ALTER TABLE employees ADD COLUMN username TEXT UNIQUE;
ALTER TABLE employees ADD COLUMN role TEXT DEFAULT 'employee';
ALTER TABLE employees ADD COLUMN isActive INTEGER DEFAULT 1;
ALTER TABLE employees ADD COLUMN allowNightShift INTEGER DEFAULT 0;

-- Crea admin manualmente
INSERT INTO employees (name, username, email, password, isAdmin, role, isActive) 
VALUES ('Admin', 'admin', 'admin@example.com', 'admin123', 1, 'admin', 1);
EOF

echo "✅ Fix applicato. Riavvia il server."
```

## 📚 File Modificati

1. **server/db.js**
   - Schema CREATE TABLE aggiornato con tutte le colonne
   - ALTER TABLE come fallback per database esistenti

2. **server/server.js**
   - Timeout aumentato a 2000ms
   - Gestione errori migliorata
   - Messaggi più informativi

## 🔗 Documentazione Correlata

- **CREDENZIALI_DEFAULT.md** - Credenziali di default per nuove installazioni
- **CHANGELOG_USERNAME_AUTH.md** - Dettagli migrazione autenticazione
- **FIX_SETUP_MIGRATE_FILE.md** - Fix file migrazione mancante

---

**Data fix:** 20 Ottobre 2025  
**Versione:** v1.2.0  
**Tipo:** Database schema initialization  
**Impatto:** Risolve errore al primo avvio su installazioni nuove
