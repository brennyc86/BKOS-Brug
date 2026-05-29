import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bkos_service.dart';
import '../models/bkos_model.dart';
import '../widgets/io_kanaal_tegel.dart';
import '../widgets/vaar_modus_bar.dart';

class IoScreen extends StatelessWidget {
  const IoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BkosService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(svc.info?.naam ?? 'IO Paneel'),
        actions: [
          _VerbindingIndicator(methode: svc.verbindingsMethode),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          VaarModusBar(
            modus: svc.vaarModus,
            verlichting: svc.verlichting,
            onModus: svc.setVaarModus,
            onVerlichting: svc.setVerlichting,
          ),
          Expanded(
            child: svc.kanalen.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _KanaalGrid(kanalen: svc.kanalen),
          ),
        ],
      ),
    );
  }
}

class _KanaalGrid extends StatelessWidget {
  final List<IoKanaal> kanalen;
  const _KanaalGrid({required this.kanalen});

  @override
  Widget build(BuildContext context) {
    // Toon enkel kanalen met een naam die niet leeg is
    final zichtbaar = kanalen.where((k) => k.naam.trim().isNotEmpty).toList();
    final breedte = MediaQuery.of(context).size.width;
    // 2 kolommen op smal scherm, 3 op breed (tablet/desktop)
    final kolommen = breedte > 600 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: kolommen,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemCount: zichtbaar.length,
      itemBuilder: (context, i) {
        final kanaal = zichtbaar[i];
        return IoKanaalTegel(
          kanaal: kanaal,
          onToggle: kanaal.isIngang ? null : () => context.read<BkosService>().ioToggle(kanaal.index),
        );
      },
    );
  }
}

class _VerbindingIndicator extends StatelessWidget {
  final String methode;
  const _VerbindingIndicator({required this.methode});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: methode == 'ws' ? 'WiFi verbonden' : 'Bluetooth verbonden',
      child: Icon(
        methode == 'ws' ? Icons.wifi : Icons.bluetooth,
        color: Colors.greenAccent,
        size: 20,
      ),
    );
  }
}
