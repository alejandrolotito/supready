import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supready/core/theme/app_theme.dart';
import 'package:supready/data/datasources/local/tracking_service.dart';

// ============================================================
// SUPReady - Pantalla de Tracking
// ERS §6: Anti-Agua UX
//   - Tipografía 72pt mínimo para métricas
//   - Long Press 3000ms para finalizar (Water Shield)
//   - Funcionalidad 100% offline
//   - SOS automático si sin movimiento 15 min
// ============================================================

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  final _trackingService = TrackingService.instance;

  StreamSubscription<MetricasTracking>? _metricasSub;
  StreamSubscription<void>? _sosSub;

  MetricasTracking? _metricas;
  bool _trackingActivo = false;
  bool _cargando = false;

  // Long press controller (Water Shield UX)
  late AnimationController _longPressController;
  bool _longPressActivo = false;

  // Pulso del indicador de grabación
  late AnimationController _pulsoController;
  late Animation<double> _pulsoAnim;

  @override
  void initState() {
    super.initState();
    _longPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finalizarTracking();
        }
      });

    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulsoAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.easeInOut),
    );

    _sosSub = _trackingService.sosStream.listen((_) => _mostrarAlertaSOS());
  }

  @override
  void dispose() {
    _longPressController.dispose();
    _pulsoController.dispose();
    _metricasSub?.cancel();
    _sosSub?.cancel();
    super.dispose();
  }

  Future<void> _iniciarTracking() async {
    setState(() => _cargando = true);
    // TODO: obtener usuarioId y spotId del contexto
    final ok = await _trackingService.iniciarTracking(usuarioId: 1, spotId: 1);
    if (ok) {
      _metricasSub = _trackingService.metricasStream.listen((m) {
        if (mounted) setState(() => _metricas = m);
      });
      HapticFeedback.heavyImpact();
      setState(() {
        _trackingActivo = true;
        _cargando = false;
      });
    } else {
      setState(() => _cargando = false);
      _mostrarSnackBar('No se pudo obtener permiso de GPS');
    }
  }

  Future<void> _finalizarTracking() async {
    final ruta = await _trackingService.finalizarTracking();
    _metricasSub?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _trackingActivo = false);
    if (ruta != null && mounted) {
      _mostrarResumenRuta(ruta);
    }
  }

  void _mostrarAlertaSOS() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: SupColors.surface,
        title: const Text('⚠️ SOS ACTIVADO',
            style: TextStyle(color: SupColors.sosRed, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700)),
        content: const Text(
          'Sin movimiento detectado por 15 minutos.\nSe enviará SMS de alerta de emergencia.',
          style: TextStyle(color: SupColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Reinicia el timer de SOS
            },
            child: const Text('ESTOY BIEN', style: TextStyle(color: SupColors.cyanNeon)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SupColors.sosRed),
            onPressed: () {
              // TODO: telephony.sendSms()
              Navigator.pop(context);
            },
            child: const Text('ENVIAR SOS'),
          ),
        ],
      ),
    );
  }

  void _mostrarResumenRuta(dynamic ruta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SupColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResumenRutaSheet(ruta: ruta),
    );
  }

  void _mostrarSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: SupColors.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupColors.backgroundDeep,
      body: SafeArea(
        child: _trackingActivo ? _buildVistaActiva() : _buildVistaInicio(),
      ),
    );
  }

  // --- Vista inicial ---
  Widget _buildVistaInicio() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.surfing, size: 80, color: SupColors.cyanNeon),
          const SizedBox(height: 32),
          Text('SUPReady', style: SupTextStyles.heading1.copyWith(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Iniciá tu remada', style: SupTextStyles.body),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _cargando ? null : _iniciarTracking,
            icon: _cargando
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: SupColors.backgroundDeep, strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_cargando ? 'OBTENIENDO GPS...' : 'INICIAR REMADA'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 68),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // --- Vista activa con métricas anti-agua ---
  Widget _buildVistaActiva() {
    return Column(
      children: [
        // Header con indicador grabando
        _buildHeaderGrabando(),
        const SizedBox(height: 16),
        // Métricas principales (72pt - ERS §6)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildMetricaPrincipal(
                  label: 'DISTANCIA',
                  valor: _metricas?.distanciaKm.toStringAsFixed(2) ?? '0.00',
                  unidad: 'KM',
                ),
                const Divider(color: SupColors.divider, height: 32),
                _buildMetricaPrincipal(
                  label: 'VELOCIDAD',
                  valor: _metricas?.velocidadActualKmh.toStringAsFixed(1) ?? '0.0',
                  unidad: 'KM/H',
                ),
                const Divider(color: SupColors.divider, height: 32),
                _buildMetricaPrincipal(
                  label: 'DURACIÓN',
                  valor: _metricas?.duracionFormateada ?? '0m',
                  unidad: '',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Botón FINALIZAR con Long Press (Water Shield UX - ERS §6)
        _buildBotonFinalizar(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeaderGrabando() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: SupColors.surface,
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulsoAnim,
            child: const Icon(Icons.fiber_manual_record, color: SupColors.sosRed, size: 14),
          ),
          const SizedBox(width: 8),
          const Text('GRABANDO', style: SupTextStyles.label),
          const Spacer(),
          const Icon(Icons.wifi_off, color: SupColors.textSecondary, size: 16),
          const SizedBox(width: 4),
          const Text('OFFLINE', style: TextStyle(
            fontSize: 11, color: SupColors.textSecondary,
            fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }

  Widget _buildMetricaPrincipal({
    required String label,
    required String valor,
    required String unidad,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SupTextStyles.label),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: SupTextStyles.metricDisplay),
              ),
            ],
          ),
        ),
        if (unidad.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(unidad, style: SupTextStyles.metricUnit),
          ),
      ],
    );
  }

  // Long Press de 3 segundos con animación circular (Water Shield UX)
  Widget _buildBotonFinalizar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onLongPressStart: (_) {
          setState(() => _longPressActivo = true);
          _longPressController.forward();
        },
        onLongPressEnd: (_) {
          if (_longPressController.status != AnimationStatus.completed) {
            _longPressController.reset();
            setState(() => _longPressActivo = false);
          }
        },
        child: AnimatedBuilder(
          animation: _longPressController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Fondo base
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: SupColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SupColors.divider),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'MANTENER PARA FINALIZAR',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: SupColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                // Overlay de progreso
                if (_longPressActivo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _longPressController.value,
                        child: Container(
                          height: 72,
                          color: SupColors.semaforoRojo.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Bottom Sheet Resumen de Ruta
// ----------------------------------------------------------
class _ResumenRutaSheet extends StatelessWidget {
  final dynamic ruta;
  const _ResumenRutaSheet({required this.ruta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: SupColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('¡Remada completada! 🏄', style: SupTextStyles.heading2),
          const SizedBox(height: 20),
          _itemResumen('Distancia', '${ruta.distanciaKm.toStringAsFixed(2)} km'),
          _itemResumen('Duración', '${ruta.duracionMinutos} min'),
          _itemResumen('Velocidad media', '${ruta.velocidadMedia.toStringAsFixed(1)} km/h'),
          _itemResumen('Vel. máxima', '${ruta.velocidadMaxima.toStringAsFixed(1)} km/h'),
          const SizedBox(height: 8),
          const Text('💾 Guardada localmente', style: TextStyle(
            color: SupColors.cyanNeon, fontSize: 13, fontFamily: 'SpaceGrotesk',
          )),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  Widget _itemResumen(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SupTextStyles.body),
          Text(valor, style: const TextStyle(
            color: SupColors.textPrimary,
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          )),
        ],
      ),
    );
  }
}
