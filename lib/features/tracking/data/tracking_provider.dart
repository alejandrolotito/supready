import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GpsPointModel {
  final double latitude; final double longitude; final double speed; final DateTime timestamp;
  GpsPointModel({required this.latitude, required this.longitude, required this.speed, required this.timestamp});

  Map<String, dynamic> toMap() => {
    'latitude': latitude, 'longitude': longitude, 'speed': speed, 'timestamp': Timestamp.fromDate(timestamp),
  };
}

class TrackingState {
  final bool isTracking; final List<GpsPointModel> routePoints; final String? currentSessionId;
  TrackingState({this.isTracking = false, this.routePoints = const [], this.currentSessionId});

  TrackingState copyWith({bool? isTracking, List<GpsPointModel>? routePoints, String? currentSessionId}) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      routePoints: routePoints ?? this.routePoints,
      currentSessionId: currentSessionId ?? this.currentSessionId,
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  TrackingNotifier() : super(TrackingState());
  StreamSubscription<Position>? _gpsSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<GpsPointModel> _bufferPoints = [];

  void startTracking(String userId) async {
    final sessionRef = _firestore.collection('users').doc(userId).collection('sessions').doc();
    state = TrackingState(isTracking: true, routePoints: [], currentSessionId: sessionRef.id);
    await sessionRef.set({'startTime': FieldValue.serverTimestamp(), 'status': 'active'});

    // PARÁMETROS CRÍTICOS ANTI-LÍNEAS RECTAS
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // 2 metros obligatorios
      intervalDuration: const Duration(seconds: 3),
    );

    _gpsSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final newPoint = GpsPointModel(
        latitude: position.latitude, longitude: position.longitude, speed: position.speed, timestamp: DateTime.now(),
      );
      state = state.copyWith(routePoints: List.from(state.routePoints)..add(newPoint));
      _bufferPoints.add(newPoint);

      if (_bufferPoints.length >= 10) { _flushPointsToFirebase(userId); }
    });
  }

  Future<void> _flushPointsToFirebase(String userId) async {
    if (_bufferPoints.isEmpty || state.currentSessionId == null) return;
    final pointsToSend = List<GpsPointModel>.from(_bufferPoints);
    _bufferPoints.clear();

    final batch = _firestore.batch();
    final pointsRef = _firestore.collection('users').doc(userId).collection('sessions').doc(state.currentSessionId).collection('points');

    for (var p in pointsToSend) { batch.set(pointsRef.doc(), p.toMap()); }
    await batch.commit();
  }

  void stopTracking(String userId) async {
    await _gpsSubscription?.cancel();
    if (_bufferPoints.isNotEmpty) await _flushPointsToFirebase(userId);
    if (state.currentSessionId != null) {
      await _firestore.collection('users').doc(userId).collection('sessions').doc(state.currentSessionId).update({
        'endTime': FieldValue.serverTimestamp(), 'status': 'completed',
      });
    }
    state = state.copyWith(isTracking: false);
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>((ref) => TrackingNotifier());
