import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';

// ============================================================
// SUPReady v3 - Academia SUP
// Imágenes reales de técnica desde Wikimedia/fuentes libres
// ============================================================

class AcademyScreen extends StatelessWidget {
  const AcademyScreen({super.key});

  static const _secciones = [
    _Seccion(
      titulo: 'Postura correcta',
      descripcion: 'La base de todo. Pies paralelos al ancho de hombros, rodillas levemente flexionadas, cadera centrada sobre la tabla.',
      items: [
        _Leccion(
          titulo: 'Posición de pie estable',
          subtitulo: 'Centro de gravedad bajo, core activo',
          detalle: 'Parate en el centro de la tabla con los pies perpendiculares al eje. '
              'Flexioná levemente las rodillas, mantené el torso erguido y la vista al frente. '
              'El error más común es mirar los pies — eso desequilibra el cuerpo.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/SUP_Surf_Posture.jpg/640px-SUP_Surf_Posture.jpg',
          imageFallbackIcon: Icons.accessibility_new,
          colorTag: Color(0xFF00D2C4),
          tagLabel: 'FUNDAMENTOS',
        ),
        _Leccion(
          titulo: 'Balance en condiciones de olas',
          subtitulo: 'Adaptá tu postura al estado del mar',
          detalle: 'Con olas o corriente, bajá más el centro de gravedad separando un poco más los pies. '
              'Usá los brazos como contrapeso natural. La tabla va a moverse — vos no.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Stand_up_paddle_surfing.jpg/640px-Stand_up_paddle_surfing.jpg',
          imageFallbackIcon: Icons.waves,
          colorTag: Color(0xFF2ECC71),
          tagLabel: 'INTERMEDIO',
        ),
      ],
    ),
    _Seccion(
      titulo: 'Técnica de remada',
      descripcion: 'Una remada eficiente combina alcance, tracción con el core y recuperación limpia.',
      items: [
        _Leccion(
          titulo: 'Fase Catch — el alcance',
          subtitulo: 'Hundir la pala verticalmente',
          detalle: 'Extendé el brazo superior hacia adelante todo lo que puedas. '
              'La pala entra al agua con el ángulo hacia adelante — no perpendicular. '
              'El agarre superior (mano del "T") empuja, el inferior jala.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/SUP_Paddle_Technique.jpg/480px-SUP_Paddle_Technique.jpg',
          imageFallbackIcon: Icons.sports_hockey,
          colorTag: Color(0xFF00D2C4),
          tagLabel: 'TÉCNICA',
        ),
        _Leccion(
          titulo: 'Fase Power — la tracción',
          subtitulo: 'El motor está en el core, no en los brazos',
          detalle: 'Una vez que la pala está plantada, rotá el torso para jalar. '
              'Los brazos son palancas — el giro de cintura es la fuerza real. '
              'La pala sale del agua a la altura de la cadera, no más atrás.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Paddleboarding.jpg/640px-Paddleboarding.jpg',
          imageFallbackIcon: Icons.fitness_center,
          colorTag: Color(0xFFF1C40F),
          tagLabel: 'TÉCNICA',
        ),
        _Leccion(
          titulo: 'Fase Recovery — la salida',
          subtitulo: 'Pala baja, salida limpia',
          detalle: 'Girá la pala al sacarla para que salga con menos resistencia. '
              'Llevá el brazo adelante con la pala baja, casi rozando el agua. '
              'Evitá levantar el codo — eso gasta energía innecesaria.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Stand_Up_Paddle_Boarding.jpg/640px-Stand_Up_Paddle_Boarding.jpg',
          imageFallbackIcon: Icons.loop,
          colorTag: Color(0xFF2ECC71),
          tagLabel: 'TÉCNICA',
        ),
      ],
    ),
    _Seccion(
      titulo: 'Giros y maniobras',
      descripcion: 'Controlá la dirección con eficiencia para ahorrar energía en recorridos largos.',
      items: [
        _Leccion(
          titulo: 'Giro de proa (sweep)',
          subtitulo: 'Remo en arco amplio desde adelante',
          detalle: 'Para girar a la derecha, remá a la izquierda con un arco amplio desde la proa. '
              'Mantenés velocidad mientras girás. Es el giro más eficiente en aguas abiertas.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/SUP_Turn_Technique.jpg/480px-SUP_Turn_Technique.jpg',
          imageFallbackIcon: Icons.rotate_right,
          colorTag: Color(0xFFE74C3C),
          tagLabel: 'AVANZADO',
        ),
        _Leccion(
          titulo: 'Step back turn',
          subtitulo: 'Pisá el tail para girar rápido',
          detalle: 'Retrocedé un pie al tail para hundir la popa y girar la tabla sobre su eje. '
              'Útil en espacios reducidos o surf. Requiere buen balance previo.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/SUP_surfer.jpg/480px-SUP_surfer.jpg',
          imageFallbackIcon: Icons.swap_horiz,
          colorTag: Color(0xFFE74C3C),
          tagLabel: 'AVANZADO',
        ),
      ],
    ),
    _Seccion(
      titulo: 'Seguridad en el agua',
      descripcion: 'Conocé los protocolos básicos para salir siempre seguro.',
      items: [
        _Leccion(
          titulo: 'Leash y equipo de seguridad',
          subtitulo: 'Siempre conectado a tu tabla',
          detalle: 'El leash te mantiene unido a la tabla si caés. '
              'En agua abierta usá leash de cintura (no tobillo). '
              'En SUP de travesía: chaleco inflable > chaleco espuma.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/SUP_Safety_Equipment.jpg/480px-SUP_Safety_Equipment.jpg',
          imageFallbackIcon: Icons.security,
          colorTag: Color(0xFF2ECC71),
          tagLabel: 'SEGURIDAD',
        ),
        _Leccion(
          titulo: 'Lectura del viento y las olas',
          subtitulo: 'Reconocé condiciones peligrosas',
          detalle: 'Viento offshore (del interior hacia el mar) es el más peligroso para SUP: '
              'te aleja de la costa sin que notes la distancia. '
              'Revisá siempre el índice SUP Ready antes de salir.',
          imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Offshore_wind_diagram.svg/480px-Offshore_wind_diagram.svg.png',
          imageFallbackIcon: Icons.air,
          colorTag: Color(0xFFE74C3C),
          tagLabel: 'SEGURIDAD',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(title: const Text('Academia SUP')),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: _secciones.length,
        itemBuilder: (_, i) => _SeccionWidget(seccion: _secciones[i]),
      ),
    );
  }
}

// ─── Sección con título y lista de lecciones ─────────────────
class _SeccionWidget extends StatelessWidget {
  final _Seccion seccion;
  const _SeccionWidget({required this.seccion});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(seccion.titulo, style: SupTextStyles.heading2),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(seccion.descripcion, style: SupTextStyles.body),
      ),
      ...seccion.items.map((l) => _LeccionCard(leccion: l)),
    ]);
  }
}

// ─── Card de lección con imagen real ─────────────────────────
class _LeccionCard extends StatelessWidget {
  final _Leccion leccion;
  const _LeccionCard({required this.leccion});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _mostrarDetalle(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: SupColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SupColors.divider),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Imagen con fallback al ícono
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: leccion.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: SupColors.backgroundDeep,
                child: Center(child: Icon(leccion.imageFallbackIcon,
                    color: SupColors.cyanNeon, size: 48)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: SupColors.backgroundDeep,
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(leccion.imageFallbackIcon, color: SupColors.cyanNeon, size: 48),
                  const SizedBox(height: 8),
                  Text(leccion.titulo,
                      style: SupTextStyles.body.copyWith(fontSize: 12),
                      textAlign: TextAlign.center),
                ])),
              ),
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: leccion.colorTag.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: leccion.colorTag.withOpacity(0.5)),
                  ),
                  child: Text(leccion.tagLabel, style: TextStyle(
                    color: leccion.colorTag, fontSize: 10,
                    fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, color: SupColors.textSecondary, size: 14),
              ]),
              const SizedBox(height: 8),
              Text(leccion.titulo, style: SupTextStyles.heading2.copyWith(fontSize: 17)),
              const SizedBox(height: 3),
              Text(leccion.subtitulo, style: SupTextStyles.body.copyWith(fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SupColors.backgroundDeep,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
        builder: (_, scroll) => ListView(controller: scroll, children: [
          // Imagen grande
          CachedNetworkImage(
            imageUrl: leccion.imageUrl,
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 220, color: SupColors.surface,
              child: Center(child: Icon(leccion.imageFallbackIcon, color: SupColors.cyanNeon, size: 60))),
            errorWidget: (_, __, ___) => Container(
              height: 220, color: SupColors.surface,
              child: Center(child: Icon(leccion.imageFallbackIcon, color: SupColors.cyanNeon, size: 60))),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: SupColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              // Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: leccion.colorTag.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: leccion.colorTag.withOpacity(0.5)),
                ),
                child: Text(leccion.tagLabel, style: TextStyle(
                  color: leccion.colorTag, fontSize: 11,
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Text(leccion.titulo, style: SupTextStyles.heading1.copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text(leccion.subtitulo, style: SupTextStyles.body),
              const Divider(color: SupColors.divider, height: 28),
              Text(leccion.detalle, style: SupTextStyles.body.copyWith(
                  fontSize: 15, height: 1.7, color: Colors.white)),
              const SizedBox(height: 24),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────
class _Seccion {
  final String titulo, descripcion;
  final List<_Leccion> items;
  const _Seccion({required this.titulo, required this.descripcion, required this.items});
}

class _Leccion {
  final String titulo, subtitulo, detalle, imageUrl, tagLabel;
  final IconData imageFallbackIcon;
  final Color colorTag;
  const _Leccion({
    required this.titulo, required this.subtitulo, required this.detalle,
    required this.imageUrl, required this.imageFallbackIcon,
    required this.colorTag, required this.tagLabel,
  });
}
