import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/calendar/calendar_event.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/home/widgets/event_outfit_bottom_sheet.dart";
import "package:vestiaire_mobile/src/features/home/widgets/outfit_suggestion_card.dart";
import "package:vestiaire_mobile/src/features/outfits/services/outfit_generation_service.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CalendarEvent _makeEvent({
  String classificationSource = "keyword",
  String? location,
}) {
  return CalendarEvent(
    id: "evt-1",
    sourceCalendarId: "cal-1",
    sourceEventId: "evt-1",
    title: "Sprint Planning",
    description: "Weekly sprint planning meeting",
    location: location ?? "Conference Room B",
    startTime: DateTime(2026, 3, 15, 10, 0),
    endTime: DateTime(2026, 3, 15, 11, 0),
    allDay: false,
    eventType: "work",
    formalityScore: 5,
    classificationSource: classificationSource,
  );
}

OutfitGenerationService _makeService({
  bool shouldFail = false,
  int delayMs = 0,
}) {
  final mockClient = http_testing.MockClient((request) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (shouldFail) {
      return http.Response(
        jsonEncode({
          "error": "Internal Server Error",
          "code": "GENERATION_FAILED",
          "message": "Event outfit generation failed",
        }),
        500,
      );
    }
    return http.Response(
      jsonEncode({
        "suggestions": [
          {
            "id": "s1",
            "name": "Event Outfit",
            "items": [
              {"id": "i1", "name": "Shirt", "category": "tops", "color": "white", "photoUrl": null}
            ],
            "explanation": "Perfect for Sprint Planning.",
            "occasion": "work",
          }
        ],
        "generatedAt": "2026-03-15T10:00:00.000Z",
      }),
      200,
    );
  });

  final apiClient = ApiClient(
    baseUrl: "http://localhost:8080",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );

  return OutfitGenerationService(apiClient: apiClient);
}

Future<void> _pumpBottomSheet(
  WidgetTester tester, {
  CalendarEvent? event,
  OutfitGenerationService? service,
}) async {
  final e = event ?? _makeEvent();
  final s = service ?? _makeService();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showEventOutfitBottomSheet(
                context,
                event: e,
                outfitGenerationService: s,
              );
            },
            child: const Text("Open Sheet"),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text("Open Sheet"));
  await tester.pumpAndSettle();
}

void main() {
  group("EventOutfitBottomSheet", () {
    testWidgets("renders event details (title, time, location, type, formality)",
        (tester) async {
      await _pumpBottomSheet(tester);

      expect(find.text("Sprint Planning"), findsOneWidget);
      expect(find.text("10:00 - 11:00"), findsOneWidget);
      expect(find.text("Conference Room B"), findsOneWidget);
      expect(find.text("Work"), findsOneWidget);
      expect(find.text("Formality 5/10"), findsOneWidget);
    });

    testWidgets("shows loading shimmer initially", (tester) async {
      // Use a Completer-based service so we can control when it resolves
      final completer = Completer<http.Response>();
      final mockClient = http_testing.MockClient((request) => completer.future);

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showEventOutfitBottomSheet(
                    context,
                    event: _makeEvent(),
                    outfitGenerationService: service,
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pump(); // Initial frame
      await tester.pump(const Duration(milliseconds: 300)); // Allow bottom sheet animation

      expect(
        find.bySemanticsLabel("Loading event outfit suggestions"),
        findsOneWidget,
      );

      // Complete the completer to avoid pending timer issues
      completer.complete(http.Response(
        jsonEncode({
          "suggestions": [],
          "generatedAt": "2026-03-15T10:00:00.000Z",
        }),
        200,
      ));
      await tester.pumpAndSettle();
    });

    testWidgets("displays OutfitSuggestionCards on successful generation",
        (tester) async {
      await _pumpBottomSheet(tester);

      expect(find.byType(OutfitSuggestionCard), findsOneWidget);
      expect(find.text("Event Outfit"), findsOneWidget);
    });

    testWidgets("shows error state with retry button on generation failure",
        (tester) async {
      await _pumpBottomSheet(
        tester,
        service: _makeService(shouldFail: true),
      );

      expect(
        find.text("Unable to generate suggestions for this event."),
        findsOneWidget,
      );
      expect(find.text("Try Again"), findsOneWidget);
    });

    testWidgets("retry button re-triggers generation", (tester) async {
      // First call fails, set up accordingly
      int callCount = 0;
      final mockClient = http_testing.MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              "error": "Internal Server Error",
              "code": "GENERATION_FAILED",
              "message": "Failed",
            }),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            "suggestions": [
              {
                "id": "s1",
                "name": "Retry Outfit",
                "items": [
                  {"id": "i1", "name": "Shirt", "category": "tops", "color": "blue", "photoUrl": null}
                ],
                "explanation": "Works great.",
                "occasion": "work",
              }
            ],
            "generatedAt": "2026-03-15T10:00:00.000Z",
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: "http://localhost:8080",
        authService: _MockAuthService(),
        httpClient: mockClient,
      );
      final service = OutfitGenerationService(apiClient: apiClient);

      await _pumpBottomSheet(tester, service: service);

      // Should show error
      expect(find.text("Try Again"), findsOneWidget);

      // Tap retry
      await tester.tap(find.text("Try Again"));
      await tester.pumpAndSettle();

      // Should now show success
      expect(find.text("Retry Outfit"), findsOneWidget);
      expect(callCount, 2);
    });

    testWidgets("shows 'User override' indicator for user-classified events",
        (tester) async {
      await _pumpBottomSheet(
        tester,
        event: _makeEvent(classificationSource: "user"),
      );

      expect(find.text("User override"), findsOneWidget);
    });

    testWidgets("semantics labels are present", (tester) async {
      await _pumpBottomSheet(tester);

      expect(
        find.bySemanticsLabel(RegExp(r"Outfit suggestions for Sprint Planning")),
        findsOneWidget,
      );
    });
  });
}
