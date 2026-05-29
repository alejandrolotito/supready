import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../data/datasources/remote/firestore_service.dart';

// ============================================================
// SUPReady - Chat de Salida (Firestore tiempo real)
// Mensajes persisten en Firestore → todos los usuarios los ven
// ============================================================

class ChatSalidaScreen extends StatefulWidget {
  final SalidaGrupal salida;
  const ChatSalidaScreen({super.key, required this.salida});
  @override
  State<ChatSalidaScreen> createState() => _ChatSalidaScreenState();
}

class _ChatSalidaScreenState extends State<ChatSalidaScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;

  String? get _firestoreId => widget.salida.firestoreId;

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  void _scrollAbajo() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _firestoreId == null) return;
    final usuario = AuthService.instance.usuarioActual;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Iniciá sesión para chatear'),
          backgroundColor: SupColors.surface));
      return;
    }
    setState(() => _enviando = true);
    _ctrl.clear();
    await FirestoreService.instance.enviarMensaje(_firestoreId!, usuario, texto);
    setState(() => _enviando = false);
    _scrollAbajo();
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
                    fontFamily: 'SpaceGrotesk', fontSize: 11,
                    fontWeight: FontWeight.w600)),
            avatar: const Icon(Icons.people, color: SupColors.cyanNeon, size: 14),
          ),
        ),
      ],
    ),
    body: _firestoreId == null
        ? _buildSinFirestore()
        : Column(children: [
            Expanded(
              child: StreamBuilder<List<MensajeChat>>(
                stream: FirestoreService.instance.streamMensajes(_firestoreId!),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: SupColors.cyanNeon));
                  }
                  final mensajes = snap.data ?? [];
                  if (mensajes.isEmpty) return _buildVacio();
                  // Auto-scroll cuando llegan mensajes nuevos
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAbajo());
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: mensajes.length,
                    itemBuilder: (_, i) => _buildMensaje(mensajes[i]),
                  );
                },
              ),
            ),
            _buildInput(),
          ]),
  );

  Widget _buildSinFirestore() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off, color: SupColors.textSecondary, size: 48),
    const SizedBox(height: 12),
    const Text('Chat no disponible', style: SupTextStyles.heading2),
    const SizedBox(height: 8),
    const Text('Esta salida fue creada localmente.\nCreá una nueva desde la app.',
        style: SupTextStyles.body, textAlign: TextAlign.center),
  ]));

  Widget _buildVacio() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('💬', style: TextStyle(fontSize: 48)),
      SizedBox(height: 12),
      Text('Sé el primero en escribir', style: SupTextStyles.body),
    ]),
  );

  Widget _buildInput() => Container(
    color: SupColors.surface,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: Row(children: [
      Expanded(
        child: TextField(
          controller: _ctrl,
          style: const TextStyle(color: SupColors.textPrimary),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _enviar(),
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
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _enviando ? null : _enviar,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _enviando ? SupColors.surface : SupColors.cyanNeon),
          child: _enviando
              ? const Padding(padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: SupColors.cyanNeon))
              : const Icon(Icons.send_rounded,
                  color: SupColors.backgroundDeep, size: 20)),
      ),
    ]),
  );

  Widget _buildMensaje(MensajeChat m) {
    final usuario = AuthService.instance.usuarioActual;
    final esPropio = m.autorId == (usuario?.googleId ?? usuario?.usuarioId.toString());
    final fmt = '${m.timestamp.hour.toString().padLeft(2,'0')}:${m.timestamp.minute.toString().padLeft(2,'0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: esPropio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esPropio) ...[
            CircleAvatar(
              radius: 14, backgroundColor: SupColors.cyanNeonDim,
              backgroundImage: m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
              child: m.avatarUrl == null ? Text(
                  m.autorNombre.isNotEmpty ? m.autorNombre[0].toUpperCase() : '?',
                  style: const TextStyle(color: SupColors.cyanNeon,
                      fontSize: 11, fontWeight: FontWeight.w700)) : null),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: esPropio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!esPropio)
                Padding(padding: const EdgeInsets.only(bottom: 2),
                    child: Text(m.autorNombre,
                        style: SupTextStyles.label.copyWith(fontSize: 10))),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: esPropio ? SupColors.cyanNeon : SupColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(esPropio ? 16 : 4),
                    bottomRight: Radius.circular(esPropio ? 4 : 16),
                  ),
                ),
                child: Text(m.texto, style: TextStyle(
                    color: esPropio ? SupColors.backgroundDeep : SupColors.textPrimary,
                    fontFamily: 'SpaceGrotesk', fontSize: 14))),
              const SizedBox(height: 2),
              Text(fmt, style: SupTextStyles.body.copyWith(fontSize: 10)),
            ],
          ),
          if (esPropio) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
