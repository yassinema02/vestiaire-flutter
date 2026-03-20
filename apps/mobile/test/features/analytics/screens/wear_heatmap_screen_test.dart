import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart" as http_testing;
import "package:vestiaire_mobile/src/core/auth/auth_service.dart";
import "package:vestiaire_mobile/src/core/networking/api_client.dart";
import "package:vestiaire_mobile/src/features/analytics/screens/wear_heatmap_screen.dart";

class _MockAuthService implements AuthService {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => "mock-token";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _buildApiClient({
  Map<String, dynamic>? heatmapResponse,
  bool failAll = false,
  bool emptyData = false,
}) {
  final mockClient = http_testing.MockClient((request) async {
    if (failAll) {
      return http.Response(
        '{"error":"Internal Server Error","code":"INTERNAL_SERVER_ERROR","message":"Server error"}',
        500,
      );
    }
    if (request.url.path == "/v1/analytics/heatmap") {
      if (emptyData) {
        return http.Response(
          jsonEncode({
            "dailyActivity": [],
            "streakStats": {
              "currentStreak": 0,
              "longestStreak": 0,
              "totalDaysLogged": 0,
              "avgItemsPerDay": 0.0,
            },
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(heatmapResponse ?? {
          "dailyActivity": [
            {"date": "2026-03-01", "itemsCount": 3},
            {"date": "2026-03-02", "itemsCount": 1},
            {"date": "2026-03-05", "itemsCount": 7},
            {"date": "2026-03-10", "itemsCount": 4},
            {"date": "2026-03-15", "itemsCount": 2},
          ],
          "streakStats": {
            "currentStreak": 5,
            "longestStreak": 12,
            "totalDaysLogged": 45,
            "avgItemsPerDay": 2.8,
          },
        }),
        200,
      );
    }
    return http.Response('{"error":"Not Found"}', 404);
  });

  return ApiClient(
    baseUrl: "http://localhost:3000",
    authService: _MockAuthService(),
    httpClient: mockClient,
  );
}

Widget _buildApp({
  ApiClient? apiClient,
  DateTime? initialDate,
}) {
  return MaterialApp(
    home: WearHeatmapScreen(
      apiClient: apiClient ?? _buildApiClient(),
      initialDate: initialDate ?? DateTime(2026, 3, 15),
    ),
  );
}

void main() {
  testWidgets("renders month view by default", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text("Wear Heatmap"), findsOneWidget);
    expect(find.text("Month"), findsOneWidget);
    expect(find.text("Quarter"), findsOneWidget);
    expect(find.text("Year"), findsOneWidget);
  });

  testWidgets("color intensity: displays colored day cells", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Should see day numbers in the month grid
    expect(find.text("1"), findsWidgets);
    expect(find.text("15"), findsOneWidget);
  });

  testWidgets("view mode toggle switches between month, quarter, year", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Switch to Quarter
    await tester.tap(find.text("Quarter"));
    await tester.pumpAndSettle();

    // Quarter view should show Q1 in navigation header
    expect(find.textContaining("Q1 2026"), findsOneWidget);

    // Switch to Year
    await tester.tap(find.text("Year"));
    await tester.pumpAndSettle();

    expect(find.text("2026"), findsOneWidget);
  });

  testWidgets("month view shows navigation arrows", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets("streak statistics row shows 4 metrics", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text("Current Streak"), findsOneWidget);
    expect(find.text("Longest Streak"), findsOneWidget);
    expect(find.text("Total Days"), findsOneWidget);
    expect(find.text("Avg Items/Day"), findsOneWidget);

    expect(find.text("5"), findsWidgets); // current streak value (may overlap with day number)
    expect(find.text("12"), findsWidgets); // longest streak value (may overlap with day number 12)
    expect(find.text("45"), findsOneWidget); // total days value
    expect(find.text("2.8"), findsOneWidget); // avg items per day value
  });

  testWidgets("color legend displays correctly", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text("None"), findsOneWidget);
    expect(find.text("1-2"), findsOneWidget);
    expect(find.text("3-5"), findsOneWidget);
    expect(find.text("6+"), findsOneWidget);
  });

  testWidgets("loading state shows progress indicator", (tester) async {
    await tester.pumpWidget(_buildApp());
    // Don't settle -- capture loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("error state shows retry button", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(failAll: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets("empty state shows correct message", (tester) async {
    await tester.pumpWidget(_buildApp(
      apiClient: _buildApiClient(emptyData: true),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text("No wear data yet. Log your outfits to build your heatmap!"),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
  });

  testWidgets("semantics labels present", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(RegExp("Wear heatmap")),
      findsOneWidget,
    );
  });

  testWidgets("navigation arrows work - back", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Should show March 2026
    expect(find.text("March 2026"), findsOneWidget);

    // Navigate back
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text("February 2026"), findsOneWidget);
  });

  testWidgets("year view shows 12 months in grid", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Switch to Year view
    await tester.tap(find.text("Year"));
    await tester.pumpAndSettle();

    // Should show month abbreviations
    expect(find.text("Jan"), findsOneWidget);
    expect(find.text("Dec"), findsOneWidget);
  });

  testWidgets("streak stats icons are present", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
  });
}
