import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

// ============================================================
// SUPReady - Compartir ruta como imagen PNG
// ============================================================

class RutaShareCard extends StatelessWidget {
  final GlobalKey repaintKey;
  final RutaTrazadaModel ruta;
  const RutaShareCard({super.key, required this.repaintKey, required this.ruta});

  @override
  Widget build(BuildContext context) {
    final dt = ruta.iniciadaEn;
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0B192C), Color(0xFF112236)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            const Text('🏄', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SUPReady', style: TextStyle(
                  color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
              Text('${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} ${dt.year}',
                  style: SupTextStyles.body.copyWith(fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF1E3A5F), height: 1),
          const SizedBox(height: 18),

          // Métricas
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _met('DISTANCIA', '${ruta.distanciaKm.toStringAsFixed(2)}', 'km'),
            Container(width: 1, height: 48, color: const Color(0xFF1E3A5F)),
            _met('DURACIÓN', '${ruta.duracionMinutos}', 'min'),
            Container(width: 1, height: 48, color: const Color(0xFF1E3A5F)),
            _met('VEL. MEDIA', '${ruta.velocidadMedia.toStringAsFixed(1)}', 'km/h'),
          ]),
          const SizedBox(height: 14),

          // Vel. máxima
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.rocket_launch, color: SupColors.cyanNeon, size: 15),
              const SizedBox(width: 8),
              const Text('Vel. máxima', style: TextStyle(
                  color: SupColors.textSecondary, fontFamily: 'SpaceGrotesk', fontSize: 11)),
              const Spacer(),
              Text('${ruta.velocidadMaxima.toStringAsFixed(1)} km/h',
                  style: const TextStyle(color: SupColors.cyanNeon,
                      fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 18),

          Center(child: Text('supready.app', style: TextStyle(
              color: SupColors.textSecondary.withOpacity(0.4),
              fontFamily: 'SpaceGrotesk', fontSize: 10, letterSpacing: 1))),
        ]),
      ),
    );
  }

  Widget _met(String label, String valor, String unidad) => Column(children: [
    Text(label, style: const TextStyle(color: SupColors.textSecondary,
        fontFamily: 'SpaceGrotesk', fontSize: 8, letterSpacing: 0.7,
        fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 26)),
    Text(unidad, style: const TextStyle(color: SupColors.cyanNeon,
        fontFamily: 'SpaceGrotesk', fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}

Future<void> compartirRutaComoImagen(
    GlobalKey key, RutaTrazadaModel ruta) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) { _compartirTexto(ruta); return; }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))
        ?.buffer.asUint8List();
    if (bytes == null) { _compartirTexto(ruta); return; }
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/supready_ruta.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')],
        text: '🏄 ${ruta.distanciaKm.toStringAsFixed(2)} km en ${ruta.duracionMinutos} min — #SUPReady');
  } catch (_) { _compartirTexto(ruta); }
}

void _compartirTexto(RutaTrazadaModel ruta) => Share.share(
  '🏄 Remé ${ruta.distanciaKm.toStringAsFixed(2)} km en ${ruta.duracionMinutos} min!\n'
  '📊 Media: ${ruta.velocidadMedia.toStringAsFixed(1)} km/h · '
  'Máx: ${ruta.velocidadMaxima.toStringAsFixed(1)} km/h\n#SUPReady');
