import "dart:io";

import "package:flutter/material.dart";

import "../../../core/networking/api_client.dart";
import "extraction_progress_screen.dart";

/// Bulk Import Preview screen displaying selected photo thumbnails
/// with toggle selection, count display, and upload flow.
///
/// Story 10.1: Bulk Photo Gallery Selection (FR-EXT-01)
class BulkImportPreviewScreen extends StatefulWidget {
  const BulkImportPreviewScreen({
    required this.photoPaths,
    required this.apiClient,
    this.onImportComplete,
    super.key,
  });

  final List<String> photoPaths;
  final ApiClient apiClient;
  final VoidCallback? onImportComplete;

  @override
  State<BulkImportPreviewScreen> createState() =>
      _BulkImportPreviewScreenState();
}

class _BulkImportPreviewScreenState extends State<BulkImportPreviewScreen> {
  late List<bool> _selected;
  bool _isUploading = false;
  int _uploadedCount = 0;
  int _totalToUpload = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.photoPaths.length, true);
  }

  int get _selectedCount => _selected.where((s) => s).length;

  List<String> get _selectedPaths {
    final paths = <String>[];
    for (int i = 0; i < widget.photoPaths.length; i++) {
      if (_selected[i]) paths.add(widget.photoPaths[i]);
    }
    return paths;
  }

  void _togglePhoto(int index) {
    setState(() {
      _selected[index] = !_selected[index];
    });
  }

  Future<void> _startUpload() async {
    final paths = _selectedPaths;
    if (paths.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _totalToUpload = paths.length;
      _errorMessage = null;
    });

    try {
      // Step 1: Get bulk signed URLs
      final urlMaps = await widget.apiClient.getBulkSignedUploadUrls(
        count: paths.length,
      );

      // Step 2: Upload each photo
      final successfulPhotos = <Map<String, String>>[];
      int failedCount = 0;

      for (int i = 0; i < paths.length; i++) {
        if (!mounted || !_isUploading) break;

        try {
          final urlInfo = urlMaps[i];
          final uploadUrl = urlInfo["uploadUrl"] as String;
          final publicUrl = urlInfo["publicUrl"] as String;

          await widget.apiClient.uploadImage(paths[i], uploadUrl);

          successfulPhotos.add({
            "photoUrl": publicUrl,
            "originalFilename": paths[i].split("/").last,
          });
        } catch (_) {
          failedCount++;
        }

        if (mounted) {
          setState(() {
            _uploadedCount = i + 1;
          });
        }
      }

      if (!mounted || !_isUploading) return;

      if (successfulPhotos.isEmpty) {
        setState(() {
          _isUploading = false;
          _errorMessage = "All uploads failed. Please try again.";
        });
        return;
      }

      // Step 3: Create extraction job
      final jobResult = await widget.apiClient.createExtractionJob(
        totalPhotos: successfulPhotos.length,
        photos: successfulPhotos,
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      final jobId = (jobResult["job"] as Map<String, dynamic>?)?["id"] as String?
          ?? jobResult["id"] as String?;

      if (failedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "$failedCount photo(s) failed to upload. Job created with ${successfulPhotos.length} photos.",
            ),
          ),
        );
      }

      // Navigate to ExtractionProgressScreen
      if (mounted && jobId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ExtractionProgressScreen(
              jobId: jobId,
              apiClient: widget.apiClient,
            ),
          ),
        );
      } else if (mounted) {
        // Fallback: pop back to wardrobe
        widget.onImportComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = "Import failed. Please try again.";
        });
      }
    }
  }

  Future<bool> _showCancelDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Import"),
        content: const Text(
          "Cancel import? Uploaded photos will be discarded.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Continue Upload"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Cancel Import"),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _showCancelDialog();
        if (shouldPop && mounted) {
          setState(() { _isUploading = false; });
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: Semantics(
            label: "Bulk Import Preview",
            child: const Text("Bulk Import Preview"),
          ),
          backgroundColor: const Color(0xFFF3F4F6),
          elevation: 0,
          leading: Semantics(
            label: "Cancel Import",
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (_isUploading) {
                  final shouldCancel = await _showCancelDialog();
                  if (shouldCancel && mounted) {
                    setState(() { _isUploading = false; });
                    Navigator.of(context).pop();
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    label: "$_selectedCount photos selected",
                    child: Text(
                      "$_selectedCount photos selected",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: widget.photoPaths.length,
                      itemBuilder: (context, index) {
                        return _buildPhotoTile(index);
                      },
                    ),
                  ),
                ),
                // Start Import button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Semantics(
                      label: "Start Import",
                      child: ElevatedButton(
                        onPressed:
                            _selectedCount > 0 && !_isUploading
                                ? _startUpload
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Start Import",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Upload progress overlay
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Uploading $_uploadedCount of $_totalToUpload photos...",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _totalToUpload > 0
                                ? _uploadedCount / _totalToUpload
                                : 0,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(int index) {
    final isSelected = _selected[index];

    return Semantics(
      label: "Toggle photo selection",
      child: GestureDetector(
        onTap: _isUploading ? null : () => _togglePhoto(index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(widget.photoPaths[index]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(
                    Icons.image,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              if (!isSelected)
                Container(
                  color: Colors.grey.withValues(alpha: 0.6),
                  child: const Center(
                    child: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
