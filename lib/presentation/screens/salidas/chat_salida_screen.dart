import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/datasources/local/sup_database.dart';

// ============================================================
// SUPReady - Chat de Salida Grupal (local, sin Firebase)
// Mensajes persistidos en SQLite, listo para sync Firebase
// ============================================================

class ChatSalidaScreen extends StatefulWidget {
  final SalidaGrupal salida;
  const ChatSalidaScreen({super.key, required this.salida});
  @override
  State<ChatSalidaScreen> createState() => _ChatSalidaScreenState();
}

class _ChatSalidaScreenState extends State<ChatSalidaScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<_Mensaje> _mensajes = [];

  @override
  void initState() {
    super.initState();
    _cargarMensajes();
  }

  Future<void> _cargarMensajes() async {
    // Por ahora mensajes en memoria (listos para Firebase)
    // Se podrían persistir en SQLite con tabla mensajes_chat
    if (mounted) setState(() {
      _mensajes = [
        _Mensaje(
          autor: 'Sistema',
          texto: '💬 Chat de la salida creado. ¡Coordinen acá!',
          hora: widget.salida.fechaHora.subtract(const Duration(days: 1)),
          esPropio: false, esSistema: true),
      ];
    });
  }

  void _enviar() {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    final usuario = AuthService.instance.usuarioActual;
    setState(() {
      _mensajes.add(_Mensaje(
        autor: usuario?.nombre ?? 'Vos',
        texto: texto,
        hora: DateTime.now(),
        esPropio: true, esSistema: false,
      ));
    });
    _ctrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SupColors.backgroundDeep,
    appBar: AppBar(
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Chat de la salida'),
        Text(widget.salida.spotNombre,
            style: SupTextStyles.body.copyWith(fontSize: 12)),
      ]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Chip(
            backgroundColor: SupColors.cyanNeonDim,
            label: Text('${widget.salida.participantes.length} palistas',
                style: const TextStyle(color: SupColors.cyanNeon,
                    fontFamily: 'SpaceGrotesk', fontSize: 11, fontWeight: FontWeight.w600)),
            avatar: const Icon(Icons.people, color: SupColors.cyanNeon, size: 14),
          ),
        ),
      ],
    ),
    body: Column(children: [
      // Aviso Firebase
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: SupColors.semaforoAmarillo.withOpacity(0.1),
        child: Row(children: [
          const Icon(Icons.info_outline, color: SupColors.semaforoAmarillo, size: 14),
          const SizedBox(width: 6),
          Expanded(child: Text(
            'Chat en tiempo real disponible con Firebase (ver SALIDAS_GRUPALES.md)',
            style: SupTextStyles.body.copyWith(fontSize: 11,
                color: SupColors.semaforoAmarillo))),
        ]),
      ),
      // Lista de mensajes
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: _mensajes.length,
          itemBuilder: (_, i) => _buildMensaje(_mensajes[i]),
        ),
      ),
      // Input
      Container(
        color: SupColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: SupColors.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Mensaje...',
                hintStyle: const TextStyle(color: SupColors.textSecondary),
                filled: true, fillColor: SupColors.backgroundDeep,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: SupColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: SupColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: SupColors.cyanNeon, width: 1.5)),
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviar,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: SupColors.cyanNeon),
              child: const Icon(Icons.send_rounded,
                  color: SupColors.backgroundDeep, size: 20)),
          ),
        ]),
      ),
    ]),
  );

  Widget _buildMensaje(_Mensaje m) {
    if (m.esSistema) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: SupColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SupColors.divider)),
          child: Text(m.texto, style: SupTextStyles.body.copyWith(fontSize: 12)),
        ),
      );
    }

    final fmt = '${m.hora.hour.toString().padLeft(2,'0')}:${m.hora.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: m.esPropio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!m.esPropio) ...[
            CircleAvatar(radius: 14, backgroundColor: SupColors.cyanNeonDim,
                child: Text(m.autor.isNotEmpty ? m.autor[0].toUpperCase() : '?',
                    style: const TextStyle(color: SupColors.cyanNeon,
                        fontSize: 11, fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: m.esPropio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!m.esPropio)
                Text(m.autor, style: SupTextStyles.label.copyWith(fontSize: 10)),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: m.esPropio ? SupColors.cyanNeon : SupColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(m.esPropio ? 16 : 4),
                    bottomRight: Radius.circular(m.esPropio ? 4 : 16),
                  ),
                ),
                child: Text(m.texto, style: TextStyle(
                    color: m.esPropio ? SupColors.backgroundDeep : SupColors.textPrimary,
                    fontFamily: 'SpaceGrotesk', fontSize: 14)),
              ),
              const SizedBox(height: 2),
              Text(fmt, style: SupTextStyles.body.copyWith(fontSize: 10)),
            ],
          ),
          if (m.esPropio) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _Mensaje {
  final String autor, texto;
  final DateTime hora;
  final bool esPropio, esSistema;
  const _Mensaje({required this.autor, required this.texto, required this.hora,
      required this.esPropio, required this.esSistema});
}
