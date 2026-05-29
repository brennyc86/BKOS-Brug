# BKOS-NUI Firmware Aanpassingen voor Apps

Deze map bevat de firmware-uitbreidingen voor BKOS-NUI zodat de externe apps
(Android / iOS / Windows / webapp) kunnen verbinden.

Actieve BKOS repo: `https://github.com/brennyc86/BKOS-NUI`

---

## Benodigde bibliotheek

Installeer in Arduino IDE → Bibliotheekbeheer:
- **"WebSockets" door Markus Sattler** (v2.x) — voor de WebSocket server

BLE is ingebouwd in ESP32 Arduino Core, geen extra installatie nodig.

---

## Stap 1: Bestanden kopiëren

Kopieer naar `BKOS_NUI/`:
- `bkos_client.h`
- `bkos_client.ino`

---

## Stap 2: hardware.ino aanpassen

Voeg `#include "bkos_client.h"` toe bovenaan `hardware.h`.

In `hw_setup()` (onderaan, na wifi_setup en net_setup):
```cpp
bkos_client_setup();
```

In `hw_loop()` (samen met de andere loop-aanroepen):
```cpp
bkos_client_loop();
```

---

## Stap 3: Controleer bestaande functienamen

`bkos_client.ino` roept deze functies aan die al in BKOS bestaan:
- `net_io_kanaal_toggle(int kanaal)` — uit bkos_net
- `net_io_naam_toggle(char* naam, int prefix)` — uit bkos_net
- `net_app_state_sync()` — uit bkos_net
- `io_verlichting_update()` — uit io
- `io_kanalen_cnt`, `io_output[]`, `io_input[]`, `io_namen[]` — uit app_state
- `vaar_modus`, `licht_instelling` — uit app_state
- `wifi_verbonden` — uit app_state
- `net_peers[]`, `net_eigen_naam`, `net_modus` — uit bkos_net
- `NET_MAX_PEERS` — uit bkos_net.h
- `BKOS_NUI_VERSIE` — uit ota.h
- `IO_NAAM_LEN`, `MAX_IO_KANALEN` — uit app_state.h of io.h

Controleer of exacte namen overeenkomen. Als iets anders heet, pas aan in bkos_client.ino.

Controleer ook of deze functies bestaan:
```cpp
void net_io_kanaal_zet(int kanaal, int staat);
```
Als `net_io_kanaal_zet` niet bestaat, voeg toe aan `bkos_net.ino`:
```cpp
void net_io_kanaal_zet(int kanaal, int staat) {
  // Stuur IO_TOGGLE met expliciete staat
  // Werkt vergelijkbaar met net_io_kanaal_toggle maar stuurt staat
  if (kanaal < 0 || kanaal >= io_kanalen_cnt) return;
  if (net_modus == NET_MASTER) {
    io_output[kanaal] = staat ? IO_AAN : IO_UIT;
    io_gewijzigd[kanaal] = true;
  } else {
    // Stuur naar master
    uint8_t buf[2] = { (uint8_t)kanaal, (uint8_t)staat };
    net_stuur_naar_master(NET_MSG_IO_TOGGLE, buf, 2);
  }
}
```
En declareer in `bkos_net.h`:
```cpp
void net_io_kanaal_zet(int kanaal, int staat);
```

---

## Stap 4: Partitie schema check

BLE + WiFi tegelijk gebruiken meer heap. Controleer of er genoeg RAM is.
- ESP32-S3 heeft 512KB SRAM — meer dan genoeg
- Geen partitie-aanpassing nodig, alleen RAM-gebruik monitoren

Als de ESP32 herstart (stack overflow), vergroot de taakstack in hardware.ino:
```cpp
// Verhoog wifi_taak stack van 8192 naar 12288 als BLE actief is
xTaskCreatePinnedToCore(wifi_taak, "wifi", 12288, NULL, 1, NULL, 0);
```

---

## Stap 5: Test

1. Compileer en flash via Arduino IDE
2. Verbind telefoon met hetzelfde WiFi-netwerk als de ESP32
3. Open de app, voer het IP-adres van de ESP32 in
4. WebSocket verbinding moet tot stand komen op poort 8080
5. IO lijst moet verschijnen met alle kanalen

Voor BLE test:
1. Zet WiFi uit op de telefoon
2. Scan voor Bluetooth apparaten — zoek naar "BKOS-NUI" (of eigen naam)
3. Verbind — IO lijst moet verschijnen

---

## Versienummer

Na succesvolle integratie: verhoog `BKOS_NUI_VERSIE` in `ota.h` en `versie.txt`.
Commit en push zodat GitHub Actions de nieuwe firmware.bin bouwt.

---

## Bekende beperkingen

- BLE en ESP-NOW gebruiken beide de 2.4GHz radio — dit werkt dankzij coexistentie in ESP32
  maar bij zware belasting kan er lichte latency optreden
- WebSocket max 4 gelijktijdige clients (beperking arduinoWebSockets library)
- BLE max 1 verbinding tegelijk (standaard ESP32 BLE stack)
- Kanaalnamen worden bij BLE in chunks opgehaald — eerste verbinding duurt ~1 seconde langer
