import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/subscription/subscription_service.dart";
import "../../resale/screens/donation_history_screen.dart";
import "../../resale/screens/resale_history_screen.dart";
import "../../resale/services/donation_service.dart";
import "../../resale/services/resale_history_service.dart";
import "../../shopping/screens/shopping_scan_screen.dart";
import "../../shopping/services/shopping_scan_service.dart";
import "../../settings/screens/account_deletion_screen.dart";
import "../../subscription/screens/subscription_screen.dart";
import "../widgets/badge_collection_grid.dart";
import "../widgets/badge_detail_sheet.dart";
import "../widgets/challenge_progress_card.dart";
import "../widgets/gamification_header.dart";
import "../widgets/streak_detail_sheet.dart";

/// The profile screen displaying gamification stats and account actions.
///
/// Loads user stats from the API and displays the [GamificationHeader]
/// at the top, followed by subscription and account management options.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.apiClient,
    this.onSignOut,
    this.onDeleteAccount,
    this.subscriptionService,
    this.onNotificationSettings,
    super.key,
  });

  /// The API client for fetching user stats.
  final ApiClient apiClient;

  /// Called when the user taps sign out.
  final VoidCallback? onSignOut;

  /// Called when the user completes account deletion.
  final Future<void> Function()? onDeleteAccount;

  /// Optional subscription service for premium features.
  final SubscriptionService? subscriptionService;

  /// Called when the user taps notification settings.
  final VoidCallback? onNotificationSettings;

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _hasError = false;

  List<Map<String, dynamic>> _allBadges = [];
  List<Map<String, dynamic>> _earnedBadges = [];
  bool _badgesError = false;
  Map<String, dynamic>? _challengeData;

  // Resale summary
  String _resaleSubtitle = "View your resale activity";

  // Donation summary
  String _donationSubtitle = "View your donations";

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await widget.apiClient.getUserStats();
      if (!mounted) return;
      final stats = result["stats"] as Map<String, dynamic>?;

      // Parse earned badges from stats response
      List<Map<String, dynamic>> earned = [];
      if (stats != null) {
        final badgesRaw = stats["badges"] as List<dynamic>? ?? [];
        earned = badgesRaw.cast<Map<String, dynamic>>();
      }

      // Parse challenge data from stats response
      Map<String, dynamic>? challengeData;
      if (stats != null) {
        final challenge = stats["challenge"];
        if (challenge is Map<String, dynamic>) {
          challengeData = challenge;
        }
      }

      setState(() {
        _stats = stats;
        _earnedBadges = earned;
        _challengeData = challengeData;
        _isLoading = false;
      });

      // Check for streak freeze notification
      _checkFreezeNotification();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }

    // Load badge catalog independently
    try {
      final catalog = await widget.apiClient.getBadgeCatalog();
      if (!mounted) return;
      setState(() {
        _allBadges = catalog;
        _badgesError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _badgesError = true;
      });
    }

    // Load resale summary (best-effort)
    try {
      final resaleService = ResaleHistoryService(apiClient: widget.apiClient);
      final result = await resaleService.fetchHistory(limit: 0);
      if (!mounted) return;
      if (result != null) {
        final summary = result["summary"] as Map<String, dynamic>?;
        if (summary != null) {
          final sold = (summary["itemsSold"] as num?)?.toInt() ?? 0;
          final earnings = (summary["totalEarnings"] as num?)?.toDouble() ?? 0.0;
          final currencyFormat = NumberFormat.currency(symbol: "\u00A3");
          setState(() {
            _resaleSubtitle = "$sold items sold \u2022 ${currencyFormat.format(earnings)} earned";
          });
        }
      }
    } catch (_) {
      // Best-effort: keep default subtitle
    }

    // Load donation summary (best-effort)
    try {
      final donationService = DonationService(apiClient: widget.apiClient);
      final donationResult = await donationService.fetchDonations(limit: 0);
      if (!mounted) return;
      if (donationResult != null) {
        final summary = donationResult["summary"] as Map<String, dynamic>?;
        if (summary != null) {
          final donated = (summary["totalDonated"] as num?)?.toInt() ?? 0;
          setState(() {
            _donationSubtitle = "$donated items donated";
          });
        }
      }
    } catch (_) {
      // Best-effort: keep default subtitle
    }
  }

  Future<void> _checkFreezeNotification() async {
    if (_stats == null) return;

    final freezeUsedAt = _stats!["streakFreezeUsedAt"] as String?;
    if (freezeUsedAt == null) return;

    // Check if freeze was used this week (simple presence check)
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotified = prefs.getString("last_freeze_notification_date");

      if (lastNotified != freezeUsedAt) {
        final currentStreak =
            (_stats!["currentStreak"] as num?)?.toInt() ?? 0;
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.ac_unit,
                    color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Streak freeze used! Your $currentStreak-day streak is safe.",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await prefs.setString("last_freeze_notification_date", freezeUsedAt);
      }
    } catch (_) {
      // Silently fail - notification is best-effort
    }
  }

  void _onBadgeTap(Map<String, dynamic> badge, bool isEarned) {
    String? awardedAt;
    if (isEarned) {
      final key = badge["key"] as String? ?? "";
      final match = _earnedBadges.where((b) => b["key"] == key);
      if (match.isNotEmpty) {
        awardedAt = match.first["awardedAt"] as String?;
      }
    }
    showBadgeDetailSheet(
      context,
      badge: badge,
      isEarned: isEarned,
      awardedAt: awardedAt,
    );
  }

  void _openStreakDetailSheet() {
    if (_stats == null) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => StreakDetailSheet(
        currentStreak: (_stats!["currentStreak"] as num?)?.toInt() ?? 0,
        longestStreak: (_stats!["longestStreak"] as num?)?.toInt() ?? 0,
        streakFreezeAvailable:
            (_stats!["streakFreezeAvailable"] as bool?) ?? true,
        streakFreezeUsedAt: _stats!["streakFreezeUsedAt"] as String?,
        lastStreakDate: _stats!["lastStreakDate"] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        actions: [
          if (widget.onNotificationSettings != null)
            Semantics(
              label: "Notification settings",
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: "Notification settings",
                onPressed: widget.onNotificationSettings,
              ),
            ),
          if (widget.onSignOut != null)
            Semantics(
              label: "Sign out",
              child: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: "Sign out",
                onPressed: widget.onSignOut,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gamification header (loading / error / success)
              if (_isLoading)
                _buildLoadingPlaceholder()
              else if (_hasError)
                _buildErrorBanner()
              else if (_stats != null)
                _buildGamificationHeader(),

              // Challenge progress card (between header and badges)
              if (!_isLoading && !_hasError && _challengeData != null) ...[
                const SizedBox(height: 16),
                _buildChallengeCard(),
              ],

              const SizedBox(height: 24),

              // Badge collection section
              if (!_isLoading && !_hasError && _stats != null) ...[
                Row(
                  children: [
                    const Text(
                      "Badges",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${_earnedBadges.length}/15",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_badgesError)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Unable to load badges",
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadUserStats,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  )
                else if (_allBadges.isNotEmpty)
                  BadgeCollectionGrid(
                    allBadges: _allBadges,
                    earnedBadges: _earnedBadges,
                    onBadgeTap: _onBadgeTap,
                  ),
                const SizedBox(height: 24),
              ],

              // Shopping Assistant entry point
              if (!_isLoading && !_hasError) ...[
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Semantics(
                    label: "Shopping Assistant",
                    child: ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5)),
                      title: const Text("Shopping Assistant"),
                      subtitle: const Text(
                        "Check purchases against your wardrobe",
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final scanService = ShoppingScanService(apiClient: widget.apiClient);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ShoppingScanScreen(
                              shoppingScanService: scanService,
                              subscriptionService: widget.subscriptionService!,
                              apiClient: widget.apiClient,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Resale History entry point
              if (!_isLoading && !_hasError) ...[
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Semantics(
                    label: "Resale History",
                    child: ListTile(
                      leading: const Icon(Icons.history, color: Color(0xFF4F46E5)),
                      title: const Text("Resale History"),
                      subtitle: Text(
                        _resaleSubtitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResaleHistoryScreen(
                              apiClient: widget.apiClient,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Donation History entry point
              if (!_isLoading && !_hasError) ...[
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Semantics(
                    label: "Donation History",
                    child: ListTile(
                      leading: const Icon(Icons.volunteer_activism, color: Color(0xFF8B5CF6)),
                      title: const Text("Donation History"),
                      subtitle: Text(
                        _donationSubtitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DonationHistoryScreen(
                              apiClient: widget.apiClient,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Subscription section
              if (widget.subscriptionService != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text("Vestiaire Pro"),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SubscriptionScreen(
                            subscriptionService: widget.subscriptionService!,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      widget.subscriptionService!.presentCustomerCenter();
                    },
                    child: const Text("Manage Subscription"),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Delete account
              if (widget.onDeleteAccount != null)
                Semantics(
                  label: "Delete Account",
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountDeletionScreen(
                            onDeleteRequested: () async {
                              await widget.apiClient.deleteAccount();
                            },
                            onAccountDeleted: () {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                              widget.onDeleteAccount!();
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Delete Account",
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Unable to load stats",
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadUserStats,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    final data = _challengeData!;
    final status = data["status"] as String? ?? "active";
    final currentProgress = (data["currentProgress"] as num?)?.toInt() ?? 0;
    final targetCount = (data["targetCount"] as num?)?.toInt() ?? 20;
    final timeRemainingSeconds =
        (data["timeRemainingSeconds"] as num?)?.toInt();
    final reward = data["reward"] as Map<String, dynamic>?;
    final rewardDescription =
        reward?["description"] as String? ?? "Unlock 1 month Premium free";

    return ChallengeProgressCard(
      name: data["name"] as String? ?? "Closet Safari",
      currentProgress: currentProgress,
      targetCount: targetCount,
      status: status,
      timeRemainingSeconds: timeRemainingSeconds,
      rewardDescription: rewardDescription,
      onAccept: status != "active" && status != "completed" && status != "expired"
          ? _handleAcceptChallenge
          : null,
    );
  }

  Future<void> _handleAcceptChallenge() async {
    try {
      await widget.apiClient.acceptChallenge("closet_safari");
      if (!mounted) return;
      _loadUserStats();
    } catch (_) {
      // Best-effort
    }
  }

  Widget _buildGamificationHeader() {
    final stats = _stats!;
    return GamificationHeader(
      currentLevel: (stats["currentLevel"] as num?)?.toInt() ?? 1,
      currentLevelName:
          (stats["currentLevelName"] as String?) ?? "Closet Rookie",
      totalPoints: (stats["totalPoints"] as num?)?.toInt() ?? 0,
      currentStreak: (stats["currentStreak"] as num?)?.toInt() ?? 0,
      itemCount: (stats["itemCount"] as num?)?.toInt() ?? 0,
      nextLevelThreshold: (stats["nextLevelThreshold"] as num?)?.toInt(),
      streakFreezeAvailable:
          (stats["streakFreezeAvailable"] as bool?) ?? true,
      onStreakTap: _openStreakDetailSheet,
    );
  }
}
