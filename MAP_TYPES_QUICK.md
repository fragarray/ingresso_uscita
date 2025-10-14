# 🗺️ Guida Rapida - Cambio Tipo Mappa

## ❌ Google Maps NON Funziona su Windows

**Perché?** Il pacchetto `google_maps_flutter` usa widget nativi Android/iOS che non esistono su Windows Desktop.

| Piattaforma | Google Maps |
|-------------|-------------|
| Android     | ✅ Funziona |
| iOS         | ✅ Funziona |
| **Windows** | ❌ **NO**   |
| macOS       | ❌ NO       |
| Linux       | ❌ NO       |

---

## ✅ Soluzione: 2 Tipi di Mappa Cross-Platform

### 🛣️ 1. Stradale (Default)
- **Provider:** CartoDB Positron (Light)
- **Cosa vedi:** Strade, nomi vie principali, città, quartieri
- **Quando usarla:** Navigazione urbana, ricerca indirizzi
- **Caratteristiche:** Mappa pulita, stile professionale, meno POI
- **Gratuita:** ✅ Uso commerciale permesso

### 🛰️ 2. Satellite Ibrida
- **Provider:** ESRI World Imagery + CartoDB Labels overlay
- **Cosa vedi:** Foto satellitari reali + nomi strade sovrapposti
- **Quando usarla:** Vedere edifici reali, terreni, campi
- **Caratteristiche:** **Foto reale CON nomi strade!** (migliore di entrambi i mondi)
- **Gratuita:** ✅ Nessuna API key richiesta

---

## 🎮 Come Usarlo

### UI Layout
```
┌────────────────────────────────┐
│  [🔍 Cerca indirizzo...]       │
│                                │
│         [MAPPA]                │
│                                │
│  [🗺️] ← Cambia tipo            │
│  [+]  ← Zoom in               │
│  [−]  ← Zoom out              │
└────────────────────────────────┘
```

### Funzionamento
1. **Click sul pulsante 🗺️** (icona layers a sinistra)
2. La mappa cambia tipo:
   - Click: Stradale ⇄ **Satellite Ibrida**
3. **Passa sopra** il pulsante per vedere il tipo corrente

---

## 📸 Confronto Visivo

### Stradale (Pulita)
```
┌─────────────────────────┐
│ Via Roma    Via Milano  │
│    │           │        │
│    ├───────────┤        │
│    │   Duomo   │        │
│    │           │        │
│ Piazza Dante            │
└─────────────────────────┘
```
✅ Nomi strade e città  
✅ Quartieri  
✅ Mappa pulita (meno POI)  
✅ Ricerca indirizzo

### Satellite Ibrida (Foto + Nomi)
```
┌─────────────────────────┐
│  [Foto Aerea + Labels]  │
│ Via Roma   🏠🏠🏠       │
│   │  🛣️               │
│   │ 🌳🌳🌾🌾          │
│ Piazza Dante            │
└─────────────────────────┘
```
✅ Foto satellitare reale  
✅ **Nomi strade sovrapposti** (novità!)  
✅ Dettagli visivi  
✅ Meglio della sola foto

---

## 🎯 Quando Usare Quale Mappa

### Cantiere in Città
1. **Stradale** - Cerca indirizzo e posiziona
2. *(Opzionale)* **Satellite Ibrida** - Verifica edificio reale CON nomi vie

### Cantiere Rurale
1. **Stradale** - Cerca area generale
2. **Satellite Ibrida** - Identifica visivamente (campi, boschi) E leggi i nomi

### Posizionamento Preciso
1. **Satellite Ibrida** - Vedi foto reale + nomi strade
2. Posiziona cantiere con massima precisione

---

## ✅ Tutto Funziona su Windows!

- ✅ Cambio tipo mappa (toggle stradale/satellite)
- ✅ Ricerca indirizzo (su entrambi i tipi)
- ✅ **Nomi strade anche su satellite!** 🎉
- ✅ Mappa stradale più pulita (meno POI)
- ✅ Zoom in/out
- ✅ Gratuito
- ✅ Nessuna API key richiesta

**Google Maps non serve!** 🎉
