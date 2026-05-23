import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

class SpotCard extends StatelessWidget {
  final SpotModel spot;
  final VoidCallback? onTap;
  final VoidCallback? onFavorito;

  const SpotCard({super.key, required this.spot, this.onTap, this.onFavorito});

  @override
  Widget build(BuildContext context) {
    final indice = spot.indiceViabilidad;
    final color  = _color(indice);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: SupColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(_icon(indice), color: color, size: 20),
              const SizedBox(width: 8),
              Text(_label(indice), style: TextStyle(
                  color: color, fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.1)),
              const Spacer(),
              if (spot.condiciones?.cacheExpirada == true) _badgeDatosViejos(),
              if (onFavorito != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onFavorito,
                  child: Icon(
                    spot.esFavorito ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: spot.esFavorito ? Colors.amber : SupColors.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ]),
          ),
          // Cuerpo
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _Semaforo(color: color),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(spot.nombre, style: SupTextStyles.spotName),
                if (spot.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(spot.descripcion, style: SupTextStyles.body.copyWith(fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                if (spot.condiciones != null) _MeteoRow(c: spot.condiciones!),
              ])),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: SupColors.textSecondary),
            ]),
          ),
        ]),
      ),
    );
  }

  Color _color(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo: return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }
  String _label(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return 'CONDICIONES ÓPTIMAS';
      case SupReadyIndex.amarillo: return 'PRECAUCIÓN — AVANZADOS';
      case SupReadyIndex.rojo: return 'PELIGRO — NO SALIR';
      case SupReadyIndex.sinDatos: return 'SIN DATOS';
    }
  }
  IconData _icon(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return Icons.check_circle_outline;
      case SupReadyIndex.amarillo: return Icons.warning_amber_outlined;
      case SupReadyIndex.rojo: return Icons.dangerous_outlined;
      case SupReadyIndex.sinDatos: return Icons.cloud_off_outlined;
    }
  }

  Widget _badgeDatosViejos() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: SupColors.semaforoAmarillo.withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: SupColors.semaforoAmarillo.withOpacity(0.5))),
    child: const Text('DESACTUALIZADO', style: TextStyle(fontSize: 8, color: SupColors.semaforoAmarillo,
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)));
}

class _Semaforo extends StatelessWidget {
  final Color color;
  const _Semaforo({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)]),
    child: Center(child: Container(width: 22, height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color))));
}

class _MeteoRow extends StatelessWidget {
  final CondicionesClimaticasModel c;
  const _MeteoRow({required this.c});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 4, children: [
    _chip(Icons.air, '${c.vientoKts.toStringAsFixed(0)} kts'),
    _chip(Icons.waves, '${c.olasMetros.toStringAsFixed(1)} m'),
    _chip(Icons.navigation, c.dirVientoTexto),
    if (c.tempAguaC != null) _chip(Icons.thermostat, '${c.tempAguaC!.toStringAsFixed(0)}°C'),
    if (c.esOffshore) _chip(Icons.arrow_outward, 'OFFSHORE', color: SupColors.semaforoRojo),
    if (c.esCrossShore) _chip(Icons.compare_arrows, 'CROSS', color: SupColors.semaforoAmarillo),
  ]);

  Widget _chip(IconData icon, String text, {Color? color}) {
    final c = color ?? SupColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c), const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: c, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600)),
    ]);
  }
}
