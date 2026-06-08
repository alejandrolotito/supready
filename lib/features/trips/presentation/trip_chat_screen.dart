import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/trip_chat_provider.dart';

class TripChatScreen extends ConsumerWidget {
  final String tripId; final String tripTitle;
  final TextEditingController _msgController = TextEditingController();

  TripChatScreen({Key? key, required this.tripId, required this.tripTitle}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(tripChatProvider(tripId));

    return Scaffold(
      appBar: AppBar(title: Text("Chat: $tripTitle")),
      body: Column(
        children: [
          Expanded(
            child: chatAsync.when(
              data: (messages) => ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final bool isMe = m.senderId == "rider_pro_123";
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text, style: const TextStyle(color: Colors.white)),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const Center(child: Text("ERROR: Solo inscriptos activos pueden ver este chat.", style: TextStyle(color: Colors.red))),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Escribir...", hintStyle: TextStyle(color: Colors.white30)))),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF06B6D4)),
                  onPressed: () {
                    if (_msgController.text.trim().isEmpty) return;
                    ChatService.sendMessage(tripId, "rider_pro_123", "Alejandro", _msgController.text);
                    _msgController.clear();
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
