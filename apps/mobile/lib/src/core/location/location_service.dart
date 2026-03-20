import "package:geolocator/geolocator.dart";
import "package:geocoding/geocoding.dart";

/// Service for managing location permissions and coordinate acquisition.
///
/// Accepts optional [GeolocatorPlatform] for dependency injection in tests.
class LocationService {
  LocationService({GeolocatorPlatform? geolocator})
      : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _geolocator;

  /// Checks the current location permission status.
  Future<LocationPermission> checkPermission() =>
      _geolocator.checkPermission();

  /// Requests location permission from the user.
  Future<LocationPermission> requestPermission() =>
      _geolocator.requestPermission();

  /// Checks whether location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() =>
      _geolocator.isLocationServiceEnabled();

  /// Gets the current device position with low accuracy (city-level).
  ///
  /// Returns null on failure to avoid crashing the app.
  Future<Position?> getCurrentPosition() async {
    try {
      return await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Converts coordinates to a human-readable location name.
  ///
  /// Returns "city, country" on success, or formatted coordinates
  /// ("lat, lon") if reverse geocoding fails.
  Future<String> getLocationName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality ?? p.subAdministrativeArea ?? "";
        final country = p.country ?? "";
        if (city.isNotEmpty) return "$city, $country";
      }
    } catch (_) {}
    return "${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}";
  }

  /// Opens the device location settings so the user can enable location.
  Future<void> openLocationSettings() =>
      _geolocator.openLocationSettings();
}
