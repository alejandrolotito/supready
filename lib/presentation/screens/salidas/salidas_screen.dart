import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'crear_salida_screen.dart';
import 'detalle_salida_screen.dart';

// ============================================================
// SUPReady - Pantalla de Salidas Grupales
// Lista de salidas + botón crear nueva
// ============================================================

class SalidasScreen extends StatefulWidget {
  const SalidasScreen({super.key});
  @override
  State<SalidasScreen> createState() => _SalidasScreenState();
}

class _SalidasScreenState extends State<SalidasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<SalidaGrupal> _proximas = [];
  List<SalidaGrupal> _misSalidas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final todas = await SupDatabase.instance.getSalidas();
    final usuario = AuthService.instance.usuarioActual;
    final ahora = DateTime.now();
    if (mounted) setState(() {
      _proximas = todas.where((s) =>
          s.fechaHora.isAfter(ahora) && s.estado != EstadoSalida.cancelada).toList();
      _misSalidas = todas.where((s) =>
          s.organizadorId == (usuario?.usuarioId ?? -1) ||
          s.participantes.any((p) => p.usuarioId == (usuario?.usuarioId ?? -1))).toList();
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(
      title: const Text('Salidas grupales'),
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: SupColors.cyanNeon,
        labelColor: SupColors.cyanNeon,
        unselectedLabelColor: SupColors.textSecondary,
        labelStyle: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'PRÓXIMAS'), Tab(text: 'MIS SALIDAS')],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: SupColors.cyanNeon,
      foregroundColor: SupColors.backgroundDeep,
      icon: const Icon(Icons.add),
      label: const Text('CREAR SALIDA', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const CrearSalidaScreen()));
        _cargar();
      },
    ),
    body: _cargando
        ? const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon))
        : TabBarView(controller: _tabCtrl, children: [
            _buildLista(_proximas, 'No hay salidas próximas.\n¡Creá la primera!'),
            _buildLista(_misSalidas, 'Todavía no participás en ninguna salida.'),
          ]),
  );

  Widget _buildLista(List<SalidaGrupal> salidas, String emptyMsg) =>
      RefreshIndicator(
        color: SupColors.cyanNeon, backgroundColor: SupColors.surface,
        onRefresh: _cargar,
        child: salidas.isEmpty
            ? _buildVacio(emptyMsg)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: salidas.length,
                itemBuilder: (_, i) => _SalidaCard(
                  salida: salidas[i],
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DetalleSalidaScreen(salida: salidas[i])));
                    _cargar();
                  },
                ),
              ),
      );

  Widget _buildVacio(String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.group_outlined, color: SupColors.textSecondary, size: 64),
      const SizedBox(height: 16),
      Text(msg, style: SupTextStyles.body, textAlign: TextAlign.center),
    ]),
  );
}

// ─── Card de salida ──────────────────────────────────────────
class _SalidaCard extends StatelessWidget {
  final SalidaGrupal salida;
  final VoidCallback onTap;
  const _SalidaCard({required this.salida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = salida.fechaHora;
    final fechaStr = '${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month-1]}';
    final horaStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final cuposColor = salida.llena ? SupColors.semaforoRojo
        : salida.cuposDisponibles <= 2 ? SupColors.semaforoAmarillo
        : SupColors.semaforoVerde;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: SupColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SupColors.divider),
        ),
        child: Column(children: [
          // Header con fecha y estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF112236),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.calendar_today, color: SupColors.cyanNeon, size: 14),
              const SizedBox(width: 6),
              Text('$fechaStr · $horaStr',
                  style: const TextStyle(color: SupColors.textPrimary,
                      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              _estadoBadge(salida.estado),
            ]),
          ),
          // Cuerpo
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Ícono nivel
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: SupColors.cyanNeonDim, borderRadius: BorderRadius.circular(12)),
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
                // Info chips
                Wrap(spacing: 10, runSpacing: 4, children: [
                  _chip(Icons.people_outline, '${salida.participantes.length}/${salida.cuposMax}', cuposColor),
                  _chip(Icons.signal_cellular_alt, _labelNivel(salida.nivelMinimo), SupColors.textSecondary),
                  if (!salida.esPublica)
                    _chip(Icons.lock_outline, 'Privada', SupColors.textSecondary),
                ]),
              ])),
              const Icon(Icons.chevron_right, color: SupColors.textSecondary),
            ]),
          ),
          // Avatares de participantes
          if (salida.participantes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(children: [
                ...salida.participantes.take(5).map((p) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: SupColors.cyanNeonDim,
                    backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                    child: p.avatarUrl == null
                        ? Text(p.nombre.isNotEmpty ? p.nombre[0].toUpperCase() : '?',
                            style: const TextStyle(color: SupColors.cyanNeon,
                                fontSize: 12, fontWeight: FontWeight.w700))
                        : null),
                )),
                if (salida.participantes.length > 5)
                  CircleAvatar(
                    radius: 14, backgroundColor: SupColors.surface,
                    child: Text('+${salida.participantes.length - 5}',
                        style: const TextStyle(color: SupColors.textSecondary,
                            fontSize: 10, fontFamily: 'SpaceGrotesk'))),
                const Spacer(),
                if (!salida.llena)
                  Text('${salida.cuposDisponibles} cupo${salida.cuposDisponibles == 1 ? "" : "s"} libre${salida.cuposDisponibles == 1 ? "" : "s"}',
                      style: TextStyle(color: cuposColor, fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w600, fontSize: 11)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _estadoBadge(EstadoSalida estado) {
    String label; Color color;
    switch (estado) {
      case EstadoSalida.abierta:    label = 'ABIERTA';   color = SupColors.semaforoVerde; break;
      case EstadoSalida.enCurso:    label = '🏄 EN CURSO'; color = SupColors.cyanNeon; break;
      case EstadoSalida.finalizada: label = 'FINALIZADA'; color = SupColors.textSecondary; break;
      case EstadoSalida.cancelada:  label = 'CANCELADA';  color = SupColors.semaforoRojo; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)));
  }

  Widget _chip(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 3),
    Text(label, style: TextStyle(color: color, fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w600, fontSize: 12)),
  ]);

  String _emojiNivel(NivelSalida n) {
    switch(n) {
      case NivelSalida.todos: return '🌊';
      case NivelSalida.principiante: return '🟢';
      case NivelSalida.intermedio: return '🟡';
      case NivelSalida.avanzado: return '🔴';
    }
  }

  String _labelNivel(NivelSalida n) {
    switch(n) {
      case NivelSalida.todos: return 'Todos los niveles';
      case NivelSalida.principiante: return 'Principiante+';
      case NivelSalida.intermedio: return 'Intermedio+';
      case NivelSalida.avanzado: return 'Avanzado';
    }
  }
}
