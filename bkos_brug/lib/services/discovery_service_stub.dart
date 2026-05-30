// Stub voor web — mDNS niet beschikbaar in browser
import 'dart:async';
import '../models/bkos_model.dart';

class DiscoveryService {
  Stream<List<GevondenApparaat>> get apparaten => const Stream.empty();
  List<GevondenApparaat> get huidig => const [];
  Future<void> start() async {}
  Future<void> stop() async {}
  void dispose() {}
}
