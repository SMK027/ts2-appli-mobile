// Issue #9 - [CF-HOME] : Service de géolocalisation GPS
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Récupère la position GPS de l'utilisateur
  /// Demande la permission si nécessaire
  /// Retourne null si la permission est refusée ou en cas d'erreur
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      // geolocator non supporté sur cette plateforme (ex: Linux desktop)
      return null;
    }
  }
}
