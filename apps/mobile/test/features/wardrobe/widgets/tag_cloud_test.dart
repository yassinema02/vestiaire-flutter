import "package:firebase_core/firebase_core.dart";
import "package:firebase_core_platform_interface/test.dart" as firebase_test;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/wardrobe/models/taxonomy.dart";
import "package:vestiaire_mobile/src/features/wardrobe/widgets/tag_cloud.dart";

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    firebase_test.setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group("TagCloud", () {
    testWidgets("renders all tag groups with labels", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const ["tops"],
                    options: validCategories,
                    onChanged: (_) {},
                  ),
                  TagGroup(
                    label: "Color",
                    value: const ["blue"],
                    options: validColors,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text("Category"), findsOneWidget);
      expect(find.text("Color"), findsOneWidget);
      expect(find.text("Tops"), findsOneWidget);
      expect(find.text("Blue"), findsOneWidget);
    });

    testWidgets("tapping a chip opens bottom sheet", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const ["tops"],
                    options: validCategories,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      // The bottom sheet should show the title "Category"
      // and all category options
      expect(find.text("Bottoms"), findsOneWidget);
      expect(find.text("Dresses"), findsOneWidget);
    });

    testWidgets("single-select updates value and closes sheet", (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const ["tops"],
                    options: validCategories,
                    onChanged: (v) => selectedValue = v.first,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Dresses"));
      await tester.pumpAndSettle();

      expect(selectedValue, "dresses");
    });

    testWidgets("multi-select allows multiple selections", (tester) async {
      List<String>? selectedValues;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Season",
                    value: const ["spring"],
                    options: validSeasons,
                    isMultiSelect: true,
                    onChanged: (v) => selectedValues = v,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Spring"));
      await tester.pumpAndSettle();

      // In multi-select mode, tap summer
      await tester.tap(find.text("Summer"));
      await tester.pump();

      // Tap Done
      await tester.tap(find.text("Done"));
      await tester.pumpAndSettle();

      expect(selectedValues, isNotNull);
      expect(selectedValues!.contains("spring"), isTrue);
      expect(selectedValues!.contains("summer"), isTrue);
    });

    testWidgets("loading state shows shimmer placeholders", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                isLoading: true,
                groups: const [],
              ),
            ),
          ),
        ),
      );

      // Shimmer placeholders are rendered as Containers with gray background
      final containers = find.byType(Container);
      expect(containers, findsWidgets);

      // Should not find any chip labels
      expect(find.text("Category"), findsNothing);
    });

    testWidgets("chips meet 44px minimum touch target", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const ["tops"],
                    options: validCategories,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Find the SizedBox wrapping the ActionChip
      final sizedBoxes = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 44,
      );
      expect(sizedBoxes, findsWidgets);
    });

    testWidgets("empty value shows 'Not set' placeholder", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const [],
                    options: validCategories,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text("Not set"), findsOneWidget);
    });

    testWidgets("Semantics labels are present on chips", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TagCloud(
                groups: [
                  TagGroup(
                    label: "Category",
                    value: const ["tops"],
                    options: validCategories,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == "Category: Tops",
        ),
        findsOneWidget,
      );
    });
  });
}
