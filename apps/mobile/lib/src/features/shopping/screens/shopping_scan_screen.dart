import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";

import "../../../core/networking/api_client.dart";
import "../../../core/subscription/subscription_service.dart";
import "../../../core/widgets/premium_gate_card.dart";
import "../models/shopping_scan.dart";
import "../services/shopping_scan_service.dart";
import "product_review_screen.dart";

/// The Shopping Assistant screen for scanning product URLs and screenshots.
///
/// Provides URL input, screenshot upload via camera/gallery,
/// triggers API-side scraping + AI analysis, and displays extracted product metadata.
///
/// Story 8.1: Product URL Scraping (FR-SHP-02)
/// Story 8.2: Product Screenshot Upload (FR-SHP-01, FR-SHP-04)
class ShoppingScanScreen extends StatefulWidget {
  const ShoppingScanScreen({
    required this.shoppingScanService,
    required this.subscriptionService,
    required this.apiClient,
    this.imagePicker,
    super.key,
  });

  final ShoppingScanService shoppingScanService;
  final SubscriptionService subscriptionService;
  final ApiClient apiClient;
  final ImagePicker? imagePicker;

  @override
  State<ShoppingScanScreen> createState() => _ShoppingScanScreenState();
}

class _ShoppingScanScreenState extends State<ShoppingScanScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  ShoppingScan? _scanResult;
  String? _errorMessage;
  bool _showRateLimit = false;
  String? _screenshotImagePath;
  bool _isScreenshotLoading = false;

  ImagePicker get _imagePicker => widget.imagePicker ?? ImagePicker();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _urlController.text = data.text!;
      });
    }
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (!url.startsWith("https://")) {
      setState(() {
        _errorMessage = "Please enter a valid HTTPS URL";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _scanResult = null;
      _showRateLimit = false;
      _screenshotImagePath = null;
      _isScreenshotLoading = false;
    });

    try {
      final result = await widget.shoppingScanService.scanUrl(url);
      if (!mounted) return;
      setState(() {
        _scanResult = result;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        setState(() {
          _showRateLimit = true;
          _isLoading = false;
        });
      } else if (e.statusCode == 422) {
        setState(() {
          _errorMessage =
              e.message.isNotEmpty ? e.message : "Unable to extract product information from this URL. Try uploading a screenshot instead.";
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Something went wrong. Please try again.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
        _isLoading = false;
      });
    }
  }

  Future<void> _showScreenshotOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: "Take Photo",
                  child: ListTile(
                    leading: const Icon(Icons.camera_alt, color: Color(0xFF4F46E5)),
                    title: const Text("Take Photo"),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                Semantics(
                  label: "Choose from Gallery",
                  child: ListTile(
                    leading: const Icon(Icons.photo_library, color: Color(0xFF4F46E5)),
                    title: const Text("Choose from Gallery"),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 90,
    );

    if (image == null) return;
    if (!mounted) return;

    setState(() {
      _screenshotImagePath = image.path;
      _isScreenshotLoading = true;
      _isLoading = false;
      _errorMessage = null;
      _scanResult = null;
      _showRateLimit = false;
    });

    try {
      // (a) Get signed upload URL
      final signedUrlResponse = await widget.apiClient.getSignedUploadUrl(
        purpose: "shopping_screenshot",
      );
      final uploadUrl = signedUrlResponse["uploadUrl"] as String;
      final publicUrl = signedUrlResponse["publicUrl"] as String;

      // (b) Upload the image
      await widget.apiClient.uploadImage(image.path, uploadUrl);

      // (c) Trigger server-side AI analysis
      final result = await widget.shoppingScanService.scanScreenshot(publicUrl);

      if (!mounted) return;
      setState(() {
        _scanResult = result;
        _isScreenshotLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        setState(() {
          _showRateLimit = true;
          _isScreenshotLoading = false;
          _screenshotImagePath = null;
        });
      } else if (e.statusCode == 422) {
        setState(() {
          _errorMessage = e.message.isNotEmpty
              ? e.message
              : "Unable to identify clothing in this image. Try a clearer photo or paste a product URL instead.";
          _isScreenshotLoading = false;
          _screenshotImagePath = null;
        });
      } else {
        setState(() {
          _errorMessage = "Something went wrong. Please try again.";
          _isScreenshotLoading = false;
          _screenshotImagePath = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
        _isScreenshotLoading = false;
        _screenshotImagePath = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Shopping Assistant"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                "Check if a potential purchase matches your wardrobe",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // URL Input
              Semantics(
                label: "Product URL input",
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: "Paste product URL here...",
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),

              // Paste from clipboard button
              Semantics(
                label: "Paste from clipboard",
                child: TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text("Paste from Clipboard"),
                ),
              ),
              const SizedBox(height: 16),

              // Analyze button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  label: "Analyze product URL",
                  child: ElevatedButton(
                    onPressed: _urlController.text.trim().isEmpty || _isLoading
                        ? null
                        : _analyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text("Scraping product details..."),
                            ],
                          )
                        : const Text(
                            "Analyze",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Screenshot upload card (active)
              Semantics(
                label: "Upload Screenshot",
                child: GestureDetector(
                  onTap: _isScreenshotLoading ? null : _showScreenshotOptions,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.camera_alt, color: Color(0xFF4F46E5)),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Upload Screenshot",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              "Analyze from photo or screenshot",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Screenshot preview with loading
              if (_isScreenshotLoading && _screenshotImagePath != null)
                Semantics(
                  label: "Screenshot preview",
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.file(
                                File(_screenshotImagePath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned.fill(
                                child: Container(
                                  color: Colors.white.withAlpha(128),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Analyzing screenshot...",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Rate limit gate
              if (_showRateLimit)
                PremiumGateCard(
                  title: "Daily Scan Limit Reached",
                  subtitle:
                      "Free users get 3 scans per day. Go Premium for unlimited scans.",
                  icon: Icons.shopping_bag_outlined,
                  subscriptionService: widget.subscriptionService,
                ),

              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Try a URL instead",
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                ),

              // Scan result
              if (_scanResult != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final scan = _scanResult!;
    return Semantics(
      label: "Scan result for ${scan.displayName}",
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            if (scan.hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  scan.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),
            if (scan.hasImage) const SizedBox(height: 12),

            // Product name
            Text(
              scan.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),

            // Brand
            if (scan.brand != null) ...[
              const SizedBox(height: 4),
              Text(
                scan.brand!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],

            // Price
            if (scan.displayPrice.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scan.displayPrice,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],

            // Metadata chips
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (scan.category != null) _buildChip(scan.category!),
                if (scan.color != null) _buildChip(scan.color!),
                if (scan.style != null) _buildChip(scan.style!),
                if (scan.pattern != null && scan.pattern != "solid")
                  _buildChip(scan.pattern!),
                if (scan.material != null && scan.material != "unknown")
                  _buildChip(scan.material!),
              ],
            ),

            // Review & Edit button (Story 8.3)
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: "Review & Edit",
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductReviewScreen(
                          initialScan: _scanResult!,
                          shoppingScanService: widget.shoppingScanService,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Review & Edit"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}
