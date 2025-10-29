# 📱 Sistema QR Code per Timbrature - Guida Utente

## 🎯 Panoramica

È stata implementata la funzionalità QR Code per permettere ai dipendenti di timbrare automaticamente nei cantieri tramite scansione QR con la fotocamera del dispositivo.

## 🔧 Funzionalità Implementate

### Per gli Amministratori

**Generazione QR Code:**
1. Aprire l'app SinergyWork come Admin
2. Andare sul tab "Cantieri"
3. Toccare su un cantiere nella mappa
4. Nel dialog dei dettagli, toccare il pulsante **"GENERA QR CODE"** (blu)
5. Si aprirà un dialog con:
   - QR code stampabile/salvabile
   - Informazioni sul cantiere
   - Istruzioni per l'uso
6. Toccare **"SALVA PNG"** per salvare il QR come immagine ad alta risoluzione

**Stampa e Posizionamento:**
- Stampare il QR code salvato (consigliato: 10x10 cm minimo)
- Posizionare il QR nel cantiere in zona visibile e protetta dalle intemperie
- Il QR code è valido per 24 ore dalla generazione

### Per i Dipendenti

**Timbratura con QR:**
1. **NON aprire l'app SinergyWork** (importante!)
2. Aprire la **fotocamera nativa** del dispositivo (iOS Camera, Android Camera)
3. Inquadrare il QR code del cantiere
4. Apparirà una notifica: "Apri in SinergyWork" - toccarla
5. L'app si apre automaticamente mostrando il login
6. Nel frattempo il GPS si carica in background
7. Inserire username e password e fare LOGIN
8. **La timbratura avviene automaticamente** dopo il login
9. Viene mostrato un dialog di conferma con i dettagli

**App Compatibili per Scansione:**
- ✅ Fotocamera nativa iOS/Android (consigliato)
- ✅ Google Lens
- ✅ App QR Scanner di terze parti
- ✅ Browser Chrome/Safari con scanner integrato

## 🔄 Flusso Automatico

```
Scansiona QR → Apri App → GPS Preload → Login → Timbratura Automatica → Conferma
```

**Caratteristiche Automatiche:**
- ✅ **Tipo automatico**: Se ultimo record era IN → timbra OUT, se era OUT → timbra IN
- ✅ **GPS precaricato**: Si attiva durante il login, non prima
- ✅ **Validazione sicura**: Firma crittografica e scadenza 24h
- ✅ **Feedback completo**: Dialog con tipo, orario, posizione GPS e accuratezza

## 🛠️ Configurazione Tecnica

**Deep Link Schema:** `sinergywork://scan/{base64_data}`

**Sicurezza:**
- Firma SHA-256 con chiave segreta
- Scadenza QR automatica dopo 24 ore
- Validazione GPS e posizione

**Dati QR Code:**
```json
{
  "cantiere_id": "CANT-timestamp-001",
  "cantiere_name": "Nome Cantiere",
  "server_host": "IP o dominio server",
  "server_port": 8080,
  "timestamp": 1730067200,
  "signature": "hash SHA-256"
}
```

## 🔍 Risoluzione Problemi

**QR non viene rilevato:**
- Verificare buona illuminazione
- Avvicinare il dispositivo (distanza 20-50cm)
- Provare con app QR Scanner alternativa

**App non si apre dopo scansione:**
- Verificare che SinergyWork sia installata
- Reinstallare l'app se necessario
- Verificare che il QR non sia danneggiato

**GPS non si carica:**
- Verificare permessi location nelle impostazioni
- Abilitare GPS/Location sul dispositivo
- Uscire all'aperto se in zona coperta

**Timbratura non funziona:**
- Verificare che QR non sia scaduto (max 24h)
- Controllare connessione internet
- Verificare che server sia raggiungibile

## 📋 Vantaggi del Sistema

✅ **UX Migliorata**: Fotocamera nativa = più veloce e familiare
✅ **Sicurezza**: Firma crittografica e scadenza automatica  
✅ **Automazione**: Login → Timbratura automatica senza click aggiuntivi
✅ **Compatibilità**: Funziona con qualsiasi scanner QR
✅ **Accuratezza**: GPS precaricato per timbrature precise

## 🚀 Prossimi Sviluppi

- Integrazione sistema di autenticazione token
- API server per gestione timbrature QR
- Supporto iOS (se necessario)
- Notifiche push per conferma timbratura

---

**Versione:** 1.0  
**Data:** 29 Ottobre 2024  
**Compatibilità:** Android, Windows (Linux in sviluppo)