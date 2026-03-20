import "package:flutter/material.dart";

import "../constants/taxonomy_constants.dart";
import "../models/shopping_scan.dart";
import "../services/shopping_scan_service.dart";
import "compatibility_score_screen.dart";

/// Screen for reviewing and editing AI-extracted product metadata.
///
/// Displays taxonomy fields as tappable chips, a formality slider,
/// and text fields for product name, brand, and price.
/// The user can confirm edits (PATCH API) or skip review.
///
/// Story 8.3: Review Extracted Product Data (FR-SHP-05)
class ProductReviewScreen extends StatefulWidget {
  const ProductReviewScreen({
    required this.initialScan,
    required this.shoppingScanService,
    super.key,
  });

  final ShoppingScan initialScan;
  final ShoppingScanService shoppingScanService;

  @override
  State<ProductReviewScreen> createState() => _ProductReviewScreenState();
}

class _ProductReviewScreenState extends State<ProductReviewScreen> {
  late ShoppingScan _editedScan;
  bool _isSubmitting = false;

  late TextEditingController _productNameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _editedScan = widget.initialScan.copyWith();
    _productNameController =
        TextEditingController(text: widget.initialScan.productName ?? "");
    _brandController =
        TextEditingController(text: widget.initialScan.brand ?? "");
    _priceController = TextEditingController(
      text: widget.initialScan.price != null
          ? widget.initialScan.price.toString()
          : "",
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _updateScan(ShoppingScan updated) {
    setState(() {
      _editedScan = updated;
    });
  }

  Future<void> _onConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final updates = _editedScan.toJson();
      await widget.shoppingScanService
          .updateScan(widget.initialScan.id, updates);
      if (!mounted) return;
      // Navigate to CompatibilityScoreScreen (Story 8.4)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CompatibilityScoreScreen(
            scanId: widget.initialScan.id,
            scan: _editedScan,
            shoppingScanService: widget.shoppingScanService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e")),
      );
    }
  }

  void _onSkipReview() {
    // Navigate to CompatibilityScoreScreen (Story 8.4)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CompatibilityScoreScreen(
          scanId: widget.initialScan.id,
          scan: widget.initialScan,
          shoppingScanService: widget.shoppingScanService,
        ),
      ),
    );
  }

  void _showSingleSelectBottomSheet({
    required String title,
    required List<String> options,
    required String? currentValue,
    required void Function(String) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((option) {
                          final isSelected = option == currentValue;
                          return Semantics(
                            label: "$title option: $option",
                            child: ChoiceChip(
                              label: Text(option),
                              selected: isSelected,
                              selectedColor: const Color(0xFF4F46E5).withAlpha(51),
                              checkmarkColor: const Color(0xFF4F46E5),
                              onSelected: (_) {
                                onSelected(option);
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiSelectBottomSheet({
    required String title,
    required List<String> options,
    required List<String> currentValues,
    required void Function(List<String>) onChanged,
  }) {
    List<String> selected = List<String>.from(currentValues);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              maxChildSize: 0.8,
              minChildSize: 0.3,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              onChanged(selected);
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              "Done",
                              style: TextStyle(color: Color(0xFF4F46E5)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: options.map((option) {
                              final isSelected = selected.contains(option);
                              return Semantics(
                                label: "$title option: $option",
                                child: FilterChip(
                                  label: Text(option),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF4F46E5).withAlpha(51),
                                  checkmarkColor: const Color(0xFF4F46E5),
                                  onSelected: (val) {
                                    setSheetState(() {
                                      if (val) {
                                        selected.add(option);
                                      } else {
                                        selected.remove(option);
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      // Ensure changes are applied even if the sheet is dismissed
      onChanged(selected);
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildTaxonomyChip({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String) onSelected,
  }) {
    return Semantics(
      label: "$label chip",
      child: GestureDetector(
        onTap: () {
          _showSingleSelectBottomSheet(
            title: "Select $label",
            options: options,
            currentValue: value,
            onSelected: onSelected,
          );
        },
        child: Chip(
          label: Text(value ?? "Select $label"),
          avatar: const Icon(Icons.edit, size: 16),
          backgroundColor: value != null ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
          side: BorderSide(
            color: value != null ? const Color(0xFF4F46E5).withAlpha(77) : const Color(0xFFD1D5DB),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required List<String>? values,
    required List<String> options,
    required void Function(List<String>) onChanged,
  }) {
    final currentValues = values ?? [];
    return Semantics(
      label: "$label chips",
      child: GestureDetector(
        onTap: () {
          _showMultiSelectBottomSheet(
            title: "Select $label",
            options: options,
            currentValues: currentValues,
            onChanged: onChanged,
          );
        },
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (currentValues.isEmpty)
              Chip(
                label: Text("Select $label"),
                avatar: const Icon(Icons.edit, size: 16),
                backgroundColor: const Color(0xFFF3F4F6),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              )
            else
              ...currentValues.map(
                (v) => Chip(
                  label: Text(v),
                  backgroundColor: const Color(0xFFEEF2FF),
                  side: BorderSide(
                    color: const Color(0xFF4F46E5).withAlpha(77),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            const Icon(Icons.edit, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Review Product"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product summary header (read-only)
              _buildProductHeader(),
              const SizedBox(height: 16),

              // Taxonomy single-select chips
              _buildSectionTitle("Category"),
              _buildTaxonomyChip(
                label: "Category",
                value: _editedScan.category,
                options: validCategories,
                onSelected: (val) =>
                    _updateScan(_editedScan.copyWith(category: val)),
              ),

              _buildSectionTitle("Color"),
              _buildTaxonomyChip(
                label: "Color",
                value: _editedScan.color,
                options: validColors,
                onSelected: (val) =>
                    _updateScan(_editedScan.copyWith(color: val)),
              ),

              _buildSectionTitle("Pattern"),
              _buildTaxonomyChip(
                label: "Pattern",
                value: _editedScan.pattern,
                options: validPatterns,
                onSelected: (val) =>
                    _updateScan(_editedScan.copyWith(pattern: val)),
              ),

              _buildSectionTitle("Material"),
              _buildTaxonomyChip(
                label: "Material",
                value: _editedScan.material,
                options: validMaterials,
                onSelected: (val) =>
                    _updateScan(_editedScan.copyWith(material: val)),
              ),

              _buildSectionTitle("Style"),
              _buildTaxonomyChip(
                label: "Style",
                value: _editedScan.style,
                options: validStyles,
                onSelected: (val) =>
                    _updateScan(_editedScan.copyWith(style: val)),
              ),

              // Multi-select chips
              _buildSectionTitle("Secondary Colors"),
              _buildMultiSelectChips(
                label: "Secondary Colors",
                values: _editedScan.secondaryColors,
                options: validColors,
                onChanged: (vals) =>
                    _updateScan(_editedScan.copyWith(secondaryColors: vals)),
              ),

              _buildSectionTitle("Season"),
              _buildMultiSelectChips(
                label: "Season",
                values: _editedScan.season,
                options: validSeasons,
                onChanged: (vals) =>
                    _updateScan(_editedScan.copyWith(season: vals)),
              ),

              _buildSectionTitle("Occasion"),
              _buildMultiSelectChips(
                label: "Occasion",
                values: _editedScan.occasion,
                options: validOccasions,
                onChanged: (vals) =>
                    _updateScan(_editedScan.copyWith(occasion: vals)),
              ),

              // Formality slider
              _buildSectionTitle("Formality Score"),
              _buildFormalitySlider(),

              // Text fields
              _buildSectionTitle("Product Name"),
              Semantics(
                label: "Product name field",
                child: TextField(
                  controller: _productNameController,
                  decoration: InputDecoration(
                    hintText: "Enter product name",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    _updateScan(_editedScan.copyWith(productName: val));
                  },
                ),
              ),

              _buildSectionTitle("Brand"),
              Semantics(
                label: "Brand field",
                child: TextField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    hintText: "Enter brand",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    _updateScan(_editedScan.copyWith(brand: val));
                  },
                ),
              ),

              _buildSectionTitle("Price"),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: "Price field",
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: "0.00",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          _updateScan(_editedScan.copyWith(price: parsed ?? 0));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: "Currency dropdown",
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: DropdownButton<String>(
                        value: _editedScan.currency ?? "GBP",
                        underline: const SizedBox(),
                        items: validCurrencies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _updateScan(_editedScan.copyWith(currency: val));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  label: "Confirm button",
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            "Confirm",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  label: "Skip Review button",
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _onSkipReview,
                    child: const Text(
                      "Skip Review",
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader() {
    final scan = widget.initialScan;
    return Container(
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
          if (scan.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                scan.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ),
          if (scan.hasImage) const SizedBox(height: 12),
          Text(
            scan.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
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
        ],
      ),
    );
  }

  Widget _buildFormalitySlider() {
    final value = (_editedScan.formalityScore ?? 5).toDouble();
    return Semantics(
      label: "Formality score slider",
      child: Container(
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
          children: [
            Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F46E5),
              ),
            ),
            Slider(
              value: value,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: const Color(0xFF4F46E5),
              onChanged: (newVal) {
                _updateScan(
                    _editedScan.copyWith(formalityScore: newVal.toInt()));
              },
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Very Casual",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                Text(
                  "Black Tie",
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
