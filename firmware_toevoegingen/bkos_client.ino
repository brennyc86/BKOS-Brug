// bkos_client.ino — implementatie van WebSocket + BLE client API
// Benodigde bibliotheek: arduinoWebSockets (Markus Sattler)
//   Arduino IDE → Bibliotheekbeheer → "WebSockets" van Markus Sattler → installeer
// BLE: ingebouwd in ESP32 Arduino Core

#include "bkos_client.h"
#include "app_state.h"
#include "io.h"
#include "bkos_net.h"

// ─── WebSocket ───────────────────────────────────────────────────────────────
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

static WebSocketsServer _ws(BKOS_WS_POORT);
static bool _ws_client_verbonden[4] = {false};
static byte _ws_prev_output[MAX_IO_KANALEN];
static bool _ws_prev_input[MAX_IO_KANALEN];
static byte _ws_prev_modus = 255;
static byte _ws_prev_licht = 255;

static void _ws_stuur(uint8_t num, const String& json) {
  _ws.sendTXT(num, json);
}

static void _ws_broadcast(const String& json) {
  _ws.broadcastTXT(json);
}

static String _io_full_json() {
  // Gebruik StaticJsonDocument voor kleine buffers op embedded
  String out = "{\"t\":\"io_full\",\"cnt\":";
  out += io_kanalen_cnt;
  out += ",\"o\":[";
  for (int i = 0; i < io_kanalen_cnt; i++) {
    if (i) out += ',';
    out += io_output[i];
  }
  out += "],\"i\":[";
  for (int i = 0; i < io_kanalen_cnt; i++) {
    if (i) out += ',';
    out += io_input[i] ? 1 : 0;
  }
  out += "],\"n\":[";
  for (int i = 0; i < io_kanalen_cnt; i++) {
    if (i) out += ',';
    out += '"';
    out += io_namen[i];
    out += '"';
  }
  out += "]}";
  return out;
}

static String _state_json() {
  String s = "{\"t\":\"state\",\"m\":";
  s += vaar_modus;
  s += ",\"l\":";
  s += licht_instelling;
  s += "}";
  return s;
}

static String _net_json() {
  String s = "{\"t\":\"net\",\"peers\":[";
  bool first = true;
  for (int i = 0; i < NET_MAX_PEERS; i++) {
    if (net_peers[i].mac[0] == 0) continue;
    if (!first) s += ',';
    first = false;
    s += "{\"naam\":\"";
    s += net_peers[i].naam;
    s += "\",\"mode\":";
    s += net_peers[i].modus;
    s += ",\"online\":";
    s += net_peers[i].online ? "true" : "false";
    s += ",\"io\":";
    s += net_peers[i].io_kanalen;
    s += "}";
  }
  s += "]}";
  return s;
}

static String _info_json() {
  String s = "{\"t\":\"info\",\"naam\":\"";
  s += net_eigen_naam;
  s += "\",\"ver\":\"";
  s += BKOS_NUI_VERSIE;
  s += "\",\"mac\":\"";
  // MAC ophalen
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char mac_str[18];
  snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  s += mac_str;
  s += "\",\"net_modus\":";
  s += net_modus;
  s += "}";
  return s;
}

static void _ws_verwerk_cmd(uint8_t num, const String& tekst) {
  // Minimale JSON parse zonder bibliotheek voor performance
  if (tekst.indexOf("\"io_toggle\"") >= 0) {
    int idx = tekst.indexOf("\"i\":");
    if (idx >= 0) {
      int kanaal = tekst.substring(idx + 4).toInt();
      net_io_kanaal_toggle(kanaal);
    }
  } else if (tekst.indexOf("\"io_set\"") >= 0) {
    int idx_i = tekst.indexOf("\"i\":");
    int idx_v = tekst.indexOf("\"v\":");
    if (idx_i >= 0 && idx_v >= 0) {
      int kanaal = tekst.substring(idx_i + 4).toInt();
      int staat = tekst.substring(idx_v + 4).toInt();
      // Stuur via net als master, anders lokaal
      net_io_kanaal_zet(kanaal, staat);
    }
  } else if (tekst.indexOf("\"io_naam\"") >= 0) {
    int idx = tekst.indexOf("\"n\":\"");
    if (idx >= 0) {
      int start = idx + 5;
      int end = tekst.indexOf('"', start);
      String naam = tekst.substring(start, end);
      char buf[IO_NAAM_LEN + 1];
      naam.toCharArray(buf, sizeof(buf));
      net_io_naam_toggle(buf, 1); // 1 = prefix match
    }
  } else if (tekst.indexOf("\"set_modus\"") >= 0) {
    int idx = tekst.indexOf("\"m\":");
    if (idx >= 0) vaar_modus = tekst.substring(idx + 4).toInt();
    net_app_state_sync();
  } else if (tekst.indexOf("\"set_licht\"") >= 0) {
    int idx = tekst.indexOf("\"l\":");
    if (idx >= 0) licht_instelling = tekst.substring(idx + 4).toInt();
    io_verlichting_update();
    net_app_state_sync();
  } else if (tekst.indexOf("\"ping\"") >= 0) {
    _ws_stuur(num, "{\"t\":\"pong\"}");
  }
}

static void _ws_event(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      _ws_client_verbonden[num] = true;
      _ws_stuur(num, _io_full_json());
      _ws_stuur(num, _state_json());
      _ws_stuur(num, _net_json());
      _ws_stuur(num, _info_json());
      break;
    case WStype_DISCONNECTED:
      _ws_client_verbonden[num] = false;
      break;
    case WStype_TEXT:
      _ws_verwerk_cmd(num, String((char*)payload));
      break;
    default:
      break;
  }
}

void bkos_ws_setup() {
  _ws.begin();
  _ws.onEvent(_ws_event);
  memset(_ws_prev_output, 255, sizeof(_ws_prev_output));
}

void bkos_ws_loop() {
  if (!wifi_verbonden) return;
  _ws.loop();

  // Detecteer IO wijzigingen en stuur delta's
  for (int i = 0; i < io_kanalen_cnt; i++) {
    if (io_output[i] != _ws_prev_output[i] || io_input[i] != _ws_prev_input[i]) {
      String delta = "{\"t\":\"io_delta\",\"ch\":";
      delta += i;
      delta += ",\"o\":";
      delta += io_output[i];
      delta += ",\"i\":";
      delta += io_input[i] ? 1 : 0;
      delta += "}";
      _ws_broadcast(delta);
      _ws_prev_output[i] = io_output[i];
      _ws_prev_input[i] = io_input[i];
    }
  }

  // State wijzigingen
  if (vaar_modus != _ws_prev_modus || licht_instelling != _ws_prev_licht) {
    _ws_broadcast(_state_json());
    _ws_prev_modus = vaar_modus;
    _ws_prev_licht = licht_instelling;
  }
}

void bkos_ws_stuur_io_full() {
  _ws_broadcast(_io_full_json());
}

void bkos_ws_stuur_io_delta(int kanaal) {
  String delta = "{\"t\":\"io_delta\",\"ch\":";
  delta += kanaal;
  delta += ",\"o\":";
  delta += io_output[kanaal];
  delta += ",\"i\":";
  delta += io_input[kanaal] ? 1 : 0;
  delta += "}";
  _ws_broadcast(delta);
}

void bkos_ws_stuur_state() {
  _ws_broadcast(_state_json());
}

void bkos_ws_stuur_net() {
  _ws_broadcast(_net_json());
}

bool bkos_ws_heeft_clients() {
  for (int i = 0; i < 4; i++) if (_ws_client_verbonden[i]) return true;
  return false;
}

// ─── BLE ─────────────────────────────────────────────────────────────────────
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

static BLEServer* _ble_server = nullptr;
static BLECharacteristic* _ble_io_out = nullptr;
static BLECharacteristic* _ble_io_in = nullptr;
static BLECharacteristic* _ble_io_namen = nullptr;
static BLECharacteristic* _ble_io_cmd = nullptr;
static BLECharacteristic* _ble_app_state = nullptr;
static BLECharacteristic* _ble_net_peers = nullptr;
static BLECharacteristic* _ble_info = nullptr;
static bool _ble_verbonden = false;

class BLEServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer*) override { _ble_verbonden = true; }
  void onDisconnect(BLEServer* svr) override {
    _ble_verbonden = false;
    svr->startAdvertising();
  }
};

class IOCmdCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* ch) override {
    std::string val = ch->getValue();
    if (val.empty()) return;
    uint8_t cmd = (uint8_t)val[0];
    if (cmd == 0x01 && val.size() >= 3) {
      uint8_t kanaal = (uint8_t)val[1];
      uint8_t actie = (uint8_t)val[2];
      if (actie == 0xFF) net_io_kanaal_toggle(kanaal);
      else net_io_kanaal_zet(kanaal, actie);
    } else if (cmd == 0x02 && val.size() >= 3) {
      uint8_t len = (uint8_t)val[1];
      char naam[IO_NAAM_LEN + 1] = {0};
      memcpy(naam, &val[2], min((int)len, IO_NAAM_LEN));
      net_io_naam_toggle(naam, 1);
    } else if (cmd == 0x10 && val.size() >= 2) {
      vaar_modus = (uint8_t)val[1];
      net_app_state_sync();
    } else if (cmd == 0x11 && val.size() >= 2) {
      licht_instelling = (uint8_t)val[1];
      io_verlichting_update();
      net_app_state_sync();
    }
  }
};

class NamenCB : public BLECharacteristicCallbacks {
  // Chunked read: client schrijft chunk-offset als 1 byte, leest dan chunk
  void onWrite(BLECharacteristic* ch) override {
    std::string v = ch->getValue();
    uint8_t offset = v.empty() ? 0 : (uint8_t)v[0];
    uint8_t chunk = 18; // namen per packet
    uint8_t buf[2 + 18 * IO_NAAM_LEN];
    buf[0] = offset;
    int cnt = min((int)chunk, io_kanalen_cnt - (int)offset);
    buf[1] = max(cnt, 0);
    for (int i = 0; i < buf[1]; i++) {
      memcpy(&buf[2 + i * IO_NAAM_LEN], io_namen[offset + i], IO_NAAM_LEN);
    }
    _ble_io_namen->setValue(buf, 2 + buf[1] * IO_NAAM_LEN);
  }
};

void bkos_ble_setup() {
  BLEDevice::init(net_eigen_naam[0] ? net_eigen_naam : "BKOS-NUI");
  _ble_server = BLEDevice::createServer();
  _ble_server->setCallbacks(new BLEServerCB());

  BLEService* svc = _ble_server->createService(BLE_SERVICE_UUID);

  _ble_io_out = svc->createCharacteristic(BLE_IO_OUTPUT_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  _ble_io_out->addDescriptor(new BLE2902());

  _ble_io_in = svc->createCharacteristic(BLE_IO_INPUT_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  _ble_io_in->addDescriptor(new BLE2902());

  _ble_io_namen = svc->createCharacteristic(BLE_IO_NAMEN_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  _ble_io_namen->setCallbacks(new NamenCB());

  _ble_io_cmd = svc->createCharacteristic(BLE_IO_CMD_UUID,
    BLECharacteristic::PROPERTY_WRITE);
  _ble_io_cmd->setCallbacks(new IOCmdCB());

  _ble_app_state = svc->createCharacteristic(BLE_APP_STATE_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  _ble_app_state->addDescriptor(new BLE2902());

  _ble_net_peers = svc->createCharacteristic(BLE_NET_PEERS_UUID,
    BLECharacteristic::PROPERTY_READ);

  _ble_info = svc->createCharacteristic(BLE_INFO_UUID,
    BLECharacteristic::PROPERTY_READ);

  // Initiële waarden
  bkos_ble_notify_io();
  bkos_ble_notify_state();

  svc->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(BLE_SERVICE_UUID);
  adv->start();
}

void bkos_ble_notify_io() {
  if (!_ble_io_out || !_ble_io_in) return;
  _ble_io_out->setValue(io_output, io_kanalen_cnt);
  if (_ble_verbonden) _ble_io_out->notify();

  uint8_t in_buf[MAX_IO_KANALEN];
  for (int i = 0; i < io_kanalen_cnt; i++) in_buf[i] = io_input[i] ? 1 : 0;
  _ble_io_in->setValue(in_buf, io_kanalen_cnt);
  if (_ble_verbonden) _ble_io_in->notify();
}

void bkos_ble_notify_state() {
  if (!_ble_app_state) return;
  uint8_t buf[2] = { vaar_modus, licht_instelling };
  _ble_app_state->setValue(buf, 2);
  if (_ble_verbonden) _ble_app_state->notify();
}

void bkos_ble_loop() {
  // BLE is interrupt-driven, geen polling nodig
  // Net/info characteristics bijwerken wanneer gevraagd
}

// ─── Gecombineerde setup/loop ─────────────────────────────────────────────────

void bkos_client_setup() {
  bkos_ws_setup();
  bkos_ble_setup();
}

void bkos_client_loop() {
  bkos_ws_loop();
  bkos_ble_loop();
}
