import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/local/sup_database.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/datasources/remote/clima_service.dart';
import '../../../data/datasources/remote/firestore_service.dart';

class CrearSalidaScreen extends StatefulWidget {
  const CrearSalidaScreen({super.key});
  @override
  State<CrearSalidaScreen> createState() => _CrearSalidaScreenState();
}

class _CrearSalidaScreenState extends State<CrearSalidaScreen> {
  int _paso = 0;
  SpotModel? _spot;
  DateTime _fecha = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _hora = const TimeOfDay(hour: 8, minute: 0);
  NivelSalida _nivel = NivelSalida.todos;
  int _cupos = 6;
  bool _esPublica = true;
  final _descCtrl = TextEditingController();
  List<SpotModel> _spots = [];
  CondicionesClimaticasModel? _clima;
  bool _cargandoSpots = true;
  bool _guardando = false;

  @override
  void initState() { super.initState(); _cargarSpots(); }

  Future<void> _cargarSpots() async {
    final spots = await SupDatabase.instance.getSpots();
    if (mounted) setState(() { _spots = spots; _cargandoSpots = false; });
  }

  Future<void> _seleccionarSpot(SpotModel s) async {
    setState(() { _spot = s; _clima = null; });
    final c = await ClimaService.instance.obtenerCondiciones(
        spotId: s.spotId!, latitud: s.latitud, longitud: s.longitud);
    if (mounted) setState(() => _clima = c);
  }

  DateTime get _fechaHora => DateTime(
      _fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);

  Future<void> _guardar() async {
    if (_spot == null) return;
    setState(() => _guardando = true);
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Necesitás iniciar sesión para crear salidas'),
          backgroundColor: SupColors.semaforoRojo));
      return;
    }
    final salida = SalidaGrupal(
      organizadorId: usuario.usuarioId ?? 0,
      spotId: _spot!.spotId!, spotNombre: _spot!.nombre,
      fechaHora: _fechaHora, nivelMinimo: _nivel,
      cuposMax: _cupos, esPublica: _esPublica,
      descripcion: _descCtrl.text.trim(),
    );
    try {
      // 1. Guardar en Firestore (multiusuario)
      final firestoreId = await FirestoreService.instance.crearSalida(salida, usuario.nombre);
      
      // 2. También subir perfil público del organizador
      await FirestoreService.instance.upsertPerfil(usuario);

      // 3. Guardar en la base de datos local SQLite para reflejarlo en la pestaña "Mis Salidas"
      final localSalida = SalidaGrupal(
        firestoreId: firestoreId,
        organizadorId: salida.organizadorId,
        spotId: salida.spotId,
        spotNombre: salida.spotNombre,
        fechaHora: salida.fechaHora,
        nivelMinimo: salida.nivelMinimo,
        cuposMax: salida.cuposMax,
        esPublica: salida.esPublica,
        estado: salida.estado,
        descripcion: salida.descripcion,
      );
      final localId = await SupDatabase.instance.crearSalida(localSalida);

      // Auto-anotar al creador en la subcolección local y remota
      final participante = ParticipanteSalida(
        usuarioId: usuario.usuarioId ?? 0,
        nombre: usuario.nombre,
        avatarUrl: usuario.avatarUrl,
        estado: EstadoParticipante.confirmado,
      );
      await SupDatabase.instance.anotarseEnSalida(localId, participante);
      await FirestoreService.instance.anotarseEnSalida(firestoreId, usuario);

      setState(() => _guardando = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Salida creada! Otros palistas ya pueden verla 🏄'),
            backgroundColor: SupColors.semaforoVerde));
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al crear salida: $e'),
            backgroundColor: SupColors.semaforoRojo));
      }
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
      LinearProgressIndicator(value: (_paso + 1) / 3,
          backgroundColor: SupColors.surface,
          valueColor: const AlwaysStoppedAnimation<Color>(SupColors.cyanNeon)),
      Expanded(child: [_buildSpot(), _buildFechaHora(), _buildDetalles()][_paso]),
    ]),
  );

  Widget _buildSpot() {
    if (_cargandoSpots) return const Center(child: CircularProgressIndicator(color: SupColors.cyanNeon));
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('¿Dónde van a remar?', style: SupTextStyles.body),
        const SizedBox(height: 16),
        ..._spots.map((s) {
          final sel = _spot?.spotId == s.spotId;
          return GestureDetector(
            onTap: () => _seleccionarSpot(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel ? SupColors.cyanNeonDim : SupColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? SupColors.cyanNeon : SupColors.divider,
                    width: sel ? 2 : 1)),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, color: SupColors.cyanNeon, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(s.nombre, style: SupTextStyles.heading2.copyWith(fontSize: 15))),
                if (s.esFavorito) const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                if (sel) const Icon(Icons.check_circle, color: SupColors.cyanNeon, size: 20),
              ]),
            ),
          );
        }),
        if (_spot != null) ...[
          const SizedBox(height: 16),
          Container(height: 150,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SupColors.divider)),
            clipBehavior: Clip.hardEdge,
            child: FlutterMap(
              options: MapOptions(initialCenter: LatLng(_spot!.latitud, _spot!.longitud),
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.supready.app'),
                MarkerLayer(markers: [Marker(
                    point: LatLng(_spot!.latitud, _spot!.longitud), width: 32, height: 32,
                    child: Container(decoration: BoxDecoration(shape: BoxShape.circle,
                        color: SupColors.cyanNeon,
                        border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.surfing, color: SupColors.backgroundDeep, size: 16)))])
              ],
            )),
          if (_clima != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: SupColors.cyanNeonDim,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _miniClima(Icons.air, '${_clima!.vientoKts.toStringAsFixed(0)} kts'),
                _miniClima(Icons.waves, '${_clima!.olasMetros.toStringAsFixed(1)} m'),
                _miniClima(Icons.navigation, _clima!.dirVientoTexto),
              ])),
          ],
        ],
      ])),
      _boton(_spot != null, 'SIGUIENTE →'),
    ]);
  }

  Widget _buildFechaHora() {
    final dias  = ['Dom','Lun','Mar','Mié','Jue','Vie','Sáb'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final hoy = DateTime.now();
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('¿Qué día?', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        SizedBox(height: 80, child: ListView.builder(
          scrollDirection: Axis.horizontal, itemCount: 14,
          itemBuilder: (_, i) {
            final d = hoy.add(Duration(days: i + 1));
            final sel = _fecha.day == d.day && _fecha.month == d.month;
            return GestureDetector(
              onTap: () => setState(() => _fecha = d),
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
        const Text('¿A qué hora?', style: SupTextStyles.heading2),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final h in [6,7,8,9,10,11,14,15,16,17,18])
            GestureDetector(
              onTap: () => setState(() => _hora = TimeOfDay(hour: h, minute: 0)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: _hora.hour == h ? SupColors.cyanNeon : SupColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _hora.hour == h ? SupColors.cyanNeon : SupColors.divider)),
                child: Text('${h.toString().padLeft(2,'0')}:00', style: TextStyle(
                    color: _hora.hour == h ? SupColors.backgroundDeep : SupColors.textPrimary,
                    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 16))),
            ),
          GestureDetector(
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _hora);
              if (t != null) setState(() => _hora = t);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: SupColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SupColors.cyanNeon, width: 1.5)),
              child: const Text('Otra...', style: TextStyle(color: SupColors.cyanNeon,
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 14)))),
        ]),
      ])),
      _boton(true, 'SIGUIENTE →'),
    ]);
  }

  Widget _buildDetalles() {
    final dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    final meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final dt = _fechaHora;
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Nivel mínimo', style: SupTextStyles.heading2),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: NivelSalida.values.map((n) {
          final sel = _nivel == n;
          return GestureDetector(
            onTap: () => setState(() => _nivel = n),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: sel ? SupColors.cyanNeon : SupColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? SupColors.cyanNeon : SupColors.divider)),
              child: Text(_labelNivel(n), style: TextStyle(
                  color: sel ? SupColors.backgroundDeep : SupColors.textPrimary,
                  fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 13))),
          );
        }).toList()),
        const SizedBox(height: 20),
        Row(children: [
          const Text('Cupos máximos', style: SupTextStyles.heading2),
          const Spacer(),
          IconButton(onPressed: () { if (_cupos > 2) setState(() => _cupos--); },
              icon: const Icon(Icons.remove_circle_outline, color: SupColors.cyanNeon)),
          Text('$_cupos', style: const TextStyle(color: SupColors.textPrimary,
              fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w700, fontSize: 22)),
          IconButton(onPressed: () { if (_cupos < 20) setState(() => _cupos++); },
              icon: const Icon(Icons.add_circle_outline, color: SupColors.cyanNeon)),
        ]),
        const SizedBox(height: 16),
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
            value: _esPublica, activeColor: SupColors.cyanNeon,
            onChanged: (v) => setState(() => _esPublica = v)),
        ),
        const SizedBox(height: 16),
        TextField(controller: _descCtrl, style: const TextStyle(color: SupColors.textPrimary),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Descripción opcional...',
              hintStyle: const TextStyle(color: SupColors.textSecondary),
              filled: true, fillColor: SupColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SupColors.divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SupColors.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)))),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: SupColors.cyanNeonDim,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SupColors.cyanNeon.withOpacity(0.3))),
          child: Column(children: [
            _resumen('📍 Spot', _spot?.nombre ?? ''),
            const Divider(color: SupColors.divider, height: 16),
            _resumen('📅 Fecha', '${dias[dt.weekday-1]} ${dt.day} ${meses[dt.month]} ${dt.hour.toString().padLeft(2,'0')}:00'),
            const Divider(color: SupColors.divider, height: 16),
            _resumen('👥 Cupos', '$_cupos palistas'),
            const Divider(color: SupColors.divider, height: 16),
            _resumen('🌊 Nivel', _labelNivel(_nivel)),
          ])),
      ])),
      _boton(!_guardando, _guardando ? 'CREANDO...' : 'CREAR SALIDA 🏄',
          action: _guardar),
    ]);
  }

  Widget _boton(bool activo, String label, {Future<void> Function()? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: ElevatedButton(
      onPressed: activo ? (action ?? () => setState(() => _paso++)) : null,
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
      child: Text(label, style: const TextStyle(fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700, fontSize: 16))));

  Widget _miniClima(IconData icon, String val) => Column(children: [
    Icon(icon, color: SupColors.cyanNeon, size: 16), const SizedBox(height: 2),
    Text(val, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'JetBrainsMono', fontSize: 13, fontWeight: FontWeight.w600))]);

  Widget _resumen(String label, String valor) => Row(children: [
    Text(label, style: SupTextStyles.body.copyWith(fontSize: 13)), const Spacer(),
    Text(valor, style: const TextStyle(color: SupColors.textPrimary,
        fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 13))]);

  String _labelNivel(NivelSalida n) => const {
    NivelSalida.todos: '🌊 Todos',
    NivelSalida.principiante: '🟢 Principiante+',
    NivelSalida.intermedio: '🟡 Intermedio+',
    NivelSalida.avanzado: '🔴 Solo avanzados',
  }[n]!;
}
