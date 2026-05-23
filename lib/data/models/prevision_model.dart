// ============================================================
// SUPReady - Modelo de Previsión Horaria
// ============================================================

class PrevisionHoraria {
  final DateTime hora;
  final double vientoKts;
  final double rachasKts;
  final double olasMetros;
  final double dirVientoGrados;
  final double probabilidadLluvia; // 0-100 %
  final double precipitacionMm;
  final bool tormentaElectrica;
  final double? tempAguaC;

  const PrevisionHoraria({
    required this.hora,
    required this.vientoKts,
    required this.rachasKts,
    required this.olasMetros,
    required this.dirVientoGrados,
    required this.probabilidadLluvia,
    required this.precipitacionMm,
    required this.tormentaElectrica,
    this.tempAguaC,
  });

  // Índice de riesgo SUP (0=verde 1=amarillo 2=rojo)
  int get nivelRiesgo {
    if (tormentaElectrica || vientoKts > 15 || rachasKts > 18 || olasMetros > 1.0) return 2;
    if (vientoKts >= 9 || rachasKts >= 12 || olasMetros >= 0.5 || probabilidadLluvia > 60) return 1;
    return 0;
  }

  String get dirTexto {
    final d = dirVientoGrados;
    if (d < 22.5 || d >= 337.5) return 'N';
    if (d < 67.5) return 'NE';
    if (d < 112.5) return 'E';
    if (d < 157.5) return 'SE';
    if (d < 202.5) return 'S';
    if (d < 247.5) return 'SO';
    if (d < 292.5) return 'O';
    return 'NO';
  }
}

class DatosSolares {
  final DateTime amanecer;
  final DateTime anochecer;
  const DatosSolares({required this.amanecer, required this.anochecer});
}
