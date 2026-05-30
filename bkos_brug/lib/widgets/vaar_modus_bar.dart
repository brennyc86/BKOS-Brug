import 'package:flutter/material.dart';
import '../models/bkos_model.dart';
import '../theme.dart';

class VaarModusBar extends StatelessWidget {
  final VaarModus modus;
  final Verlichting verlichting;
  final ValueChanged<VaarModus> onModus;
  final ValueChanged<Verlichting> onVerlichting;

  const VaarModusBar({
    super.key,
    required this.modus,
    required this.verlichting,
    required this.onModus,
    required this.onVerlichting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavBar,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: VaarModus.values.map((m) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ModusKnop(
                  label: _label(m),
                  actief: modus == m,
                  onTap: () => onModus(m),
                ),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _VerlichtingKnop(verlichting: verlichting, onChange: onVerlichting),
      ]),
    );
  }

  String _label(VaarModus m) {
    switch (m) {
      case VaarModus.haven:  return 'HAVEN';
      case VaarModus.zeilen: return 'ZEILEN';
      case VaarModus.motor:  return 'MOTOR';
      case VaarModus.anker:  return 'ANKER';
    }
  }
}

class _ModusKnop extends StatelessWidget {
  final String label;
  final bool actief;
  final VoidCallback onTap;

  const _ModusKnop({required this.label, required this.actief, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: actief ? kGroenPrimair.withOpacity(0.35) : kOppervlakHoog,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: actief ? kGroenLicht.withOpacity(0.6) : kBeigeRand,
            width: actief ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: actief ? FontWeight.bold : FontWeight.normal,
              color: actief ? kBeige : kBeigeZacht,
              letterSpacing: 0.5,
            )),
      ),
    );
  }
}

class _VerlichtingKnop extends StatelessWidget {
  final Verlichting verlichting;
  final ValueChanged<Verlichting> onChange;

  const _VerlichtingKnop({required this.verlichting, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(Verlichting.values[(verlichting.index + 1) % 3]),
      child: Tooltip(
        message: _label,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kleur.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kleur.withOpacity(0.35)),
          ),
          child: Icon(_icoon, color: _kleur, size: 18),
        ),
      ),
    );
  }

  String get _label {
    switch (verlichting) {
      case Verlichting.uit:  return 'Verlichting UIT';
      case Verlichting.aan:  return 'Verlichting AAN';
      case Verlichting.auto_: return 'Verlichting AUTO';
    }
  }

  IconData get _icoon {
    switch (verlichting) {
      case Verlichting.uit:   return Icons.lightbulb_outline;
      case Verlichting.aan:   return Icons.lightbulb;
      case Verlichting.auto_: return Icons.brightness_auto;
    }
  }

  Color get _kleur {
    switch (verlichting) {
      case Verlichting.uit:   return kBeigeDim;
      case Verlichting.aan:   return kStatusBlok; // amber
      case Verlichting.auto_: return kStatusIngang; // blauw-groen
    }
  }
}
