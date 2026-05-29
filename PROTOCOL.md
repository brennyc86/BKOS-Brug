# BKOS Client Protocol Specification

Communicatieprotocol tussen BKOS-NUI firmware en externe apps (Flutter / webapp).

---

## Verbindingsmethoden

| Methode      | Platforms                | Poort/Transport  | Wanneer                         |
|--------------|--------------------------|------------------|---------------------------------|
| WebSocket    | Alle (Android/iOS/Win/Web) | TCP 8080, JSON  | Op hetzelfde WiFi netwerk       |
| BLE GATT     | Android, iOS, Windows    | Bluetooth LE     | Dichtbij, niet op zelfde WiFi   |

De app probeert altijd WebSocket eerst. Als dat mislukt na 3 seconden → BLE scan starten.

---

## 1. WebSocket Protocol (JSON)

### Verbinding
- URL: `ws://<esp32-ip>:8080/bkos`
- Na connect stuurt server automatisch `io_full`, `state`, `net`, `info`

### Server → Client berichten

```json
{ "t": "io_full",
  "cnt": 24,
  "o": [0,1,0,2,1,0,...],
  "i": [0,0,1,0,...],
  "n": ["LICHT1","MOTOR","POMP",...] }
```
`o` = output states (0=UIT, 1=AAN, 2=INV_UIT, 3=INV_AAN, 4=GEBLOKKEERD)  
`i` = input feedback (0/1)  
`n` = kanaalnamen (IO_NAAM_LEN = 12 chars max)

```json
{ "t": "io_delta", "ch": 5, "o": 1, "i": 0 }
```
Incrementele update van één kanaal (na toggle of IO wijziging).

```json
{ "t": "state", "m": 0, "l": 1 }
```
`m` = vaarmodus (0=HAVEN, 1=ZEILEN, 2=MOTOR, 3=ANKER)  
`l` = verlichting (0=UIT, 1=AAN, 2=AUTO)

```json
{ "t": "net",
  "peers": [
    { "naam": "Salon", "mode": 2, "online": true, "io": 8 },
    { "naam": "Keuken", "mode": 4, "online": false, "io": 0 }
  ]
}
```
`mode`: 1=MASTER, 2=SLAVE, 3=EXTRA, 4=HEADLESS

```json
{ "t": "info",
  "naam": "BKOS-NUI",
  "ver": "0.0.260529.1",
  "mac": "AA:BB:CC:DD:EE:FF",
  "net_modus": 1
}
```

```json
{ "t": "pong" }
```

### Client → Server berichten

```json
{ "t": "io_toggle", "i": 5 }
```
Toggle kanaal op index 5.

```json
{ "t": "io_set", "i": 5, "v": 1 }
```
Kanaal 5 expliciet op AAN (v=0 UIT, v=1 AAN).

```json
{ "t": "io_naam", "n": "LICHT_STUUR" }
```
Toggle kanaal op exacte naam of prefix.

```json
{ "t": "set_modus", "m": 2 }
```
Vaarmodus instellen.

```json
{ "t": "set_licht", "l": 1 }
```
Verlichting instellen.

```json
{ "t": "ping" }
```

---

## 2. BLE GATT Protocol

### Service UUID
`424b4f53-0000-1000-8000-00805f9b34fb`  
("BKOS" = 0x42 0x4B 0x4F 0x53 in ASCII)

### Characteristics

| UUID                                        | Naam          | Properties       | Formaat                        |
|---------------------------------------------|---------------|------------------|-------------------------------|
| `424b4f53-0001-1000-8000-00805f9b34fb`      | IO_OUTPUT     | READ + NOTIFY    | byte[] max 72 bytes, output states |
| `424b4f53-0002-1000-8000-00805f9b34fb`      | IO_INPUT      | READ + NOTIFY    | byte[] max 72 bytes, input states  |
| `424b4f53-0003-1000-8000-00805f9b34fb`      | IO_NAMEN      | READ             | zie chunked formaat hieronder  |
| `424b4f53-0004-1000-8000-00805f9b34fb`      | IO_CMD        | WRITE            | zie commando formaat           |
| `424b4f53-0005-1000-8000-00805f9b34fb`      | APP_STATE     | READ + NOTIFY    | [vaarmodus, verlichting]       |
| `424b4f53-0006-1000-8000-00805f9b34fb`      | NET_PEERS     | READ             | zie peer formaat               |
| `424b4f53-0007-1000-8000-00805f9b34fb`      | DEVICE_INFO   | READ             | zie info formaat               |

### IO_NAMEN formaat (chunked read)
BLE max packet = 512 bytes. Namen worden opgesplitst:
- Byte 0: chunk offset (0, 18, 36, ...)
- Byte 1: aantal namen in dit chunk
- Bytes 2+: aaneengeregen namen van elk IO_NAAM_LEN (12) bytes

App leest addig chunks tot offset >= io_kanalen_cnt.

### IO_CMD formaat
```
[0x01, kanaal_idx, 0xFF]          → toggle kanaal
[0x01, kanaal_idx, 0x00]          → kanaal UIT
[0x01, kanaal_idx, 0x01]          → kanaal AAN
[0x02, naam_len, naam...]         → toggle op naam (prefix match)
[0x10, modus]                     → set vaarmodus
[0x11, instelling]                → set verlichting
```

### NET_PEERS formaat
Per peer (max 8): `[mode, online, io_cnt, naam_len, naam...]`  
`naam` = null-terminated string, max NET_NAAM_LEN bytes

### DEVICE_INFO formaat
Null-terminated strings aaneengevoegd: `naam\0versie\0mac\0net_modus\0`

---

## Authenticatie

Geen authenticatie vereist voor lezen. Voor schrijfcommando's (toggle, modus wijzigen):
- Firmware leest PIN uit `/bkos_pin.txt` (4 cijfers)
- Eerste `IO_CMD` of POST na verbinding met `[0x00, pin[0], pin[1], pin[2], pin[3]]` = auth
- Na succesvolle auth: `[0xAA]` response via APP_STATE notify
- PIN `0000` = geen beveiliging (default)

*Opmerking: voor eerste versie kan auth worden weggelaten; PIN = `0000` altijd.*
