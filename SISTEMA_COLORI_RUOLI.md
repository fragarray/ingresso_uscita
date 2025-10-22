# 🎨 Sistema Colori Ruoli - Lista Dipendenti

## 📋 Panoramica

Nella tab **"Personale"** dell'area Admin, i dipendenti nella lista sono ora distinguibili visivamente attraverso un sistema di colori che identifica:
- **Ruolo** (Admin, Capocantiere, Operaio)
- **Stato di servizio** (In servizio/Non in servizio)

---

## 🎨 Schema Colori

### 1. **Amministratore (Admin)** - BLU 🔵
- **Sfondo card:** Blu chiaro (Blue[50])
- **Avatar:** Blu con icona admin panel settings
- **Badge:** "ADMIN" su sfondo blu
- **Elevazione:** 3 (card rialzata)

**Quando:** `employee.role == EmployeeRole.admin`

```dart
cardColor = Colors.blue[50];
avatarColor = Colors.blue;
icon = Icons.admin_panel_settings;
```

---

### 2. **Capocantiere (Foreman)** - ARANCIONE 🟠
- **Sfondo card:** Arancione chiaro (Orange[50])
- **Avatar:** Arancione con icona engineering
- **Badge:** "CAPOCANTIERE" su sfondo arancione
- **Elevazione:** 3 (card rialzata)

**Quando:** `employee.role == EmployeeRole.foreman`

```dart
cardColor = Colors.orange[50];
avatarColor = Colors.orange;
icon = Icons.engineering;
```

---

### 3. **Operaio in Servizio** - VERDE 🟢
- **Sfondo card:** Verde chiaro (Green[50])
- **Avatar:** Verde con icona check
- **Badge:** Nessuno (ma testo "Timbrato IN" sotto email)
- **Elevazione:** 3 (card rialzata)
- **Indicatore:** Riga con icona orologio + "Timbrato IN"

**Quando:** `employee.role == EmployeeRole.employee` E `isClockedIn == true`

```dart
cardColor = Colors.green[50];
avatarColor = Colors.green;
icon = Icons.check;
```

---

### 4. **Operaio Non in Servizio** - TRASPARENTE ⚪
- **Sfondo card:** Trasparente (null)
- **Avatar:** Grigio con iniziale nome
- **Badge:** Nessuno
- **Elevazione:** 1 (card piatta)

**Quando:** `employee.role == EmployeeRole.employee` E `isClockedIn == false`

```dart
cardColor = null;
avatarColor = null;
icon = Text(employee.name[0]);
```

---

## 🎯 Priorità Colori

Il sistema segue questa priorità per assegnare il colore:

1. **Selezionato** → Colore primario tema (override su tutto)
2. **Admin** → Blu
3. **Foreman** → Arancione
4. **In Servizio** → Verde
5. **Default** → Trasparente

```dart
if (isSelected) {
  cardColor = Theme.of(context).colorScheme.primaryContainer;
} else if (employee.role == EmployeeRole.admin) {
  cardColor = Colors.blue[50];
} else if (employee.role == EmployeeRole.foreman) {
  cardColor = Colors.orange[50];
} else if (isClockedIn) {
  cardColor = Colors.green[50];
}
```

---

## 📊 Legenda Colori

All'interno della card "Lista Dipendenti", sopra l'elenco, viene mostrata una **legenda visiva** con:

```
[🔵] Admin    [🟠] Capocantiere    [🟢] In Servizio    [⚪] Operaio
```

Ogni elemento mostra:
- Un quadratino colorato con bordo
- Il testo descrittivo del ruolo/stato

**Implementazione:**
```dart
Widget _buildLegendItem(Color color, String label) {
  return Row(
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      Text(label, style: TextStyle(fontSize: 11)),
    ],
  );
}
```

---

## 🎭 Avatar Icon

Ogni ruolo ha un'icona distintiva nell'avatar:

| Ruolo | Icona | Codice |
|-------|-------|--------|
| **Admin** | 🛡️ | `Icons.admin_panel_settings` |
| **Capocantiere** | 👷 | `Icons.engineering` |
| **In Servizio** | ✅ | `Icons.check` |
| **Operaio** | 📝 | Prima lettera nome (es. "M") |

---

## 🔍 Esempi Visivi

### Esempio 1: Amministratore
```
┌─────────────────────────────────────┐
│ 🔵 [Admin Icon] Mario Rossi [ADMIN] │ ← Sfondo blu chiaro
│    admin@example.com                │
└─────────────────────────────────────┘
```

### Esempio 2: Capocantiere
```
┌─────────────────────────────────────────────┐
│ 🟠 [Engineer] Giovanni [CAPOCANTIERE]       │ ← Sfondo arancione
│    giovanni@site.com                        │
└─────────────────────────────────────────────┘
```

### Esempio 3: Operaio in Servizio
```
┌─────────────────────────────────────┐
│ 🟢 [✓] Luca Bianchi                │ ← Sfondo verde
│    luca@operai.it                   │
│    ⏰ Timbrato IN                   │
└─────────────────────────────────────┘
```

### Esempio 4: Operaio NON in Servizio
```
┌─────────────────────────────────────┐
│ ⚪ [P] Paolo Verdi                  │ ← Sfondo trasparente
│    paolo@operai.it                  │
└─────────────────────────────────────┘
```

---

## 📝 Badge Ruolo

I badge appaiono accanto al nome per ruoli privilegiati:

### Admin Badge
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text('ADMIN', style: TextStyle(
    color: Colors.white,
    fontSize: 9,
    fontWeight: FontWeight.bold,
  )),
)
```

### Capocantiere Badge
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.orange,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text('CAPOCANTIERE', style: TextStyle(
    color: Colors.white,
    fontSize: 9,
    fontWeight: FontWeight.bold,
  )),
)
```

---

## 🎨 Accessibilità

Il sistema di colori rispetta i principi di accessibilità:

1. **Contrasto:** Sfondo chiaro + testo scuro = buon contrasto
2. **Non solo colore:** Badge testuali + icone per identificare ruoli
3. **Consistenza:** Colori coerenti in tutta l'app
4. **Elevazione:** Card rialzate per ruoli privilegiati

---

## 🔄 Comportamento Interattivo

### Card Selezionata
Quando un dipendente è selezionato:
- Sfondo diventa **primaryContainer** (override su tutti i colori)
- Mantiene badge e icone specifiche del ruolo
- Elevazione aumentata

### Hover (Desktop)
Su desktop, al passaggio del mouse:
- Effetto InkWell con ripple
- BorderRadius: 12px
- Feedback tattile

---

## 📊 Statistiche Colori

In una lista tipica di 10 dipendenti:
- 🔵 Admin: 1-2 dipendenti (10-20%)
- 🟠 Capocantiere: 1-3 dipendenti (10-30%)
- 🟢 In Servizio: 3-6 dipendenti (30-60%)
- ⚪ Operai: 3-5 dipendenti (30-50%)

---

## 🛠️ File Modificati

**`lib/widgets/personnel_tab.dart`:**
- Riga ~3370: Logica colore card basata su ruolo
- Riga ~3389: Avatar colorato con icona ruolo-specifica
- Riga ~3420: Badge ruolo (Admin/Capocantiere)
- Riga ~3320: Legenda colori sopra lista
- Riga ~4602: Metodo `_buildLegendItem()`

---

## 🎯 Vantaggi UX

1. **Immediata identificazione visiva** dei ruoli
2. **Riduzione carico cognitivo** - non serve leggere ogni card
3. **Stato servizio chiaro** - verde = in servizio
4. **Gerarchia visiva** - card rialzate per ruoli speciali
5. **Ricerca facilitata** - trova rapidamente admin/capicantiere

---

## 📚 Riferimenti

- **EmployeeRole Enum:** `lib/models/employee.dart`
- **Personnel Tab:** `lib/widgets/personnel_tab.dart`
- **Theme Colors:** Material Design 3

---

**Ultimo aggiornamento:** 20 Ottobre 2025  
**Versione:** v1.2.0  
**Feature:** Sistema colori ruoli dipendenti
