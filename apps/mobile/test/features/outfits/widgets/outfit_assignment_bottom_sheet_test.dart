import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/outfits/models/calendar_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/models/outfit_suggestion.dart";
import "package:vestiaire_mobile/src/features/outfits/models/saved_outfit.dart";
import "package:vestiaire_mobile/src/features/outfits/services/calendar_outfit_service.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_generation_service.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_persistence_service.dart";
import "package:vestiaire_mobile/src/features/outfits/widgets/outfit_assignment_bottom_sheet.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _MockOutfitPersistenceService extends OutfitPersistenceService {
  _MockOutfitPersistenceService({this.savedOutfits = const []})
      : super(apiClient: _dummyApiClient());

  final List<SavedOutfit> savedOutfits;

  @override
  Future<List<SavedOutfit>> listOutfits() async => savedOutfits;

  @override
  Future<Map<String, dynamic>?> saveOutfit(OutfitSuggestion suggestion) async {
    return {"id": "saved-outfit-1", "outfit": {"id": "saved-outfit-1"}};
  }
}

class _MockOutfitGenerationService extends OutfitGenerationService {
  _MockOutfitGenerationService({this.shouldGenerate = false})
      : super(apiClient: _dummyApiClient());

  final bool shouldGenerate;

  @override
  Future<OutfitGenerationResponse> generateOutfits(dynamic context) async {
    if (shouldGenerate) {
      return OutfitGenerationResponse(
        result: OutfitGenerationResult(
          suggestions: [
            const OutfitSuggestion(
              id: "s1",
              name: "Generated Look",
              items: [],
              explanation: "AI generated.",
              occasion: "casual",
            ),
          ],
          generatedAt: DateTime.now(),
        ),
      );
    }
    return const OutfitGenerationResponse(isError: true);
  }
}

class _MockCalendarOutfitService extends CalendarOutfitService {
  _MockCalendarOutfitService({this.shouldFailCreate = false})
      : super(apiClient: _dummyApiClient());

  final bool shouldFailCreate;

  @override
  Future<CalendarOutfit?> createCalendarOutfit({
    required String outfitId,
    String? calendarEventId,
    required String scheduledDate,
    String? notes,
  }) async {
    if (shouldFailCreate) return null;
    return CalendarOutfit.fromJson({
      "id": "co-new",
      "outfitId": outfitId,
      "calendarEventId": null,
      "scheduledDate": scheduledDate,
      "notes": null,
      "outfit": {"id": outfitId, "name": "Test", "occasion": "casual", "source": "ai", "items": []},
      "createdAt": "2026-03-19T00:00:00Z",
      "updatedAt": null,
    });
  }

  @override
  Future<CalendarOutfit?> updateCalendarOutfit(
    String id, {
    required String outfitId,
    String? calendarEventId,
    String? notes,
  }) async {
    return null;
  }
}

Widget _buildTestWidget({
  List<SavedOutfit> savedOutfits = const [],
  bool shouldFailCreate = false,
  bool shouldGenerate = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            showModalBottomSheet<CalendarOutfit>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => OutfitAssignmentBottomSheet(
                selectedDate: DateTime(2026, 3, 20),
                outfitPersistenceService: _MockOutfitPersistenceService(
                    savedOutfits: savedOutfits),
                outfitGenerationService:
                    _MockOutfitGenerationService(shouldGenerate: shouldGenerate),
                calendarOutfitService:
                    _MockCalendarOutfitService(shouldFailCreate: shouldFailCreate),
              ),
            );
          },
          child: const Text("Open Sheet"),
        ),
      ),
    ),
  );
}

void main() {
  group("OutfitAssignmentBottomSheet", () {
    testWidgets("renders two tabs: Saved Outfits and Generate New",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Saved Outfits"), findsOneWidget);
      expect(find.text("Generate New"), findsOneWidget);
    });

    testWidgets("Saved Outfits tab lists saved outfits", (tester) async {
      final outfit = SavedOutfit(
        id: "o1",
        name: "Test Outfit",
        occasion: "casual",
        source: "ai",
        createdAt: DateTime(2026, 3, 15),
        items: [],
      );

      await tester.pumpWidget(_buildTestWidget(savedOutfits: [outfit]));
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Test Outfit"), findsOneWidget);
      expect(find.text("Select"), findsOneWidget);
    });

    testWidgets("shows empty state when no saved outfits", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("No saved outfits available"), findsOneWidget);
    });

    testWidgets("Generate New tab shows generate button", (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      // Switch to Generate New tab
      await tester.tap(find.text("Generate New"));
      await tester.pumpAndSettle();

      expect(find.text("Generate Outfits"), findsOneWidget);
    });

    testWidgets("Generate New tab triggers outfit generation",
        (tester) async {
      await tester.pumpWidget(
          _buildTestWidget(shouldGenerate: true));
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      // Switch to Generate New tab
      await tester.tap(find.text("Generate New"));
      await tester.pumpAndSettle();

      // Tap generate button
      await tester.tap(find.text("Generate Outfits"));
      await tester.pumpAndSettle();

      expect(find.text("Generated Look"), findsOneWidget);
      expect(find.text("Assign This"), findsOneWidget);
    });

    testWidgets("shows error state on creation failure", (tester) async {
      final outfit = SavedOutfit(
        id: "o1",
        name: "Test Outfit",
        createdAt: DateTime(2026, 3, 15),
        items: [],
      );

      await tester.pumpWidget(
          _buildTestWidget(savedOutfits: [outfit], shouldFailCreate: true));
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      // Select the saved outfit
      await tester.tap(find.text("Select"));
      await tester.pumpAndSettle();

      expect(find.text("Failed to assign outfit"), findsOneWidget);
    });

    testWidgets("shows Assign Outfit title for new assignment",
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Assign Outfit"), findsOneWidget);
    });
  });
}
