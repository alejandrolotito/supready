import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/clima_service.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CondicionesClimaticasModel? _condiciones;
  List<RutaTrazadaModel> _rutasRecientes = [];
  bool _cargandoClima = true;
  bool _cargandoRutas = true;

  static const _spotFavorito = SpotModel(
    spotId: 1, nombre: 'Playa Grande MDQ',
    latitud: -38.0055, longitud: -57.5426, descripcion: 'Mar del Plata',
  );

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future<void> _cargarDatos() async { _cargarClima(); _cargarRutas(); }

  Future<void> _cargarClima() async {
    setState(() => _cargandoClima = true);
    final c = await ClimaService.instance.obtenerCondiciones(
      spotId: _spotFavorito.spotId!, latitud: _spotFavorito.latitud, longitud: _spotFavorito.longitud);
    if (mounted) setState(() { _condiciones = c; _cargandoClima = false; });
  }

  Future<void> _cargarRutas() async {
    setState(() => _cargandoRutas = true);
    final usuario = AuthService.instance.usuarioActual;
    if (usuario?.usuarioId != null) {
      final rutas = await SupDatabase.instance.getRutasPorUsuario(usuario!.usuarioId!);
      if (mounted) setState(() { _rutasRecientes = rutas.take(3).toList(); _cargandoRutas = false; });
    } else {
      if (mounted) setState(() => _cargandoRutas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(
        child: RefreshIndicator(
          color: SupColors.cyanNeon, backgroundColor: SupColors.surface, onRefresh: _cargarDatos,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(), const SizedBox(height: 20),
              _buildSpotFavorito(), const SizedBox(height: 20),
              _buildRutasRecientes(), const SizedBox(height: 20),
              _buildStatsRapidas(), const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final usuario = AuthService.instance.usuarioActual;
    final h = DateTime.now().hour;
    final saludo = h < 12 ? 'Buenos días' : h < 18 ? 'Buenas tardes' : 'Buenas noches';
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(saludo, style: SupTextStyles.body),
        Text(usuario != null ? usuario.nombre : 'Palista', style: SupTextStyles.heading1),
      ]),
      const Spacer(),
      usuario?.avatarUrl != null
          ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(usuario!.avatarUrl!))
          : const CircleAvatar(radius: 22, backgroundColor: SupColors.surface,
              child: Icon(Icons.person, color: SupColors.cyanNeon)),
    ]);
  }

  Widget _buildSpotFavorito() {
    final spot = SpotModel(spotId: _spotFavorito.spotId, nombre: _spotFavorito.nombre,
        latitud: _spotFavorito.latitud, longitud: _spotFavorito.longitud,
        descripcion: _spotFavorito.descripcion, condiciones: _condiciones);
    final indice = spot.indiceViabilidad;
    final color = _colorIndice(indice);
    return GestureDetector(
      onTap: () => context.go('/spots'),
      child: Container(
        decoration: BoxDecoration(
          color: SupColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)])),
              const SizedBox(width: 8),
              Text('SPOT FAVORITO', style: SupTextStyles.label),
              const Spacer(),
              Text(_labelIndice(indice), style: TextStyle(
                color: color, fontSize: 11, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _cargandoClima
                ? const Center(child: Padding(padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: SupColors.cyanNeon, strokeWidth: 2)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_spotFavorito.nombre, style: SupTextStyles.heading2),
                    const SizedBox(height: 12),
                    if (_condiciones != null) ...[
                      Row(children: [
                        _meteoChip(Icons.air, '${_condiciones!.vientoKts.toStringAsFixed(0)} kts', 'Viento'),
                        const SizedBox(width: 12),
                        _meteoChip(Icons.waves, '${_condiciones!.olasMetros.toStringAsFixed(1)} m', 'Olas'),
                        const SizedBox(width: 12),
                        _meteoChip(Icons.navigation, '${_condiciones!.dirVientoGrados.toStringAsFixed(0)}°', 'Dirección'),
                      ]),
                      const SizedBox(height: 8),
                      Text('Actualizado hace ${DateTime.now().difference(_condiciones!.actualizadoEn).inMinutes} min',
                          style: SupTextStyles.body.copyWith(fontSize: 11)),
                    ] else
                      const Text('Sin datos de clima', style: SupTextStyles.body),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _meteoChip(IconData icon, String valor, String label) => Column(children: [
    Icon(icon, color: SupColors.cyanNeon, size: 20), const SizedBox(height: 4),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
        fontSize: 16, fontWeight: FontWeight.w700)),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 11)),
  ]);

  Widget _buildRutasRecientes() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      const Text('Últimas remadas', style: SupTextStyles.heading2), const Spacer(),
      TextButton(onPressed: () => context.go('/historial'),
          child: const Text('Ver todo', style: TextStyle(color: SupColors.cyanNeon, fontFamily: 'SpaceGrotesk'))),
    ]),
    const SizedBox(height: 8),
    if (_cargandoRutas)
      const Center(child: Padding(padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: SupColors.cyanNeon, strokeWidth: 2)))
    else if (_rutasRecientes.isEmpty)
      _buildEmptyRutas()
    else
      ..._rutasRecientes.map(_buildRutaCard),
  ]);

  Widget _buildEmptyRutas() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: SupColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupColors.divider)),
    child: Column(children: [
      const Icon(Icons.surfing, color: SupColors.textSecondary, size: 40),
      const SizedBox(height: 12),
      const Text('Todavía no remaste', style: SupTextStyles.body),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () => context.go('/track'), child: const Text('INICIAR PRIMERA REMADA')),
    ]),
  );

  Widget _buildRutaCard(RutaTrazadaModel ruta) {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = ruta.iniciadaEn;
    final fecha = '${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month-1]} · ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: SupColors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupColors.divider)),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: SupColors.cyanNeonDim, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.route, color: SupColors.cyanNeon, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fecha, style: SupTextStyles.body.copyWith(fontSize: 12)),
          const SizedBox(height: 2),
          Text('${ruta.distanciaKm.toStringAsFixed(2)} km · ${ruta.duracionMinutos} min',
              style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ])),
        Text('${ruta.velocidadMedia.toStringAsFixed(1)} km/h',
            style: SupTextStyles.label.copyWith(fontSize: 11)),
      ]),
    );
  }

  Widget _buildStatsRapidas() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: SupColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupColors.divider)),
    child: Row(children: [
      _statItem('Total km', '0.0'), Container(width: 1, height: 40, color: SupColors.divider),
      _statItem('Sesiones', '0'), Container(width: 1, height: 40, color: SupColors.divider),
      _statItem('Vel. media', '0.0 km/h'),
    ]),
  );

  Widget _statItem(String label, String valor) => Expanded(child: Column(children: [
    Text(valor, style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'JetBrainsMono',
        fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 12)),
  ]));

  Color _colorIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo: return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }
  String _labelIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return 'ÓPTIMO';
      case SupReadyIndex.amarillo: return 'PRECAUCIÓN';
      case SupReadyIndex.rojo: return 'PELIGRO';
      case SupReadyIndex.sinDatos: return 'SIN DATOS';
    }
  }
}
