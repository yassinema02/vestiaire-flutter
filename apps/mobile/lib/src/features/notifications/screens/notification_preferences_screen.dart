import "package:flutter/material.dart";

/// Describes a notification preference category for display.
class NotificationCategory {
  const NotificationCategory({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Non-social notification categories (boolean toggles).
const kBooleanNotificationCategories = [
  NotificationCategory(
    key: "outfit_reminders",
    title: "Outfit Reminders",
    subtitle: "Morning outfit suggestions",
    icon: Icons.wb_sunny_outlined,
  ),
  NotificationCategory(
    key: "wear_logging",
    title: "Wear Logging",
    subtitle: "Evening reminders to log outfits",
    icon: Icons.edit_note,
  ),
  NotificationCategory(
    key: "analytics",
    title: "Style Insights",
    subtitle: "Wardrobe analytics and tips",
    icon: Icons.insights,
  ),
  NotificationCategory(
    key: "resale_prompts",
    title: "Resale Prompts",
    subtitle: "Monthly suggestions for items to sell or donate",
    icon: Icons.sell,
  ),
];

/// All supported notification categories (backward compat for existing tests).
const kNotificationCategories = [
  NotificationCategory(
    key: "outfit_reminders",
    title: "Outfit Reminders",
    subtitle: "Morning outfit suggestions",
    icon: Icons.wb_sunny_outlined,
  ),
  NotificationCategory(
    key: "wear_logging",
    title: "Wear Logging",
    subtitle: "Evening reminders to log outfits",
    icon: Icons.edit_note,
  ),
  NotificationCategory(
    key: "analytics",
    title: "Style Insights",
    subtitle: "Wardrobe analytics and tips",
    icon: Icons.insights,
  ),
  NotificationCategory(
    key: "resale_prompts",
    title: "Resale Prompts",
    subtitle: "Monthly suggestions for items to sell or donate",
    icon: Icons.sell,
  ),
  NotificationCategory(
    key: "social",
    title: "Social Updates",
    subtitle: "Squad posts and reactions",
    icon: Icons.people_outline,
  ),
];

/// Social notification mode options.
const kSocialModes = [
  {"value": "all", "label": "All posts"},
  {"value": "morning", "label": "Morning digest"},
  {"value": "off", "label": "Off"},
];

/// Screen for managing notification category preferences.
///
/// Loads current preferences from the profile and allows toggling
/// individual categories. Changes are persisted immediately via the API.
/// For the "Outfit Reminders" category, a time picker row is displayed
/// below the toggle to configure the morning notification time.
///
/// Story 9.6: Social Updates uses a three-option selector instead of a toggle.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({
    required this.initialPreferences,
    required this.onPreferenceChanged,
    this.notificationsEnabled = true,
    this.onOpenSettings,
    this.morningTime,
    this.onMorningTimeChanged,
    this.eveningReminderTime,
    this.onEveningTimeChanged,
    this.socialMode = "all",
    this.onSocialModeChanged,
    this.postingReminderEnabled = true,
    this.onPostingReminderEnabledChanged,
    this.postingReminderTime,
    this.onPostingReminderTimeChanged,
    this.eventRemindersEnabled = true,
    this.onEventRemindersEnabledChanged,
    this.eventReminderTime,
    this.onEventReminderTimeChanged,
    this.formalityThreshold = 7,
    this.onFormalityThresholdChanged,
    super.key,
  });

  /// The initial preference values loaded from the profile.
  final Map<String, bool> initialPreferences;

  /// Called when a preference toggle changes. Should persist to the API.
  /// Returns true on success, false on failure (for rollback).
  final Future<bool> Function(String key, bool value) onPreferenceChanged;

  /// Whether OS-level notifications are currently enabled.
  final bool notificationsEnabled;

  /// Called when the user taps to open system notification settings.
  final VoidCallback? onOpenSettings;

  /// The initial morning notification time. Defaults to 08:00.
  final TimeOfDay? morningTime;

  /// Called when the user selects a new morning notification time.
  final ValueChanged<TimeOfDay>? onMorningTimeChanged;

  /// The initial evening reminder time. Defaults to 20:00 (8:00 PM).
  final TimeOfDay? eveningReminderTime;

  /// Called when the user selects a new evening reminder time.
  final ValueChanged<TimeOfDay>? onEveningTimeChanged;

  /// The current social notification mode: "all", "morning", or "off".
  final String socialMode;

  /// Called when the user selects a new social notification mode.
  final ValueChanged<String>? onSocialModeChanged;

  /// Whether the daily posting reminder is enabled.
  final bool postingReminderEnabled;

  /// Called when the user toggles the daily posting reminder.
  final ValueChanged<bool>? onPostingReminderEnabledChanged;

  /// The initial posting reminder time. Defaults to 09:00.
  final TimeOfDay? postingReminderTime;

  /// Called when the user selects a new posting reminder time.
  final ValueChanged<TimeOfDay>? onPostingReminderTimeChanged;

  /// Whether event reminders are enabled.
  final bool eventRemindersEnabled;

  /// Called when the user toggles event reminders.
  final ValueChanged<bool>? onEventRemindersEnabledChanged;

  /// The initial event reminder time. Defaults to 20:00 (8:00 PM).
  final TimeOfDay? eventReminderTime;

  /// Called when the user selects a new event reminder time.
  final ValueChanged<TimeOfDay>? onEventReminderTimeChanged;

  /// The formality threshold for event reminders. Range 6-10, default 7.
  final int formalityThreshold;

  /// Called when the user changes the formality threshold.
  final ValueChanged<int>? onFormalityThresholdChanged;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late Map<String, bool> _preferences;
  late TimeOfDay _morningTime;
  late TimeOfDay _eveningTime;
  late String _socialMode;
  late bool _postingReminderEnabled;
  late TimeOfDay _postingReminderTime;
  late bool _eventRemindersEnabled;
  late TimeOfDay _eventReminderTime;
  late int _formalityThreshold;

  @override
  void initState() {
    super.initState();
    _preferences = Map<String, bool>.from(widget.initialPreferences);
    _morningTime =
        widget.morningTime ?? const TimeOfDay(hour: 8, minute: 0);
    _eveningTime =
        widget.eveningReminderTime ?? const TimeOfDay(hour: 20, minute: 0);
    _socialMode = widget.socialMode;
    _postingReminderEnabled = widget.postingReminderEnabled;
    _postingReminderTime =
        widget.postingReminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    _eventRemindersEnabled = widget.eventRemindersEnabled;
    _eventReminderTime =
        widget.eventReminderTime ?? const TimeOfDay(hour: 20, minute: 0);
    _formalityThreshold = widget.formalityThreshold;
  }

  Future<void> _onToggle(String key, bool value) async {
    // Optimistic update
    final previousValue = _preferences[key] ?? true;
    setState(() {
      _preferences[key] = value;
    });

    final success = await widget.onPreferenceChanged(key, value);
    if (!success && mounted) {
      // Rollback on failure
      setState(() {
        _preferences[key] = previousValue;
      });
    }
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _morningTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _morningTime = picked;
      });
      widget.onMorningTimeChanged?.call(picked);
    }
  }

  Future<void> _pickEveningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eveningTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _eveningTime = picked;
      });
      widget.onEveningTimeChanged?.call(picked);
    }
  }

  Future<void> _pickPostingReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _postingReminderTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _postingReminderTime = picked;
      });
      widget.onPostingReminderTimeChanged?.call(picked);
    }
  }

  Future<void> _pickEventReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventReminderTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _eventReminderTime = picked;
      });
      widget.onEventReminderTimeChanged?.call(picked);
    }
  }

  String _formalityThresholdLabel(int threshold) {
    switch (threshold) {
      case 6:
        return "Semi-formal";
      case 7:
        return "Formal";
      case 8:
        return "Very Formal";
      case 9:
        return "Black Tie";
      case 10:
        return "Ultra Formal";
      default:
        return "Formal";
    }
  }

  void _onSocialModeSelected(String mode) {
    setState(() {
      _socialMode = mode;
    });
    widget.onSocialModeChanged?.call(mode);
    Navigator.of(context).pop();
  }

  void _showSocialModeSelector() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Social Notification Mode",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              ...kSocialModes.map((mode) {
                final value = mode["value"]!;
                final label = mode["label"]!;
                return RadioListTile<String>(
                  title: Text(label),
                  value: value,
                  groupValue: _socialMode,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (v) {
                    if (v != null) _onSocialModeSelected(v);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _socialModeLabel(String mode) {
    switch (mode) {
      case "all":
        return "All posts";
      case "morning":
        return "Morning digest";
      case "off":
        return "Off";
      default:
        return "All posts";
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, "0");
    final period = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Notification Preferences"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!widget.notificationsEnabled)
              Semantics(
                label: "Notifications disabled banner",
                child: GestureDetector(
                  onTap: widget.onOpenSettings,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Notifications are turned off. Tap to open Settings.",
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Column(
                children: [
                  // Boolean toggle categories (outfit_reminders, wear_logging, analytics)
                  ...kBooleanNotificationCategories.map((category) {
                    final isOutfitReminders =
                        category.key == "outfit_reminders";
                    final isWearLogging = category.key == "wear_logging";
                    final outfitEnabled =
                        _preferences["outfit_reminders"] ?? true;
                    final wearLoggingEnabled =
                        _preferences["wear_logging"] ?? true;
                    return Column(
                      children: [
                        Semantics(
                          label: "${category.title} toggle",
                          child: SwitchListTile(
                            title: Text(
                              category.title,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              category.subtitle,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            secondary: Icon(
                              category.icon,
                              color: const Color(0xFF4F46E5),
                            ),
                            value: _preferences[category.key] ?? true,
                            activeThumbColor: const Color(0xFF4F46E5),
                            onChanged: (value) =>
                                _onToggle(category.key, value),
                          ),
                        ),
                        if (isOutfitReminders && outfitEnabled)
                          Semantics(
                            label: "Morning notification time picker",
                            child: GestureDetector(
                              onTap: _pickMorningTime,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 40,
                                  right: 16,
                                  bottom: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Reminder Time",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(_morningTime),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isWearLogging && wearLoggingEnabled)
                          Semantics(
                            label: "Evening reminder time picker",
                            child: GestureDetector(
                              onTap: _pickEveningTime,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 40,
                                  right: 16,
                                  bottom: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Reminder Time",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(_eveningTime),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }),
                  // Social Updates: three-option mode selector
                  Semantics(
                    label: "Social notification mode selector",
                    child: ListTile(
                      leading: const Icon(
                        Icons.people_outline,
                        color: Color(0xFF4F46E5),
                      ),
                      title: const Text(
                        "Social Updates",
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        "Squad posts and reactions",
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        _socialModeLabel(_socialMode),
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 14,
                        ),
                      ),
                      onTap: _showSocialModeSelector,
                    ),
                  ),
                  // Daily Posting Reminder (visible when social mode != "off")
                  if (_socialMode != "off") ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Semantics(
                      label: "Daily posting reminder toggle",
                      child: SwitchListTile(
                        title: const Text(
                          "Daily Posting Reminder",
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          "Get reminded to share your OOTD each morning",
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        value: _postingReminderEnabled,
                        activeThumbColor: const Color(0xFF4F46E5),
                        onChanged: (value) {
                          setState(() {
                            _postingReminderEnabled = value;
                          });
                          widget.onPostingReminderEnabledChanged?.call(value);
                        },
                      ),
                    ),
                    if (_postingReminderEnabled)
                      Semantics(
                        label: "Posting reminder time picker",
                        child: GestureDetector(
                          onTap: _pickPostingReminderTime,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 40,
                              right: 16,
                              bottom: 12,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Reminder Time",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  _formatTime(_postingReminderTime),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  // Event Reminders section (Story 12.3)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Semantics(
                    label: "Event reminders toggle",
                    child: SwitchListTile(
                      title: const Text(
                        "Event Reminders",
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        "Get reminded the evening before formal events",
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.event_available,
                        color: Color(0xFF4F46E5),
                      ),
                      value: _eventRemindersEnabled,
                      activeThumbColor: const Color(0xFF4F46E5),
                      onChanged: (value) {
                        setState(() {
                          _eventRemindersEnabled = value;
                        });
                        widget.onEventRemindersEnabledChanged?.call(value);
                      },
                    ),
                  ),
                  if (_eventRemindersEnabled) ...[
                    Semantics(
                      label: "Event reminder time picker",
                      child: GestureDetector(
                        onTap: _pickEventReminderTime,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 40,
                            right: 16,
                            bottom: 12,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Event Reminder Time",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                _formatTime(_eventReminderTime),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      label: "Formality threshold selector",
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 40,
                          right: 16,
                          bottom: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Minimum formality",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  _formalityThresholdLabel(
                                      _formalityThreshold),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              min: 6,
                              max: 10,
                              divisions: 4,
                              value: _formalityThreshold.toDouble(),
                              activeColor: const Color(0xFF4F46E5),
                              label: _formalityThresholdLabel(
                                  _formalityThreshold),
                              onChanged: (value) {
                                final intValue = value.round();
                                setState(() {
                                  _formalityThreshold = intValue;
                                });
                                widget.onFormalityThresholdChanged
                                    ?.call(intValue);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
