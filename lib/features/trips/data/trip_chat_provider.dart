import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessageModel {
  final String id; final String senderId; final String senderName; final String text; final DateTime timestamp;
  ChatMessageModel({required this.id, required this.senderId, required this.senderName, required this.text, required this.timestamp});

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id, senderId: data['senderId'] ?? '', senderName: data['senderName'] ?? 'Palista',
      text: data['text'] ?? '', timestamp: (data['timestamp'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}

final tripChatProvider = StreamProvider.family<List<ChatMessageModel>, String>((ref, tripId) {
  return FirebaseFirestore.instance
      .collection('group_trips').doc(tripId).collection('messages')
      .orderBy('timestamp', descending: true).snapshots()
      .map((snap) => snap.docs.map((d) => ChatMessageModel.fromFirestore(d)).toList());
});

class ChatService {
  static Future<void> sendMessage(String tripId, String senderId, String senderName, String text) async {
    if (text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('group_trips')
        .doc(tripId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
