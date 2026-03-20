import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/services/trip_detection_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group("TripDetectionService", () {
    test("detectTrips calls API and returns parsed trips on success", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({
            "trips": [
              {
                "id": "trip_barcelona_2026-03-20_2026-03-24",
                "destination": "Barcelona",
                "startDate": "2026-03-20",
                "endDate": "2026-03-24",
                "durationDays": 4,
                "eventIds": ["e1", "e2"],
                "destinationCoordinates": {
                  "latitude": 41.39,
                  "longitude": 2.17,
                },
              }
            ]
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = TripDetectionService(apiClient: apiClient);
      final trips = await service.detectTrips();

      expect(trips, hasLength(1));
      expect(trips[0].id, "trip_barcelona_2026-03-20_2026-03-24");
      expect(trips[0].destination, "Barcelona");
      expect(trips[0].durationDays, 4);
      expect(trips[0].eventIds, ["e1", "e2"]);
      expect(trips[0].destinationLatitude, 41.39);
      expect(trips[0].destinationLongitude, 2.17);
    });

    test("detectTrips returns empty list on API error", () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Internal Server Error", "code": "INTERNAL_SERVER_ERROR", "message": "Error"}),
          500,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = TripDetectionService(apiClient: apiClient);
      final trips = await service.detectTrips();

      expect(trips, isEmpty);
    });

    test("detectTrips returns empty list on network error", () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception("Network error");
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );

      final service = TripDetectionService(apiClient: apiClient);
      final trips = await service.detectTrips();

      expect(trips, isEmpty);
    });
  });
}
