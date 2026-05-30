// BkosService — centrale state en verbindingslogica
// Beheert WebSocket verbinding + BLE verbinding
// Kiest automatisch de beste methode

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/bkos_model.dart';
// Conditionele import: stub op web, echte implementatie op native platforms
import 'ble_service_stub.dart' if (dart.library.io) 'ble_service.dart';

class BkosService extends ChangeNotifier {
  // Verbindingstoestand
  bool _verbonden = false;
  bool _verbindingBezig = false;
  String _foutmelding = '';
  String _verbindingsMethode = ''; // 'ws' of 'ble'

  // BKOS data
  List<IoKanaal> _kanalen = [];
  List<NetwerkPeer> _peers = [];
  BkosInfo? _info;
  VaarModus _vaarModus = VaarModus.haven;
  Verlichting _verlichting = Verlichting.uit;

  // WebSocket
  WebSocketChannel? _ws;
  Timer? _reconnectTimer;

  // BLE
  late final BleService _ble;

  bool get verbonden => _verbonden;
  bool get verbindingBezig => _verbindingBezig;
  String get foutmelding => _foutmelding;
  String get verbindingsMethode => _verbindingsMethode;
  List<IoKanaal> get kanalen => _kanalen;
  List<NetwerkPeer> get peers => _peers;
  BkosInfo? get info => _info;
  VaarModus get vaarModus => _vaarModus;
  Verlichting get verlichting => _verlichting;

  BkosService() {
    if (!kIsWeb) _ble = BleService(onData: _verwerkBleData);
  }

  // ─── Verbinden ─────────────────────────────────────────────────────────────

  Future<void> verbindWebSocket(String ip, {int poort = 8080}) async {
    _verbindingBezig = true;
    _foutmelding = '';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('laatste_ip', ip);

    try {
      _ws = WebSocketChannel.connect(Uri.parse('ws://$ip:$poort/bkos'));
      await _ws!.ready.timeout(const Duration(seconds: 5));

      _ws!.stream.listen(
        _verwerkWsData,
        onDone: _wsVerbroken,
        onError: (_) => _wsVerbroken(),
      );

      _verbonden = true;
      _verbindingsMethode = 'ws';
    } catch (e) {
      _foutmelding = 'Kan niet verbinden: $e';
      _verbonden = false;
    }

    _verbindingBezig = false;
    notifyListeners();
  }

  Future<void> verbindBle(String deviceId) async {
    if (kIsWeb) return;
    _verbindingBezig = true;
    notifyListeners();

    final ok = await _ble.verbind(deviceId);
    if (ok) {
      _verbonden = true;
      _verbindingsMethode = 'ble';
    } else {
      _foutmelding = 'BLE verbinding mislukt';
    }

    _verbindingBezig = false;
    notifyListeners();
  }

  void verbreek() {
    _ws?.sink.close();
    _ws = null;
    if (!kIsWeb) _ble.verbreek();
    _verbonden = false;
    _kanalen = [];
    _peers = [];
    _info = null;
    _reconnectTimer?.cancel();
    notifyListeners();
  }

  // ─── Commando's ────────────────────────────────────────────────────────────

  void ioToggle(int index) {
    _stuur({'t': 'io_toggle', 'i': index});
  }

  void ioNaamToggle(String naam) {
    _stuur({'t': 'io_naam', 'n': naam});
  }

  void setVaarModus(VaarModus modus) {
    _stuur({'t': 'set_modus', 'm': modus.index});
  }

  void setVerlichting(Verlichting v) {
    _stuur({'t': 'set_licht', 'l': v.index});
  }

  void _stuur(Map<String, dynamic> msg) {
    final json = jsonEncode(msg);
    if (_verbindingsMethode == 'ws') {
      _ws?.sink.add(json);
    } else if (!kIsWeb) {
      _ble.stuurCmd(msg);
    }
  }

  // ─── WebSocket data verwerking ──────────────────────────────────────────────

  void _verwerkWsData(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      final type = msg['t'] as String?;

      switch (type) {
        case 'io_full':
          _verwerkIoFull(msg);
        case 'io_delta':
          _verwerkIoDelta(msg);
        case 'state':
          _vaarModus = VaarModus.values[msg['m'] as int];
          _verlichting = Verlichting.values[msg['l'] as int];
          notifyListeners();
        case 'net':
          _verwerkNet(msg);
        case 'info':
          _info = BkosInfo(
            naam: msg['naam'] ?? '',
            bootnaam: msg['boot'] ?? '',
            versie: msg['ver'] ?? '',
            mac: msg['mac'] ?? '',
            netModus: msg['net_modus'] ?? 0,
          );
          notifyListeners();
        case 'pong':
          break;
      }
    } catch (_) {}
  }

  void _verwerkIoFull(Map<String, dynamic> msg) {
    final cnt = msg['cnt'] as int;
    final outputs = (msg['o'] as List).cast<int>();
    final inputs = (msg['i'] as List).cast<int>();
    final namen = (msg['n'] as List).cast<String>();

    _kanalen = List.generate(cnt, (i) => IoKanaal(
      index: i,
      naam: namen[i],
      output: IoOutput.values[outputs[i].clamp(0, IoOutput.values.length - 1)],
      input: inputs[i] == 1,
      isIngang: false, // TODO: richting bits toevoegen als firmware dat stuurt
    ));
    notifyListeners();
  }

  void _verwerkIoDelta(Map<String, dynamic> msg) {
    final ch = msg['ch'] as int;
    if (ch >= _kanalen.length) return;
    final output = IoOutput.values[(msg['o'] as int).clamp(0, IoOutput.values.length - 1)];
    final input = (msg['i'] as int) == 1;
    _kanalen = List.of(_kanalen)..[ch] = _kanalen[ch].copyWith(output: output, input: input);
    notifyListeners();
  }

  void _verwerkNet(Map<String, dynamic> msg) {
    final peers = (msg['peers'] as List).cast<Map<String, dynamic>>();
    _peers = peers.map((p) => NetwerkPeer(
      naam: p['naam'] ?? '',
      modus: p['mode'] ?? 0,
      online: p['online'] ?? false,
      ioKanalen: p['io'] ?? 0,
    )).toList();
    notifyListeners();
  }

  void _wsVerbroken() {
    if (!_verbonden) return;
    _verbonden = false;
    notifyListeners();
    // Herverbind na 5 seconden
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('laatste_ip');
      if (ip != null) verbindWebSocket(ip);
    });
  }

  // ─── BLE data verwerking ────────────────────────────────────────────────────

  void _verwerkBleData(String type, Uint8List data) {
    switch (type) {
      case 'io_out':
        // data = byte array van output states
        if (_kanalen.isEmpty) return;
        _kanalen = List.generate(
          data.length,
          (i) => i < _kanalen.length
              ? _kanalen[i].copyWith(output: IoOutput.values[data[i].clamp(0, 5)])
              : IoKanaal(index: i, naam: 'CH${i + 1}', output: IoOutput.values[data[i].clamp(0, 5)], input: false, isIngang: false),
        );
        notifyListeners();
      case 'io_in':
        for (int i = 0; i < data.length && i < _kanalen.length; i++) {
          _kanalen = List.of(_kanalen)..[i] = _kanalen[i].copyWith(input: data[i] == 1);
        }
        notifyListeners();
      case 'app_state':
        if (data.length >= 2) {
          _vaarModus = VaarModus.values[data[0].clamp(0, 3)];
          _verlichting = Verlichting.values[data[1].clamp(0, 2)];
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    verbreek();
    super.dispose();
  }
}
