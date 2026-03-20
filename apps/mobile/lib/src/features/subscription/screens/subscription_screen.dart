import "package:flutter/material.dart";
import "package:purchases_flutter/purchases_flutter.dart";

import "../../../core/subscription/subscription_service.dart";
import "../../../core/subscription/subscription_sync_service.dart";

/// Screen that shows the user's subscription status and available plans.
///
/// Provides access to:
/// - Current subscription status (Pro or Free)
/// - RevenueCat paywall for upgrading
/// - Customer Center for managing existing subscriptions
/// - Restore purchases
/// - Differentiates trial vs paid subscription display
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    required this.subscriptionService,
    this.syncService,
    this.firebaseUid,
    this.onSubscriptionChanged,
    super.key,
  });

  final SubscriptionService subscriptionService;

  /// Optional sync service for pushing entitlement state to the backend.
  final SubscriptionSyncService? syncService;

  /// Firebase UID for sync operations.
  final String? firebaseUid;

  /// Optional callback when subscription status changes.
  final VoidCallback? onSubscriptionChanged;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProUser = false;
  bool _isLoading = true;
  String? _activeProductId;
  DateTime? _expirationDate;
  String? _error;

  /// Whether the premium status comes from a trial (set externally via server data).
  /// This is checked via the syncService response.
  bool _isTrialPremium = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    widget.subscriptionService.addCustomerInfoUpdateListener(
      _onCustomerInfoUpdated,
    );
  }

  @override
  void dispose() {
    widget.subscriptionService.removeCustomerInfoUpdateListener(
      _onCustomerInfoUpdated,
    );
    super.dispose();
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    if (!mounted) return;
    _updateFromCustomerInfo(info);
    // Sync with backend when entitlement changes
    _syncWithBackend();
  }

  Future<void> _syncWithBackend() async {
    if (widget.syncService == null || widget.firebaseUid == null) return;
    try {
      final status =
          await widget.syncService!.syncSubscription(widget.firebaseUid!);
      if (mounted) {
        setState(() {
          _isTrialPremium = status.premiumSource == "trial";
        });
      }
    } catch (e) {
      debugPrint("SubscriptionScreen sync error: $e");
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final customerInfo =
          await widget.subscriptionService.getCustomerInfo();
      _updateFromCustomerInfo(customerInfo);
      // Also sync with backend to get premiumSource info
      await _syncWithBackend();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Could not load subscription status.";
        });
      }
    }
  }

  void _updateFromCustomerInfo(CustomerInfo info) {
    if (!mounted) return;

    final proEntitlement =
        info.entitlements.all[SubscriptionService.proEntitlementId];
    final isActive = proEntitlement?.isActive ?? false;

    setState(() {
      _isProUser = isActive;
      _activeProductId = proEntitlement?.productIdentifier;
      _expirationDate = proEntitlement?.expirationDate != null
          ? DateTime.tryParse(proEntitlement!.expirationDate!)
          : null;
      _isLoading = false;
    });
  }

  Future<void> _handleUpgrade() async {
    try {
      await widget.subscriptionService.presentPaywall();
      // Refresh status after paywall closes.
      await _loadSubscriptionStatus();
      widget.onSubscriptionChanged?.call();
    } catch (e) {
      debugPrint("Paywall error: $e");
    }
  }

  Future<void> _handleManageSubscription() async {
    try {
      await widget.subscriptionService.presentCustomerCenter();
      await _loadSubscriptionStatus();
      widget.onSubscriptionChanged?.call();
    } catch (e) {
      debugPrint("Customer center error: $e");
    }
  }

  Future<void> _handleRestorePurchases() async {
    setState(() => _isLoading = true);
    try {
      final info = await widget.subscriptionService.restorePurchases();
      _updateFromCustomerInfo(info);
      // Sync with backend after restore
      await _syncWithBackend();
      widget.onSubscriptionChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Purchases restored.")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not restore purchases.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Vestiaire Pro"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadSubscriptionStatus,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 24),
          if (!_isProUser) ...[
            _buildUpgradeSection(),
            const SizedBox(height: 24),
          ],
          if (_isProUser && _isTrialPremium) ...[
            _buildTrialUpgradeSection(),
            const SizedBox(height: 12),
          ],
          if (_isProUser && !_isTrialPremium) ...[
            FilledButton.tonal(
              onPressed: _handleManageSubscription,
              child: const Text("Manage Subscription"),
            ),
            const SizedBox(height: 12),
          ],
          TextButton(
            onPressed: _handleRestorePurchases,
            child: const Text("Restore Purchases"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isProUser ? const Color(0xFF4F46E5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isProUser ? Icons.workspace_premium : Icons.lock_outline,
            size: 48,
            color: _isProUser ? Colors.white : const Color(0xFF4F46E5),
          ),
          const SizedBox(height: 16),
          Text(
            _isProUser
                ? (_isTrialPremium ? "Premium Trial" : "Vestiaire Pro")
                : "Free Plan",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isProUser ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isProUser
                ? _buildActiveDescription()
                : "Upgrade to unlock all features",
            style: TextStyle(
              fontSize: 14,
              color: _isProUser
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  String _buildActiveDescription() {
    if (_isTrialPremium) {
      if (_expirationDate != null) {
        final remaining = _expirationDate!.difference(DateTime.now()).inDays;
        return "Trial expires in $remaining days";
      }
      return "Premium Trial \u2022 Active";
    }

    final planName = _activeProductId == SubscriptionService.yearlyProductId
        ? "Yearly"
        : "Monthly";
    if (_expirationDate != null) {
      final remaining = _expirationDate!.difference(DateTime.now()).inDays;
      return "$planName plan \u2022 Renews in $remaining days";
    }
    return "$planName plan \u2022 Active";
  }

  Widget _buildUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Unlock Vestiaire Pro",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Get unlimited access to all premium features.",
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _handleUpgrade,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            "View Plans",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTrialUpgradeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Keep Your Premium Access",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Your trial will expire soon. Subscribe to keep all premium features.",
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _handleUpgrade,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            "Subscribe to Keep Premium",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
