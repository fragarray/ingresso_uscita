# ⚡ FIX RAPIDO - Errore "no such column: username"

## 🔴 Errore Riscontrato

```
❌ [LOGIN] Errore database: SQLITE_ERROR: no such column: username
```

## ✅ Soluzione Veloce (30 secondi)

Sul **Raspberry Pi**, esegui questi comandi:

```bash
cd ~/ingresso_uscita_server
wget https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/server/quick_fix.sh
bash quick_fix.sh
sudo systemctl restart ingresso-uscita
```

### Cosa fa lo script:
1. ✅ Crea backup del database
2. ✅ Aggiunge colonne mancanti (`username`, `role`, ecc.)
3. ✅ Crea utente admin di default
4. ✅ Mostra credenziali

### Credenziali dopo il fix:
```
Username: admin
Password: admin123
```

## 🧪 Verifica Funzionamento

```bash
# Controlla che il servizio sia attivo
sudo systemctl status ingresso-uscita

# Monitora i log
sudo journalctl -u ingresso-uscita -f
```

Dovresti vedere:
```
✅ Utente amministratore creato con successo!
📋 Credenziali di default:
   Username: admin
   Password: admin123
```

## 🔍 Verifica Utenti nel Database

```bash
cd ~/ingresso_uscita_server
node check_users.js
```

Oppure:

```bash
sqlite3 database.db "SELECT id, name, username, email, role FROM employees;"
```

## 📚 Documentazione Completa

Per maggiori dettagli vedi:
- **FIX_ADMIN_CREATION_ERROR.md** - Spiegazione completa del problema
- **CREDENZIALI_DEFAULT.md** - Gestione credenziali
- **fix_database_schema.sh** - Script interattivo completo

---

**Ultimo aggiornamento:** 20 Ottobre 2025  
**Versione:** v1.2.0  
**Tipo:** Database schema fix
