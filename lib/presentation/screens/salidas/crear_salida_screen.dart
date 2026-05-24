import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/datasources/remote/clima_service.dart';

// ============================================================
// SUPReady - Crear Salida Grupal
// Flujo: spot → fecha/hora → detalles → confirmar
// ============================================================

class CrearSalidaScreen extends StatefulWidget {
  const CrearSalidaScreen({super.key});
  @override
  State<CrearSalidaScreen> createState() => _CrearSalidaScreenState();
}

class _CrearSalidaScreenState extends State<CrearSalidaScreen> {
  int _paso = 0; // 0=spot, 1=fechahora, 2=detalles
  
  // Selecciones
  SpotModel? _spotSeleccionado;
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 8, minute: 0);
  NivelSalida _nivel = NivelSalida.todos;
  int _cupos = 6;
  bool _esPublica = true;
  final _descCtrl = TextEditingController();
  
  List<SpotModel> _spots = [];
  CondicionesClimaticasModel? _climaSpot;
  bool _cargandoSpots = true;
  bool _guardando = false;

  @override
  void initState() { super.initState(); _cargarSpots(); }

  Future<void> _cargarSpots() async {
    final spots = await SupDatabase.instance.getSpots();
    if (mounted) setState(() { _spots = spots; _cargandoSpots = false; });
  }

  Future<void> _seleccionarSpot(SpotModel spot) async {
    setState(() { _spotSeleccionado = spot; _climaSpot = null; });
    final clima = await ClimaService.instance.obtenerCondiciones(
        spotId: spot.spotId!, latitud: spot.latitud, longitud: spot.longitud);
    if (mounted) setState(() => _climaSpot = clima);
  }

  DateTime get _fechaHoraCombinada => DateTime(
    _fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day,
    _horaSeleccionada.hour, _horaSeleccionada.minute);

  Future<void> _guardar() async {
    if (_spotSeleccionado == null) return;
    setState(() => _guardando = true);
    final usuario = AuthService.instance.usuarioActual;
    final salida = SalidaGrupal(
      organizadorId: usuario?.usuarioId ?? 0,
      spotId: _spotSeleccionado!.spotId!,
      spotNombre: _spotSeleccionado!.nombre,
      fechaHora: _fechaHoraCombinada,
      nivelMinimo: _nivel,
      cuposMax: _cupos,
      esPublica: _esPublica,
      descripcion: _descCtrl.text.trim(),
    );
    await SupDatabase.instance.crearSalida(salida);
    setState(() => _guardando = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Salida creada! 🏄'),
        backgroundColor: SupColors.semaforoVerde));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(
      title: Text(['Elegí el spot', 'Fecha y hora', 'Detalles'][_paso]),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _paso == 0 ? () => Navigator.pop(context) : () => setState(() => _paso--),
      ),
    ),
    body: Column(children: [
      // Progress indicator
      LinearProgressIndicator(
        value: (_paso + 1) / 3,
        backgroundColor: SupColors.surface,
        valueColor: const AlwaysStoppedAnimation<Color>(SupColors.cyanNeon),
      ),
      Expanded(child: [
        _buildPasoSpot(),
        _buildPasoFechaHora(),
        _buildPasoDetalles(),
      ][_paso]),
    ]),
  );

  // ── PASO 1: Seleccionar spot ─────────────────────────────
  Widget _buildPasoSpot() {
    if (_cargandoSpots) return const Center(
        child: CircularProgressIndicator(color: SupColors.cyanNeon));
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('¿Dónde van a remar?', style: SupTextStyles.body),
          const SizedBox(height: 16),
          ..._spots.map((s) {
            final sel = _spotSeleccionado?.spotId == s.spotId;
            final indice = s.condiciones != null
                ? s.indiceViabilidad : SupReadyIndex.sinDatos;
            return GestureDetector(
              onTap: () => _seleccionarSpot(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? SupColors.cyanNeonDim : SupColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? SupColors.cyanNeon : SupColors.divider,
                    width: sel ? 2 : 1)),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _colorIndice(indice))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 15)),
                    Text(s.descripcion, style: SupTextStyles.body.copyWith(fontSize: 12)),
                  ])),
                  if (s.esFavorito)
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  if (sel)
                    const Icon(Icons.check_circle, color: SupColors.cyanNeon, size: 20),
                ]),
              ),
            );
          }),
          // Mini mapa del spot seleccionado
          if (_spotSeleccionado != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 160, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SupColors.divider)),
              clipBehavior: Clip.hardEdge,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_spotSeleccionado!.latitud, _spotSeleccionado!.longitud),
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.supready.app'),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(_spotSeleccionado!.latitud, _spotSeleccionado!.longitud),
                      width: 36, height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: SupColors.cyanNeon,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [BoxShadow(color: SupColors.cyanNeon.withOpacity(0.5), blurRadius: 8)]),
                        child: const Icon(Icons.surfing, color: SupColors.backgroundDeep, size: 18))),
                  ]),
                ],
              ),
            ),
            if (_climaSpot != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorIndice(_SpotHelper.indice(_climaSpot!)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _colorIndice(_SpotHelper.indice(_climaSpot!)).withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _miniClima(Icons.air, '${_climaSpot!.vientoKts.toStringAsFixed(0)} kts'),
                  _miniClima(Icons.waves, '${_climaSpot!.olasMetros.toStringAsFixed(1)} m'),
                  _miniClima(Icons.navigation, _climaSpot!.dirVientoTexto),
                ]),
              ),
            ],
          ],
        ]),
      ),
      _botonSiguiente(_spotSeleccionado != null, 'SIGUIENTE →'),
    ]);
  }

  // ── PASO 2: Fecha y hora ─────────────────────────────────
  Widget _buildPasoFechaHora() {
    final dias = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final hoy = DateTime.now();
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
        // Selector de días (próximos 14 días)
        const Text('¿Qué día?', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 14,
          itemBuilder: (_, i) {
            final d = hoy.add(Duration(days: i + 1));
            final sel = _fechaSeleccionada.day == d.day &&
                _fechaSeleccionada.month == d.month;
            return GestureDetector(
              onTap: () => setState(() => _fechaSeleccionada = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: sel ? SupColors.cyanNeon : SupColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? SupColors.cyanNeon : SupColors.divider)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(dias[d.weekday % 7], style: TextStyle(
                      color: sel ? SupColors.backgroundDeep : SupColors.textSecondary,
                      fontFamily: 'SpaceGrotesk', fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${d.day}', style: TextStyle(
                      color: sel ? SupColors.backgroundDeep : SupColors.textPrimary,
                      fontFamily: 'JetBrainsMono', fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(meses[d.month], style: TextStyle(
                      color: sel ? SupColors.backgroundDeep : SupColors.textSecondary,
                      fontFamily: 'SpaceGrotesk', fontSize: 10)),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 28),
        // Selector de hora
        const Text('¿A qué hora?', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final h in [6, 7, 8, 9, 10, 11, 14, 15, 16, 17, 18])
            GestureDetector(
              onTap: () => setState(() => _horaSeleccionada = TimeOfDay(hour: h, minute: 0)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _horaSeleccionada.hour == h ? SupColors.cyanNeon : SupColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _horaSeleccionada.hour == h ? SupColors.cyanNeon : SupColors.divider)),
                child: Text('${h.toString().padLeft(2,'0')}:00', style: TextStyle(
                    color: _horaSeleccionada.hour == h ? SupColors.backgroundDeep : SupColors.textPrimary,
                    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          // Hora personalizada
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _horaSeleccionada);
              if (t != null) setState(() => _horaSeleccionada = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: SupColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SupColors.cyanNeon, width: 1.5)),
              child: const Text('Otra...', style: TextStyle(color: SupColors.cyanNeon,
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 14))),
          ),
        ]),
        const SizedBox(height: 20),
        // Resumen
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(12), border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.event, color: SupColors.cyanNeon),
            const SizedBox(width: 10),
            Text(
              '${dias[_fechaHoraCombinada.weekday % 7]} ${_fechaHoraCombinada.day} ${meses[_fechaHoraCombinada.month]} a las ${_horaSeleccionada.hour.toString().padLeft(2,'0')}:00',
              style: const TextStyle(color: SupColors.textPrimary, fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ])),
      _botonSiguiente(true, 'SIGUIENTE →'),
    ]);
  }

  // ── PASO 3: Detalles ────────────────────────────────────
  Widget _buildPasoDetalles() => Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
      // Nivel
      const Text('Nivel mínimo', style: SupTextStyles.heading2),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: NivelSalida.values.map((n) {
        final sel = _nivel == n;
        return GestureDetector(
          onTap: () => setState(() => _nivel = n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? SupColors.cyanNeon : SupColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? SupColors.cyanNeon : SupColors.divider)),
            child: Text(_labelNivelFull(n), style: TextStyle(
                color: sel ? SupColors.backgroundDeep : SupColors.textPrimary,
                fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13))),
        );
      }).toList()),
      const SizedBox(height: 24),
      // Cupos
      Row(children: [
        const Text('Cupos máximos', style: SupTextStyles.heading2),
        const Spacer(),
        IconButton(
          onPressed: () { if (_cupos > 2) setState(() => _cupos--); },
          icon: const Icon(Icons.remove_circle_outline, color: SupColors.cyanNeon)),
        Text('$_cupos', style: const TextStyle(color: SupColors.textPrimary,
            fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 22)),
        IconButton(
          onPressed: () { if (_cupos < 20) setState(() => _cupos++); },
          icon: const Icon(Icons.add_circle_outline, color: SupColors.cyanNeon)),
      ]),
      const SizedBox(height: 20),
      // Visibilidad
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: SupColors.surface,
            borderRadius: BorderRadius.circular(14), border: Border.all(color: SupColors.divider)),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Salida pública', style: TextStyle(color: SupColors.textPrimary,
              fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600)),
          subtitle: Text(_esPublica ? 'Visible para todos los palistas' : 'Solo por invitación',
              style: SupTextStyles.body.copyWith(fontSize: 12)),
          value: _esPublica,
          activeColor: SupColors.cyanNeon,
          onChanged: (v) => setState(() => _esPublica = v),
        ),
      ),
      const SizedBox(height: 20),
      // Descripción
      TextField(
        controller: _descCtrl,
        style: const TextStyle(color: SupColors.textPrimary),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Descripción opcional (ej: circuito de 8 km, nivel de marea...)',
          hintStyle: const TextStyle(color: SupColors.textSecondary),
          filled: true, fillColor: SupColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SupColors.divider)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SupColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
        ),
      ),
      const SizedBox(height: 24),
      // Resumen final
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SupColors.cyanNeonDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3))),
        child: Column(children: [
          _resumenRow('📍 Spot', _spotSeleccionado?.nombre ?? ''),
          const Divider(color: SupColors.divider, height: 16),
          _resumenRow('📅 Fecha', _formatFecha()),
          const Divider(color: SupColors.divider, height: 16),
          _resumenRow('👥 Cupos', '$_cupos palistas'),
          const Divider(color: SupColors.divider, height: 16),
          _resumenRow('🏄 Nivel', _labelNivelFull(_nivel)),
        ]),
      ),
    ])),
    _botonSiguiente(!_guardando, _guardando ? 'CREANDO...' : 'CREAR SALIDA 🏄',
        action: _guardar, color: SupColors.cyanNeon),
  ]);

  Widget _resumenRow(String label, String valor) => Row(children: [
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 13)),
    const Spacer(),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13)),
  ]);

  Widget _botonSiguiente(bool activo, String label,
      {Future<void> Function()? action, Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: ElevatedButton(
      onPressed: activo ? (action ?? () => setState(() => _paso++)) : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: color ?? SupColors.cyanNeon,
        foregroundColor: SupColors.backgroundDeep,
        textStyle: const TextStyle(fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700, fontSize: 16)),
      child: Text(label)),
  );

  Widget _miniClima(IconData icon, String val) => Column(children: [
    Icon(icon, color: SupColors.cyanNeon, size: 16),
    const SizedBox(height: 2),
    Text(val, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontSize: 13, fontWeight: FontWeight.w600)),
  ]);

  Color _colorIndice(SupReadyIndex i) {
    switch(i) {
      case SupReadyIndex.verde: return SupColors.semaforoVerde;
      case SupReadyIndex.amarillo: return SupColors.semaforoAmarillo;
      case SupReadyIndex.rojo: return SupColors.semaforoRojo;
      case SupReadyIndex.sinDatos: return SupColors.textSecondary;
    }
  }

  String _labelNivelFull(NivelSalida n) {
    switch(n) {
      case NivelSalida.todos: return '🌊 Todos los niveles';
      case NivelSalida.principiante: return '🟢 Principiante+';
      case NivelSalida.intermedio: return '🟡 Intermedio+';
      case NivelSalida.avanzado: return '🔴 Solo avanzados';
    }
  }

  String _formatFecha() {
    final dias = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = _fechaHoraCombinada;
    return '${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} ${dt.hour.toString().padLeft(2,'0')}:00';
  }
}

class _SpotHelper {
  static SupReadyIndex indice(CondicionesClimaticasModel c) {
    if (c.vientoKts > 15 || c.rafagasKts > 18 || c.olasMetros > 1.0 || c.esOffshore)
      return SupReadyIndex.rojo;
    if (c.vientoKts >= 9 || c.esCrossShore || c.olasMetros >= 0.5)
      return SupReadyIndex.amarillo;
    return SupReadyIndex.verde;
  }
}
