// Data modellen voor BKOS Brug

enum VaarModus { haven, zeilen, motor, anker }
enum Verlichting { uit, aan, auto_ }

// IO output states (gelijk aan firmware defines)
enum IoOutput { uit, aan, invUit, invAan, geblokkeerd, invGeblokkeerd }

extension IoOutputDisplay on IoOutput {
  String get label {
    switch (this) {
      case IoOutput.aan:
      case IoOutput.invAan:      return 'AAN';
      case IoOutput.uit:
      case IoOutput.invUit:      return 'UIT';
      case IoOutput.geblokkeerd:
      case IoOutput.invGeblokkeerd: return 'BLOK';
    }
  }

  bool get isAan => this == IoOutput.aan || this == IoOutput.invAan;
  bool get isGeblokkeerd => this == IoOutput.geblokkeerd || this == IoOutput.invGeblokkeerd;
}

class IoKanaal {
  final int index;
  final String naam;
  final IoOutput output;
  final bool input;
  final bool isIngang;

  const IoKanaal({
    required this.index,
    required this.naam,
    required this.output,
    required this.input,
    required this.isIngang,
  });

  IoKanaal copyWith({IoOutput? output, bool? input}) => IoKanaal(
    index: index, naam: naam,
    output: output ?? this.output,
    input: input ?? this.input,
    isIngang: isIngang,
  );
}

class NetwerkPeer {
  final String naam;
  final int modus;
  final bool online;
  final int ioKanalen;

  const NetwerkPeer({
    required this.naam,
    required this.modus,
    required this.online,
    required this.ioKanalen,
  });

  String get modusLabel {
    switch (modus) {
      case 1: return 'MASTER';
      case 2: return 'SLAVE';
      case 3: return 'EXTRA';
      case 4: return 'HEADLESS';
      default: return 'ONBEKEND';
    }
  }
}

class BkosInfo {
  final String naam;      // computernaam (net_eigen_naam)
  final String bootnaam;  // naam van het schip
  final String versie;
  final String mac;
  final int netModus;

  const BkosInfo({
    required this.naam,
    required this.bootnaam,
    required this.versie,
    required this.mac,
    required this.netModus,
  });

  String get netModusLabel {
    switch (netModus) {
      case 0: return 'STANDALONE';
      case 1: return 'MASTER';
      case 2: return 'SLAVE';
      case 3: return 'EXTRA';
      case 4: return 'HEADLESS';
      default: return '?';
    }
  }
}

// Gevonden BKOS apparaat via mDNS of eerder opgeslagen IP
class GevondenApparaat {
  final String ip;
  final int poort;
  final String computernaam;
  final String bootnaam;
  final int netModus;
  final bool viaMdns; // false = handmatig ingevoerd

  const GevondenApparaat({
    required this.ip,
    this.poort = 8080,
    this.computernaam = '',
    this.bootnaam = '',
    this.netModus = -1,
    this.viaMdns = true,
  });

  String get weergaveNaam =>
    computernaam.isNotEmpty ? computernaam : 'BKOS apparaat';

  String get netModusLabel {
    switch (netModus) {
      case 0: return 'STANDALONE';
      case 1: return 'MASTER';
      case 2: return 'SLAVE';
      case 3: return 'EXTRA';
      case 4: return 'HEADLESS';
      default: return '';
    }
  }
}
