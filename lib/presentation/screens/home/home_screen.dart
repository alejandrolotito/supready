import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_events.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/clima_service.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../../data/datasources/remote/firestore_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<SpotModel> _todosLosSpots = [];
  SpotModel? _spotSeleccionado;
  CondicionesClimaticasModel? _condiciones;
  List<RutaTrazadaModel> _rutasRecientes = [];
  EstadisticasUsuario? _stats;
  bool _cargandoClima = true, _cargandoRutas = true;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    AppEvents.instance.favoritoChanged.addListener(_onFavoritoChanged);
  }

  @override
  void dispose() {
    AppEvents.instance.favoritoChanged.removeListener(_onFavoritoChanged);
    super.dispose();
  }

  void _onFavoritoChanged() => _cargarSpots(cambiarFavorito: true);

  Future<void> _cargarTodo() async {
    await Future.wait([_cargarSpots(), _cargarRutas()]);
  }

  Future<void> _cargarSpots({bool cambiarFavorito = false}) async {
    setState(() => _cargandoClima = true);
    final spots = await SupDatabase.instance.getSpots();
    if (spots.isEmpty) {
      if (mounted) setState(() => _cargandoClima = false);
      return;
    }
    SpotModel? sel;
    if (cambiarFavorito || _spotSeleccionado == null) {
      sel = spots.firstWhere((s) => s.esFavorito, orElse: () => spots.first);
    } else {
      sel = spots.firstWhere(
          (s) => s.spotId == _spotSeleccionado!.spotId,
          orElse: () => spots.first);
    }
    if (mounted) setState(() { _todosLosSpots = spots; _spotSeleccionado = sel; });
    await _cargarClimaSpot(sel!);
  }

  Future<void> _cargarClimaSpot(SpotModel spot) async {
    setState(() => _cargandoClima = true);
    final c = await ClimaService.instance.obtenerCondiciones(
        spotId: spot.spotId!, latitud: spot.latitud, longitud: spot.longitud);
    if (mounted) setState(() { _condiciones = c; _cargandoClima = false; });
  }

  Future<void> _cargarRutas() async {
    setState(() => _cargandoRutas = true);
    final usuario = AuthService.instance.usuarioActual;
    final rutas = usuario?.usuarioId != null
        ? await SupDatabase.instance.getRutasPorUsuario(usuario!.usuarioId!)
        : await SupDatabase.instance.getAllRutas();
    final stats = await StatsRepository.instance.calcular(usuario?.usuarioId);
    if (mounted) setState(() {
      _rutasRecientes = rutas.take(3).toList();
      _stats = stats;
      _cargandoRutas = false;
    });
  }

  void _onCambiarSpot(SpotModel? spot) {
    if (spot == null || spot.spotId == _spotSeleccionado?.spotId) return;
    setState(() => _spotSeleccionado = spot);
    _cargarClimaSpot(spot);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioActual;
    final h = DateTime.now().hour;
    final saludo = h < 12 ? 'Buenos días' : h < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(
        child: RefreshIndicator(
          color: SupColors.cyanNeon, backgroundColor: SupColors.surface,
          onRefresh: _cargarTodo,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // Header
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(saludo, style: SupTextStyles.body),
                Text(usuario?.nombre ?? 'Palista', style: SupTextStyles.heading1),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: usuario?.avatarUrl != null
                    ? CircleAvatar(radius: 22,
                        backgroundImage: NetworkImage(usuario!.avatarUrl!))
                    : const CircleAvatar(radius: 22,
                        backgroundColor: SupColors.surface,
                        child: Icon(Icons.person, color: SupColors.cyanNeon)),
              ),
            ]),
            const SizedBox(height: 20),

            // Dropdown spots
            _buildDropdown(),
            const SizedBox(height: 12),

            // Clima tarjeta
            _buildClima(),
            const SizedBox(height: 20),

            // Últimas remadas
            _buildRutas(),
            const SizedBox(height: 20),

            // Stats
            _buildStats(),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    if (_todosLosSpots.isEmpty) {
      return GestureDetector(
        onTap: () => context.go('/spots'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SupColors.divider)),
          child: const Row(children: [
            Icon(Icons.add_location_alt_outlined, color: SupColors.cyanNeon),
            SizedBox(width: 10),
            Text('Agregar un spot', style: SupTextStyles.body),
            Spacer(),
            Icon(Icons.chevron_right, color: SupColors.textSecondary),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: SupColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SupColors.cyanNeon.withOpacity(0.4), width: 1.5)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SpotModel>(
          value: _spotSeleccionado,
          isExpanded: true,
          dropdownColor: SupColors.surfaceElevated,
          icon: const Icon(Icons.keyboard_arrow_down, color: SupColors.cyanNeon),
          items: _todosLosSpots.map((s) => DropdownMenuItem(
            value: s,
            child: Row(children: [
              Icon(s.esFavorito ? Icons.star_rounded : Icons.location_on_outlined,
                  color: s.esFavorito ? Colors.amber : SupColors.cyanNeon, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(s.nombre, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SupColors.textPrimary,
                      fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 15))),
              const SizedBox(width: 8),
              Container(width: 8, height: 8, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _colorIndice(s.indiceViabilidad))),
            ]),
          )).toList(),
          onChanged: _onCambiarSpot,
        ),
      ),
    );
  }

  Widget _buildClima() {
    if (_spotSeleccionado == null) return const SizedBox.shrink();
    final indice = _condiciones != null
        ? SpotModel(spotId: _spotSeleccionado!.spotId, nombre: _spotSeleccionado!.nombre,
            latitud: _spotSeleccionado!.latitud, longitud: _spotSeleccionado!.longitud,
            condiciones: _condiciones).indiceViabilidad
        : SupReadyIndex.sinDatos;
    final color = _colorIndice(indice);

    return Container(
      decoration: BoxDecoration(color: SupColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)])),
            const SizedBox(width: 8),
            Text(_labelIndice(indice), style: TextStyle(color: color,
                fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700,
                fontSize: 12, letterSpacing: 0.8)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.go('/prevision'),
              child: const Row(children: [
                Text('Previsión 48h', style: TextStyle(
                    color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk', fontSize: 11)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: SupColors.cyanNeon, size: 10),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _cargandoClima
              ? const Center(child: Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: SupColors.cyanNeon, strokeWidth: 2)))
              : _condiciones != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _chip(Icons.air, '${_condiciones!.vientoKts.toStringAsFixed(0)} kts', 'Viento'),
                        _chip(Icons.waves, '${_condiciones!.olasMetros.toStringAsFixed(1)} m', 'Olas'),
                        _chip(Icons.navigation, _condiciones!.dirVientoTexto, 'Dir.'),
                        if (_condiciones!.tempAguaC != null)
                          _chip(Icons.thermostat,
                              '${_condiciones!.tempAguaC!.toStringAsFixed(0)}°C', 'Agua'),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'Actualizado hace ${DateTime.now().difference(_condiciones!.actualizadoEn).inMinutes} min · Open-Meteo',
                        style: SupTextStyles.body.copyWith(fontSize: 11)),
                    ])
                  : const Text('Sin datos de clima', style: SupTextStyles.body),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String valor, String label) => Column(children: [
    Icon(icon, color: SupColors.cyanNeon, size: 18), const SizedBox(height: 3),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontSize: 14, fontWeight: FontWeight.w700)),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 10)),
  ]);

  Widget _buildRutas() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Text('Últimas remadas', style: SupTextStyles.heading2),
      const Spacer(),
      TextButton(onPressed: () => context.go('/historial'),
          child: const Text('Ver todo', style: TextStyle(
              color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk'))),
    ]),
    const SizedBox(height: 8),
    if (_cargandoRutas)
      const Center(child: Padding(padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: SupColors.cyanNeon, strokeWidth: 2)))
    else if (_rutasRecientes.isEmpty)
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: SupColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SupColors.divider)),
        child: Column(children: [
          const Icon(Icons.surfing, color: SupColors.textSecondary, size: 40),
          const SizedBox(height: 12),
          const Text('Todavía no remaste', style: SupTextStyles.body),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => context.go('/track'),
              child: const Text('INICIAR PRIMERA REMADA')),
        ]))
    else ..._rutasRecientes.map((r) {
        final dt = r.iniciadaEn;
        final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
        final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SupColors.divider)),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.route, color: SupColors.cyanNeon, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} · '
                  '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                  style: SupTextStyles.body.copyWith(fontSize: 12)),
              const SizedBox(height: 2),
              Text('${r.distanciaKm.toStringAsFixed(2)} km · ${r.duracionMinutos} min',
                  style: const TextStyle(color: SupColors.textPrimary,
                      fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 15)),
            ])),
            Text('${r.velocidadMedia.toStringAsFixed(1)} km/h',
                style: SupTextStyles.label.copyWith(fontSize: 11)),
          ]),
        );
      }),
  ]);

  Widget _buildStats() {
    final s = _stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: SupColors.surface,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: SupColors.divider)),
      child: Row(children: [
        _statItem('Total km', s == null ? '—' : s.totalKmStr),
        Container(width: 1, height: 40, color: SupColors.divider),
        _statItem('Sesiones', s == null ? '—' : '${s.totalRutas}'),
        Container(width: 1, height: 40, color: SupColors.divider),
        _statItem('Vel. media', s == null ? '—' : s.velMediaStr),
      ]),
    );
  }

  Widget _statItem(String label, String valor) => Expanded(child: Column(children: [
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontSize: 16, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 12)),
  ]));

  Color _colorIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde:    return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo:     return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }

  String _labelIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde:    return 'CONDICIONES ÓPTIMAS';
      case SupReadyIndex.amarillo: return 'PRECAUCIÓN';
      case SupReadyIndex.rojo:     return 'PELIGRO — NO SALIR';
      case SupReadyIndex.sinDatos: return 'SIN DATOS';
    }
  }
}
