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
BKOS-Apps/
├── CLAUDE.md                          ← dit bestand
├── PROTOCOL.md                        ← volledige protocol spec (lezen!)
├── firmware_toevoegingen/
│   ├── INSTRUCTIES.md                 ← hoe te integreren in BKOS-NUI
│   ├── bkos_client.h                  ← firmware header (klaar)
│   └── bkos_client.ino                ← firmware implementatie (klaar)
└── bkos_app/                          ← Flutter project
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
| `bkos_app/pubspec.yaml` | ✅ Klaar |
| `bkos_app/lib/main.dart` | ✅ Klaar |
| `bkos_app/lib/models/bkos_model.dart` | ✅ Klaar |
| `bkos_app/lib/services/bkos_service.dart` | ✅ Klaar |
| `bkos_app/lib/services/ble_service.dart` | ✅ Klaar |
| `bkos_app/lib/screens/connect_screen.dart` | ✅ Klaar |
| `bkos_app/lib/screens/io_screen.dart` | ✅ Klaar |
| `bkos_app/lib/screens/netwerk_screen.dart` | ✅ Klaar |
| `bkos_app/lib/widgets/io_kanaal_tegel.dart` | ✅ Klaar |
| `bkos_app/lib/widgets/vaar_modus_bar.dart` | ✅ Klaar |
| Platform configuraties (Android/iOS/Win/Web) | ⏳ Nog te doen |
| GitHub Actions (build APK + web) | ⏳ Nog te doen |
| Testen op echt apparaat | ⏳ Nog te doen |

---

## Volgende taken voor een nieuwe sessie

### Taak 1: Platform permissies instellen

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```
Minimum SDK naar 21 in `android/app/build.gradle`:
```
minSdkVersion 21
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Verbinding met BKOS boordcomputer via Bluetooth</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Verbinding met BKOS boordcomputer via Bluetooth</string>
```

**Windows**: BLE werkt standaard op Windows 10+ met flutter_blue_plus.
Voeg toe aan `windows/runner/main.cpp` → geen extra permissies nodig.

**Web** (`web/index.html`): Geen BLE. WebSocket werkt standaard.
Voeg toe aan `web/index.html` (voor CORS bij WebSocket):
```html
<meta http-equiv="Content-Security-Policy" content="default-src 'self' ws: wss: 'unsafe-inline'">
```

### Taak 2: Conditionele BLE imports

`ble_service.dart` mag niet gecompileerd worden op web. Voeg stub toe:

Maak `lib/services/ble_service_stub.dart`:
```dart
import 'dart:typed_data';
typedef BleDataCallback = void Function(String type, Uint8List data);
class BleService {
  BleService({required BleDataCallback onData});
  Stream<List<dynamic>> scannen() => const Stream.empty();
  void stopScan() {}
  Future<bool> verbind(String id) async => false;
  void stuurCmd(Map<String, dynamic> msg) {}
  void verbreek() {}
  bool get verbonden => false;
}
```

Gebruik conditionele import in `bkos_service.dart`:
```dart
import 'ble_service_stub.dart' if (dart.library.io) 'ble_service.dart';
```

### Taak 3: GitHub Actions workflow

Maak `.github/workflows/build.yml`:
- Build Android APK (debug of release)
- Build Web app
- Upload als artifact

Voorbeeld:
```yaml
name: Build
on: [push]
jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.19.0' }
      - run: cd bkos_app && flutter pub get
      - run: cd bkos_app && flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: bkos_app/build/app/outputs/flutter-apk/app-debug.apk

  web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: cd bkos_app && flutter pub get
      - run: cd bkos_app && flutter build web
      - uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: bkos_app/build/web/
```

### Taak 4: Firmware integratie verifiëren

Volg `firmware_toevoegingen/INSTRUCTIES.md` stap voor stap.
Controleer alle functienamen in `bkos_client.ino` tegen de actuele BKOS-NUI broncode.
Pas aan waar nodig en compileer in Arduino IDE.

### Taak 5: App verfijnen

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
