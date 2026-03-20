import "dart:convert";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/subscription/subscription_service.dart";
import "../../wardrobe/screens/wardrobe_screen.dart";
import "../widgets/ai_insights_section.dart";
import "../widgets/brand_value_section.dart";
import "../widgets/category_distribution_section.dart";
import "../widgets/cpw_item_row.dart";
import "../widgets/gap_analysis_section.dart";
import "../widgets/health_score_section.dart";
import "../../resale/screens/spring_clean_screen.dart";
import "../widgets/neglected_items_section.dart";
import "../widgets/seasonal_reports_section.dart";
import "../widgets/summary_cards_row.dart";
import "../widgets/top_worn_section.dart";
import "../widgets/sustainability_section.dart";
import "../widgets/wear_frequency_section.dart";
import "wear_heatmap_screen.dart";

/// The analytics dashboard screen displaying wardrobe value metrics
/// and a cost-per-wear breakdown list.
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({
    required this.apiClient,
    this.onNavigateToAddItem,
    this.subscriptionService,
    super.key,
  });

  final ApiClient apiClient;
  final VoidCallback? onNavigateToAddItem;

  /// Optional subscription service for presenting the RevenueCat paywall.
  final SubscriptionService? subscriptionService;

  @override
  State<AnalyticsDashboardScreen> createState() =>
      AnalyticsDashboardScreenState();
}

/// Visible for testing.
class AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>>? _itemsCpw;
  List<Map<String, dynamic>>? _topWornItems;
  List<Map<String, dynamic>>? _neglectedItems;
  List<Map<String, dynamic>>? _categoryDistribution;
  List<Map<String, dynamic>>? _wearFrequency;
  String _topWornPeriod = "all";
  bool _isLoading = true;
  String? _error;

  // Sustainability state
  int? _sustainabilityScore;
  Map<String, dynamic>? _sustainabilityFactors;
  double? _co2SavedKg;
  double? _co2CarKmEquivalent;
  int? _sustainabilityPercentile;
  bool _sustainabilityBadgeAwarded = false;

  // Brand value state
  List<Map<String, dynamic>>? _brandValueBrands;
  List<String>? _brandValueCategories;
  Map<String, dynamic>? _bestValueBrand;
  Map<String, dynamic>? _mostInvestedBrand;
  String _brandValueCategory = "all";

  // Gap analysis state
  List<Map<String, dynamic>>? _gapAnalysisGaps;
  int? _gapAnalysisTotalItems;
  Set<String> _dismissedGapIds = {};

  // Seasonal reports state
  List<Map<String, dynamic>>? _seasonalSeasons;
  String? _currentSeason;
  Map<String, dynamic>? _transitionAlert;

  // Health score state (FREE tier)
  int? _healthScore;
  String? _healthColorTier;
  Map<String, dynamic>? _healthFactors;
  int? _healthPercentile;
  String? _healthRecommendation;
  int? _healthTotalItems;
  int? _healthItemsWorn90d;

  // AI summary state
  String? _aiSummary;
  bool _isLoadingAiSummary = false;
  String? _aiSummaryError;
  bool _isPremium = false;
  bool _aiSummaryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGapCacheFromPrefs();
    _loadAnalytics();
  }

  Future<void> _loadGapCacheFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedJson = prefs.getString("dismissed_gap_ids");
      if (dismissedJson != null) {
        final list = (jsonDecode(dismissedJson) as List<dynamic>).cast<String>();
        if (mounted) {
          setState(() {
            _dismissedGapIds = list.toSet();
          });
        }
      }
      final cacheJson = prefs.getString("gap_analysis_cache");
      if (cacheJson != null) {
        final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _gapAnalysisGaps = ((cache["gaps"] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
            _gapAnalysisTotalItems = (cache["totalItems"] as num?)?.toInt();
          });
        }
      }
    } catch (_) {
    }
  }

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final isPremiumCached = widget.subscriptionService?.isPremiumCached ?? false;
      final futures = <Future<Map<String, dynamic>>>[
        widget.apiClient.getWardrobeSummary(),
        widget.apiClient.getItemsCpw(),
        widget.apiClient.getTopWornItems(period: _topWornPeriod),
        widget.apiClient.getNeglectedItems(),
        widget.apiClient.getCategoryDistribution(),
        widget.apiClient.getWearFrequency(),
        widget.apiClient.getWardrobeHealthScore().then<Map<String, dynamic>>(
          (value) => value,
          onError: (_) => <String, dynamic>{},
        ),
      ];

      // Conditional premium-only fetches
      if (isPremiumCached) {
        futures.add(widget.apiClient.getBrandValueAnalytics());
        futures.add(widget.apiClient.getSustainabilityAnalytics());
        futures.add(widget.apiClient.getGapAnalysis());
        futures.add(widget.apiClient.getSeasonalReports());
      }

      final results = await Future.wait(futures);
      final healthResult = results[6];

      if (!mounted) return;
      setState(() {
        _summary = (results[0]["summary"] as Map<String, dynamic>?) ?? results[0];
        _itemsCpw = ((results[1]["items"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _topWornItems = ((results[2]["items"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _neglectedItems = ((results[3]["items"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _categoryDistribution = ((results[4]["categories"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _wearFrequency = ((results[5]["days"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();

        // Health score data (FREE tier, fetched separately)
        if (healthResult.isNotEmpty) {
          _healthScore = (healthResult["score"] as num?)?.toInt();
          _healthColorTier = healthResult["colorTier"] as String?;
          _healthFactors = healthResult["factors"] as Map<String, dynamic>?;
          _healthPercentile = (healthResult["percentile"] as num?)?.toInt();
          _healthRecommendation = healthResult["recommendation"] as String?;
          _healthTotalItems = (healthResult["totalItems"] as num?)?.toInt();
          _healthItemsWorn90d = (healthResult["itemsWorn90d"] as num?)?.toInt();
        }

        // Brand value data (premium only)
        if (isPremiumCached && results.length > 7) {
          final bvResult = results[7];
          _brandValueBrands = ((bvResult["brands"] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>();
          _brandValueCategories = ((bvResult["availableCategories"] as List<dynamic>?) ?? [])
              .cast<String>();
          _bestValueBrand = bvResult["bestValueBrand"] as Map<String, dynamic>?;
          _mostInvestedBrand = bvResult["mostInvestedBrand"] as Map<String, dynamic>?;
        } else {
          _brandValueBrands = null;
          _brandValueCategories = null;
          _bestValueBrand = null;
          _mostInvestedBrand = null;
        }

        // Sustainability data (premium only)
        if (isPremiumCached && results.length > 8) {
          final susResult = results[8];
          _sustainabilityScore = (susResult["score"] as num?)?.toInt();
          _sustainabilityFactors = susResult["factors"] as Map<String, dynamic>?;
          _co2SavedKg = (susResult["co2SavedKg"] as num?)?.toDouble();
          _co2CarKmEquivalent = (susResult["co2CarKmEquivalent"] as num?)?.toDouble();
          _sustainabilityPercentile = (susResult["percentile"] as num?)?.toInt();
          _sustainabilityBadgeAwarded = susResult["badgeAwarded"] as bool? ?? false;
        } else {
          _sustainabilityScore = null;
          _sustainabilityFactors = null;
          _co2SavedKg = null;
          _co2CarKmEquivalent = null;
          _sustainabilityPercentile = null;
          _sustainabilityBadgeAwarded = false;
        }

        // Gap analysis data (premium only)
        if (isPremiumCached && results.length > 9) {
          final gapResult = results[9];
          final newGaps = ((gapResult["gaps"] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>();
          final newTotalItems = (gapResult["totalItems"] as num?)?.toInt() ?? 0;

          // Check if wardrobe count changed — invalidate dismissed gaps
          _checkWardrobeCountChange(newTotalItems);

          _gapAnalysisGaps = newGaps;
          _gapAnalysisTotalItems = newTotalItems;

          // Cache the results
          _cacheGapAnalysis(newGaps, newTotalItems);
        } else if (!isPremiumCached) {
          _gapAnalysisGaps = null;
          _gapAnalysisTotalItems = null;
        }

        // Seasonal reports data (premium only)
        if (isPremiumCached && results.length > 10) {
          final seasonalResult = results[10];
          _seasonalSeasons = ((seasonalResult["seasons"] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>();
          _currentSeason = seasonalResult["currentSeason"] as String?;
          _transitionAlert = seasonalResult["transitionAlert"] as Map<String, dynamic>?;
        } else if (!isPremiumCached) {
          _seasonalSeasons = null;
          _currentSeason = null;
          _transitionAlert = null;
        }
        _brandValueCategory = "all";
        _isLoading = false;
      });

      // Load AI summary after analytics data is available
      if (!_aiSummaryLoaded) {
        _loadAiSummary();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshAnalytics() async {
    _aiSummaryLoaded = false;
    // Invalidate gap cache on pull-to-refresh
    _invalidateGapCache();
    await _loadAnalytics();
  }

  void _invalidateGapCache() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove("gap_analysis_cache");
    }).catchError((_) {});
  }

  void _checkWardrobeCountChange(int newTotalItems) {
    SharedPreferences.getInstance().then((prefs) {
      final cacheJson = prefs.getString("gap_analysis_cache");
      if (cacheJson != null) {
        final cache = jsonDecode(cacheJson) as Map<String, dynamic>;
        final cachedCount = (cache["cachedItemCount"] as num?)?.toInt() ?? 0;
        if (cachedCount != newTotalItems) {
          // Wardrobe changed — clear dismissed gaps
          _dismissedGapIds = {};
          prefs.remove("dismissed_gap_ids");
        }
      }
    }).catchError((_) {});
  }

  Future<void> _cacheGapAnalysis(
    List<Map<String, dynamic>> gaps,
    int totalItems,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = {
        "gaps": gaps,
        "totalItems": totalItems,
        "cachedItemCount": totalItems,
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString("gap_analysis_cache", jsonEncode(cache));
    } catch (_) {
      // Best-effort caching
    }
  }

  void _dismissGap(String gapId) {
    setState(() {
      _dismissedGapIds = {..._dismissedGapIds, gapId};
    });
    // Persist to shared_preferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(
        "dismissed_gap_ids",
        jsonEncode(_dismissedGapIds.toList()),
      );
    }).catchError((_) {});
  }

  Future<void> _loadAiSummary() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAiSummary = true;
      _aiSummaryError = null;
    });

    try {
      final response = await widget.apiClient.getAiAnalyticsSummary();
      if (!mounted) return;
      setState(() {
        _isPremium = true;
        _aiSummary = response["summary"] as String?;
        _isLoadingAiSummary = false;
        _aiSummaryLoaded = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        // Free user -- expected, not an error
        setState(() {
          _isPremium = false;
          _isLoadingAiSummary = false;
          _aiSummaryLoaded = true;
        });
      } else {
        setState(() {
          _isPremium = true; // Assume premium if we get a non-403 error
          _aiSummaryError = e.message;
          _isLoadingAiSummary = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPremium = true;
        _aiSummaryError = e.toString();
        _isLoadingAiSummary = false;
      });
    }
  }

  Future<void> _handleUpgrade() async {
    if (widget.subscriptionService != null) {
      await widget.subscriptionService!.presentPaywallIfNeeded();
      // After paywall dismissal, reload AI summary to reflect any purchase
      _aiSummaryLoaded = false;
      _loadAiSummary();
    }
  }

  Future<void> _loadBrandValue(String category) async {
    try {
      final result = await widget.apiClient.getBrandValueAnalytics(
        category: category == "all" ? null : category,
      );
      if (!mounted) return;
      setState(() {
        _brandValueCategory = category;
        _brandValueBrands = ((result["brands"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        _brandValueCategories = ((result["availableCategories"] as List<dynamic>?) ?? [])
            .cast<String>();
        _bestValueBrand = result["bestValueBrand"] as Map<String, dynamic>?;
        _mostInvestedBrand = result["mostInvestedBrand"] as Map<String, dynamic>?;
      });
    } catch (e) {
      // Silently fail on category filter change -- dashboard still usable
    }
  }

  void _navigateToBrandWardrobe(Map<String, dynamic> brand) {
    final brandName = brand["brand"] as String?;
    if (brandName == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WardrobeScreen(
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Future<void> _loadTopWorn(String period) async {
    try {
      final result =
          await widget.apiClient.getTopWornItems(period: period);
      if (!mounted) return;
      setState(() {
        _topWornPeriod = period;
        _topWornItems = ((result["items"] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (e) {
      // Silently fail on period filter change -- dashboard still usable
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Analytics"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: Semantics(
        label: "Analytics dashboard",
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadAnalytics,
              child: const Text(
                "Retry",
                style: TextStyle(color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
      );
    }

    final totalItems = (_summary?["totalItems"] as num?)?.toInt() ?? 0;

    // Empty state: no items at all
    if (totalItems == 0) {
      return _buildEmptyState();
    }

    final pricedItems = (_summary?["pricedItems"] as num?)?.toInt() ?? 0;
    final totalValue = (_summary?["totalValue"] as num?)?.toDouble();
    final averageCpw = (_summary?["averageCpw"] as num?)?.toDouble();
    final currency = _summary?["dominantCurrency"] as String?;

    return RefreshIndicator(
      onRefresh: _refreshAnalytics,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Health Score section (hero position, first)
          if (_healthScore != null)
            SliverToBoxAdapter(
              child: HealthScoreSection(
                score: _healthScore!,
                colorTier: _healthColorTier ?? "red",
                factors: _healthFactors ?? {},
                percentile: _healthPercentile ?? 100,
                recommendation: _healthRecommendation ?? "",
                totalItems: _healthTotalItems ?? 0,
                itemsWorn90d: _healthItemsWorn90d ?? 0,
                onSpringCleanTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SpringCleanScreen(
                        apiClient: widget.apiClient,
                      ),
                    ),
                  );
                },
              ),
            ),
          // AI Insights section (above summary cards)
          SliverToBoxAdapter(
            child: AiInsightsSection(
              isPremium: _isPremium,
              summary: _aiSummary,
              isLoading: _isLoadingAiSummary,
              error: _aiSummaryError,
              onRetry: _loadAiSummary,
              subscriptionService: widget.subscriptionService,
              onUpgrade: _handleUpgrade,
            ),
          ),
          // Summary cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SummaryCardsRow(
                totalItems: totalItems,
                totalValue: (pricedItems > 0) ? totalValue : null,
                averageCpw: (pricedItems > 0) ? averageCpw : null,
                currency: currency,
              ),
            ),
          ),
          // Section header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "Cost-Per-Wear Breakdown",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ),
          // CPW list or no-price prompt
          if (pricedItems == 0)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.attach_money, size: 32, color: Color(0xFF9CA3AF)),
                    SizedBox(height: 8),
                    Text(
                      "Add purchase prices to your items to see cost-per-wear analytics.",
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _itemsCpw![index];
                  return CpwItemRow(
                    itemId: (item["id"] as String?) ?? "",
                    name: item["name"] as String?,
                    category: item["category"] as String?,
                    photoUrl: item["photoUrl"] as String?,
                    purchasePrice: (item["purchasePrice"] as num?)?.toDouble(),
                    currency: item["currency"] as String?,
                    wearCount: (item["wearCount"] as num?)?.toInt() ?? 0,
                    cpw: (item["cpw"] as num?)?.toDouble(),
                    onTap: () => _navigateToItemDetail(item),
                  );
                },
                childCount: _itemsCpw?.length ?? 0,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // Top 10 Most Worn section
          SliverToBoxAdapter(
            child: TopWornSection(
              items: _topWornItems ?? [],
              selectedPeriod: _topWornPeriod,
              onPeriodChanged: _loadTopWorn,
              onItemTap: _navigateToItemDetail,
            ),
          ),
          // Neglected Items section
          SliverToBoxAdapter(
            child: NeglectedItemsSection(
              items: _neglectedItems ?? [],
              onItemTap: _navigateToItemDetail,
            ),
          ),
          // Category Distribution section
          SliverToBoxAdapter(
            child: CategoryDistributionSection(
              categories: _categoryDistribution ?? [],
            ),
          ),
          // Wear Frequency section
          SliverToBoxAdapter(
            child: WearFrequencySection(
              days: _wearFrequency ?? [],
            ),
          ),
          // Brand Value section (premium-gated)
          SliverToBoxAdapter(
            child: BrandValueSection(
              isPremium: widget.subscriptionService?.isPremiumCached ?? false,
              brands: _brandValueBrands ?? [],
              availableCategories: _brandValueCategories ?? [],
              bestValueBrand: _bestValueBrand,
              mostInvestedBrand: _mostInvestedBrand,
              selectedCategory: _brandValueCategory,
              onCategoryChanged: _loadBrandValue,
              onBrandTap: _navigateToBrandWardrobe,
              subscriptionService: widget.subscriptionService,
            ),
          ),
          // Sustainability section (premium-gated)
          SliverToBoxAdapter(
            child: SustainabilitySection(
              isPremium: widget.subscriptionService?.isPremiumCached ?? false,
              score: _sustainabilityScore ?? 0,
              factors: _sustainabilityFactors ?? {},
              co2SavedKg: _co2SavedKg ?? 0.0,
              co2CarKmEquivalent: _co2CarKmEquivalent ?? 0.0,
              percentile: _sustainabilityPercentile ?? 100,
              badgeAwarded: _sustainabilityBadgeAwarded,
              subscriptionService: widget.subscriptionService,
            ),
          ),
          // Gap Analysis section (premium-gated)
          SliverToBoxAdapter(
            child: GapAnalysisSection(
              isPremium: widget.subscriptionService?.isPremiumCached ?? false,
              gaps: _gapAnalysisGaps ?? [],
              totalItems: _gapAnalysisTotalItems ?? 0,
              onDismissGap: _dismissGap,
              dismissedGapIds: _dismissedGapIds,
              subscriptionService: widget.subscriptionService,
            ),
          ),
          // Seasonal Reports section (premium-gated)
          SliverToBoxAdapter(
            child: SeasonalReportsSection(
              isPremium: widget.subscriptionService?.isPremiumCached ?? false,
              seasons: _seasonalSeasons ?? [],
              currentSeason: _currentSeason ?? _getCurrentSeason(),
              transitionAlert: _transitionAlert,
              onViewHeatmap: _navigateToHeatmap,
              subscriptionService: widget.subscriptionService,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            const Text(
              "Add items to your wardrobe to see analytics!",
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onNavigateToAddItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Add Item"),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) return "spring";
    if (month >= 6 && month <= 8) return "summer";
    if (month >= 9 && month <= 11) return "fall";
    return "winter";
  }

  void _navigateToHeatmap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WearHeatmapScreen(
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  void _navigateToItemDetail(Map<String, dynamic> item) {
    final itemId = item["id"] as String?;
    if (itemId == null) return;

    // Navigate to ItemDetailScreen using the standard navigation pattern.
    // Import is avoided to keep analytics module loosely coupled.
    // Instead, push a named-style route that the app's router handles,
    // or use MaterialPageRoute with a lazy import.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ItemDetailPlaceholder(itemId: itemId),
      ),
    );
  }
}

/// Temporary placeholder for item detail navigation.
///
/// In production, this would push to the actual ItemDetailScreen.
/// This keeps the analytics module decoupled from the wardrobe module.
class _ItemDetailPlaceholder extends StatelessWidget {
  const _ItemDetailPlaceholder({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Item Detail")),
      body: Center(child: Text("Item: $itemId")),
    );
  }
}
