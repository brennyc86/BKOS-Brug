// Data modellen voor BKOS app

enum VaarModus { haven, zeilen, motor, anker }
enum Verlichting { uit, aan, auto_ }

// IO output states (gelijk aan firmware defines)
enum IoOutput { uit, aan, invUit, invAan, geblokkeerd, invGeblokkeerd }

extension IoOutputDisplay on IoOutput {
  String get label {
    switch (this) {
      case IoOutput.aan: return 'AAN';
      case IoOutput.invAan: return 'AAN';
      case IoOutput.uit: return 'UIT';
      case IoOutput.invUit: return 'UIT';
      case IoOutput.geblokkeerd:
      case IoOutput.invGeblokkeerd: return 'BLOK';
    }
  }

  bool get isAan =>
      this == IoOutput.aan || this == IoOutput.invAan;

  bool get isGeblokkeerd =>
      this == IoOutput.geblokkeerd || this == IoOutput.invGeblokkeerd;
}

class IoKanaal {
  final int index;
  final String naam;
  final IoOutput output;
  final bool input;
  final bool isIngang; // richtingsflag

  const IoKanaal({
    required this.index,
    required this.naam,
    required this.output,
    required this.input,
    required this.isIngang,
  });

  IoKanaal copyWith({IoOutput? output, bool? input}) => IoKanaal(
    index: index,
    naam: naam,
    output: output ?? this.output,
    input: input ?? this.input,
    isIngang: isIngang,
  );
}

class NetwerkPeer {
  final String naam;
  final int modus; // 1=master, 2=slave, 3=extra, 4=headless
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
  final String naam;
  final String versie;
  final String mac;
  final int netModus;

  const BkosInfo({
    required this.naam,
    required this.versie,
    required this.mac,
    required this.netModus,
  });
}
