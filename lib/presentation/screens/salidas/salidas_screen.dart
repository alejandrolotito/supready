import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/firestore_service.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'crear_salida_screen.dart';
import 'detalle_salida_screen.dart';

// ============================================================
// SUPReady - Salidas Grupales (Firestore multiusuario)
// Tiempo real: todos los usuarios ven las mismas salidas
// ============================================================

class SalidasScreen extends StatefulWidget {
  const SalidasScreen({super.key});
  @override
  State<SalidasScreen> createState() => _SalidasScreenState();
}

class _SalidasScreenState extends State<SalidasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioActual;
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Salidas grupales'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: SupColors.cyanNeon,
          labelColor: SupColors.cyanNeon,
          unselectedLabelColor: SupColors.textSecondary,
          labelStyle: const TextStyle(
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'PRÓXIMAS'), Tab(text: 'MIS SALIDAS')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SupColors.cyanNeon,
        foregroundColor: SupColors.backgroundDeep,
        icon: const Icon(Icons.add),
        label: const Text('CREAR SALIDA',
            style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CrearSalidaScreen())),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        // Tab 1: Salidas públicas (tiempo real Firestore)
        StreamBuilder<List<SalidaGrupal>>(
          stream: FirestoreService.instance.streamSalidasPublicas(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon));
            }
            if (snap.hasError) {
              return _buildError(snap.error.toString());
            }
            final salidas = snap.data ?? [];
            final ahora = DateTime.now();
            final proximas = salidas.where((s) => s.fechaHora.isAfter(ahora)).toList();
            return proximas.isEmpty
                ? _buildVacio('No hay salidas próximas.\n¡Creá la primera!')
                : _buildLista(proximas);
          },
        ),
        // Tab 2: Mis salidas (organizador o participante)
        usuario == null
            ? _buildLoginRequired()
            : StreamBuilder<List<SalidaGrupal>>(
                stream: FirestoreService.instance.streamMisSalidas(
                    usuario.googleId ?? usuario.usuarioId.toString()),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon));
                  }
                  final salidas = snap.data ?? [];
                  return salidas.isEmpty
                      ? _buildVacio('Todavía no participás en ninguna salida.')
                      : _buildLista(salidas);
                },
              ),
      ]),
    );
  }

  Widget _buildLista(List<SalidaGrupal> salidas) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    itemCount: salidas.length,
    itemBuilder: (_, i) => _SalidaCard(
      salida: salidas[i],
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetalleSalidaScreen(salida: salidas[i]))),
    ),
  );

  Widget _buildVacio(String msg) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.group_outlined, color: SupColors.textSecondary, size: 64),
    const SizedBox(height: 16),
    Text(msg, style: SupTextStyles.body, textAlign: TextAlign.center),
  ]));

  Widget _buildError(String err) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off, color: SupColors.textSecondary, size: 48),
    const SizedBox(height: 12),
    const Text('Sin conexión a Firestore', style: SupTextStyles.heading2),
    const SizedBox(height: 8),
    Text(err.length > 80 ? err.substring(0, 80) + '...' : err,
        style: SupTextStyles.body.copyWith(fontSize: 11), textAlign: TextAlign.center),
  ]));

  Widget _buildLoginRequired() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.login, color: SupColors.cyanNeon, size: 48),
    const SizedBox(height: 16),
    const Text('Iniciá sesión para ver tus salidas', style: SupTextStyles.body),
  ]));
}

// ─── Card de salida ─────────────────────────────────────────
class _SalidaCard extends StatelessWidget {
  final SalidaGrupal salida;
  final VoidCallback onTap;
  const _SalidaCard({required this.salida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = salida.fechaHora;
    final cuposColor = salida.llena ? SupColors.semaforoRojo
        : salida.cuposDisponibles <= 2 ? SupColors.semaforoAmarillo
        : SupColors.semaforoVerde;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: SupColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SupColors.divider)),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF112236),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: SupColors.cyanNeon, size: 14),
              const SizedBox(width: 6),
              Text('${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} · '
                  '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(color: SupColors.textPrimary,
                      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              _estadoBadge(salida.estado),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(_emojiNivel(salida.nivelMinimo),
                      style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(salida.spotNombre, style: SupTextStyles.heading2.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                if (salida.descripcion.isNotEmpty)
                  Text(salida.descripcion, style: SupTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 4, children: [
                  _chip(Icons.people_outline,
                      '${salida.participantes.length}/${salida.cuposMax}', cuposColor),
                  _chip(Icons.signal_cellular_alt,
                      _labelNivel(salida.nivelMinimo), SupColors.textSecondary),
                ]),
              ])),
              const Icon(Icons.chevron_right, color: SupColors.textSecondary),
            ]),
          ),
          if (salida.participantes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                ...salida.participantes.take(5).map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: CircleAvatar(radius: 14,
                    backgroundColor: SupColors.cyanNeonDim,
                    backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                    child: p.avatarUrl == null ? Text(
                        p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                        style: const TextStyle(color: SupColors.cyanNeon,
                            fontSize: 12, fontWeight: FontWeight.w700)) : null))),
                const Spacer(),
                if (!salida.llena)
                  Text('${salida.cuposDisponibles} cupo${salida.cuposDisponibles == 1 ? "" : "s"}',
                      style: TextStyle(color: cuposColor, fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w600, fontSize: 11)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _estadoBadge(EstadoSalida e) {
    final map = {
      EstadoSalida.abierta:    ('ABIERTA', SupColors.semaforoVerde),
      EstadoSalida.enCurso:    ('EN CURSO', SupColors.cyanNeon),
      EstadoSalida.finalizada: ('FINALIZADA', SupColors.textSecondary),
      EstadoSalida.cancelada:  ('CANCELADA', SupColors.semaforoRojo),
    };
    final (label, color) = map[e]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 10)));
  }

  Widget _chip(IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color), const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w600, fontSize: 12)),
      ]);

  String _emojiNivel(NivelSalida n) => const {
    NivelSalida.todos: '🌊', NivelSalida.principiante: '🟢',
    NivelSalida.intermedio: '🟡', NivelSalida.avanzado: '🔴',
  }[n]!;

  String _labelNivel(NivelSalida n) => const {
    NivelSalida.todos: 'Todos los niveles', NivelSalida.principiante: 'Principiante+',
    NivelSalida.intermedio: 'Intermedio+', NivelSalida.avanzado: 'Solo avanzados',
  }[n]!;
}
