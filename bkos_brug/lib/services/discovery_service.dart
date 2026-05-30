// discovery_service.dart — mDNS zoekdienst voor BKOS apparaten op WiFi
// Vereist dat BKOS-NUI firmware de _bkos._tcp service adverteert via ESPmDNS
// Zie firmware_toevoegingen/INSTRUCTIES.md voor hoe dit in BKOS in te stellen

import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import '../models/bkos_model.dart';

class DiscoveryService {
  BonsoirDiscovery? _discovery;
  final _controller = StreamController<List<GevondenApparaat>>.broadcast();
  final List<GevondenApparaat> _gevonden = [];

  Stream<List<GevondenApparaat>> get apparaten => _controller.stream;
  List<GevondenApparaat> get huidig => List.unmodifiable(_gevonden);

  Future<void> start() async {
    await stop();
    _gevonden.clear();

    _discovery = BonsoirDiscovery(type: '_bkos._tcp');
    await _discovery!.ready;

    _discovery!.eventStream!.listen((BonsoirDiscoveryEvent event) {
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        event.service!.resolve(_discovery!.serviceResolver);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final svc = event.service as ResolvedBonsoirService;
        final attrs = svc.attributes ?? {};
        final apparaat = GevondenApparaat(
          ip: svc.host ?? '',
          poort: svc.port,
          computernaam: attrs['comp'] ?? svc.name,
          bootnaam: attrs['boot'] ?? '',
          netModus: int.tryParse(attrs['modus'] ?? '') ?? -1,
          viaMdns: true,
        );
        if (apparaat.ip.isNotEmpty) {
          // Vervang als al aanwezig (update), anders toevoegen
          final idx = _gevonden.indexWhere((a) => a.ip == apparaat.ip);
          if (idx >= 0) {
            _gevonden[idx] = apparaat;
          } else {
            _gevonden.add(apparaat);
          }
          _controller.add(List.unmodifiable(_gevonden));
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        final name = event.service?.name ?? '';
        _gevonden.removeWhere((a) => a.computernaam == name);
        _controller.add(List.unmodifiable(_gevonden));
      }
    });

    await _discovery!.start();
  }

  Future<void> stop() async {
    await _discovery?.stop();
    _discovery = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
