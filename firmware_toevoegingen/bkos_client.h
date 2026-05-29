// bkos_client.h — WebSocket + BLE server voor externe apps
// Voeg toe aan BKOS_NUI project
// Afhankelijkheden: app_state.h, io.h, bkos_net.h

#pragma once
#include <Arduino.h>

// WebSocket server — poort 8080
void bkos_ws_setup();
void bkos_ws_loop();
void bkos_ws_stuur_io_full();       // volledige IO sync naar alle clients
void bkos_ws_stuur_io_delta(int kanaal); // één kanaal update
void bkos_ws_stuur_state();         // vaarmodus + verlichting
void bkos_ws_stuur_net();           // peer lijst
bool bkos_ws_heeft_clients();

// BLE GATT server
void bkos_ble_setup();
void bkos_ble_loop();
void bkos_ble_notify_io();          // notificeer geabonneerde BLE clients
void bkos_ble_notify_state();

// Combinatie setup/loop (roep aan vanuit hardware.ino)
void bkos_client_setup();
void bkos_client_loop();

// UUIDs voor BLE service (zie PROTOCOL.md)
#define BLE_SERVICE_UUID    "424b4f53-0000-1000-8000-00805f9b34fb"
#define BLE_IO_OUTPUT_UUID  "424b4f53-0001-1000-8000-00805f9b34fb"
#define BLE_IO_INPUT_UUID   "424b4f53-0002-1000-8000-00805f9b34fb"
#define BLE_IO_NAMEN_UUID   "424b4f53-0003-1000-8000-00805f9b34fb"
#define BLE_IO_CMD_UUID     "424b4f53-0004-1000-8000-00805f9b34fb"
#define BLE_APP_STATE_UUID  "424b4f53-0005-1000-8000-00805f9b34fb"
#define BLE_NET_PEERS_UUID  "424b4f53-0006-1000-8000-00805f9b34fb"
#define BLE_INFO_UUID       "424b4f53-0007-1000-8000-00805f9b34fb"

// WebSocket poort
#define BKOS_WS_POORT 8080
