// BleService — BLE GATT verbinding naar BKOS-NUI
// Alleen geladen op niet-web platforms
// Zie PROTOCOL.md voor UUID definities

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs (gelijk aan bkos_client.h)
const String _kServiceUuid     = '424b4f53-0000-1000-8000-00805f9b34fb';
const String _kIoOutputUuid    = '424b4f53-0001-1000-8000-00805f9b34fb';
const String _kIoInputUuid     = '424b4f53-0002-1000-8000-00805f9b34fb';
const String _kIoNamenUuid     = '424b4f53-0003-1000-8000-00805f9b34fb';
const String _kIoCmdUuid       = '424b4f53-0004-1000-8000-00805f9b34fb';
const String _kAppStateUuid    = '424b4f53-0005-1000-8000-00805f9b34fb';
const String _kNetPeersUuid    = '424b4f53-0006-1000-8000-00805f9b34fb';
const String _kDeviceInfoUuid  = '424b4f53-0007-1000-8000-00805f9b34fb';

typedef BleDataCallback = void Function(String type, Uint8List data);

class BleService {
  final BleDataCallback onData;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _namenChar;
  bool _verbonden = false;

  BleService({required this.onData});

  // Scan naar BKOS apparaten (naam begint met "BKOS")
  Stream<List<ScanResult>> scannen() {
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [Guid(_kServiceUuid)],
    );
    return FlutterBluePlus.scanResults;
  }

  void stopScan() => FlutterBluePlus.stopScan();

  Future<bool> verbind(String deviceId) async {
    try {
      _device = BluetoothDevice.fromId(deviceId);
      await _device!.connect(timeout: const Duration(seconds: 10));

      final services = await _device!.discoverServices();
      final svc = services.firstWhere(
        (s) => s.uuid.str128.toLowerCase() == _kServiceUuid,
      );

      for (final ch in svc.characteristics) {
        final uuid = ch.uuid.str128.toLowerCase();
        switch (uuid) {
          case _kIoOutputUuid:
            await ch.setNotifyValue(true);
            ch.lastValueStream.listen((v) => onData('io_out', Uint8List.fromList(v)));
          case _kIoInputUuid:
            await ch.setNotifyValue(true);
            ch.lastValueStream.listen((v) => onData('io_in', Uint8List.fromList(v)));
          case _kAppStateUuid:
            await ch.setNotifyValue(true);
            ch.lastValueStream.listen((v) => onData('app_state', Uint8List.fromList(v)));
          case _kIoCmdUuid:
            _cmdChar = ch;
          case _kIoNamenUuid:
            _namenChar = ch;
          default:
            break;
        }
      }

      // Namen ophalen in chunks
      await _laadNamen(svc);

      _verbonden = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _laadNamen(BluetoothService svc) async {
    if (_namenChar == null) return;
    final namenChar = _namenChar!;
    const naamLen = 12;
    List<String> namen = [];
    int offset = 0;

    while (true) {
      // Schrijf gevraagde offset
      await namenChar.write([offset], withoutResponse: false);
      final chunk = await namenChar.read();
      if (chunk.length < 2) break;
      final chunkOffset = chunk[0];
      final count = chunk[1];
      if (count == 0) break;

      for (int i = 0; i < count; i++) {
        final start = 2 + i * naamLen;
        if (start + naamLen > chunk.length) break;
        final bytes = chunk.sublist(start, start + naamLen);
        final naam = String.fromCharCodes(bytes.takeWhile((b) => b != 0));
        namen.add(naam);
      }

      offset += count;
      if (chunkOffset + count >= 240) break; // MAX_IO_KANALEN
    }

    // Stuur namen als speciale callback
    if (namen.isNotEmpty) {
      final joined = namen.join('\n');
      onData('namen', Uint8List.fromList(joined.codeUnits));
    }
  }

  void stuurCmd(Map<String, dynamic> msg) {
    if (_cmdChar == null) return;
    final List<int> bytes = _bouwCmd(msg);
    if (bytes.isNotEmpty) {
      _cmdChar!.write(bytes, withoutResponse: true);
    }
  }

  List<int> _bouwCmd(Map<String, dynamic> msg) {
    final type = msg['t'] as String?;
    switch (type) {
      case 'io_toggle':
        return [0x01, msg['i'] as int, 0xFF];
      case 'io_set':
        return [0x01, msg['i'] as int, (msg['v'] as int? ?? 0)];
      case 'io_naam':
        final naam = (msg['n'] as String).codeUnits;
        return [0x02, naam.length, ...naam];
      case 'set_modus':
        return [0x10, msg['m'] as int];
      case 'set_licht':
        return [0x11, msg['l'] as int];
      default:
        return [];
    }
  }

  void verbreek() {
    _device?.disconnect();
    _device = null;
    _cmdChar = null;
    _namenChar = null;
    _verbonden = false;
  }

  bool get verbonden => _verbonden;
}
