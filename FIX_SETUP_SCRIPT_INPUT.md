# Fix: Setup Script Input Non Funzionante con curl | bash

**Data**: 20 Ottobre 2025  
**Problema**: Lo script di setup non riusciva a leggere l'input utente quando eseguito con `curl | bash`  
**Status**: ✅ RISOLTO

---

## 🔴 Problema Riscontrato

### Sintomo
Quando lo script `setup_server_fixed.sh` veniva eseguito con:
```bash
curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh | bash
```

Il menu di selezione per la gestione del server non funzionava:
```
Scegli come vuoi gestire il server:

1) systemd (servizio di sistema - CONSIGLIATO per Raspberry Pi)
2) PM2 (process manager con monitoraggio)
3) Avvio manuale (node server.js)
4) Nessuno (configuro dopo)

Scelta [1-4]: Scelta non valida
```

Lo script saltava direttamente al messaggio "Scelta non valida" senza aspettare l'input dell'utente.

### Output del Test
```bash
pi@ras:~ $ curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh | bash
...
[9/9] Test avvio server...
✓ server.js sintatticamente corretto
✓ Server funzionante (test ping superato)

╔═══════════════════════════════════════════════════════╗
║   ✓ Setup completato con successo!                   ║
╚═══════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scegli come vuoi gestire il server:

1) systemd (servizio di sistema - CONSIGLIATO per Raspberry Pi)
2) PM2 (process manager con monitoraggio)
3) Avvio manuale (node server.js)
4) Nessuno (configuro dopo)

Scelta non valida    <-- SALTAVA DIRETTAMENTE QUI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔍 Causa Tecnica

### Il Problema con le Pipe
Quando uno script viene eseguito tramite pipe (`curl | bash`), lo **standard input (stdin)** proviene dalla pipe stessa, non dal terminale dell'utente.

**Flusso Normale**:
```
Terminale (utente digita) → stdin → Script bash → read comando
```

**Flusso con curl | bash**:
```
curl (scarica script) → pipe → bash (esegue script)
                                     ↓
                        read comando riceve EOF dalla pipe (nessun input)
```

### Codice Problematico
```bash
read -p "Scelta [1-4]: " CHOICE
# CHOICE rimane vuoto perché stdin è la pipe, non il terminale
```

### Variabile Vuota
- `read` non riceve input dal terminale
- La variabile `CHOICE` rimane vuota
- Il `case $CHOICE in` va direttamente al caso `*)` (default)
- Viene stampato "Scelta non valida"

---

## ✅ Soluzione Applicata

### Redirect a `/dev/tty`
La soluzione è redirigere lo stdin di `read` verso `/dev/tty` (il terminale corrente):

```bash
read -p "Scelta [1-4]: " CHOICE < /dev/tty
```

### Cosa fa `/dev/tty`
- **`/dev/tty`**: È un file speciale che rappresenta sempre il terminale di controllo del processo corrente
- **Redirect `< /dev/tty`**: Forza `read` a leggere dal terminale invece che da stdin
- **Risultato**: L'utente può digitare input anche quando lo script è eseguito tramite pipe

---

## 🔧 Modifiche Applicate

### File Modificato
- **File**: `setup_server_fixed.sh`
- **Linee modificate**: 6 comandi `read`

### Comando 1 - Sovrascrittura Directory (Linea 107)
```bash
# PRIMA
read -p "Sovrascrivere? (s/n) " -n 1 -r

# DOPO
read -p "Sovrascrivere? (s/n) " -n 1 -r < /dev/tty
```

### Comando 2 - Abilitazione Avvio Automatico systemd (Linea 471)
```bash
# PRIMA
read -p "$(echo -e ${YELLOW}Vuoi abilitare l\'avvio automatico? [s/N] ${NC})" -n 1 -r

# DOPO
read -p "$(echo -e ${YELLOW}Vuoi abilitare l\'avvio automatico? [s/N] ${NC})" -n 1 -r < /dev/tty
```

### Comando 3 - Avvio Server systemd (Linea 478)
```bash
# PRIMA
read -p "$(echo -e ${YELLOW}Vuoi avviare il server ora? [s/N] ${NC})" -n 1 -r

# DOPO
read -p "$(echo -e ${YELLOW}Vuoi avviare il server ora? [s/N] ${NC})" -n 1 -r < /dev/tty
```

### Comando 4 - Scelta Gestione Server (Linea 500) ⭐ CRITICO
```bash
# PRIMA
read -p "$(echo -e ${YELLOW}Scelta [1-4]: ${NC})" CHOICE

# DOPO
read -p "$(echo -e ${YELLOW}Scelta [1-4]: ${NC})" CHOICE < /dev/tty
```

### Comando 5 - Avvio Server PM2 (Linea 515)
```bash
# PRIMA
read -p "$(echo -e ${YELLOW}Vuoi avviare il server con PM2 ora? [s/N] ${NC})" -n 1 -r

# DOPO
read -p "$(echo -e ${YELLOW}Vuoi avviare il server con PM2 ora? [s/N] ${NC})" -n 1 -r < /dev/tty
```

### Comando 6 - Avvio Automatico PM2 (Linea 523)
```bash
# PRIMA
read -p "$(echo -e ${YELLOW}Vuoi configurare l\'avvio automatico con PM2? [s/N] ${NC})" -n 1 -r

# DOPO
read -p "$(echo -e ${YELLOW}Vuoi configurare l\'avvio automatico con PM2? [s/N] ${NC})" -n 1 -r < /dev/tty
```

---

## 📊 Risultato Atteso

### Prima della Fix
```bash
Scelta [1-4]: Scelta non valida
# Non aspettava input, andava direttamente a "non valida"
```

### Dopo la Fix
```bash
Scelta [1-4]: █
# Cursor lampeggiante, aspetta che l'utente digiti 1, 2, 3 o 4
```

### Esempio di Esecuzione Corretta
```bash
pi@ras:~ $ curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh | bash
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scegli come vuoi gestire il server:

1) systemd (servizio di sistema - CONSIGLIATO per Raspberry Pi)
2) PM2 (process manager con monitoraggio)
3) Avvio manuale (node server.js)
4) Nessuno (configuro dopo)

Scelta [1-4]: 1    <-- UTENTE DIGITA 1 E PREME INVIO

Creazione servizio systemd...
✓ Servizio systemd creato: ingresso-uscita
File di configurazione: /etc/systemd/system/ingresso-uscita.service

Comandi disponibili:
   sudo systemctl start ingresso-uscita      # Avvia il server
   sudo systemctl stop ingresso-uscita       # Ferma il server
   ...
```

---

## 🧪 Test e Validazione

### Metodo di Test
```bash
# Su Raspberry Pi
curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh | bash
```

### Scenari di Test

#### ✅ Test 1: Scelta systemd
```bash
Scelta [1-4]: 1
Vuoi abilitare l'avvio automatico? [s/N] s
Vuoi avviare il server ora? [s/N] s

✓ Avvio automatico abilitato
● ingresso-uscita.service - Server Ingresso/Uscita
   Active: active (running)
✓ Server avviato
```

#### ✅ Test 2: Scelta PM2
```bash
Scelta [1-4]: 2
Installazione PM2...
✓ PM2 installato

Vuoi avviare il server con PM2 ora? [s/N] s
✓ Server avviato con PM2

Vuoi configurare l'avvio automatico con PM2? [s/N] s
[PM2] Generating system startup script...
```

#### ✅ Test 3: Scelta Manuale
```bash
Scelta [1-4]: 3
Hai scelto avvio manuale

Per avviare il server:
   cd /home/pi/ingresso_uscita_server
   node server.js
```

#### ✅ Test 4: Nessuna Configurazione
```bash
Scelta [1-4]: 4
Nessuna configurazione automatica
📱 Configura l'app Flutter con IP: 192.168.1.9
```

#### ✅ Test 5: Input Non Valido
```bash
Scelta [1-4]: 5
Scelta non valida
# Continua comunque agli step successivi
```

---

## 🔐 Sicurezza e Compatibilità

### Sicurezza di `/dev/tty`
- ✅ **Safe**: `/dev/tty` è uno standard POSIX presente su tutti i sistemi Unix/Linux
- ✅ **Non privilegiato**: Non richiede permessi root
- ✅ **Isolato**: Non espone dati sensibili

### Compatibilità Sistemi

| Sistema Operativo | `/dev/tty` Supporto | Testato |
|-------------------|---------------------|---------|
| Raspberry Pi OS | ✅ Sì | ✅ Sì |
| Ubuntu | ✅ Sì | ✅ Sì |
| Debian | ✅ Sì | ✅ Sì |
| CentOS/RHEL | ✅ Sì | ⚠️ Non testato |
| macOS | ✅ Sì | ⚠️ Non testato |
| Alpine Linux | ✅ Sì | ⚠️ Non testato |

### Modalità di Esecuzione

| Metodo | Funziona PRIMA | Funziona DOPO |
|--------|----------------|---------------|
| `bash setup_server_fixed.sh` | ✅ Sì | ✅ Sì |
| `curl \| bash` | ❌ NO | ✅ Sì |
| `wget -O - \| bash` | ❌ NO | ✅ Sì |
| Esecuzione remota SSH | ✅ Sì | ✅ Sì |

---

## 📚 Informazioni Tecniche Aggiuntive

### Perché `/dev/tty` Funziona
1. **Indipendenza da stdin**: `/dev/tty` è un device file che punta sempre al terminale di controllo
2. **Persistenza**: Rimane disponibile anche quando stdin è rediretto
3. **Standard POSIX**: Parte dello standard POSIX.1-2001, garantito su tutti i sistemi Unix

### Alternativa: Script Temporaneo
Un altro metodo sarebbe stato scaricare lo script in un file temporaneo:

```bash
# Metodo alternativo (NON usato)
curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh -o /tmp/setup.sh
bash /tmp/setup.sh
rm /tmp/setup.sh
```

**Vantaggi della soluzione `/dev/tty`**:
- ✅ Più elegante (one-liner)
- ✅ Non lascia file temporanei
- ✅ Funziona anche con pipe
- ✅ Non richiede permessi di scrittura su `/tmp`

---

## 🚀 Deployment

### File Aggiornato
Il file `setup_server_fixed.sh` è stato aggiornato nel repository:
```bash
https://github.com/fragarray/ingresso_uscita/blob/main/setup_server_fixed.sh
```

### Aggiornamenti Versione 1.1.4
**Data**: 20 Ottobre 2025

#### Fix Aggiuntivo: npm install bloccato
Durante i test è emerso un secondo problema: il comando `npm install` si bloccava quando eseguito tramite `curl | bash`.

**Problema**:
```bash
if npm install --quiet --no-progress 2>&1 | tee /tmp/npm_install.log | grep -E "ERR!|warn"; then
```

- Il pipe con `grep` bloccava l'output fino alla fine del comando
- L'utente non vedeva alcun feedback durante l'installazione (5-10 minuti)
- Sembrava che lo script si fosse bloccato

**Soluzione**:
```bash
echo -e "${YELLOW}Installazione in corso... (potrebbero apparire warning, è normale)${NC}"
npm install 2>&1 | tee /tmp/npm_install.log
NPM_EXIT_CODE=${PIPESTATUS[0]}

if [ $NPM_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}✗ Errore durante l'installazione npm${NC}"
    echo -e "${YELLOW}Controlla il log: /tmp/npm_install.log${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Installazione npm completata${NC}"
```

**Vantaggi**:
- ✅ Output in tempo reale durante l'installazione
- ✅ L'utente vede i warning npm man mano che appaiono
- ✅ Salva comunque il log completo in `/tmp/npm_install.log`
- ✅ Controlla l'exit code con `${PIPESTATUS[0]}`
- ✅ Esce con errore chiaro se npm fallisce

### Come Usare la Versione Aggiornata
```bash
# Su Raspberry Pi, esegui:
curl -fsSL https://raw.githubusercontent.com/fragarray/ingresso_uscita/main/setup_server_fixed.sh | bash

# Quando richiesto, scegli l'opzione desiderata:
# 1 = systemd (CONSIGLIATO per Raspberry Pi)
# 2 = PM2
# 3 = Manuale
# 4 = Nessuna configurazione
```

### Verifica Versione
Lo script mostra la versione all'inizio:
```
╔═══════════════════════════════════════════════════════╗
║   Setup Server Ingresso/Uscita v1.1.3                ║
║   Raspberry Pi 5 / Linux ARM64/x64                   ║
║   Con Audit Trail + Report Excel + Email            ║
╚═══════════════════════════════════════════════════════╝
```

---

## ✅ Checklist di Verifica

- [x] Identificato problema con `read` in pipe
- [x] Applicato fix con `< /dev/tty` a tutti i comandi `read`
- [x] Testato con `curl | bash` su Raspberry Pi
- [x] Verificato input utente funzionante
- [x] Testata scelta systemd
- [x] Verificato servizio systemd creato correttamente
- [x] Documentato problema e soluzione
- [x] File aggiornato su GitHub

---

## 🎯 Conclusione

Il problema era causato dall'esecuzione dello script tramite pipe (`curl | bash`), che faceva sì che `read` non potesse accedere all'input del terminale. La soluzione è stata semplice ma efficace: redirigere tutti i comandi `read` verso `/dev/tty`, permettendo allo script di leggere l'input direttamente dal terminale dell'utente.

Ora lo script funziona perfettamente sia quando eseguito direttamente (`bash script.sh`) sia quando eseguito tramite pipe (`curl | bash`).

**Status**: ✅ **RISOLTO E TESTATO**

---

**File Correlati**:
- `setup_server_fixed.sh` - Script aggiornato con fix
- `SETUP_SERVER_COMPARISON.md` - Confronto con versione precedente
- Questo documento - Spiegazione del problema e soluzione
