import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bkos_service.dart';
import '../models/bkos_model.dart';
import '../theme.dart';
// mDNS discovery: stub op web, echt op native
import '../services/discovery_service_stub.dart'
    if (dart.library.io) '../services/discovery_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController();
  final _discovery = DiscoveryService();
  List<GevondenApparaat> _gevonden = [];
  bool _scanBezig = false;
  bool _handmatigUitgeklapt = false;
  bool _bleScannen = false;
  List<ScanResult> _bleResultaten = [];

  @override
  void initState() {
    super.initState();
    _laadLaatsteIp();
    if (!kIsWeb) _startDiscovery();
  }

  Future<void> _laadLaatsteIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('laatste_ip');
    if (ip != null) setState(() => _ipController.text = ip);
  }

  Future<void> _startDiscovery() async {
    setState(() { _scanBezig = true; _gevonden = []; });
    _discovery.apparaten.listen((lijst) {
      if (mounted) setState(() => _gevonden = lijst);
    });
    await _discovery.start();
    // Na 15 seconden stoppen met actief scannen maar resultaten bewaren
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) setState(() => _scanBezig = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BkosService>();

    return Scaffold(
      backgroundColor: kAchtergrond,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _Header(),
              const SizedBox(height: 32),

              // WiFi discovery sectie
              if (!kIsWeb) ...[
                _SectieKop(
                  titel: 'BKOS APPARATEN OP NETWERK',
                  actief: _scanBezig,
                  onHerscan: _startDiscovery,
                ),
                const SizedBox(height: 10),
                if (_gevonden.isEmpty && _scanBezig)
                  const _ScanIndicator()
                else if (_gevonden.isEmpty && !_scanBezig)
                  _GeenApparaten(onHerscan: _startDiscovery)
                else
                  ..._gevonden.map((a) => _ApparaatTegel(
                    apparaat: a,
                    onVerbind: () => _verbindWifiApparaat(svc, a),
                  )),
                const SizedBox(height: 20),
              ],

              // Handmatig IP
              _HandmatigPanel(
                uitgeklapt: _handmatigUitgeklapt || kIsWeb,
                onToggle: kIsWeb ? null : () =>
                    setState(() => _handmatigUitgeklapt = !_handmatigUitgeklapt),
                controller: _ipController,
                bezig: svc.verbindingBezig,
                onVerbind: () => _verbindHandmatig(svc),
              ),

              // BLE sectie
              if (!kIsWeb) ...[
                const SizedBox(height: 20),
                _SectieKop(titel: 'BLUETOOTH'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _bleScannen ? null : _startBleScan,
                  icon: _bleScannen
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kBeige))
                      : const Icon(Icons.bluetooth_searching, color: kBeigeZacht),
                  label: Text(
                    _bleScannen ? 'Scannen...' : 'Zoek via Bluetooth',
                    style: const TextStyle(color: kBeigeZacht),
                  ),
                ),
                if (_bleResultaten.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._bleResultaten.map((r) => _BleApparaatTegel(
                    result: r,
                    onVerbind: () => _verbindBle(svc, r.device.remoteId.str),
                  )),
                ],
              ],

              if (svc.foutmelding.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(svc.foutmelding,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verbindWifiApparaat(BkosService svc, GevondenApparaat a) async {
    await svc.verbindWebSocket(a.ip, poort: a.poort);
    if (svc.verbonden && mounted) context.go('/io');
  }

  Future<void> _verbindHandmatig(BkosService svc) async {
    await svc.verbindWebSocket(_ipController.text.trim());
    if (svc.verbonden && mounted) context.go('/io');
  }

  Future<void> _verbindBle(BkosService svc, String deviceId) async {
    await svc.verbindBle(deviceId);
    if (svc.verbonden && mounted) context.go('/io');
  }

  void _startBleScan() {
    const bkosUuid = '424b4f53-0000-1000-8000-00805f9b34fb';
    setState(() { _bleScannen = true; _bleResultaten = []; });
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [Guid(bkosUuid)],
    );
    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      // Filter: alleen apparaten met BKOS naam of met de BKOS service UUID
      final bkosResultaten = results.where((r) {
        final naam = r.device.platformName.toLowerCase();
        if (naam.contains('bkos')) return true;
        final uuids = r.advertisementData.serviceUuids.map((g) => g.str128.toLowerCase());
        return uuids.contains(bkosUuid);
      }).toList();
      setState(() => _bleResultaten = bkosResultaten);
    });
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _bleScannen = false);
    });
  }

  @override
  void dispose() {
    _discovery.dispose();
    _ipController.dispose();
    super.dispose();
  }
}

// ─── Header met zeilboot ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Kajuitzeilboot icoon
      Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kOppervlak,
              border: Border.all(color: kGroenPrimair.withOpacity(0.4), width: 1.5),
            ),
          ),
          const Icon(Icons.sailing, size: 52, color: kGroenLicht),
        ],
      ),
      const SizedBox(height: 14),
      const Text('BKOS Brug',
          style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: kBeige, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      const Text('Boordcomputer verbinding',
          style: TextStyle(fontSize: 13, color: kBeigeZacht)),
    ]);
  }
}

// ─── Sectie kop ──────────────────────────────────────────────────────────────

class _SectieKop extends StatelessWidget {
  final String titel;
  final bool actief;
  final VoidCallback? onHerscan;

  const _SectieKop({required this.titel, this.actief = false, this.onHerscan});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(titel,
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: kBeigeZacht, letterSpacing: 1.3)),
      const Spacer(),
      if (actief)
        const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: kGroenPrimair))
      else if (onHerscan != null)
        GestureDetector(
          onTap: onHerscan,
          child: const Icon(Icons.refresh, size: 18, color: kBeigeZacht),
        ),
    ]);
  }
}

// ─── Scan indicator ───────────────────────────────────────────────────────────

class _ScanIndicator extends StatelessWidget {
  const _ScanIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kOppervlak,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBeigeRand),
      ),
      child: const Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: kGroenPrimair)),
        SizedBox(width: 12),
        Text('Zoeken naar BKOS apparaten...',
            style: TextStyle(color: kBeigeZacht, fontSize: 13)),
      ]),
    );
  }
}

// ─── Geen apparaten gevonden ──────────────────────────────────────────────────

class _GeenApparaten extends StatelessWidget {
  final VoidCallback onHerscan;
  const _GeenApparaten({required this.onHerscan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kOppervlak,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBeigeRand),
      ),
      child: Column(children: [
        const Icon(Icons.wifi_off, color: kBeigeDim, size: 32),
        const SizedBox(height: 8),
        const Text('Geen BKOS apparaten gevonden',
            style: TextStyle(color: kBeigeZacht, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Zorg dat BKOS en dit apparaat op hetzelfde netwerk zitten',
            style: TextStyle(color: kBeigeDim, fontSize: 11),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton(onPressed: onHerscan,
            child: const Text('Opnieuw scannen',
                style: TextStyle(color: kGroenLicht))),
      ]),
    );
  }
}

// ─── Gevonden apparaat tegel ──────────────────────────────────────────────────

class _ApparaatTegel extends StatelessWidget {
  final GevondenApparaat apparaat;
  final VoidCallback onVerbind;

  const _ApparaatTegel({required this.apparaat, required this.onVerbind});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kOppervlak,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kGroenPrimair.withOpacity(0.4), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kGroenPrimair.withOpacity(0.15),
          ),
          child: const Icon(Icons.sailing, color: kGroenLicht, size: 22),
        ),
        title: Text(
          apparaat.weergaveNaam,
          style: const TextStyle(
            color: kBeige, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (apparaat.bootnaam.isNotEmpty)
              Text(apparaat.bootnaam,
                  style: const TextStyle(color: kBeigeZacht, fontSize: 12)),
            Row(children: [
              if (apparaat.netModusLabel.isNotEmpty)
                _ModusBadge(apparaat.netModusLabel),
              const SizedBox(width: 6),
              Text(apparaat.ip,
                  style: const TextStyle(color: kBeigeDim, fontSize: 11)),
            ]),
          ],
        ),
        trailing: FilledButton(
          onPressed: onVerbind,
          style: FilledButton.styleFrom(
            backgroundColor: kGroenPrimair,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Verbind', style: TextStyle(color: kBeige)),
        ),
      ),
    );
  }
}

class _ModusBadge extends StatelessWidget {
  final String label;
  const _ModusBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kGroenPrimair.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kGroenPrimair.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
            fontSize: 10, color: kGroenLicht, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Handmatig IP panel ───────────────────────────────────────────────────────

class _HandmatigPanel extends StatelessWidget {
  final bool uitgeklapt;
  final VoidCallback? onToggle;
  final TextEditingController controller;
  final bool bezig;
  final VoidCallback onVerbind;

  const _HandmatigPanel({
    required this.uitgeklapt,
    required this.onToggle,
    required this.controller,
    required this.bezig,
    required this.onVerbind,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggle != null)
          GestureDetector(
            onTap: onToggle,
            child: Row(children: [
              const Text('HANDMATIG IP INVOEREN',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: kBeigeDim, letterSpacing: 1.3)),
              const Spacer(),
              Icon(uitgeklapt ? Icons.expand_less : Icons.expand_more,
                  color: kBeigeDim, size: 18),
            ]),
          ),
        if (uitgeklapt) ...[
          if (onToggle != null) const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'IP-adres ESP32',
              hintText: '192.168.1.100',
              prefixIcon: Icon(Icons.wifi, color: kBeigeZacht),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: kBeige),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: bezig ? null : onVerbind,
            icon: bezig
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kBeige))
                : const Icon(Icons.link, color: kBeige),
            label: Text(bezig ? 'Verbinden...' : 'Verbinden',
                style: const TextStyle(color: kBeige)),
          ),
        ],
      ],
    );
  }
}

// ─── BLE apparaat tegel ───────────────────────────────────────────────────────

class _BleApparaatTegel extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onVerbind;
  const _BleApparaatTegel({required this.result, required this.onVerbind});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: kOppervlak,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBeigeRand),
      ),
      child: ListTile(
        leading: const Icon(Icons.bluetooth, color: kBeigeZacht),
        title: Text(
          result.device.platformName.isNotEmpty
              ? result.device.platformName : 'BKOS apparaat',
          style: const TextStyle(color: kBeige, fontSize: 14)),
        subtitle: Text(result.device.remoteId.str,
            style: const TextStyle(color: kBeigeDim, fontSize: 11)),
        trailing: TextButton(
          onPressed: onVerbind,
          child: const Text('Verbind', style: TextStyle(color: kGroenLicht)),
        ),
      ),
    );
  }
}
