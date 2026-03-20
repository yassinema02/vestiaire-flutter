import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/widgets/style_points_toast.dart";
import "../../profile/widgets/badge_awarded_modal.dart";
import "../../profile/widgets/streak_celebration_toast.dart";
import "../services/wear_log_service.dart";

/// A modal bottom sheet with two tabs for logging worn items.
///
/// - "Select Items" tab: grid of wardrobe items with multi-select checkboxes.
/// - "Select Outfit" tab: list of previously saved outfits.
///
/// After confirmation, creates a wear log via [WearLogService] and calls
/// [onLogged] on success.
class LogOutfitBottomSheet extends StatefulWidget {
  const LogOutfitBottomSheet({
    required this.wearLogService,
    this.apiClient,
    this.onLogged,
    super.key,
  });

  final WearLogService wearLogService;
  final ApiClient? apiClient;
  final VoidCallback? onLogged;

  @override
  State<LogOutfitBottomSheet> createState() => _LogOutfitBottomSheetState();
}

class _LogOutfitBottomSheetState extends State<LogOutfitBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Items tab state
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = true;
  final Set<String> _selectedItemIds = {};

  // Outfits tab state
  List<Map<String, dynamic>> _outfits = [];
  bool _loadingOutfits = true;
  String? _selectedOutfitId;
  List<String>? _selectedOutfitItemIds;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
    _loadOutfits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (widget.apiClient == null) {
      setState(() => _loadingItems = false);
      return;
    }
    try {
      final response = await widget.apiClient!.listItems();
      final items = (response["items"] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _items = items.cast<Map<String, dynamic>>();
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  Future<void> _loadOutfits() async {
    if (widget.apiClient == null) {
      setState(() => _loadingOutfits = false);
      return;
    }
    try {
      final response = await widget.apiClient!.listOutfits();
      final outfits = (response["outfits"] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _outfits = outfits.cast<Map<String, dynamic>>();
        _loadingOutfits = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOutfits = false);
    }
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _selectOutfit(Map<String, dynamic> outfit) {
    final outfitId = outfit["id"] as String;
    final items = outfit["items"] as List<dynamic>? ?? [];
    final itemIds = items
        .map((i) => (i as Map<String, dynamic>)["id"] as String)
        .toList();
    setState(() {
      _selectedOutfitId = outfitId;
      _selectedOutfitItemIds = itemIds;
    });
  }

  Future<void> _confirmItems() async {
    if (_selectedItemIds.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    // Optimistic UI: show success immediately
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Outfit logged! +${_selectedItemIds.length} items tracked",
        ),
      ),
    );

    widget.onLogged?.call();

    // API call in background
    try {
      final result = await widget.wearLogService.logItems(_selectedItemIds.toList());
      _showPointsToast(messenger, result.pointsAwarded);
      _showStreakToast(messenger, result.streakUpdate);
      _showBadgeModals(navigator, result.badgesAwarded);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Failed to save wear log. Tap to retry."),
        ),
      );
    }
  }

  Future<void> _confirmOutfit() async {
    if (_selectedOutfitId == null || _selectedOutfitItemIds == null) return;

    final outfitId = _selectedOutfitId!;
    final itemIds = _selectedOutfitItemIds!;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    // Optimistic UI: show success immediately
    messenger.showSnackBar(
      SnackBar(
        content: Text("Outfit logged! +${itemIds.length} items tracked"),
      ),
    );

    widget.onLogged?.call();

    // API call in background
    try {
      final result = await widget.wearLogService.logOutfit(outfitId, itemIds);
      _showPointsToast(messenger, result.pointsAwarded);
      _showStreakToast(messenger, result.streakUpdate);
      _showBadgeModals(navigator, result.badgesAwarded);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Failed to save wear log. Tap to retry."),
        ),
      );
    }
  }

  void _showBadgeModals(NavigatorState navigator, List<Map<String, dynamic>>? badgesAwarded) {
    if (badgesAwarded == null || badgesAwarded.isEmpty) return;

    // Show badge modals with a 1000ms delay after streak toast
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (navigator.mounted) {
        showBadgeAwardedModals(navigator.context, badgesAwarded);
      }
    });
  }

  void _showStreakToast(ScaffoldMessengerState messenger, Map<String, dynamic>? streakData) {
    if (streakData == null) return;
    final streakExtended = streakData["streakExtended"] as bool? ?? false;
    final isNewStreak = streakData["isNewStreak"] as bool? ?? false;
    final currentStreak = streakData["currentStreak"] as int? ?? 0;

    if (!streakExtended && !isNewStreak) return;

    // Show streak toast after a 500ms delay (after points toast)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (isNewStreak && currentStreak == 1) {
        messenger.showSnackBar(
          SnackBar(
            content: StreakCelebrationToast(
              currentStreak: currentStreak,
              isNewStreak: true,
            ),
            duration: const Duration(milliseconds: 2500),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      } else if (streakExtended) {
        messenger.showSnackBar(
          SnackBar(
            content: StreakCelebrationToast(
              currentStreak: currentStreak,
            ),
            duration: const Duration(milliseconds: 2500),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        );
      }
    });
  }

  void _showPointsToast(ScaffoldMessengerState messenger, Map<String, dynamic>? pointsData) {
    if (pointsData == null) return;
    final pts = pointsData["pointsAwarded"] as int?;
    if (pts == null || pts <= 0) return;

    // Build bonus label
    String? bonusLabel;
    final bonuses = pointsData["bonuses"] as Map<String, dynamic>?;
    if (bonuses != null) {
      final parts = <String>[];
      if ((bonuses["streakDay"] as int? ?? 0) > 0) parts.add("streak bonus");
      if ((bonuses["firstLogOfDay"] as int? ?? 0) > 0) parts.add("first log bonus");
      if (parts.isNotEmpty) bonusLabel = "Includes ${parts.join(" + ")}!";
    }

    messenger.showSnackBar(
      SnackBar(
        content: StylePointsToast(
          pointsAwarded: pts,
          bonusLabel: bonusLabel,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Log outfit bottom sheet",
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Log Today's Outfit",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF4F46E5),
                tabs: const [
                  Tab(text: "Select Items"),
                  Tab(text: "Select Outfit"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildItemsTab(scrollController),
                    _buildOutfitsTab(scrollController),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsTab(ScrollController scrollController) {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Semantics(
        label: "Select items to log",
        child: const Center(
          child: Text("Add items to your wardrobe first"),
        ),
      );
    }

    return Semantics(
      label: "Select items to log",
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final id = item["id"] as String;
                final name = item["name"] as String? ??
                    item["category"] as String? ??
                    "Item";
                final photoUrl = item["photoUrl"] as String? ??
                    item["photo_url"] as String?;
                final isSelected = _selectedItemIds.contains(id);

                return GestureDetector(
                  onTap: () => _toggleItem(id),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                )
                              : Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: "Log ${_selectedItemIds.length} items button",
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedItemIds.isNotEmpty ? _confirmItems : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _selectedItemIds.isEmpty
                        ? "Select Items"
                        : "Log ${_selectedItemIds.length} Items",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitsTab(ScrollController scrollController) {
    if (_loadingOutfits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_outfits.isEmpty) {
      return Semantics(
        label: "Select outfit to log",
        child: const Center(
          child: Text("No saved outfits yet"),
        ),
      );
    }

    return Semantics(
      label: "Select outfit to log",
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _outfits.length,
              itemBuilder: (context, index) {
                final outfit = _outfits[index];
                final outfitId = outfit["id"] as String;
                final name =
                    outfit["name"] as String? ?? "Outfit ${index + 1}";
                final items = outfit["items"] as List<dynamic>? ?? [];
                final occasion = outfit["occasion"] as String? ?? "";
                final isSelected = _selectedOutfitId == outfitId;

                return Card(
                  elevation: isSelected ? 2 : 0,
                  color: isSelected
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.05)
                      : null,
                  child: ListTile(
                    title: Text(name),
                    subtitle:
                        Text("${items.length} items${occasion.isNotEmpty ? ' · $occasion' : ''}"),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF4F46E5))
                        : null,
                    onTap: () => _selectOutfit(outfit),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              label: "Log outfit button",
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedOutfitId != null ? _confirmOutfit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Log Outfit"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
