import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bkos_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController();
  bool _bleScannen = false;
  List<ScanResult> _bleResultaten = [];

  @override
  void initState() {
    super.initState();
    _laadLaatsteIp();
  }

  Future<void> _laadLaatsteIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('laatste_ip');
    if (ip != null) _ipController.text = ip;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BkosService>();

    return Scaffold(
      appBar: AppBar(title: const Text('BKOS Verbinden')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo / header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.directions_boat, size: 64, color: Color(0xFF5B8FB9)),
                SizedBox(height: 12),
                Text('BKOS Boordcomputer',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
            ),

            // WiFi sectie
            _SectieKop(titel: 'WiFi Verbinding'),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Adres ESP32',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.wifi),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: svc.verbindingBezig ? null : () => _verbindWifi(svc),
              icon: svc.verbindingBezig
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: Text(svc.verbindingBezig ? 'Verbinden...' : 'Verbinden via WiFi'),
            ),

            if (!kIsWeb) ...[
              const SizedBox(height: 32),
              _SectieKop(titel: 'Bluetooth'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _bleScannen ? null : _startBleScan,
                icon: _bleScannen
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_bleScannen ? 'Scannen...' : 'Zoek BKOS apparaten'),
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
              Text(svc.foutmelding,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verbindWifi(BkosService svc) async {
    await svc.verbindWebSocket(_ipController.text.trim());
    if (svc.verbonden && mounted) context.go('/io');
  }

  Future<void> _verbindBle(BkosService svc, String deviceId) async {
    await svc.verbindBle(deviceId);
    if (svc.verbonden && mounted) context.go('/io');
  }

  void _startBleScan() {
    setState(() { _bleScannen = true; _bleResultaten = []; });
    final stream = context.read<BkosService>(); // niet gebruikt, BleService direct
    // Gebruik FlutterBluePlus direct
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      withServices: [Guid('424b4f53-0000-1000-8000-00805f9b34fb')],
    );
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _bleResultaten = results);
    });
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _bleScannen = false);
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}

class _SectieKop extends StatelessWidget {
  final String titel;
  const _SectieKop({required this.titel});

  @override
  Widget build(BuildContext context) {
    return Text(titel,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2));
  }
}

class _BleApparaatTegel extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onVerbind;
  const _BleApparaatTegel({required this.result, required this.onVerbind});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bluetooth),
        title: Text(result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'BKOS apparaat'),
        subtitle: Text(result.device.remoteId.str),
        trailing: TextButton(onPressed: onVerbind, child: const Text('Verbind')),
      ),
    );
  }
}
