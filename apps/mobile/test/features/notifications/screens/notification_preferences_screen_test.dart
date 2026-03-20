import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:vestiaire_mobile/src/features/notifications/screens/notification_preferences_screen.dart";

void main() {
  group("NotificationPreferencesScreen", () {
    late List<MapEntry<String, bool>> capturedChanges;

    setUp(() {
      capturedChanges = [];
    });

    Widget buildSubject({
      Map<String, bool>? preferences,
      bool notificationsEnabled = true,
      bool apiSuccess = true,
      VoidCallback? onOpenSettings,
      TimeOfDay? morningTime,
      ValueChanged<TimeOfDay>? onMorningTimeChanged,
      TimeOfDay? eveningReminderTime,
      ValueChanged<TimeOfDay>? onEveningTimeChanged,
      String socialMode = "all",
      ValueChanged<String>? onSocialModeChanged,
      bool postingReminderEnabled = true,
      ValueChanged<bool>? onPostingReminderEnabledChanged,
      TimeOfDay? postingReminderTime,
      ValueChanged<TimeOfDay>? onPostingReminderTimeChanged,
      bool eventRemindersEnabled = true,
      ValueChanged<bool>? onEventRemindersEnabledChanged,
      TimeOfDay? eventReminderTime,
      ValueChanged<TimeOfDay>? onEventReminderTimeChanged,
      int formalityThreshold = 7,
      ValueChanged<int>? onFormalityThresholdChanged,
    }) {
      return MaterialApp(
        home: NotificationPreferencesScreen(
          initialPreferences: preferences ??
              {
                "outfit_reminders": true,
                "wear_logging": true,
                "analytics": true,
              },
          notificationsEnabled: notificationsEnabled,
          onPreferenceChanged: (key, value) async {
            capturedChanges.add(MapEntry(key, value));
            return apiSuccess;
          },
          onOpenSettings: onOpenSettings,
          morningTime: morningTime,
          onMorningTimeChanged: onMorningTimeChanged,
          eveningReminderTime: eveningReminderTime,
          onEveningTimeChanged: onEveningTimeChanged,
          socialMode: socialMode,
          onSocialModeChanged: onSocialModeChanged,
          postingReminderEnabled: postingReminderEnabled,
          onPostingReminderEnabledChanged: onPostingReminderEnabledChanged,
          postingReminderTime: postingReminderTime,
          onPostingReminderTimeChanged: onPostingReminderTimeChanged,
          eventRemindersEnabled: eventRemindersEnabled,
          onEventRemindersEnabledChanged: onEventRemindersEnabledChanged,
          eventReminderTime: eventReminderTime,
          onEventReminderTimeChanged: onEventReminderTimeChanged,
          formalityThreshold: formalityThreshold,
          onFormalityThresholdChanged: onFormalityThresholdChanged,
        ),
      );
    }

    testWidgets("renders title", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Notification Preferences"), findsOneWidget);
    });

    testWidgets("renders all four category labels",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Outfit Reminders"), findsOneWidget);
      expect(find.text("Wear Logging"), findsOneWidget);
      expect(find.text("Style Insights"), findsOneWidget);
      expect(find.text("Social Updates"), findsOneWidget);
    });

    testWidgets("renders subtitles for each category", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Morning outfit suggestions"), findsOneWidget);
      expect(find.text("Evening reminders to log outfits"), findsOneWidget);
      expect(find.text("Wardrobe analytics and tips"), findsOneWidget);
      expect(find.text("Squad posts and reactions"), findsOneWidget);
    });

    testWidgets("toggles reflect initial state", (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {
          "outfit_reminders": true,
          "wear_logging": false,
          "analytics": true,
        },
      ));

      // 3 boolean toggles + 1 posting reminder toggle = 4 Switches
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, greaterThanOrEqualTo(3));
      expect(switches[0].value, isTrue); // outfit_reminders
      expect(switches[1].value, isFalse); // wear_logging
      expect(switches[2].value, isTrue); // analytics
    });

    testWidgets("toggling a switch triggers API call", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Find the first SwitchListTile and toggle it
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      expect(capturedChanges.length, 1);
      expect(capturedChanges.first.key, "outfit_reminders");
      expect(capturedChanges.first.value, isFalse);
    });

    testWidgets("OS-denied banner renders when notifications disabled",
        (tester) async {
      await tester.pumpWidget(buildSubject(notificationsEnabled: false));

      expect(
        find.text("Notifications are turned off. Tap to open Settings."),
        findsOneWidget,
      );
    });

    testWidgets("OS-denied banner does not render when notifications enabled",
        (tester) async {
      await tester.pumpWidget(buildSubject(notificationsEnabled: true));

      expect(
        find.text("Notifications are turned off. Tap to open Settings."),
        findsNothing,
      );
    });

    testWidgets("OS-denied banner tap calls onOpenSettings", (tester) async {
      bool settingsOpened = false;
      await tester.pumpWidget(buildSubject(
        notificationsEnabled: false,
        onOpenSettings: () => settingsOpened = true,
      ));

      await tester.tap(find.text(
          "Notifications are turned off. Tap to open Settings."));
      await tester.pumpAndSettle();

      expect(settingsOpened, isTrue);
    });

    testWidgets("Semantics widgets wrap all toggles", (tester) async {
      await tester.pumpWidget(buildSubject());

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .where((s) => s.properties.label?.contains("toggle") == true)
          .map((s) => s.properties.label)
          .toList();
      expect(labels, contains("Outfit Reminders toggle"));
      expect(labels, contains("Wear Logging toggle"));
      expect(labels, contains("Style Insights toggle"));
    });

    testWidgets("Semantics widget wraps disabled banner", (tester) async {
      await tester.pumpWidget(buildSubject(notificationsEnabled: false));

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .where((s) => s.properties.label?.contains("banner") == true)
          .map((s) => s.properties.label)
          .toList();
      expect(labels, contains("Notifications disabled banner"));
    });

    // --- Morning time picker tests (Story 4.7) ---

    testWidgets(
        "time picker row renders below Outfit Reminders toggle when toggle is on",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": true, "wear_logging": true, "analytics": true},
      ));

      // Both morning and evening time picker rows show "Reminder Time"
      // Plus posting reminder time = 3 if posting reminder enabled
      expect(find.text("Reminder Time"), findsNWidgets(3));
    });

    testWidgets("time picker row is hidden when Outfit Reminders toggle is off",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": false, "wear_logging": true, "analytics": true},
      ));

      // Morning time picker hidden, but evening + posting reminder still visible
      expect(find.text("Reminder Time"), findsNWidgets(2));
    });

    testWidgets("default time displays as 8:00 AM", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("8:00 AM"), findsOneWidget);
    });

    testWidgets("custom morning time is displayed", (tester) async {
      await tester.pumpWidget(buildSubject(
        morningTime: const TimeOfDay(hour: 7, minute: 30),
      ));

      expect(find.text("7:30 AM"), findsOneWidget);
    });

    testWidgets("tapping the time value opens the time picker dialog",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("8:00 AM"));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets("selecting a new time calls onMorningTimeChanged callback",
        (tester) async {
      TimeOfDay? capturedTime;
      await tester.pumpWidget(buildSubject(
        onMorningTimeChanged: (time) => capturedTime = time,
      ));

      await tester.tap(find.text("8:00 AM"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("OK"));
      await tester.pumpAndSettle();

      expect(capturedTime, isNotNull);
    });

    testWidgets(
        "Semantics label 'Morning notification time picker' is present",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .map((s) => s.properties.label)
          .where((l) => l != null)
          .toList();
      expect(labels, contains("Morning notification time picker"));
    });

    testWidgets(
        "time picker row disappears when outfit_reminders is toggled off",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": true, "wear_logging": true, "analytics": true},
      ));

      // Morning + evening + posting = 3
      expect(find.text("Reminder Time"), findsNWidgets(3));

      // Toggle outfit_reminders off
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Morning hidden: evening + posting = 2
      expect(find.text("Reminder Time"), findsNWidgets(2));
    });

    // --- Evening time picker tests (Story 5.2) ---

    testWidgets(
        "evening time picker row renders below Wear Logging toggle when toggle is on",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": true, "wear_logging": true, "analytics": true},
      ));

      expect(find.text("Reminder Time"), findsNWidgets(3));
      // Evening default + event reminder default = 2 instances of "8:00 PM"
      expect(find.text("8:00 PM"), findsNWidgets(2));
    });

    testWidgets(
        "evening time picker row is hidden when Wear Logging toggle is off",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": true, "wear_logging": false, "analytics": true},
      ));

      // Morning + posting = 2
      expect(find.text("Reminder Time"), findsNWidgets(2));
      // Event reminder still shows 8:00 PM
      expect(find.text("8:00 PM"), findsOneWidget);
    });

    testWidgets("tapping the evening time value opens the time picker dialog",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Tap the first "8:00 PM" (evening reminder, not event reminder)
      await tester.tap(find.text("8:00 PM").first);
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets(
        "selecting a new evening time calls onEveningTimeChanged callback",
        (tester) async {
      TimeOfDay? capturedTime;
      await tester.pumpWidget(buildSubject(
        onEveningTimeChanged: (time) => capturedTime = time,
      ));

      // Tap the first "8:00 PM" (evening reminder, not event reminder)
      await tester.tap(find.text("8:00 PM").first);
      await tester.pumpAndSettle();

      await tester.tap(find.text("OK"));
      await tester.pumpAndSettle();

      expect(capturedTime, isNotNull);
    });

    testWidgets("default evening time displays as 8:00 PM", (tester) async {
      await tester.pumpWidget(buildSubject());

      // Evening + event reminder both default to 8:00 PM
      expect(find.text("8:00 PM"), findsNWidgets(2));
    });

    testWidgets(
        "Semantics label 'Evening reminder time picker' is present",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .map((s) => s.properties.label)
          .where((l) => l != null)
          .toList();
      expect(labels, contains("Evening reminder time picker"));
    });

    testWidgets("all existing tests including morning time picker tests continue to pass",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {"outfit_reminders": true, "wear_logging": true, "analytics": true},
        morningTime: const TimeOfDay(hour: 7, minute: 0),
        eveningReminderTime: const TimeOfDay(hour: 21, minute: 30),
      ));

      expect(find.text("7:00 AM"), findsOneWidget);
      expect(find.text("9:30 PM"), findsOneWidget);
      expect(find.text("Reminder Time"), findsNWidgets(3));
    });

    // --- Story 9.6: Social mode selector tests ---

    testWidgets("social mode selector renders with current mode label",
        (tester) async {
      await tester.pumpWidget(buildSubject(socialMode: "all"));

      expect(find.text("All posts"), findsOneWidget);
    });

    testWidgets("social mode selector shows 'Morning digest' for morning mode",
        (tester) async {
      await tester.pumpWidget(buildSubject(socialMode: "morning"));

      expect(find.text("Morning digest"), findsOneWidget);
    });

    testWidgets("social mode selector shows 'Off' for off mode",
        (tester) async {
      await tester.pumpWidget(buildSubject(socialMode: "off"));

      expect(find.text("Off"), findsOneWidget);
    });

    testWidgets("tapping social mode opens bottom sheet with three options",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text("Social Updates"));
      await tester.pumpAndSettle();

      // Bottom sheet should show all three radio options
      // "All posts" appears twice: trailing text on ListTile + radio in bottom sheet
      expect(find.text("All posts"), findsNWidgets(2));
      expect(find.text("Morning digest"), findsOneWidget);
      expect(find.text("Off"), findsOneWidget);
      expect(find.text("Social Notification Mode"), findsOneWidget);
    });

    testWidgets("selecting 'Morning digest' calls onSocialModeChanged with 'morning'",
        (tester) async {
      String? capturedMode;
      await tester.pumpWidget(buildSubject(
        onSocialModeChanged: (mode) => capturedMode = mode,
      ));

      await tester.tap(find.text("Social Updates"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Morning digest"));
      await tester.pumpAndSettle();

      expect(capturedMode, "morning");
    });

    testWidgets("selecting 'Off' calls onSocialModeChanged with 'off'",
        (tester) async {
      String? capturedMode;
      await tester.pumpWidget(buildSubject(
        onSocialModeChanged: (mode) => capturedMode = mode,
      ));

      await tester.tap(find.text("Social Updates"));
      await tester.pumpAndSettle();

      // Find the "Off" text in the bottom sheet
      await tester.tap(find.text("Off").last);
      await tester.pumpAndSettle();

      expect(capturedMode, "off");
    });

    testWidgets("daily posting reminder toggle visible when social mode is not 'off'",
        (tester) async {
      await tester.pumpWidget(buildSubject(socialMode: "all"));

      expect(find.text("Daily Posting Reminder"), findsOneWidget);
    });

    testWidgets("daily posting reminder toggle hidden when social mode is 'off'",
        (tester) async {
      await tester.pumpWidget(buildSubject(socialMode: "off"));

      expect(find.text("Daily Posting Reminder"), findsNothing);
    });

    testWidgets("posting reminder time picker visible when toggle is on",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        postingReminderEnabled: true,
      ));

      expect(find.text("9:00 AM"), findsOneWidget);
    });

    testWidgets("posting reminder time picker hidden when toggle is off",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        postingReminderEnabled: false,
      ));

      // 9:00 AM should not appear (posting reminder time)
      expect(find.text("9:00 AM"), findsNothing);
    });

    testWidgets("tapping posting time picker opens time picker dialog",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        postingReminderEnabled: true,
      ));

      await tester.tap(find.text("9:00 AM"));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
    });

    testWidgets("Semantics labels present on all new elements", (tester) async {
      await tester.pumpWidget(buildSubject());

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final labels = semanticsWidgets
          .map((s) => s.properties.label)
          .where((l) => l != null)
          .toList();
      expect(labels, contains("Social notification mode selector"));
      expect(labels, contains("Daily posting reminder toggle"));
      expect(labels, contains("Posting reminder time picker"));
    });

    testWidgets("posting reminder toggle calls onPostingReminderEnabledChanged",
        (tester) async {
      bool? capturedValue;
      await tester.pumpWidget(buildSubject(
        postingReminderEnabled: true,
        onPostingReminderEnabledChanged: (v) => capturedValue = v,
      ));

      // Find the posting reminder toggle
      final switches = find.byType(Switch);
      // The posting reminder switch is after the 4 boolean toggles (outfit_reminders, wear_logging, analytics, resale_prompts)
      await tester.tap(switches.at(4));
      await tester.pumpAndSettle();

      expect(capturedValue, isFalse);
    });

    // --- Story 12.3: Event Reminders Section Tests ---

    testWidgets("Event reminders toggle renders with 'Event Reminders' title",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Event Reminders"), findsOneWidget);
      expect(
        find.text("Get reminded the evening before formal events"),
        findsOneWidget,
      );
    });

    testWidgets(
        "Event reminders sub-options (time picker, threshold) visible when toggle is on",
        (tester) async {
      await tester.pumpWidget(
          buildSubject(eventRemindersEnabled: true));
      await tester.pumpAndSettle();

      // Should see "Reminder Time" for event reminder (plus existing ones)
      // and "Minimum formality" label
      expect(find.text("Minimum formality"), findsOneWidget);
      expect(find.text("Formal"), findsOneWidget); // Default threshold 7 label
    });

    testWidgets(
        "Event reminders sub-options hidden when toggle is off",
        (tester) async {
      await tester.pumpWidget(
          buildSubject(eventRemindersEnabled: false));
      await tester.pumpAndSettle();

      expect(find.text("Minimum formality"), findsNothing);
    });

    testWidgets("Default event reminder time displays as '8:00 PM'",
        (tester) async {
      await tester.pumpWidget(buildSubject(eventRemindersEnabled: true));
      await tester.pumpAndSettle();

      expect(find.text("8:00 PM"), findsWidgets);
    });

    testWidgets("Default formality threshold is 7", (tester) async {
      await tester.pumpWidget(
          buildSubject(eventRemindersEnabled: true, formalityThreshold: 7));
      await tester.pumpAndSettle();

      expect(find.text("Formal"), findsOneWidget);
    });

    testWidgets(
        "Formality threshold selector renders with current value",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        eventRemindersEnabled: true,
        formalityThreshold: 9,
      ));
      await tester.pumpAndSettle();

      // Should display the label for threshold 9
      expect(find.text("Black Tie"), findsOneWidget);
    });

    testWidgets(
        "Changing formality threshold calls onFormalityThresholdChanged",
        (tester) async {
      int? capturedThreshold;
      await tester.pumpWidget(buildSubject(
        eventRemindersEnabled: true,
        formalityThreshold: 6,
        onFormalityThresholdChanged: (value) {
          capturedThreshold = value;
        },
      ));
      await tester.pumpAndSettle();

      // Find the Slider widget and drag it to the right
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Drag slider from its center to the far right to change value
      // Need to scroll first as slider might not be visible
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();

      // Tap on a position to the right of center to change value
      final sliderTopLeft = tester.getTopLeft(slider);
      final sliderSize = tester.getSize(slider);
      // Tap at 90% of the slider width (near max value)
      await tester.tapAt(Offset(
        sliderTopLeft.dx + sliderSize.width * 0.9,
        sliderTopLeft.dy + sliderSize.height / 2,
      ));
      await tester.pumpAndSettle();

      expect(capturedThreshold, isNotNull);
    });

    testWidgets(
        "Semantics labels present on all event reminder elements",
        (tester) async {
      await tester.pumpWidget(
          buildSubject(eventRemindersEnabled: true));
      await tester.pumpAndSettle();

      // Verify Semantics widgets exist with the expected labels
      final allSemantics = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );

      final labels = allSemantics
          .map((s) => s.properties.label)
          .where((l) => l != null)
          .toSet();

      expect(labels.contains("Event reminders toggle"), isTrue);
      expect(labels.contains("Event reminder time picker"), isTrue);
      expect(labels.contains("Formality threshold selector"), isTrue);
    });

    testWidgets("Toggling event reminders off calls callback", (tester) async {
      bool? capturedValue;
      await tester.pumpWidget(buildSubject(
        eventRemindersEnabled: true,
        onEventRemindersEnabledChanged: (value) {
          capturedValue = value;
        },
      ));
      await tester.pumpAndSettle();

      // Scroll to make event reminders visible (may be off-screen due to 4 boolean toggles + posting reminder)
      await tester.scrollUntilVisible(find.text("Event Reminders"), 100);
      await tester.pumpAndSettle();

      // Find all switches -- event reminders is after 4 boolean toggles + posting reminder
      final switches = find.byType(Switch);
      await tester.tap(switches.at(5));
      await tester.pumpAndSettle();

      expect(capturedValue, isFalse);
    });

    testWidgets("All existing tests (morning, evening, posting, social) continue to pass",
        (tester) async {
      // This test verifies the screen still renders correctly with all sections
      await tester.pumpWidget(buildSubject(
        morningTime: const TimeOfDay(hour: 7, minute: 30),
        eveningReminderTime: const TimeOfDay(hour: 21, minute: 0),
        socialMode: "all",
        postingReminderEnabled: true,
        eventRemindersEnabled: true,
      ));

      expect(find.text("Outfit Reminders"), findsOneWidget);
      expect(find.text("Wear Logging"), findsOneWidget);
      expect(find.text("Style Insights"), findsOneWidget);
      expect(find.text("Resale Prompts"), findsOneWidget);
      expect(find.text("Social Updates"), findsOneWidget);
      expect(find.text("Daily Posting Reminder"), findsOneWidget);
      expect(find.text("Event Reminders"), findsOneWidget);
    });
  });

  // ─── Story 13.2: Resale Prompts Toggle Tests ───

  group("Resale Prompts Toggle (Story 13.2)", () {
    late List<MapEntry<String, bool>> capturedChanges;

    setUp(() {
      capturedChanges = [];
    });

    Widget buildSubject({
      Map<String, bool>? preferences,
      bool apiSuccess = true,
    }) {
      return MaterialApp(
        home: NotificationPreferencesScreen(
          initialPreferences: preferences ??
              {
                "outfit_reminders": true,
                "wear_logging": true,
                "analytics": true,
                "resale_prompts": true,
              },
          onPreferenceChanged: (key, value) async {
            capturedChanges.add(MapEntry(key, value));
            return apiSuccess;
          },
        ),
      );
    }

    testWidgets("Resale Prompts toggle is visible", (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text("Resale Prompts"), findsOneWidget);
      expect(find.text("Monthly suggestions for items to sell or donate"),
          findsOneWidget);
    });

    testWidgets("Toggling off updates notification_preferences",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Find and tap the Resale Prompts switch
      final switches = find.byType(Switch);
      // Resale Prompts is the 4th boolean toggle
      // outfit_reminders, wear_logging, analytics, resale_prompts
      await tester.tap(switches.at(3));
      await tester.pumpAndSettle();

      expect(capturedChanges.length, 1);
      expect(capturedChanges[0].key, "resale_prompts");
      expect(capturedChanges[0].value, false);
    });

    testWidgets("Toggling on updates notification_preferences",
        (tester) async {
      await tester.pumpWidget(buildSubject(
        preferences: {
          "outfit_reminders": true,
          "wear_logging": true,
          "analytics": true,
          "resale_prompts": false,
        },
      ));

      final switches = find.byType(Switch);
      await tester.tap(switches.at(3));
      await tester.pumpAndSettle();

      expect(capturedChanges.length, 1);
      expect(capturedChanges[0].key, "resale_prompts");
      expect(capturedChanges[0].value, true);
    });

    testWidgets("Semantics label present for resale prompts toggle",
        (tester) async {
      await tester.pumpWidget(buildSubject());

      // Verify the Semantics widget with the correct label wraps the toggle
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "Resale Prompts toggle",
        ),
        findsOneWidget,
      );
    });
  });
}
