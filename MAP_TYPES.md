# 🗺️ Tipi di Mappa - Documentazione

## ✅ Implementazione Completata

### Funzionalità
Pulsante per cambiare il tipo di mappa tra tre modalità:
1. **Stradale** (OpenStreetMap)
2. **Satellite** (ESRI World Imagery)
3. **Topografica** (OpenTopoMap)

---

## 🌍 Perché Non Google Maps?

### Compatibilità Google Maps
Il pacchetto `google_maps_flutter` **NON funziona su Windows Desktop**:

| Piattaforma | Compatibilità Google Maps |
|-------------|---------------------------|
| Android     | ✅ Funziona               |
| iOS         | ✅ Funziona               |
| Web         | ⚠️ Funziona (API diversa) |
| Windows     | ❌ **NON supportato**     |
| macOS       | ❌ **NON supportato**     |
| Linux       | ❌ **NON supportato**     |

**Motivo:** Google Maps usa widget nativi Android/iOS che non esistono su Desktop.

### Soluzione Adottata
Usiamo **OpenStreetMap** (flutter_map) che funziona su **TUTTE le piattaforme** tramite tile HTTP.

---

## 🎨 Tre Tipi di Mappa Disponibili

### 1. 🛣️ Stradale (Street)
**Provider:** OpenStreetMap (stile HOT - Humanitarian)  
**URL:** `https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png`

**Caratteristiche:**
- ✅ Mappa stradale dettagliata
- ✅ Nomi vie, edifici, punti di interesse
- ✅ Ottimale per navigazione urbana
- ✅ **Gratuita**, open source
- ✅ Aggiornamenti continui dalla community

**Quando Usarla:**
- Navigazione stradale
- Ricerca indirizzi
- Posizionamento cantieri in città

**Esempio Visivo:**
```
┌─────────────────────────────┐
│  Via Roma                   │
│    │                        │
│  ──┼──  Piazza Dante        │
│    │                        │
│  Via Milano                 │
└─────────────────────────────┘
```

---

### 2. 🛰️ Satellite
**Provider:** ESRI World Imagery  
**URL:** `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}`

**Caratteristiche:**
- ✅ **Immagini satellitari reali**
- ✅ Vista aerea ad alta risoluzione
- ✅ Copre tutto il mondo
- ✅ **Gratuita** (fornita da ESRI)
- ⚠️ Non include nomi strade (solo immagini)
- ⚠️ Aggiornamenti meno frequenti

**Quando Usarla:**
- Verifica posizione edifici reali
- Cantieri in aree rurali/aperta campagna
- Identificazione terreni, campi, boschi
- Confronto con mappa stradale

**Esempio Visivo:**
```
┌─────────────────────────────┐
│  [Foto satellitare]         │
│   🏠🏠🏠   🌳               │
│      🛣️                    │
│   🌳🌳🌾🌾                  │
└─────────────────────────────┘
```

**Limitazioni:**
- **No nomi strade** (solo immagine visiva)
- **No ricerca indirizzo** sulla mappa satellite
- Usa comunque il geocoding per centrare

---

### 3. 🏔️ Topografica (Terrain)
**Provider:** OpenTopoMap  
**URL:** `https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png`

**Caratteristiche:**
- ✅ **Curve di livello** (altitudine)
- ✅ Rilievi montuosi evidenziati
- ✅ Pendenze e dislivelli visibili
- ✅ Nomi strade + informazioni topografiche
- ✅ Stile simile a mappe escursionistiche
- ✅ **Gratuita**, open source

**Quando Usarla:**
- Cantieri in zone montuose/collinari
- Verifica dislivelli terreno
- Pianificazione accessi in zone impervie
- Identificazione pendii/vallate

**Esempio Visivo:**
```
┌─────────────────────────────┐
│        /\  Monte Rosa       │
│       /  \  (1500m)         │
│      / 100\                 │
│     /  200 \                │
│    /───300──\               │
│   Via Piana (400m)          │
└─────────────────────────────┘
```

**Vantaggi Tecnici:**
- Vedi pendenza prima di inviare squadre
- Identifica accessi migliori
- Prevedi difficoltà logistiche

---

## 🎮 Come Usare il Pulsante Cambio Mappa

### Posizione UI
```
┌────────────────────────────────┐
│  [Barra ricerca indirizzo]     │
│                                │
│           [MAPPA]              │
│                                │
│  [🗺️] ← Cambio mappa           │
│  [+]  ← Zoom in               │
│  [−]  ← Zoom out              │
└────────────────────────────────┘
```

### Funzionamento
1. **Click sul pulsante 🗺️** (icona layers)
2. La mappa cambia al tipo successivo:
   - Stradale → Satellite → Topografica → Stradale → ...
3. **Tooltip** mostra il tipo corrente quando passi sopra

### Ciclo dei Tipi
```
┌──────────┐
│ Stradale │ ───────┐
└──────────┘        │
                    ↓
┌──────────┐   ┌───────────┐
│Topograf. │←──│ Satellite │
└──────────┘   └───────────┘
```

**Click 1:** Stradale → **Satellite**  
**Click 2:** Satellite → **Topografica**  
**Click 3:** Topografica → **Stradale**

---

## 💻 Implementazione Tecnica

### Enum MapType
```dart
enum MapType {
  street,    // Mappa stradale standard
  satellite, // Vista satellitare
  terrain,   // Mappa topografica
}
```

### State Variable
```dart
MapType _currentMapType = MapType.street; // Default: stradale
```

### Metodo Cambio URL
```dart
String _getTileUrl() {
  switch (_currentMapType) {
    case MapType.street:
      return 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
    case MapType.satellite:
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case MapType.terrain:
      return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
  }
}
```

### Metodo Cambio Tipo
```dart
void _cycleMapType() {
  setState(() {
    switch (_currentMapType) {
      case MapType.street:
        _currentMapType = MapType.satellite;
        break;
      case MapType.satellite:
        _currentMapType = MapType.terrain;
        break;
      case MapType.terrain:
        _currentMapType = MapType.street;
        break;
    }
  });
}
```

### TileLayer Dinamico
```dart
TileLayer(
  urlTemplate: _getTileUrl(), // URL dinamico
  subdomains: _currentMapType == MapType.satellite 
    ? const [] // Satellite non usa subdomains
    : const ['a', 'b', 'c'],
  // ...
)
```

---

## 🧪 Testing

### Test 1: Cambio Tipo Base
```
1. Apri pagina Cantieri
2. Default: mappa stradale (strade e nomi)
3. Click pulsante 🗺️
4. ✅ Passa a satellite (foto aerea)
5. Click pulsante 🗺️
6. ✅ Passa a topografica (curve livello)
7. Click pulsante 🗺️
8. ✅ Torna a stradale
```

### Test 2: Tooltip
```
1. Passa mouse su pulsante 🗺️
2. ✅ Mostra "Stradale" / "Satellite" / "Topografica"
3. Click per cambiare
4. ✅ Tooltip aggiornato al nuovo tipo
```

### Test 3: Ricerca con Satellite
```
1. Cambia a vista satellite
2. Cerca "Colosseo, Roma"
3. ✅ Mappa si centra (geocoding funziona)
4. ✅ Vedi foto aerea del Colosseo
5. ⚠️ Nomi non visibili sulla mappa (solo foto)
```

### Test 4: Zoom con Topografica
```
1. Cambia a vista topografica
2. Cerca area montana (es. "Cervinia")
3. ✅ Vedi curve di livello
4. Zoom in (+)
5. ✅ Curve sempre più dettagliate
6. Zoom out (-)
7. ✅ Vista generale rilievi
```

### Test 5: Subdomains
```
1. Vista stradale/topografica
2. ✅ Usa subdomains a, b, c (load balancing)
3. Vista satellite
4. ✅ Non usa subdomains (URL diverso)
5. Tiles caricano correttamente in tutti i casi
```

---

## 📊 Confronto Provider

| Caratteristica | Stradale (OSM) | Satellite (ESRI) | Topografica (OTM) |
|----------------|----------------|------------------|-------------------|
| **Nomi strade** | ✅ Sì | ❌ No | ✅ Sì |
| **Foto reali** | ❌ No | ✅ Sì | ❌ No |
| **Curve livello** | ❌ No | ❌ No | ✅ Sì |
| **Edifici** | ✅ Contorni | ✅ Foto | ✅ Contorni |
| **Aggiornamenti** | Frequenti | Medi | Frequenti |
| **Costo** | Gratuito | Gratuito | Gratuito |
| **Zoom max** | 19 | 19 | 17 |
| **Uso cantieri** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Uso montana** | ⭐ | ⭐⭐ | ⭐⭐⭐ |

---

## 🎯 Best Practice d'Uso

### Scenario 1: Cantiere Urbano
```
1. Usa mappa STRADALE (default)
2. Cerca indirizzo → zoom automatico
3. Vedi nome via esatto
4. Aggiungi cantiere
5. (Opzionale) Switch a SATELLITE per vedere edificio reale
```

### Scenario 2: Cantiere Rurale
```
1. Cerca località generale (stradale)
2. Switch a SATELLITE
3. Identifica visivamente area (campi, boschi)
4. Posiziona cantiere su punto esatto
5. (Opzionale) Switch a TOPOGRAFICA per verificare pendenze
```

### Scenario 3: Cantiere Montano
```
1. Cerca località (stradale)
2. Switch a TOPOGRAFICA
3. Verifica curve di livello
4. Identifica dislivelli e accessi
5. Switch a SATELLITE per conferma visiva
6. Posiziona cantiere
```

### Scenario 4: Verifica Posizione Esistente
```
1. Visualizza cantiere su mappa stradale
2. Switch a SATELLITE
3. Confronta con foto reale
4. ✅ Conferma posizione corretta
5. ❌ Se sbagliato: modifica posizione
```

---

## 🔧 Customizzazione Futura

### Aggiungere Nuovi Provider

#### Google Maps (Solo Android/iOS)
**NON compatibile Windows!**
```dart
// Solo per riferimento - NON usare su Windows
case MapType.google:
  // Richiederebbe google_maps_flutter
  // NON funziona su desktop
```

#### Mapbox (Richiede API Key)
```dart
case MapType.mapbox:
  return 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=YOUR_TOKEN';
```

#### Altri Provider Gratuiti
- **OpenCycleMap** (mappe ciclabili)
- **Stamen Terrain** (terreno artistico)
- **CartoDB** (stile minimale)

### Aggiungere Overlay Ibridi
```dart
// Satellite + nomi strade
TileLayer(satellite),
TileLayer(labels, opacity: 0.7),
```

### Persistenza Preferenza
```dart
// Salvare tipo mappa preferito
SharedPreferences prefs = await SharedPreferences.getInstance();
await prefs.setString('map_type', _currentMapType.name);

// Caricare all'avvio
String? saved = prefs.getString('map_type');
_currentMapType = MapType.values.byName(saved ?? 'street');
```

---

## ⚠️ Limitazioni Conosciute

### Satellite (ESRI)
- ❌ **No nomi strade** sulla mappa (solo foto)
- ⚠️ Geocoding funziona per centrare, ma nomi non visibili
- ⚠️ Zoom 19 potrebbe non avere dati in alcune aree
- ⚠️ Aggiornamenti immagini meno frequenti (mesi/anni)

### Topografica (OpenTopoMap)
- ⚠️ **Zoom max 17** (più basso di altri)
- ⚠️ Rendering tiles più lento (curve di livello complesse)
- ⚠️ Meno dettagli in zone pianeggianti

### Generale
- ⚠️ Cambio tipo richiede ricaricamento tiles (1-2 secondi)
- ⚠️ Cache browser potrebbe usare più memoria con 3 tipi
- ⚠️ Rate limit dei server tile (max req/secondo)

---

## 🌐 Alternative Cross-Platform

### Cosa NON Funziona su Windows
- ❌ `google_maps_flutter` - Solo mobile
- ❌ `apple_maps_flutter` - Solo iOS
- ❌ Widget nativi Android/iOS

### Cosa FUNZIONA su Windows
- ✅ `flutter_map` - Tutte le piattaforme
- ✅ Tile-based maps (OSM, ESRI, etc.)
- ✅ HTTP image tiles
- ✅ WebView con Google Maps Embed API (alternativa)

### WebView Approach (Alternativa)
```dart
// Usare WebView per Google Maps Embed
WebView(
  initialUrl: 'https://www.google.com/maps/embed/v1/view?key=API_KEY&center=LAT,LNG',
)
```

**Pro:** Usa Google Maps  
**Contro:** Servono API key, limitazioni embed, meno controllo

---

## 📈 Performance

### Caricamento Tiles
- **Stradale:** ~50KB per tile (PNG compresso)
- **Satellite:** ~100KB per tile (JPEG foto)
- **Topografica:** ~80KB per tile (PNG con curve)

### Cache
```dart
TileLayer(
  keepBuffer: 5, // Mantiene 5 tiles fuori schermo
  // Riduce ricaricamenti durante pan/zoom
)
```

### Subdomains Load Balancing
```
Request 1 → a.tile.openstreetmap.org
Request 2 → b.tile.openstreetmap.org
Request 3 → c.tile.openstreetmap.org
Request 4 → a.tile.openstreetmap.org
...
```

Distribuisce carico su 3 server → loading 3x più veloce

---

## ✅ Checklist Implementazione

- [x] Enum `MapType` con 3 tipi
- [x] State variable `_currentMapType`
- [x] Metodo `_getTileUrl()` dinamico
- [x] Metodo `_getMapTypeName()` per tooltip
- [x] Metodo `_cycleMapType()` per cambio
- [x] TileLayer con URL dinamico
- [x] Subdomains condizionali (satellite no)
- [x] Pulsante UI con icona layers
- [x] Tooltip con nome tipo corrente
- [x] HeroTag univoco 'change_map'
- [x] Posizionamento sopra zoom buttons
- [x] Testing funzionalità
- [x] Documentazione completa

---

**Data Implementazione:** 15 Ottobre 2025  
**Tipi Disponibili:** Stradale, Satellite, Topografica  
**Provider:** OSM, ESRI, OpenTopoMap  
**Cross-Platform:** ✅ Windows, macOS, Linux, Android, iOS, Web  
**Costo:** Gratuito (tutti i provider)  
**Status:** ✅ Completato e testabile

---

## 🎓 Risorse Aggiuntive

### Documentazione Provider
- **OpenStreetMap:** https://www.openstreetmap.org/
- **ESRI World Imagery:** https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9
- **OpenTopoMap:** https://opentopomap.org/

### Flutter Map
- **Package:** https://pub.dev/packages/flutter_map
- **Docs:** https://docs.fleaflet.dev/
- **GitHub:** https://github.com/fleaflet/flutter_map

### Tile Servers
- **Lista completa:** https://wiki.openstreetmap.org/wiki/Tile_servers
- **Confronto provider:** https://switch2osm.org/providers/

---

**🎉 La tua mappa ora supporta 3 visualizzazioni diverse, tutte gratuite e cross-platform!**
