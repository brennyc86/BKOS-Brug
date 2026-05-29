// Stub voor web platform — BLE niet beschikbaar in browser
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
