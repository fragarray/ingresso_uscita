# 🔐 Credenziali di Accesso Default

## 📋 Nuova Installazione

Quando installi il server su un Raspberry Pi **completamente pulito** (senza database preesistente), il sistema crea automaticamente un utente amministratore al primo avvio.

### 👤 Credenziali Amministratore Default

```
Username: admin
Password: admin123
Email: admin@example.com
Ruolo: Amministratore
```

### 🚀 Come Accedere

1. **Avvia l'app Flutter** sul tuo dispositivo
2. **Configura l'IP del server** nelle impostazioni (es. 192.168.1.100)
3. **Login** con:
   - Username: `admin`
   - Password: `admin123`

### ⚠️ IMPORTANTE - Sicurezza

**Dopo il primo accesso:**

1. ✅ **Cambia immediatamente la password** dell'admin
2. ✅ **Crea gli altri utenti** (dipendenti, capicantiere)
3. ✅ **Personalizza i dati** (nome, email se necessario)

### 🔄 Come Cambiare la Password Admin

1. Login come admin
2. Vai su **Personale** → **Lista Dipendenti**
3. Trova "Admin" e clicca **Modifica**
4. Cambia la password
5. Salva

---

## 🆕 Aggiornamento da Versione Vecchia

Se stai **aggiornando** da una versione precedente (v1.1.x), le credenziali sono **diverse** perché sono state migrate.

### 📊 Dopo Migrazione

Le credenziali dipendono dal database esistente. Lo script `migrate_username_auth.js` genera gli username dalle email:

**Esempio conversioni:**
- `admin@example.com` → username: `admin`
- `mario.rossi@gmail.com` → username: `mario.rossi`
- `pippo@site.it` → username: `pippo`

**Se ci sono duplicati**, aggiunge suffisso numerico:
- Primo `admin@example.com` → `admin`
- Secondo `admin@other.com` → `admin_1`
- Terzo `admin@third.com` → `admin_2`

### 📝 Credenziali Post-Migrazione

Consulta il log della migrazione per vedere gli username generati:

```bash
cd ~/ingresso_uscita_server
cat migration_*.log  # Se salvato in un file
```

Oppure usa lo script di verifica:

```bash
cd ~/ingresso_uscita_server
node check_users.js
```

---

## 🔍 Verifica Utenti nel Database

### Script di Verifica

Se non ricordi le credenziali, usa questo script per vedere tutti gli utenti:

```bash
cd ~/ingresso_uscita_server
node check_users.js
```

**Output esempio:**
```
👤 ID: 1
   Nome: Admin
   Username: admin
   Email: admin@example.com
   Password: "admin123"
   Role: admin
   isActive: 1
```

### Creazione Script Manuale (se check_users.js non esiste)

```bash
cd ~/ingresso_uscita_server
cat > show_users.js << 'EOF'
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('database.db');

db.all('SELECT id, name, username, email, password, role, isActive FROM employees', (err, rows) => {
  if (err) {
    console.error('Errore:', err);
  } else {
    console.log('\n📊 UTENTI NEL DATABASE:\n');
    rows.forEach(r => {
      console.log(`👤 ID: ${r.id}`);
      console.log(`   Nome: ${r.name}`);
      console.log(`   Username: ${r.username}`);
      console.log(`   Email: ${r.email}`);
      console.log(`   Password: "${r.password}"`);
      console.log(`   Role: ${r.role}`);
      console.log(`   Active: ${r.isActive}\n`);
    });
  }
  db.close();
});
EOF

node show_users.js
```

---

## 🎯 Scenari Comuni

### Scenario 1: Primo Setup (Raspberry pulito)
✅ **Usa credenziali default:**
- Username: `admin`
- Password: `admin123`

### Scenario 2: Dopo Migrazione da v1.1.x
✅ **Consulta log migrazione** o usa `node check_users.js`
- Username: generato da email
- Password: invariata

### Scenario 3: Password Dimenticata
✅ **Opzione A - Reset manuale (richiede accesso SSH):**

```bash
cd ~/ingresso_uscita_server
sqlite3 database.db "UPDATE employees SET password = 'nuova123' WHERE username = 'admin';"
```

✅ **Opzione B - Crea nuovo admin:**

```bash
cd ~/ingresso_uscita_server
sqlite3 database.db "INSERT INTO employees (name, username, email, password, role, isAdmin, isActive) VALUES ('TempAdmin', 'temp_admin', 'temp@temp.com', 'temp123', 'admin', 1, 1);"
```

Poi login con:
- Username: `temp_admin`
- Password: `temp123`

### Scenario 4: Tutti gli Admin Bloccati
✅ **Reset completo database (ATTENZIONE: perde tutti i dati):**

```bash
cd ~/ingresso_uscita_server
rm database.db
sudo systemctl restart ingresso-uscita
# Il server ricreerà il database con admin default
```

---

## 📚 FAQ

### D: Qual è la password di default?
**R:** Per nuove installazioni: `admin123`

### D: Qual è lo username di default?
**R:** Per nuove installazioni: `admin`

### D: Le password sono criptate?
**R:** No, attualmente le password sono in **plain text** nel database. Questo è per semplicità in ambienti interni/privati. Se serve maggiore sicurezza, considera di implementare bcrypt.

### D: Posso cambiare username dopo la creazione?
**R:** Sì, dall'interfaccia admin puoi modificare qualsiasi campo (tranne username che è readonly per evitare problemi). Per cambiare username serve accesso diretto al database.

### D: Cosa succede se creo due admin con stessa email?
**R:** Il sistema genera username univoci con suffissi (`admin`, `admin_1`, ecc.)

### D: Posso eliminare l'admin di default?
**R:** Sì, ma assicurati di avere almeno un altro admin attivo prima di farlo!

---

## 🛠️ Troubleshooting

### "Credenziali non valide" anche con credenziali corrette

**Causa:** Database non sincronizzato o app non aggiornata

**Soluzione:**
1. Verifica credenziali nel database: `node check_users.js`
2. Ricompila app Flutter: `flutter clean && flutter run`
3. Riavvia server: `sudo systemctl restart ingresso-uscita`

### Server non crea admin di default

**Causa:** Database già esistente con utenti vecchi

**Soluzione:**
Il server crea admin solo se il database è vuoto. Se hai già utenti, usa la migrazione:
```bash
node migrate_username_auth.js
```

### Non riesco ad accedere da app mobile

**Verifica:**
1. ✅ Server raggiungibile: `ping <IP_RASPBERRY>`
2. ✅ Porta aperta: `curl http://<IP_RASPBERRY>:3000/api/ping`
3. ✅ Firewall: `sudo ufw allow 3000/tcp`
4. ✅ IP configurato correttamente nell'app

---

## 📞 Riepilogo Veloce

| Situazione | Username | Password |
|------------|----------|----------|
| **Nuova installazione** | `admin` | `admin123` |
| **Dopo migrazione** | Vedi log migrazione | Password invariata |
| **Password dimenticata** | Usa `check_users.js` | Reset manuale |

---

**Ultimo aggiornamento:** 20 Ottobre 2025  
**Versione server:** v1.2.0  
**Compatibilità:** Tutte le piattaforme (Raspberry Pi, Linux, Windows)
