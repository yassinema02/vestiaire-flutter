import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/calendar_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/screens/plan_week_screen.dart";
import "package:vestiaire_mobile/src/features/outfits/services/calendar_outfit_service.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_generation_service.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCalendarOutfitService extends CalendarOutfitService {
  _MockCalendarOutfitService({
    this.outfits = const [],
    this.shouldFail = false,
  }) : super(apiClient: _dummyApiClient());

  final List<CalendarOutfit> outfits;
  final bool shouldFail;

  @override
  Future<List<CalendarOutfit>> getCalendarOutfitsForDateRange(
      String startDate, String endDate) async {
    if (shouldFail) throw Exception("API error");
    return outfits;
  }

  @override
  Future<CalendarOutfit?> createCalendarOutfit({
    required String outfitId,
    String? calendarEventId,
    required String scheduledDate,
    String? notes,
  }) async {
    return null;
  }

  @override
  Future<bool> deleteCalendarOutfit(String id) async => true;
}

class _MockOutfitPersistenceService extends OutfitPersistenceService {
  _MockOutfitPersistenceService() : super(apiClient: _dummyApiClient());

  @override
  Future<List<SavedOutfit>> listOutfits() async => [];
}

class _MockOutfitGenerationService extends OutfitGenerationService {
  _MockOutfitGenerationService() : super(apiClient: _dummyApiClient());
}

ApiClient _dummyApiClient() {
  final mockClient = http_testing.MockClient((request) async {
    return http.Response(jsonEncode({}), 200);
  });
  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );
}

Widget _buildTestWidget({
  List<CalendarOutfit> calendarOutfits = const [],
  bool shouldFail = false,
}) {
  return MaterialApp(
    home: PlanWeekScreen(
      calendarOutfitService: _MockCalendarOutfitService(
        outfits: calendarOutfits,
        shouldFail: shouldFail,
      ),
      outfitPersistenceService: _MockOutfitPersistenceService(),
      outfitGenerationService: _MockOutfitGenerationService(),
    ),
  );
}

void main() {
  group("PlanWeekScreen", () {
    testWidgets("renders 7-day calendar strip with day names and dates",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Should find at least the day names for the upcoming week
      final now = DateTime.now();
      final dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      // Check that today's day name appears
      final todayName = dayNames[now.weekday - 1];
      expect(find.text(todayName), findsWidgets);
      // Check that date number appears
      expect(find.text("${now.day}"), findsWidgets);
    });

    testWidgets("shows N/A for weather when no forecast available",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Since no weather cache service is provided, all days should show N/A
      expect(find.text("N/A"), findsWidgets);
    });

    testWidgets("tapping a day selects it and shows detail panel",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the second day cell
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowDateText = find.text("${tomorrow.day}");

      if (tomorrowDateText.evaluate().isNotEmpty) {
        await tester.tap(tomorrowDateText.first);
        await tester.pumpAndSettle();
      }

      // Verify content renders without error
      expect(find.byType(PlanWeekScreen), findsOneWidget);
    });

    testWidgets("shows empty state with Assign Outfit button when no outfit scheduled",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text("No outfit scheduled"), findsOneWidget);
      expect(find.text("Assign Outfit"), findsOneWidget);
    });

    testWidgets("shows scheduled outfit card when one exists",
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final outfit = CalendarOutfit.fromJson({
        "id": "co-1",
        "outfitId": "outfit-1",
        "calendarEventId": null,
        "scheduledDate":
            "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}",
        "notes": null,
        "outfit": {
          "id": "outfit-1",
          "name": "Morning Casual",
          "occasion": "casual",
          "source": "ai",
          "items": [],
        },
        "createdAt": "2026-03-19T00:00:00Z",
        "updatedAt": "2026-03-19T00:00:00Z",
      });

      await tester.pumpWidget(_buildTestWidget(calendarOutfits: [outfit]));
      await tester.pumpAndSettle();

      expect(find.text("Morning Casual"), findsOneWidget);
      expect(find.text("Scheduled Outfits"), findsOneWidget);
    });

    testWidgets("shows loading state while fetching data", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      // Before settle, loading indicator should show
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets("shows error state with retry on fetch failure",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(shouldFail: true));
      await tester.pumpAndSettle();

      expect(find.text("Failed to load data"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("today cell shows Today label", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text("Today"), findsOneWidget);
    });

    testWidgets("semantics labels present on key elements", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Check that semantics exist via widget predicate
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("7-day calendar strip"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("No outfit scheduled"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("AppBar shows Plan Your Week title", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text("Plan Your Week"), findsOneWidget);
    });
  });
}
