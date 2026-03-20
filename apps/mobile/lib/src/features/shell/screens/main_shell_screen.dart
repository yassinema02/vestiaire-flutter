import "package:flutter/material.dart";
import "package:firebase_messaging/firebase_messaging.dart";

import "../../../config/app_config.dart";
import "../../../core/location/location_service.dart";
import "../../../core/networking/api_client.dart";
import "../../../core/notifications/evening_reminder_preferences.dart";
import "../../../core/notifications/evening_reminder_service.dart";
import "../../../core/notifications/morning_notification_preferences.dart";
import "../../../core/notifications/morning_notification_service.dart";
import "../../../core/notifications/notification_service.dart";
import "../../../core/notifications/posting_reminder_preferences.dart";
import "../../../core/notifications/posting_reminder_service.dart";
import "../../../core/notifications/event_reminder_preferences.dart";
import "../../../core/notifications/event_reminder_service.dart";
import "../../../core/subscription/subscription_service.dart";
import "../../../core/weather/weather_service.dart";
import "../../home/screens/home_screen.dart";
import "../../outfits/services/trip_detection_service.dart";
import "../../outfits/services/packing_list_service.dart";
import "../../notifications/screens/notification_preferences_screen.dart";
import "../../outfits/screens/outfit_history_screen.dart";
import "../../outfits/services/outfit_persistence_service.dart";
import "../../profile/screens/profile_screen.dart";
import "../../squads/screens/squad_list_screen.dart";
import "../../squads/services/squad_service.dart";
import "../../wardrobe/screens/add_item_screen.dart";
import "../../wardrobe/screens/wardrobe_screen.dart";

/// The main navigation shell with 5 tabs: Home, Wardrobe, Social, Outfits, Profile.
///
/// Story 9.1 replaced the "Add" tab with a "Social" tab and added a FAB
/// for quick item/outfit creation per architecture.md guidance.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    required this.config,
    this.onSignOut,
    this.onDeleteAccount,
    this.apiClient,
    this.notificationService,
    this.locationService,
    this.weatherService,
    this.subscriptionService,
    this.morningNotificationService,
    this.morningNotificationPreferences,
    this.eveningReminderService,
    this.eveningReminderPreferences,
    this.postingReminderService,
    this.postingReminderPreferences,
    this.eventReminderService,
    this.eventReminderPreferences,
    super.key,
  });

  final AppConfig config;
  final VoidCallback? onSignOut;
  final Future<void> Function()? onDeleteAccount;
  final ApiClient? apiClient;
  final NotificationService? notificationService;
  final LocationService? locationService;
  final WeatherService? weatherService;
  final SubscriptionService? subscriptionService;
  final MorningNotificationService? morningNotificationService;
  final MorningNotificationPreferences? morningNotificationPreferences;
  final EveningReminderService? eveningReminderService;
  final EveningReminderPreferences? eveningReminderPreferences;
  final PostingReminderService? postingReminderService;
  final PostingReminderPreferences? postingReminderPreferences;
  final EventReminderService? eventReminderService;
  final EventReminderPreferences? eventReminderPreferences;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  final GlobalKey<WardrobeScreenState> _wardrobeKey =
      GlobalKey<WardrobeScreenState>();

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onFabPressed() {
    if (widget.apiClient == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddItemScreen(
          apiClient: widget.apiClient!,
          onItemAdded: _onItemAdded,
        ),
      ),
    );
  }

  void _onItemAdded() {
    setState(() {
      _selectedIndex = 1; // Switch to Wardrobe tab
    });
    _wardrobeKey.currentState?.refresh();
  }

  Future<void> _openNotificationPreferences(BuildContext context) async {
    Map<String, bool> preferences = {
      "outfit_reminders": true,
      "wear_logging": true,
      "analytics": true,
    };
    bool notificationsEnabled = true;
    TimeOfDay morningTime = const TimeOfDay(hour: 8, minute: 0);
    String socialMode = "all";

    try {
      if (widget.apiClient != null) {
        final result = await widget.apiClient!.getOrCreateProfile();
        final profile = result["profile"] as Map<String, dynamic>?;
        final prefs = profile?["notificationPreferences"];
        if (prefs is Map) {
          preferences = {
            "outfit_reminders": prefs["outfit_reminders"] as bool? ?? true,
            "wear_logging": prefs["wear_logging"] as bool? ?? true,
            "analytics": prefs["analytics"] as bool? ?? true,
          };
          // Read social mode (handle legacy boolean)
          final socialValue = prefs["social"];
          if (socialValue is String) {
            socialMode = socialValue;
          } else if (socialValue is bool) {
            socialMode = socialValue ? "all" : "off";
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading notification preferences: $e");
    }

    if (widget.notificationService != null) {
      try {
        final status =
            await widget.notificationService!.getPermissionStatus();
        notificationsEnabled =
            status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
      } catch (_) {}
    }

    // Load locally stored morning notification time.
    if (widget.morningNotificationPreferences != null) {
      try {
        morningTime =
            await widget.morningNotificationPreferences!.getMorningTime();
      } catch (_) {}
    }

    // Load locally stored evening reminder time.
    TimeOfDay eveningTime = const TimeOfDay(hour: 20, minute: 0);
    if (widget.eveningReminderPreferences != null) {
      try {
        eveningTime =
            await widget.eveningReminderPreferences!.getEveningTime();
      } catch (_) {}
    }

    // Load locally stored posting reminder preferences.
    bool postingReminderEnabled = true;
    TimeOfDay postingReminderTime = const TimeOfDay(hour: 9, minute: 0);
    if (widget.postingReminderPreferences != null) {
      try {
        postingReminderEnabled =
            await widget.postingReminderPreferences!.isPostingReminderEnabled();
        postingReminderTime =
            await widget.postingReminderPreferences!.getPostingReminderTime();
      } catch (_) {}
    }

    // Load event reminder preferences (Story 12.3).
    bool eventRemindersEnabled = true;
    TimeOfDay eventReminderTime = const TimeOfDay(hour: 20, minute: 0);
    int formalityThreshold = 7;

    // Read event_reminders from server-side notification_preferences
    try {
      if (widget.apiClient != null) {
        final result = await widget.apiClient!.getOrCreateProfile();
        final profile = result["profile"] as Map<String, dynamic>?;
        final prefs = profile?["notificationPreferences"];
        if (prefs is Map) {
          eventRemindersEnabled =
              prefs["event_reminders"] as bool? ?? true;
        }
      }
    } catch (_) {}

    if (widget.eventReminderPreferences != null) {
      try {
        eventReminderTime =
            await widget.eventReminderPreferences!.getEventReminderTime();
        formalityThreshold =
            await widget.eventReminderPreferences!.getFormalityThreshold();
      } catch (_) {}
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationPreferencesScreen(
          initialPreferences: preferences,
          notificationsEnabled: notificationsEnabled,
          morningTime: morningTime,
          eveningReminderTime: eveningTime,
          socialMode: socialMode,
          postingReminderEnabled: postingReminderEnabled,
          postingReminderTime: postingReminderTime,
          eventRemindersEnabled: eventRemindersEnabled,
          eventReminderTime: eventReminderTime,
          formalityThreshold: formalityThreshold,
          onSocialModeChanged: (mode) async {
            try {
              if (widget.apiClient != null) {
                await widget.apiClient!
                    .updateNotificationPreferences({"social": mode});
              }
            } catch (e) {
              debugPrint("Error updating social mode: $e");
            }
          },
          onPostingReminderEnabledChanged: (enabled) async {
            try {
              if (widget.postingReminderPreferences != null) {
                await widget.postingReminderPreferences!
                    .setPostingReminderEnabled(enabled);
              }
              if (!enabled) {
                await widget.postingReminderService
                    ?.cancelPostingReminder();
              } else {
                final time = widget.postingReminderPreferences != null
                    ? await widget.postingReminderPreferences!
                        .getPostingReminderTime()
                    : const TimeOfDay(hour: 9, minute: 0);
                await widget.postingReminderService
                    ?.schedulePostingReminder(time: time);
              }
            } catch (e) {
              debugPrint("Error updating posting reminder: $e");
            }
          },
          onPostingReminderTimeChanged: (time) async {
            try {
              if (widget.postingReminderPreferences != null) {
                await widget.postingReminderPreferences!
                    .setPostingReminderTime(time);
              }
              if (widget.postingReminderService != null) {
                await widget.postingReminderService!
                    .schedulePostingReminder(time: time);
              }
            } catch (e) {
              debugPrint("Error updating posting reminder time: $e");
            }
          },
          onEveningTimeChanged: (time) async {
            // Persist new time and reschedule evening reminder.
            try {
              if (widget.eveningReminderPreferences != null) {
                await widget.eveningReminderPreferences!
                    .setEveningTime(time);
              }
              if (widget.eveningReminderService != null) {
                await widget.eveningReminderService!
                    .scheduleEveningReminder(time: time);
              }
            } catch (e) {
              debugPrint("Error updating evening reminder time: $e");
            }
          },
          onMorningTimeChanged: (time) async {
            // Persist new time and reschedule notification.
            try {
              if (widget.morningNotificationPreferences != null) {
                await widget.morningNotificationPreferences!
                    .setMorningTime(time);
              }
              if (widget.morningNotificationService != null) {
                final snippet =
                    MorningNotificationService.buildWeatherSnippet(
                        null, null);
                await widget.morningNotificationService!
                    .scheduleMorningNotification(
                  time: time,
                  weatherSnippet: snippet,
                );
              }
            } catch (e) {
              debugPrint("Error updating morning notification time: $e");
            }
          },
          onEventRemindersEnabledChanged: (enabled) async {
            try {
              // Persist to server
              if (widget.apiClient != null) {
                await widget.apiClient!
                    .updateNotificationPreferences({"event_reminders": enabled});
              }
              // Persist to local cache
              if (widget.eventReminderPreferences != null) {
                await widget.eventReminderPreferences!
                    .setEventRemindersEnabled(enabled);
              }
              if (!enabled) {
                await widget.eventReminderService?.cancelEventReminder();
              }
            } catch (e) {
              debugPrint("Error updating event reminder: $e");
            }
          },
          onEventReminderTimeChanged: (time) async {
            try {
              if (widget.eventReminderPreferences != null) {
                await widget.eventReminderPreferences!
                    .setEventReminderTime(time);
              }
            } catch (e) {
              debugPrint("Error updating event reminder time: $e");
            }
          },
          onFormalityThresholdChanged: (threshold) async {
            try {
              if (widget.eventReminderPreferences != null) {
                await widget.eventReminderPreferences!
                    .setFormalityThreshold(threshold);
              }
            } catch (e) {
              debugPrint("Error updating formality threshold: $e");
            }
          },
          onPreferenceChanged: (key, value) async {
            try {
              if (widget.apiClient != null) {
                await widget.apiClient!
                    .updateNotificationPreferences({key: value});
              }
              // Sync outfit_reminders toggle with local notification scheduling.
              if (key == "outfit_reminders" &&
                  widget.morningNotificationPreferences != null) {
                await widget.morningNotificationPreferences!
                    .setOutfitRemindersEnabled(value);
                if (!value) {
                  await widget.morningNotificationService
                      ?.cancelMorningNotification();
                } else {
                  final time = await widget.morningNotificationPreferences!
                      .getMorningTime();
                  final snippet =
                      MorningNotificationService.buildWeatherSnippet(
                          null, null);
                  await widget.morningNotificationService
                      ?.scheduleMorningNotification(
                    time: time,
                    weatherSnippet: snippet,
                  );
                }
              }
              // Sync wear_logging toggle with local evening reminder scheduling.
              if (key == "wear_logging" &&
                  widget.eveningReminderPreferences != null) {
                await widget.eveningReminderPreferences!
                    .setWearLoggingEnabled(value);
                if (!value) {
                  await widget.eveningReminderService
                      ?.cancelEveningReminder();
                } else {
                  final time = await widget.eveningReminderPreferences!
                      .getEveningTime();
                  await widget.eveningReminderService
                      ?.scheduleEveningReminder(time: time);
                }
              }
              return true;
            } catch (e) {
              debugPrint("Error updating notification preference: $e");
              return false;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildWardrobeTab(),
          _buildSocialTab(),
          _buildOutfitsTab(),
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: Semantics(
        label: "Add item",
        child: FloatingActionButton(
          onPressed: _onFabPressed,
          backgroundColor: const Color(0xFF4F46E5),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: "Wardrobe",
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: "Social",
          ),
          NavigationDestination(
            icon: Icon(Icons.dry_cleaning_outlined),
            selectedIcon: Icon(Icons.dry_cleaning),
            label: "Outfits",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return HomeScreen(
      locationService: widget.locationService ?? LocationService(),
      weatherService: widget.weatherService ?? WeatherService(),
      subscriptionService: widget.subscriptionService,
      tripDetectionService: widget.apiClient != null
          ? TripDetectionService(apiClient: widget.apiClient!)
          : null,
      packingListService: widget.apiClient != null
          ? PackingListService(apiClient: widget.apiClient!)
          : null,
    );
  }

  Widget _buildWardrobeTab() {
    if (widget.apiClient == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(
          child: Text(
            "Wardrobe - Coming Soon",
            style: TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          ),
        ),
      );
    }
    return WardrobeScreen(
      key: _wardrobeKey,
      apiClient: widget.apiClient!,
    );
  }

  Widget _buildSocialTab() {
    if (widget.apiClient == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(
          child: Text(
            "Social - Coming Soon",
            style: TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          ),
        ),
      );
    }
    return SquadListScreen(
      squadService: SquadService(apiClient: widget.apiClient!),
    );
  }

  Widget _buildOutfitsTab() {
    if (widget.apiClient == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(
          child: Text(
            "Outfits - Coming Soon",
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
            ),
          ),
        ),
      );
    }
    return OutfitHistoryScreen(
      outfitPersistenceService:
          OutfitPersistenceService(apiClient: widget.apiClient!),
      apiClient: widget.apiClient,
    );
  }

  Widget _buildProfileTab() {
    if (widget.apiClient == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(
          child: Text(
            "Profile - Coming Soon",
            style: TextStyle(color: Color(0xFF1F2937), fontSize: 18),
          ),
        ),
      );
    }
    return ProfileScreen(
      apiClient: widget.apiClient!,
      onSignOut: widget.onSignOut,
      onDeleteAccount: widget.onDeleteAccount,
      subscriptionService: widget.subscriptionService,
      onNotificationSettings: () => _openNotificationPreferences(context),
    );
  }
}
