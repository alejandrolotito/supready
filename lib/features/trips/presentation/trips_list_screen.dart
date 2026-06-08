import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_chat_screen.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({Key? key}) : super(key: key);

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = "rider_pro_123";
  final String _userName = "Alejandro";

  Future<void> _joinOrLeaveTrip(String tripId, List<dynamic> attendees, bool isJoined) async {
    final docRef = _firestore.collection('group_trips').doc(tripId);
    if (isJoined) {
      await docRef.update({
        'attendees': FieldValue.arrayRemove([_userId])
      });
    } else {
      await docRef.update({
        'attendees': FieldValue.arrayUnion([_userId])
      });
    }
  }

  Future<void> _createNewTrip() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Nueva Salida Grupal", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Título",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Descripción",
                  labelStyle: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await _firestore.collection('group_trips').add({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'organizerId': _userId,
                  'organizerName': _userName,
                  'date': Timestamp.now(),
                  'maxParticipants': 10,
                  'status': 'open',
                  'attendees': [_userId],
                });
                Navigator.pop(context);
              },
              child: const Text("CREAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("SALIDAS DE LA COMUNIDAD"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('group_trips').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar salidas", style: TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }

          final trips = snapshot.data?.docs ?? [];
          if (trips.isEmpty) {
            return const Center(
              child: Text(
                "No hay salidas organizadas aún.",
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final doc = trips[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Sin título';
              final desc = data['description'] ?? '';
              final organizer = data['organizerName'] ?? 'Anónimo';
              final attendees = data['attendees'] as List<dynamic>? ?? [];
              final isJoined = attendees.contains(_userId);
              final status = data['status'] ?? 'open';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'open' ? const Color(0xFF10B981).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'open' ? "ABIERTA" : "COMPLETADA",
                            style: TextStyle(
                              color: status == 'open' ? const Color(0xFF10B981) : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white38, size: 16),
                        const SizedBox(width: 6),
                        Text("Organizador: $organizer", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        const Spacer(),
                        const Icon(Icons.group, color: Colors.white38, size: 16),
                        const SizedBox(width: 6),
                        Text("${attendees.length} inscriptos", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isJoined ? const Color(0xFF334155) : const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _joinOrLeaveTrip(doc.id, attendees, isJoined),
                            child: Text(
                              isJoined ? "SALIR" : "UNIRSE",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (isJoined) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TripChatScreen(tripId: doc.id, tripTitle: title),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                              label: const Text(
                                "CHAT",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        onPressed: _createNewTrip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
