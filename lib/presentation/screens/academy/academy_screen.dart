import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  static const _lecciones = [
    {'titulo': 'Postura', 'subtitulo': 'Pies paralelos, centro de gravedad bajo', 'icon': Icons.accessibility_new},
    {'titulo': 'Fase Catch', 'subtitulo': 'Alcance vertical máximo del remo', 'icon': Icons.sports_hockey},
    {'titulo': 'Fase Power', 'subtitulo': 'Tracción con core, no con brazos', 'icon': Icons.fitness_center},
    {'titulo': 'Recuperación', 'subtitulo': 'Salida limpia y reset del remo', 'icon': Icons.loop},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Academia SUP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Biomecánica de Remada', style: SupTextStyles.heading2),
          const SizedBox(height: 4),
          const Text('Contenido offline • Cargado localmente', style: SupTextStyles.body),
          const SizedBox(height: 20),
          ..._lecciones.map((l) => _LeccionCard(
            titulo: l['titulo'] as String,
            subtitulo: l['subtitulo'] as String,
            icon: l['icon'] as IconData,
          )),
        ],
      ),
    );
  }
}

class _LeccionCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icon;
  const _LeccionCard({required this.titulo, required this.subtitulo, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SupColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SupColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: SupColors.cyanNeonDim, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: SupColors.cyanNeon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: SupTextStyles.heading2.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitulo, style: SupTextStyles.body.copyWith(fontSize: 13)),
            ]),
          ),
          const Icon(Icons.play_circle_outline, color: SupColors.cyanNeon, size: 28),
        ],
      ),
    );
  }
}
