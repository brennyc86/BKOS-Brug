import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bkos_service.dart';
import '../models/bkos_model.dart';

class NetwerkScreen extends StatelessWidget {
  const NetwerkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BkosService>();
    final info = svc.info;

    return Scaffold(
      appBar: AppBar(title: const Text('Netwerk')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Apparaat info sectie
          if (info != null) ...[
            _SectieKop('Dit Apparaat'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRij('Naam', info.naam),
                    _InfoRij('Versie', info.versie),
                    _InfoRij('MAC', info.mac),
                    _InfoRij('Netwerk modus', _netModusLabel(info.netModus)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Peers sectie
          _SectieKop('Gekoppelde Apparaten (${svc.peers.length})'),
          const SizedBox(height: 8),
          if (svc.peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Geen apparaten gekoppeld')),
            )
          else
            ...svc.peers.map((p) => _PeerTegel(peer: p)),
        ],
      ),
    );
  }

  String _netModusLabel(int modus) {
    switch (modus) {
      case 0: return 'Standalone';
      case 1: return 'Master';
      case 2: return 'Slave';
      case 3: return 'Extra';
      case 4: return 'Headless';
      default: return 'Onbekend';
    }
  }
}

class _SectieKop extends StatelessWidget {
  final String titel;
  const _SectieKop(this.titel);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(titel,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.1)),
    );
  }
}

class _InfoRij extends StatelessWidget {
  final String label;
  final String waarde;
  const _InfoRij(this.label, this.waarde);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ),
          Expanded(
            child: Text(waarde,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _PeerTegel extends StatelessWidget {
  final NetwerkPeer peer;
  const _PeerTegel({required this.peer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: peer.online
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.1),
          child: Icon(
            Icons.hub,
            color: peer.online ? Colors.greenAccent : Colors.redAccent,
            size: 20,
          ),
        ),
        title: Text(peer.naam.isNotEmpty ? peer.naam : 'Onbekend'),
        subtitle: Text('${peer.modusLabel} · ${peer.ioKanalen} kanalen'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: peer.online
                ? Colors.green.withOpacity(0.15)
                : Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            peer.online ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: peer.online ? Colors.greenAccent : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
