import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/wardrobe/widgets/filter_bar.dart";

void main() {
  group("FilterBar", () {
    testWidgets("renders all 6 filter chips including Neglect", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      expect(find.widgetWithText(FilterChip, "Category"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Color"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Season"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Occasion"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Brand"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Neglect"), findsOneWidget);
    });

    testWidgets("tapping a chip opens bottom sheet with valid options",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap Category chip
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();

      // Bottom sheet should show "All" plus taxonomy values
      expect(find.text("All"), findsOneWidget);
      expect(find.text("Tops"), findsOneWidget);
      expect(find.text("Bottoms"), findsOneWidget);
      expect(find.text("Dresses"), findsOneWidget);
      expect(find.text("Outerwear"), findsOneWidget);
    });

    testWidgets("selecting an option calls onFiltersChanged", (tester) async {
      Map<String, String?>? capturedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (filters) {
                capturedFilters = filters;
              },
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap Category chip to open bottom sheet
      await tester.tap(find.widgetWithText(FilterChip, "Category"));
      await tester.pumpAndSettle();

      // Select "Tops"
      await tester.tap(find.text("Tops"));
      await tester.pumpAndSettle();

      expect(capturedFilters, isNotNull);
      expect(capturedFilters!["category"], equals("tops"));
    });

    testWidgets("active filter chip shows selected value and is highlighted",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {"category": "tops"},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Should show "Tops" instead of "Category" on the chip
      expect(find.widgetWithText(FilterChip, "Tops"), findsOneWidget);
      expect(find.widgetWithText(FilterChip, "Category"), findsNothing);

      // The FilterChip should be selected
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "Tops"),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets("tapping All in bottom sheet clears that filter",
        (tester) async {
      Map<String, String?>? capturedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {"category": "tops"},
              onFiltersChanged: (filters) {
                capturedFilters = filters;
              },
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap the active chip (showing "Tops")
      await tester.tap(find.widgetWithText(FilterChip, "Tops"));
      await tester.pumpAndSettle();

      // Tap "All" to clear the filter
      await tester.tap(find.text("All"));
      await tester.pumpAndSettle();

      expect(capturedFilters, isNotNull);
      expect(capturedFilters!.containsKey("category"), isFalse);
    });

    testWidgets("Clear All button appears when filters are active",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {"category": "tops"},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });

    testWidgets("Clear All button is hidden when no filters are active",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.clear_all), findsNothing);
    });

    testWidgets("Clear All button clears all filters", (tester) async {
      Map<String, String?>? capturedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {"category": "tops", "color": "black"},
              onFiltersChanged: (filters) {
                capturedFilters = filters;
              },
              availableBrands: const [],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pumpAndSettle();

      expect(capturedFilters, isNotNull);
      expect(capturedFilters!.isEmpty, isTrue);
    });

    testWidgets("Semantics labels are present on all chips", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Check that Semantics widgets exist for each filter dimension
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Category filter"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Color filter"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Season filter"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Occasion filter"),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Brand filter"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("brand filter shows available brands from items",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const ["Gucci", "Nike", "Zara"],
            ),
          ),
        ),
      );

      // Tap Brand chip
      await tester.tap(find.widgetWithText(FilterChip, "Brand"));
      await tester.pumpAndSettle();

      expect(find.text("All"), findsOneWidget);
      expect(find.text("Gucci"), findsOneWidget);
      expect(find.text("Nike"), findsOneWidget);
      expect(find.text("Zara"), findsOneWidget);
    });

    // === Story 2.7: Neglect filter tests ===

    testWidgets("tapping Neglect chip opens bottom sheet with All and Neglected options",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap Neglect chip
      await tester.tap(find.widgetWithText(FilterChip, "Neglect"));
      await tester.pumpAndSettle();

      // Bottom sheet should show "All" and "Neglected"
      expect(find.text("All"), findsOneWidget);
      expect(find.text("Neglected"), findsOneWidget);
    });

    testWidgets("selecting Neglected calls onFiltersChanged with neglect: neglected",
        (tester) async {
      Map<String, String?>? capturedFilters;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (filters) {
                capturedFilters = filters;
              },
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap Neglect chip to open bottom sheet
      await tester.tap(find.widgetWithText(FilterChip, "Neglect"));
      await tester.pumpAndSettle();

      // Select "Neglected"
      await tester.tap(find.text("Neglected"));
      await tester.pumpAndSettle();

      expect(capturedFilters, isNotNull);
      expect(capturedFilters!["neglect"], equals("neglected"));
    });

    testWidgets("Neglect filter Semantics label is present",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              w.properties.label!.contains("Neglect filter"),
        ),
        findsOneWidget,
      );
    });

    testWidgets("color filter shows color options from taxonomy",
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              activeFilters: const {},
              onFiltersChanged: (_) {},
              availableBrands: const [],
            ),
          ),
        ),
      );

      // Tap Color chip
      await tester.tap(find.widgetWithText(FilterChip, "Color"));
      await tester.pumpAndSettle();

      expect(find.text("All"), findsOneWidget);
      expect(find.text("Black"), findsOneWidget);
      expect(find.text("White"), findsOneWidget);
    });
  });
}
