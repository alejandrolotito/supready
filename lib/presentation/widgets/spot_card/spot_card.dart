import 'package:flutter/material.dart';
import 'package:supready/core/theme/app_theme.dart';
import 'package:supready/data/models/models.dart';

// ============================================================
// SUPReady - Widget: SpotCard con Semáforo
// ERS RF2.2: El índice visual prioriza la cabecera del spot
// ============================================================

class SpotCard extends StatelessWidget {
  final SpotModel spot;
  final VoidCallback? onTap;

  const SpotCard({super.key, required this.spot, this.onTap});

  @override
  Widget build(BuildContext context) {
    final indice = spot.indiceViabilidad;
    final color = _colorIndice(indice);
    final label = _labelIndice(indice);
    final icon  = _iconIndice(indice);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: SupColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          children: [
            // Header coloreado con el índice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      )),
                  const Spacer(),
                  if (spot.condiciones?.cacheExpirada == true)
                    _BadgeDatosViejos(),
                ],
              ),
            ),

            // Cuerpo del spot
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Indicador semáforo circular
                  _Semaforo(color: color, indice: indice),
                  const SizedBox(width: 16),

                  // Info del spot
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.nombre, style: SupTextStyles.spotName),
                        if (spot.descripcion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(spot.descripcion,
                              style: SupTextStyles.body.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 12),
                        if (spot.condiciones != null)
                          _MeteoRow(condiciones: spot.condiciones!),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right, color: SupColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorIndice(SupReadyIndex i) {
    switch (i) {
      case SupReadyIndex.verde:    return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo:     return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }

  String _labelIndice(SupReadyIndex i) {
    switch (i) {
      case SupReadyIndex.verde:    return 'CONDICIONES ÓPTIMAS';
      case SupReadyIndex.amarillo: return 'PRECAUCIÓN — AVANZADOS';
      case SupReadyIndex.rojo:     return 'PELIGRO — NO SALIR';
      case SupReadyIndex.sinDatos: return 'SIN DATOS';
    }
  }

  IconData _iconIndice(SupReadyIndex i) {
    switch (i) {
      case SupReadyIndex.verde:    return Icons.check_circle_outline;
      case SupReadyIndex.amarillo: return Icons.warning_amber_outlined;
      case SupReadyIndex.rojo:     return Icons.dangerous_outlined;
      case SupReadyIndex.sinDatos: return Icons.cloud_off_outlined;
    }
  }
}

// ----------------------------------------------------------
// Semáforo visual circular
// ----------------------------------------------------------
class _Semaforo extends StatelessWidget {
  final Color color;
  final SupReadyIndex indice;

  const _Semaforo({required this.color, required this.indice});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Fila de métricas meteorológicas
// ----------------------------------------------------------
class _MeteoRow extends StatelessWidget {
  final CondicionesClimaticasModel condiciones;
  const _MeteoRow({required this.condiciones});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _chip(Icons.air, '${condiciones.vientoKts.toStringAsFixed(0)} kts'),
        _chip(Icons.waves, '${condiciones.olasMetros.toStringAsFixed(1)} m'),
        if (condiciones.esOffshore)
          _chip(Icons.arrow_outward, 'OFFSHORE', color: SupColors.semaforoRojo),
        if (condiciones.esCrossShore)
          _chip(Icons.compare_arrows, 'CROSS', color: SupColors.semaforoAmarillo),
      ],
    );
  }

  Widget _chip(IconData icon, String texto, {Color? color}) {
    final c = color ?? SupColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(texto, style: TextStyle(
          fontSize: 12,
          color: c,
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w600,
        )),
      ],
    );
  }
}

// ----------------------------------------------------------
// Badge datos desactualizados (ERS CU01 - Flujo alterno 3.a)
// ----------------------------------------------------------
class _BadgeDatosViejos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SupColors.semaforoAmarillo.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SupColors.semaforoAmarillo.withOpacity(0.5)),
      ),
      child: const Text(
        'DATOS NO ACTUALIZADOS',
        style: TextStyle(
          fontSize: 9,
          color: SupColors.semaforoAmarillo,
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
