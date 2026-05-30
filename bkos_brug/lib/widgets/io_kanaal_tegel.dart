import 'package:flutter/material.dart';
import '../models/bkos_model.dart';
import '../theme.dart';

class IoKanaalTegel extends StatelessWidget {
  final IoKanaal kanaal;
  final VoidCallback? onToggle;

  const IoKanaalTegel({super.key, required this.kanaal, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isAan = kanaal.output.isAan;
    final isGeblokkeerd = kanaal.output.isGeblokkeerd;
    final isIngang = kanaal.isIngang;

    final achtergrond = isGeblokkeerd
        ? kStatusBlok.withOpacity(0.08)
        : isAan
            ? kGroenPrimair.withOpacity(0.18)
            : kOppervlak;

    final randKleur = isGeblokkeerd
        ? kStatusBlok.withOpacity(0.35)
        : isAan
            ? kGroenLicht.withOpacity(0.5)
            : kBeigeRand;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: achtergrond,
          border: Border.all(color: randKleur, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Naam + input dot
            Row(children: [
              Expanded(
                child: Text(
                  kanaal.naam,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kBeige),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isIngang)
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kanaal.input ? kStatusIngang : kBeigeDim,
                  ),
                ),
            ]),
            // Status + knop
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isIngang)
                  _BadgeKlein('INGANG', kStatusIngang)
                else
                  _StatusLabel(output: kanaal.output),
                if (!isIngang && !isGeblokkeerd)
                  _ToggleKnop(isAan: isAan, onToggle: onToggle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final IoOutput output;
  const _StatusLabel({required this.output});

  @override
  Widget build(BuildContext context) {
    Color kleur;
    String tekst;
    switch (output) {
      case IoOutput.aan:
      case IoOutput.invAan:
        kleur = kStatusAan; tekst = 'AAN';
      case IoOutput.geblokkeerd:
      case IoOutput.invGeblokkeerd:
        kleur = kStatusBlok; tekst = 'BLOK';
      default:
        kleur = kStatusUit; tekst = 'UIT';
    }
    return Text(tekst,
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: kleur, letterSpacing: 0.8));
  }
}

class _ToggleKnop extends StatelessWidget {
  final bool isAan;
  final VoidCallback? onToggle;
  const _ToggleKnop({required this.isAan, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isAan ? kGroenPrimair.withOpacity(0.4) : kOppervlakHoog,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isAan ? kGroenLicht.withOpacity(0.5) : kBeigeRand),
        ),
        child: Text(
          isAan ? 'UIT' : 'AAN',
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: kBeige)),
      ),
    );
  }
}

class _BadgeKlein extends StatelessWidget {
  final String tekst;
  final Color kleur;
  const _BadgeKlein(this.tekst, this.kleur);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kleur.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tekst,
          style: TextStyle(fontSize: 10, color: kleur, fontWeight: FontWeight.bold)),
    );
  }
}
