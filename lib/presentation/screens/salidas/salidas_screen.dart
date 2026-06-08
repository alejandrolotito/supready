import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/auth_service.dart';
import 'crear_salida_screen.dart';
import 'detalle_salida_screen.dart';

class SalidasScreen extends ConsumerStatefulWidget {
  const SalidasScreen({super.key});
  @override
  ConsumerState<SalidasScreen> createState() => _SalidasScreenState();
}

class _SalidasScreenState extends ConsumerState<SalidasScreen>
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
    final uid = usuario?.googleId ?? usuario?.usuarioId.toString() ?? '';

    return Scaffold(
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
        label: const Text('CREAR SALIDA',
            style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CrearSalidaScreen())),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        // Tab 1: Salidas públicas via Riverpod
        ref.watch(salidasPublicasProvider).when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: SupColors.cyanNeon)),
          error: (e, _) => _buildError(e.toString()),
          data: (salidas) {
            final ahora = DateTime.now();
            final proximas = salidas
                .where((s) => s.fechaHora.isAfter(ahora))
                .toList();
            return proximas.isEmpty
                ? _buildVacio('No hay salidas próximas.\n¡Creá la primera!')
                : _buildLista(proximas);
          },
        ),
        // Tab 2: Mis salidas via Riverpod
        usuario == null
            ? _buildLoginRequired()
            : ref.watch(misSalidasProvider(uid)).when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: SupColors.cyanNeon)),
                error: (e, _) => _buildError(e.toString()),
                data: (salidas) => salidas.isEmpty
                    ? _buildVacio('Todavía no participás en ninguna salida.')
                    : _buildLista(salidas),
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
    Text(err.length > 100 ? '${err.substring(0, 100)}...' : err,
        style: SupTextStyles.body.copyWith(fontSize: 11), textAlign: TextAlign.center),
  ]));

  Widget _buildLoginRequired() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.login, color: SupColors.cyanNeon, size: 48),
    const SizedBox(height: 16),
    const Text('Iniciá sesión para ver tus salidas', style: SupTextStyles.body),
  ]));
}

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
                Text(salida.spotNombre,
                    style: SupTextStyles.heading2.copyWith(fontSize: 16)),
                if (salida.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(salida.descripcion,
                      style: SupTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
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
        ]),
      ),
    );
  }

  Widget _estadoBadge(EstadoSalida e) {
    final map = {
      EstadoSalida.abierta:    ('ABIERTA',    SupColors.semaforoVerde),
      EstadoSalida.enCurso:    ('EN CURSO',   SupColors.cyanNeon),
      EstadoSalida.finalizada: ('FINALIZADA', SupColors.textSecondary),
      EstadoSalida.cancelada:  ('CANCELADA',  SupColors.semaforoRojo),
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
    NivelSalida.todos:        '🌊',
    NivelSalida.principiante: '🟢',
    NivelSalida.intermedio:   '🟡',
    NivelSalida.avanzado:     '🔴',
  }[n]!;

  String _labelNivel(NivelSalida n) => const {
    NivelSalida.todos:        'Todos los niveles',
    NivelSalida.principiante: 'Principiante+',
    NivelSalida.intermedio:   'Intermedio+',
    NivelSalida.avanzado:     'Solo avanzados',
  }[n]!;
}
