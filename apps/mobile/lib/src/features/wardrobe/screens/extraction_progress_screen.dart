import "dart:async";

import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "extraction_review_screen.dart";

/// Extraction Progress screen showing real-time progress of a bulk
/// extraction job with polling, progress bar, and auto-transition.
///
/// Story 10.3: Extraction Progress & Review Flow (FR-EXT-07, FR-EXT-08)
class ExtractionProgressScreen extends StatefulWidget {
  const ExtractionProgressScreen({
    required this.jobId,
    required this.apiClient,
    super.key,
  });

  final String jobId;
  final ApiClient apiClient;

  @override
  State<ExtractionProgressScreen> createState() =>
      _ExtractionProgressScreenState();
}

class _ExtractionProgressScreenState extends State<ExtractionProgressScreen> {
  Timer? _pollTimer;
  Map<String, dynamic>? _jobData;
  bool _isRetrying = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Immediately fetch once
    _fetchJob();
    // Then poll every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchJob();
    });
  }

  Future<void> _fetchJob() async {
    try {
      final response = await widget.apiClient.getExtractionJob(widget.jobId);
      final job = response["job"] as Map<String, dynamic>?;
      if (!mounted || job == null) return;

      setState(() {
        _jobData = job;
      });

      final status = job["status"] as String?;
      if (["completed", "partial", "failed", "confirmed"].contains(status)) {
        _pollTimer?.cancel();
        if (status != "failed" && !_hasNavigated) {
          _hasNavigated = true;
          _navigateToReview(job);
        }
      }
    } catch (_) {
      // Silently continue polling on transient errors
    }
  }

  void _navigateToReview(Map<String, dynamic> jobData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(
          jobId: widget.jobId,
          jobData: jobData,
          apiClient: widget.apiClient,
        ),
      ),
    );
  }

  Future<void> _retryProcessing() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      await widget.apiClient.triggerExtractionProcessing(widget.jobId);
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _hasNavigated = false;
      });
      _startPolling();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<bool> _showBackDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Leave Progress"),
        content: const Text(
          "Processing will continue in the background. You can return to check progress later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Stay"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Leave"),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _estimatedTimeRemaining(Map<String, dynamic> job) {
    final totalPhotos = (job["totalPhotos"] as num?)?.toInt() ?? 0;
    final processedPhotos = (job["processedPhotos"] as num?)?.toInt() ?? 0;
    final remaining = (totalPhotos - processedPhotos) * 6;
    if (remaining <= 0) return "Almost done...";
    if (remaining < 60) return "~$remaining seconds remaining";
    return "~${(remaining / 60).ceil()} minutes remaining";
  }

  @override
  Widget build(BuildContext context) {
    final status = _jobData?["status"] as String?;
    final totalPhotos = (_jobData?["totalPhotos"] as num?)?.toInt() ?? 0;
    final processedPhotos =
        (_jobData?["processedPhotos"] as num?)?.toInt() ?? 0;
    final totalItemsFound =
        (_jobData?["totalItemsFound"] as num?)?.toInt() ?? 0;
    final isFailed = status == "failed";
    final progress =
        totalPhotos > 0 ? processedPhotos / totalPhotos : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _showBackDialog();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: Semantics(
            label: "Extraction Progress",
            child: const Text("Extraction Progress"),
          ),
          backgroundColor: const Color(0xFFF3F4F6),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: isFailed ? _buildFailedUI() : _buildProgressUI(
              status: status,
              totalPhotos: totalPhotos,
              processedPhotos: processedPhotos,
              totalItemsFound: totalItemsFound,
              progress: progress,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressUI({
    required String? status,
    required int totalPhotos,
    required int processedPhotos,
    required int totalItemsFound,
    required double progress,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
        ),
        const SizedBox(height: 24),
        Semantics(
          label: "Processing photo $processedPhotos of $totalPhotos",
          child: Text(
            totalPhotos > 0
                ? "Processing photo $processedPhotos of $totalPhotos..."
                : "Starting extraction...",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: "Progress indicator",
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: "Items found: $totalItemsFound",
          child: Text(
            "Items found: $totalItemsFound",
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_jobData != null)
          Semantics(
            label: "Estimated time remaining",
            child: Text(
              _estimatedTimeRemaining(_jobData!),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFailedUI() {
    final errorMessage = _jobData?["errorMessage"] as String?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 64,
        ),
        const SizedBox(height: 16),
        Semantics(
          label: "Extraction failed",
          child: const Text(
            "Extraction failed",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Semantics(
          label: "Retry extraction",
          child: ElevatedButton(
            onPressed: _isRetrying ? null : _retryProcessing,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isRetrying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text("Retry"),
          ),
        ),
      ],
    );
  }
}
