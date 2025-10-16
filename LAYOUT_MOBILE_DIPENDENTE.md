# Layout Mobile Ottimizzato - Pagina Dipendente

## 📱 Design Responsive per Smartphone

### Layout Card Cantiere - Vista Orizzontale

```
┌─────────────────────────────────────────────────────────┐
│ 🔴                                               [QUI]  │
│                                                          │
│  ┌──────┐  NOME CANTIERE                    ┌────────┐ │
│  │ 🏢  │  Via Roma 123, Milano              │ 📋 Info│ │
│  │ Icon│  45.4642, 9.1900                   │        │ │
│  └──────┘                                    │ Descr- │ │
│           📍 123m                            │ izione │ │
│                                              │ comple-│ │
│                                              │ ta qui │ │
│                                              └────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 🎨 Struttura Layout

#### **SINISTRA (60% larghezza)**
1. **Icona** (48x48px)
   - Gradiente colorato basato su stato (verde/rosso/giallo)
   - BorderRadius: 14
   - Shadow dinamica

2. **Nome Cantiere**
   - Font: 15px, Bold
   - Color: Grey[900] (nero)
   - MaxLines: 2
   - Height: 1.2

3. **Indirizzo**
   - Icon: place_outlined (14px)
   - Font: 11px
   - Color: Grey[700]
   - MaxLines: 2
   - Height: 1.3

4. **Coordinate GPS**
   - Icon: gps_fixed (13px)
   - Font: 10px, Monospace
   - Color: Grey[600]
   - Format: 4 decimali (es: 45.4642, 9.1900)
   - MaxLines: 1

5. **Badge Distanza**
   - Background: Grey[100]
   - Border: Grey[300]
   - Icon: navigation_rounded (11px)
   - Font: 11px, Bold

#### **DESTRA (40% larghezza)** - Se descrizione presente
1. **Container Descrizione**
   - Background: color.withOpacity(0.08) - tono del colore stato
   - Border: color.withOpacity(0.2), width 1.5
   - BorderRadius: 12
   - Padding: 10px

2. **Header "Info"**
   - Icon: info_outline (13px)
   - Font: 10px, Bold
   - Color: colore dello stato
   - LetterSpacing: 0.5

3. **Testo Descrizione**
   - Font: 11px
   - Color: Grey[800]
   - Height: 1.4
   - MaxLines: 6
   - Overflow: ellipsis

---

## 📐 Dimensioni Responsive

### Grid Layout per Dispositivo

| Larghezza Schermo | Colonne | AspectRatio | Uso Tipico |
|-------------------|---------|-------------|------------|
| < 600px          | **1**   | 2.2         | 📱 Smartphone |
| 600px - 900px    | **2**   | 1.4         | 📱 Smartphone Large / Tablet Small |
| 900px - 1200px   | **3**   | 1.6         | 💻 Tablet / Desktop Small |
| > 1200px         | **4**   | 1.8         | 🖥️ Desktop Large |

### Smartphone Portrait (< 600px)
- **1 colonna** per massima leggibilità
- **AspectRatio 2.2** → Card più larghe che alte
- Descrizione ben leggibile a destra
- Touch target ottimizzato (card intere)

---

## 🎯 Font Sizes Ottimizzate per Mobile

| Elemento | Font Size | Weight | Leggibilità |
|----------|-----------|--------|-------------|
| Nome Cantiere | 15px | Bold | ⭐⭐⭐⭐⭐ Ottima |
| Indirizzo | 11px | Normal | ⭐⭐⭐⭐ Buona |
| Coordinate | 10px | Normal | ⭐⭐⭐ Accettabile |
| Distanza Badge | 11px | Bold | ⭐⭐⭐⭐ Buona |
| Descrizione | 11px | Normal | ⭐⭐⭐⭐ Buona |
| Header "Info" | 10px | Bold | ⭐⭐⭐⭐ Buona |
| Badge "QUI" | 10px | Bold | ⭐⭐⭐⭐⭐ Ottima |

---

## 🎨 Colori per Stato

### Verde (OUT - Disponibile)
```dart
Colors.green[700]  // Più vicino
Colors.green[300]  // Altri cantieri
```

### Rosso (IN - Disabilitato)
```dart
Colors.red[400]  // Cantieri non disponibili
```

### Giallo (IN - Corrente)
```dart
Colors.yellow[700]  // Cantiere dove sei timbrato
```

---

## 📏 Spacing e Padding

### Card Esterna
- **Padding**: 14px (ottimizzato per touch)
- **BorderRadius**: 20px
- **Border**: 2px normale, 3px se corrente
- **Shadow**: Dynamic (più intensa se corrente)

### Layout Interno
- **SizedBox** tra icona e nome: 10px
- **SizedBox** tra nome e indirizzo: 6px
- **SizedBox** tra indirizzo e coordinate: 5px
- **SizedBox** tra coordinate e distanza: 8px
- **Gap** sinistra-destra: 10px

### Container Descrizione
- **Padding interno**: 10px
- **BorderRadius**: 12px
- **Border width**: 1.5px
- **Gap** header-testo: 6px

---

## 🔍 Visibilità e Contrasti

### Icone
- **place_outlined**: Grey[600] - Visibile
- **gps_fixed**: Grey[600] - Visibile
- **navigation_rounded**: Grey[700] - Visibile
- **info_outline**: Color dinamico (verde/rosso/giallo) - Molto visibile

### Testi
- **Nome**: Grey[900] - Contrasto alto ⭐⭐⭐⭐⭐
- **Indirizzo**: Grey[700] - Contrasto medio-alto ⭐⭐⭐⭐
- **Coordinate**: Grey[600] - Contrasto medio ⭐⭐⭐
- **Descrizione**: Grey[800] - Contrasto alto ⭐⭐⭐⭐

---

## 🎯 Touch Targets

### Dimensioni Minime (Apple & Android Guidelines)
- ✅ **Card intera**: Touch target > 44x44px
- ✅ **Icona**: 48x48px (ideale per thumb)
- ✅ **Badge distanza**: Height 22px + padding (adeguato)

### Interazioni
1. **Tap normale** → Timbratura con conferma
2. **Long press** → Dialog info complete
3. **Area attiva**: Tutta la card

---

## 📱 Esempio Concreto (iPhone 14 - 390x844)

### Con 1 Cantiere Visibile
```
┌─────────────────────────────────────────────────────────┐
│ Banner Istruzioni (gradiente blu/verde)                │
│ "Tocca un cantiere per timbrare..."                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 🔴 Pallino verde                                 [QUI]  │
│                                                          │
│  ┌──────┐                                               │
│  │ 🏢  │  NOME CANTIERE LUNGO           ┌──────────────┐│
│  │48x48│  CHE PUO ANDARE SU 2 RIGHE     │ 📋 Info     ││
│  └──────┘                                │              ││
│           📍 Via Roma 123, Milano        │ Cantiere in ││
│           🌍 45.4642, 9.1900            │ fase di     ││
│           📍 123m                        │ ristruttura-││
│                                          │ zione. Acc- ││
│                                          │ esso lat... ││
│                                          └──────────────┘│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ (Altri cantieri sotto, scroll verticale)                │
└─────────────────────────────────────────────────────────┘
```

---

## ✨ Vantaggi del Nuovo Layout

### ✅ Leggibilità
- Nome e indirizzo grandi e chiari
- Coordinate visibili ma non invasive
- Descrizione ben separata a destra
- Contrasti ottimizzati per lettura rapida

### ✅ Efficienza Spaziale
- 1 cantiere per riga su smartphone → Nessun affollamento
- Descrizione utilizza spazio a destra → No spazio sprecato
- Informazioni gerarchiche → Priorità visiva corretta

### ✅ Touch-Friendly
- Card intere tappabili (non solo icone)
- Area di touch > 44px (standard iOS/Android)
- Long press intuitivo per dettagli

### ✅ Accessibilità
- Font sizes conformi a WCAG
- Contrasti colore adeguati
- Icone riconoscibili
- Informazioni ridondanti (icona + testo)

---

## 🎭 Stati della Card

### 1. OUT - Cantiere Disponibile (Verde)
```dart
border: Colors.green[300].withOpacity(0.3), width: 2
backgroundColor: Colors.white
descriptionContainer: Colors.green.withOpacity(0.08)
descriptionBorder: Colors.green.withOpacity(0.2)
```

### 2. OUT - Cantiere Più Vicino (Verde Scuro)
```dart
border: Colors.green[700].withOpacity(0.3), width: 2
pallino: Positioned top-left, verde con glow
```

### 3. IN - Cantiere Corrente (Giallo)
```dart
border: Colors.yellow[700], width: 3
shadow: blurRadius 16, spreadRadius 2
badge "QUI": Positioned top-right
descriptionContainer: Colors.yellow.withOpacity(0.08)
```

### 4. IN - Altri Cantieri (Rosso - Disabilitati)
```dart
border: Colors.red[400].withOpacity(0.3), width: 2
descriptionContainer: Colors.red.withOpacity(0.08)
```

---

## 🔧 Testing Checklist

### Da Testare su Smartphone
- [ ] Card occupano tutta la larghezza (1 colonna)
- [ ] Nome cantiere leggibile a prima vista
- [ ] Indirizzo completo visibile
- [ ] Coordinate visibili ma non invasive
- [ ] Descrizione leggibile a destra (se presente)
- [ ] Badge distanza ben visibile
- [ ] Tap funziona su tutta la card
- [ ] Long press mostra dialog completo
- [ ] Scroll verticale fluido
- [ ] Colori distinguibili (verde/rosso/giallo)
- [ ] Badge "QUI" visibile senza sovrapporre testo
- [ ] Pallino verde cantiere vicino non copre icona

### Da Testare su Tablet
- [ ] 2-3 colonne a seconda dimensione
- [ ] Layout mantiene leggibilità
- [ ] Descrizioni non tagliate

### Da Testare su Desktop
- [ ] 3-4 colonne ben distribuite
- [ ] Tutte le info visibili senza scroll
- [ ] Aspect ratio corretto

---

**Data aggiornamento**: 16 Ottobre 2025  
**Versione Layout**: 3.0 Mobile-First  
**Compatibilità**: iOS 12+, Android 8+  
**Status**: ✅ Pronto per testing
