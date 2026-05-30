# BKOS-NUI Firmware: mDNS + bootnaam in WebSocket

Deze wijzigingen zijn nodig voor de BKOS Brug app om:
1. BKOS apparaten automatisch te vinden op het WiFi netwerk (mDNS)
2. Bootnaam te tonen op het verbindingsscherm en in de app-balk

BKOS-NUI repo: `https://github.com/brennyc86/BKOS-NUI`

---

## Wijziging 1: mDNS service adverteren

### `wifi.h` — voeg toe aan includes:
```cpp
#include <ESPmDNS.h>
```

### `wifi.h` — voeg toe aan declaraties:
```cpp
void mdns_setup();
void mdns_update();
```

### `wifi.ino` — voeg toe als nieuwe functie:
```cpp
void mdns_setup() {
  // Hostname: computernaam lowercase, spaties worden koppeltekens
  String hostnaam = String(net_eigen_naam);
  hostnaam.toLowerCase();
  for (int i = 0; i < hostnaam.length(); i++) {
    if (!isAlphaNumeric(hostnaam[i])) hostnaam[i] = '-';
  }
  if (hostnaam.isEmpty() || hostnaam == "-") hostnaam = "bkos-nui";

  if (!MDNS.begin(hostnaam.c_str())) return;

  // Adverteer de BKOS WebSocket service
  MDNS.addService("bkos", "tcp", BKOS_WS_POORT);

  // TXT records — worden uitgelezen door de BKOS Brug app
  MDNS.addServiceTxt("bkos", "tcp", "comp", net_eigen_naam);
  MDNS.addServiceTxt("bkos", "tcp", "modus", String(net_modus).c_str());

  // Bootnaam ophalen uit SPIFFS
  String boot = _mdns_bootnaam_lees();
  if (boot.length() > 0) {
    MDNS.addServiceTxt("bkos", "tcp", "boot", boot.c_str());
  }
}

// Herstart mDNS wanneer naam of modus wijzigt
void mdns_update() {
  MDNS.end();
  mdns_setup();
}

String _mdns_bootnaam_lees() {
  // Lees uit /bkos_info.csv — formaat: "bootnaam,eigenaar"
  if (!SPIFFS.exists("/bkos_info.csv")) return "";
  File f = SPIFFS.open("/bkos_info.csv", "r");
  if (!f) return "";
  String regel = f.readStringUntil('\n');
  f.close();
  int komma = regel.indexOf(',');
  if (komma < 0) return regel.trim();
  return regel.substring(0, komma).trim();
}
```

### `hardware.ino` — aanroepen:
In `hw_setup()`, na `wifi_setup()` en `net_setup()`:
```cpp
if (wifi_verbonden) mdns_setup();
```

In `hw_loop()`, voeg toe (elk uur mDNS opnieuw adverteren is voldoende):
```cpp
MDNS.update(); // roep elke loop-iteratie aan, is snel
```

### `wifi.ino` — mDNS starten bij WiFi-verbinding:
Zoek de plek waar `wifi_verbonden = true` wordt gezet en voeg toe:
```cpp
wifi_verbonden = true;
mdns_setup(); // start mDNS zodra WiFi verbonden is
```

---

## Wijziging 2: bootnaam in WebSocket info-bericht

In `bkos_client.ino`, in de functie `_info_json()`, voeg toe:

```cpp
static String _info_json() {
  String s = "{\"t\":\"info\",\"naam\":\"";
  s += net_eigen_naam;
  s += "\",\"boot\":\"";
  // Bootnaam uit SPIFFS lezen
  String boot = "";
  if (SPIFFS.exists("/bkos_info.csv")) {
    File f = SPIFFS.open("/bkos_info.csv", "r");
    if (f) {
      String r = f.readStringUntil('\n');
      f.close();
      int k = r.indexOf(',');
      boot = (k < 0) ? r.trim() : r.substring(0, k).trim();
    }
  }
  s += boot;
  s += "\",\"ver\":\"";
  s += BKOS_NUI_VERSIE;
  // ... rest van de functie hetzelfde
```

Of korter: voeg `\"boot\":\"` + bootnaam toe aan het bestaande JSON-bericht in `_info_json()`.

---

## Wijziging 3: controleer BKOS_WS_POORT beschikbaarheid

In `mdns_setup()` en `_info_json()` wordt `BKOS_WS_POORT` gebruikt.
Dit is gedefinieerd in `bkos_client.h` als `#define BKOS_WS_POORT 8080`.
Zorg dat `bkos_client.h` geïnclude is in `wifi.ino` of verplaats de constante naar een gedeeld header-bestand.

---

## Wanneer mDNS updaten?

Roep `mdns_update()` aan bij:
- Wijziging van `net_eigen_naam` (via config scherm)
- Wijziging van `net_modus` (van standalone naar master/slave)
- Wijziging van bootnaam (via info scherm)

---

## Test

Na implementatie: open de BKOS Brug app op telefoon (zelfde WiFi).
Het verbindingsscherm toont automatisch het apparaat met naam en modus.
Geen IP-adres meer nodig.
