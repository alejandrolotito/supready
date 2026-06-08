import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpotModel {
  final String id; final String name; final GeoPoint location;
  final double temperature; final double windSpeed; final String windDirection;
  final String tideTrend; final double tideHeight;

  SpotModel({required this.id, required this.name, required this.location, required this.temperature, required this.windSpeed, required this.windDirection, required this.tideTrend, required this.tideHeight});

  factory SpotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final weather = data['currentConditions'] as Map<String, dynamic>? ?? {};
    return SpotModel(
      id: doc.id, name: data['name'] ?? '', location: data['location'] as GeoPoint,
      temperature: (weather['temperature'] ?? 0.0).toDouble(),
      windSpeed: (weather['windSpeedKnots'] ?? 0.0).toDouble(),
      windDirection: weather['windDirectionStr'] ?? 'N',
      tideTrend: weather['tideTrend'] ?? 'ESTABLE',
      tideHeight: (weather['tideHeight'] ?? 0.0).toDouble(),
    );
  }
}

class FavoriteSpotNotifier extends StateNotifier<SpotModel?> {
  FavoriteSpotNotifier() : super(null);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void listenToFavoriteSpot(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((userDoc) {
      if (!userDoc.exists) return;
      final favSpotId = userDoc.data()?['favoriteSpotId'] as String?;
      if (favSpotId != null && favSpotId.isNotEmpty) {
        _firestore.collection('spots').doc(favSpotId).snapshots().listen((spotDoc) {
          if (spotDoc.exists) state = SpotModel.fromFirestore(spotDoc);
        });
      }
    });
  }

  Future<void> setFavoriteSpot(String userId, String spotId) async {
    await _firestore.collection('users').doc(userId).update({'favoriteSpotId': spotId});
  }

  Future<void> addNewSpot({required String name, required double lat, required double lng, required String creatorId}) async {
    await _firestore.collection('spots').add({
      'name': name, 'location': GeoPoint(lat, lng), 'createdBy': creatorId, 'isPublic': true,
      'currentConditions': {'temperature': 22.0, 'windSpeedKnots': 8.0, 'windDirectionStr': 'S', 'tideHeight': 0.8, 'tideTrend': 'SUBIENDO', 'lastUpdated': FieldValue.serverTimestamp()}
    });
  }
}

final favoriteSpotProvider = StateNotifierProvider<FavoriteSpotNotifier, SpotModel?>((ref) => FavoriteSpotNotifier());
