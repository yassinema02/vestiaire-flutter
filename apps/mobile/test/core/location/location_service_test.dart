import "package:flutter_test/flutter_test.dart";
import "package:geolocator/geolocator.dart";
import "package:vestiaire_mobile/src/core/location/location_service.dart";

/// Mock GeolocatorPlatform for testing.
class MockGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission permissionToReturn = LocationPermission.denied;
  LocationPermission requestPermissionToReturn = LocationPermission.whileInUse;
  bool locationServiceEnabled = true;
  Position? positionToReturn;
  bool shouldThrowOnGetPosition = false;
  bool openSettingsCalled = false;

  @override
  Future<LocationPermission> checkPermission() async => permissionToReturn;

  @override
  Future<LocationPermission> requestPermission() async =>
      requestPermissionToReturn;

  @override
  Future<bool> isLocationServiceEnabled() async => locationServiceEnabled;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (shouldThrowOnGetPosition) {
      throw const LocationServiceDisabledException();
    }
    if (positionToReturn != null) return positionToReturn!;
    throw const LocationServiceDisabledException();
  }

  @override
  Future<bool> openLocationSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

Position _testPosition({
  double latitude = 48.85,
  double longitude = 2.35,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 100,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  group("LocationService", () {
    late MockGeolocatorPlatform mockGeolocator;
    late LocationService service;

    setUp(() {
      mockGeolocator = MockGeolocatorPlatform();
      service = LocationService(geolocator: mockGeolocator);
    });

    test("checkPermission delegates to GeolocatorPlatform", () async {
      mockGeolocator.permissionToReturn = LocationPermission.whileInUse;
      final result = await service.checkPermission();
      expect(result, LocationPermission.whileInUse);
    });

    test("requestPermission delegates to GeolocatorPlatform", () async {
      mockGeolocator.requestPermissionToReturn = LocationPermission.always;
      final result = await service.requestPermission();
      expect(result, LocationPermission.always);
    });

    test("isLocationServiceEnabled delegates to GeolocatorPlatform", () async {
      mockGeolocator.locationServiceEnabled = false;
      final result = await service.isLocationServiceEnabled();
      expect(result, false);
    });

    test("getCurrentPosition returns Position on success", () async {
      mockGeolocator.positionToReturn = _testPosition();
      final result = await service.getCurrentPosition();
      expect(result, isNotNull);
      expect(result!.latitude, 48.85);
      expect(result.longitude, 2.35);
    });

    test("getCurrentPosition returns null on failure", () async {
      mockGeolocator.shouldThrowOnGetPosition = true;
      final result = await service.getCurrentPosition();
      expect(result, isNull);
    });

    test("openLocationSettings delegates to GeolocatorPlatform", () async {
      await service.openLocationSettings();
      expect(mockGeolocator.openSettingsCalled, true);
    });

    // Note: getLocationName tests are limited because geocoding uses a
    // global function (placemarkFromCoordinates) that cannot be easily
    // mocked without a platform channel mock. We test the fallback path.
    test("getLocationName returns formatted coordinates on geocoding failure",
        () async {
      // placemarkFromCoordinates will throw in test environment
      // (no platform channel), triggering the fallback
      final result = await service.getLocationName(48.85, 2.35);
      expect(result, "48.85, 2.35");
    });
  });
}
