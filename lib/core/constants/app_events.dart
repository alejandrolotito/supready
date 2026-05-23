import 'package:flutter/foundation.dart';

class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();
  final favoritoChanged = ValueNotifier<int?>(null);

  void notificarFavoritoChanged(int spotId) {
    favoritoChanged.value = spotId;
    Future.microtask(() => favoritoChanged.notifyListeners());
  }
}
