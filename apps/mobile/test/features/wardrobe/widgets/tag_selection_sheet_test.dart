import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/taxonomy.dart";
import "package:vestiaire_mobile/src/features/wardrobe/widgets/tag_selection_sheet.dart";

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("TagSelectionSheet", () {
    testWidgets("renders all options", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagSelectionSheet(
              title: "Category",
              options: validCategories,
              selectedValues: const ["tops"],
            ),
          ),
        ),
      );

      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Tops"), findsOneWidget);
      expect(find.text("Bottoms"), findsOneWidget);
      expect(find.text("Dresses"), findsOneWidget);
    });

    testWidgets("single-select auto-closes on selection", (tester) async {
      List<String>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<List<String>>(
                  context: context,
                  builder: (_) => const TagSelectionSheet(
                    title: "Category",
                    options: ["tops", "bottoms", "dresses"],
                    selectedValues: ["tops"],
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Bottoms"));
      await tester.pumpAndSettle();

      expect(result, ["bottoms"]);
    });

    testWidgets("multi-select requires Done tap", (tester) async {
      List<String>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<List<String>>(
                  context: context,
                  builder: (_) => const TagSelectionSheet(
                    title: "Season",
                    options: ["spring", "summer", "fall", "winter", "all"],
                    selectedValues: ["spring"],
                    isMultiSelect: true,
                  ),
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Select summer
      await tester.tap(find.text("Summer"));
      await tester.pump();

      // Result should not be set yet (sheet still open)
      expect(result, isNull);

      // Tap Done
      await tester.tap(find.text("Done"));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.contains("spring"), isTrue);
      expect(result!.contains("summer"), isTrue);
    });

    testWidgets("search/filter narrows options", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagSelectionSheet(
              title: "Color",
              options: validColors,
              selectedValues: const [],
            ),
          ),
        ),
      );

      // Type "bl" to filter
      await tester.enterText(find.byType(TextField), "bl");
      await tester.pump();

      // Should show Black, Blue, Light Blue (contains "bl")
      expect(find.text("Black"), findsOneWidget);
      expect(find.text("Blue"), findsOneWidget);

      // Should NOT show Red
      expect(find.text("Red"), findsNothing);
    });

    testWidgets("shows check icon for selected values", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagSelectionSheet(
              title: "Category",
              options: validCategories,
              selectedValues: const ["tops"],
            ),
          ),
        ),
      );

      // Find check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets("Done button is visible only in multi-select mode",
        (tester) async {
      // Single select - no Done button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagSelectionSheet(
              title: "Category",
              options: validCategories,
              selectedValues: const ["tops"],
            ),
          ),
        ),
      );

      expect(find.text("Done"), findsNothing);

      // Multi select - Done button visible
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TagSelectionSheet(
              title: "Season",
              options: validSeasons,
              selectedValues: const ["spring"],
              isMultiSelect: true,
            ),
          ),
        ),
      );

      expect(find.text("Done"), findsOneWidget);
    });
  });
}
