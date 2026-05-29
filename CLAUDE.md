# CLAUDE.md — BKOS-Brug

Flutter app voor de BKOS Boordcomputer (Android / iOS / Windows / Web).
Verbindt via WebSocket (WiFi) of BLE met de BKOS-NUI firmware.

**BKOS-NUI firmware repo:** `https://github.com/brennyc86/BKOS-NUI`
**Brug repo:** `https://github.com/brennyc86/BKOS-Brug`

---

## Werkwijze

Na elk afgerond stuk werk: committen en pushen naar `main`.

```bash
git add <bestanden>
git commit -m "vX.Y: omschrijving"
git push
```

---

## Project Overzicht

```
BKOS-Brug/
├── CLAUDE.md                          ← dit bestand
├── PROTOCOL.md                        ← volledige protocol spec (lezen!)
├── firmware_toevoegingen/
│   ├── INSTRUCTIES.md                 ← hoe te integreren in BKOS-NUI
│   ├── bkos_client.h                  ← firmware header (klaar)
│   └── bkos_client.ino                ← firmware implementatie (klaar)
└── bkos_brug/                          ← Flutter project
    ├── pubspec.yaml
    └── lib/
        ├── main.dart                  ← entry point, router, thema
        ├── models/bkos_model.dart     ← data modellen
        ├── services/
        │   ├── bkos_service.dart      ← centrale state + verbinding
        │   └── ble_service.dart       ← BLE GATT wrapper
        ├── screens/
        │   ├── connect_screen.dart    ← WiFi IP invoer + BLE scan
        │   ├── io_screen.dart         ← IO Paneel (hoofd scherm)
        │   └── netwerk_screen.dart    ← Netwerk peers overzicht
        └── widgets/
            ├── io_kanaal_tegel.dart   ← kanaal kaartje met toggle
            └── vaar_modus_bar.dart    ← vaarmodus + verlichting balk
```

---

## Status (start sessie hier)

| Bestand | Status |
|---------|--------|
| `firmware_toevoegingen/bkos_client.h` | ✅ Klaar |
| `firmware_toevoegingen/bkos_client.ino` | ✅ Klaar (integratie verificatie nodig) |
| `firmware_toevoegingen/INSTRUCTIES.md` | ✅ Klaar |
| `PROTOCOL.md` | ✅ Klaar |
| `bkos_brug/pubspec.yaml` | ✅ Klaar |
| `bkos_brug/lib/main.dart` | ✅ Klaar |
| `bkos_brug/lib/models/bkos_model.dart` | ✅ Klaar |
| `bkos_brug/lib/services/bkos_service.dart` | ✅ Klaar |
| `bkos_brug/lib/services/ble_service.dart` | ✅ Klaar |
| `bkos_brug/lib/screens/connect_screen.dart` | ✅ Klaar |
| `bkos_brug/lib/screens/io_screen.dart` | ✅ Klaar |
| `bkos_brug/lib/screens/netwerk_screen.dart` | ✅ Klaar |
| `bkos_brug/lib/widgets/io_kanaal_tegel.dart` | ✅ Klaar |
| `bkos_brug/lib/widgets/vaar_modus_bar.dart` | ✅ Klaar |
| `bkos_brug/android/app/src/main/AndroidManifest.xml` | ✅ Klaar |
| `bkos_brug/android/app/build.gradle` | ✅ Klaar |
| `bkos_brug/ios/Runner/Info.plist` | ✅ Klaar |
| `bkos_brug/web/index.html` | ✅ Klaar |
| `bkos_brug/web/manifest.json` | ✅ Klaar |
| `bkos_brug/lib/services/ble_service_stub.dart` | ✅ Klaar |
| Conditionele BLE import in bkos_service.dart | ✅ Klaar |
| `.github/workflows/build.yml` (Android + Web + Windows) | ✅ Klaar |
| Testen op echt apparaat | ⏳ Nog te doen |

---

## Volgende taken voor een nieuwe sessie

### Taak 1: Firmware integratie verifiëren

Volg `firmware_toevoegingen/INSTRUCTIES.md` stap voor stap.
Controleer alle functienamen in `bkos_client.ino` tegen de actuele BKOS-NUI broncode.
Pas aan waar nodig en compileer in Arduino IDE.

### Taak 2: App verfijnen

- Kanaallijst sorteren op naam (lichten bovenaan, motoren etc.)
- Scrollpositie bewaren bij IO updates
- Verbindingsstatus tonen in statusbalk (IP + ping tijd)
- "Niet verbonden" overlay met reconnect knop

---

## Verbindingslogica samenvatting

```
App start
  └─ Laatste IP opgeslagen?
       ├─ Ja → Probeer WebSocket op ws://<ip>:8080/bkos
       │         ├─ Succes → Toon IO scherm
       │         └─ Timeout 3s → Toon connect scherm
       └─ Nee → Toon connect scherm
                  ├─ Gebruiker voert IP in → WebSocket
                  └─ Gebruiker tikt "BLE scan" → Scan + verbind
```

---

## Conventies

- **Taal**: Nederlands (variabelen, functies, labels in UI)
- **State**: Alleen via `BkosService` (ChangeNotifier + Provider)
- **Navigatie**: `go_router` — routes `/connect`, `/io`, `/netwerk`
- **Thema**: Donker marine (zie `_bkosTheme()` in `main.dart`)
- **BLE niet op web**: conditionele import, nooit direct `flutter_blue_plus` importeren in schermen

---

## Protocol referentie

Zie `PROTOCOL.md` voor volledige spec van:
- WebSocket JSON berichten (server↔client)
- BLE GATT service + characteristics + commando formaten

---

## Bekende beperkingen / aandachtspunten

- WebSocket op web vereist HTTPS als de webapp via HTTPS geserveerd wordt
  (WebSocket over plain `ws://` geblokkeerd door mixed-content). Oplossing:
  ESP32 ook HTTPS serveren (complex) OF webapp via HTTP serveren (simpeler voor LAN).
- flutter_blue_plus versie 1.x — API kan wijzigen bij upgrade naar 2.x
- `io_kanalen_cnt` in de firmware bevat ook lege/ongebruikte kanalen.
  De app filtert kanalen met lege naam weg (zie `io_screen.dart`).
