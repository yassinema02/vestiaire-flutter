import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../core/networking/api_client.dart";
import "../models/taxonomy.dart";
import "../models/wardrobe_item.dart";
import "../widgets/tag_cloud.dart";

/// Screen for reviewing and editing AI-generated metadata for a wardrobe item.
///
/// Navigated to after AddItemScreen upload. Displays the item photo,
/// a TagCloud for editing taxonomy fields, and text inputs for optional
/// metadata (name, brand, purchase price, purchase date, currency).
class ReviewItemScreen extends StatefulWidget {
  const ReviewItemScreen({
    required this.item,
    required this.apiClient,
    super.key,
  });

  /// The item to review. May have pending categorization.
  final WardrobeItem item;

  /// API client for fetching updates and saving edits.
  final ApiClient apiClient;

  @override
  State<ReviewItemScreen> createState() => _ReviewItemScreenState();
}

class _ReviewItemScreenState extends State<ReviewItemScreen> {
  // Editable taxonomy state
  late String? _category;
  late String? _color;
  late List<String> _secondaryColors;
  late String? _pattern;
  late String? _material;
  late String? _style;
  late List<String> _season;
  late List<String> _occasion;

  // Editable optional metadata
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  String? _purchaseDate;
  late String _currency;

  // State
  bool _isLoading = false;
  bool _isSaving = false;
  // ignore: unused_field
  bool _isCategorizationPending = false;
  bool _isCategorizationFailed = false;
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPollRetries = 10;

  // Form validation
  String? _nameError;
  String? _brandError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _initFromItem(widget.item);

    if (widget.item.isCategorizationPending) {
      _isCategorizationPending = true;
      _isLoading = true;
      _startPolling();
    } else if (widget.item.isCategorizationFailed) {
      _isCategorizationFailed = true;
      _setDefaults();
    }
  }

  void _initFromItem(WardrobeItem item) {
    _category = item.category;
    _color = item.color;
    _secondaryColors = List<String>.from(item.secondaryColors ?? []);
    _pattern = item.pattern;
    _material = item.material;
    _style = item.style;
    _season = List<String>.from(item.season ?? []);
    _occasion = List<String>.from(item.occasion ?? []);
    _nameController = TextEditingController(text: item.name ?? "");
    _brandController = TextEditingController(text: item.brand ?? "");
    _priceController = TextEditingController(
      text: item.purchasePrice != null ? item.purchasePrice.toString() : "",
    );
    _purchaseDate = item.purchaseDate;
    _currency = item.currency ?? "GBP";
  }

  void _setDefaults() {
    _category ??= "other";
    _color ??= "unknown";
    _pattern ??= "solid";
    _material ??= "unknown";
    _style ??= "casual";
    if (_season.isEmpty) _season = ["all"];
    if (_occasion.isEmpty) _occasion = ["everyday"];
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForCategorization();
    });
  }

  Future<void> _pollForCategorization() async {
    if (!mounted) {
      _pollingTimer?.cancel();
      return;
    }

    _pollCount++;
    if (_pollCount > _maxPollRetries) {
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCategorizationPending = false;
          _isCategorizationFailed = true;
          _setDefaults();
        });
      }
      return;
    }

    try {
      final result = await widget.apiClient.getItem(widget.item.id);
      final itemData = result["item"] as Map<String, dynamic>?;
      if (itemData == null) return;

      final updatedItem = WardrobeItem.fromJson(itemData);

      if (mounted) {
        if (updatedItem.isCategorizationCompleted) {
          _pollingTimer?.cancel();
          setState(() {
            _category = updatedItem.category;
            _color = updatedItem.color;
            _secondaryColors =
                List<String>.from(updatedItem.secondaryColors ?? []);
            _pattern = updatedItem.pattern;
            _material = updatedItem.material;
            _style = updatedItem.style;
            _season = List<String>.from(updatedItem.season ?? []);
            _occasion = List<String>.from(updatedItem.occasion ?? []);
            _isLoading = false;
            _isCategorizationPending = false;
          });
        } else if (updatedItem.isCategorizationFailed) {
          _pollingTimer?.cancel();
          setState(() {
            _isLoading = false;
            _isCategorizationPending = false;
            _isCategorizationFailed = true;
            _setDefaults();
          });
        }
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  bool get _hasFormErrors =>
      _nameError != null || _brandError != null || _priceError != null;

  void _validateName(String value) {
    setState(() {
      _nameError = value.length > 200
          ? "Name must be at most 200 characters"
          : null;
    });
  }

  void _validateBrand(String value) {
    setState(() {
      _brandError = value.length > 100
          ? "Brand must be at most 100 characters"
          : null;
    });
  }

  void _validatePrice(String value) {
    if (value.isEmpty) {
      setState(() => _priceError = null);
      return;
    }
    final parsed = double.tryParse(value);
    setState(() {
      if (parsed == null) {
        _priceError = "Must be a valid number";
      } else if (parsed < 0) {
        _priceError = "Must be >= 0";
      } else {
        _priceError = null;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate != null
          ? DateTime.tryParse(_purchaseDate!) ?? now
          : now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() {
        _purchaseDate = picked.toIso8601String().split("T")[0];
      });
    }
  }

  Future<void> _saveItem() async {
    if (_hasFormErrors || _isSaving) return;

    setState(() => _isSaving = true);

    final fields = <String, dynamic>{};
    if (_category != null) fields["category"] = _category;
    if (_color != null) fields["color"] = _color;
    fields["secondaryColors"] = _secondaryColors;
    if (_pattern != null) fields["pattern"] = _pattern;
    if (_material != null) fields["material"] = _material;
    if (_style != null) fields["style"] = _style;
    fields["season"] = _season;
    fields["occasion"] = _occasion;
    if (_nameController.text.isNotEmpty) {
      fields["name"] = _nameController.text;
    }
    if (_brandController.text.isNotEmpty) {
      fields["brand"] = _brandController.text;
    }
    if (_priceController.text.isNotEmpty) {
      final price = double.tryParse(_priceController.text);
      if (price != null) fields["purchasePrice"] = price;
    }
    if (_purchaseDate != null) fields["purchaseDate"] = _purchaseDate;
    fields["currency"] = _currency;

    try {
      await widget.apiClient.updateItem(widget.item.id, fields);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save changes. Please try again."),
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Review Item",
          style: TextStyle(color: Color(0xFF1F2937)),
        ),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: Semantics(
          label: "Back",
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item photo
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: Image.network(
                          widget.item.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: const Color(0xFFE5E7EB),
                            child: const Center(
                              child: Icon(Icons.image, size: 64,
                                  color: Color(0xFF9CA3AF)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Categorization failure banner
                  if (_isCategorizationFailed) _buildFailureBanner(),

                  // Tag Cloud
                  const Text(
                    "Tags",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TagCloud(
                    isLoading: _isLoading,
                    groups: _buildTagGroups(),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Optional metadata fields
                  const Text(
                    "Details",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  Semantics(
                    label: "Item name",
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Item Name",
                        hintText: "e.g., Blue Oxford Shirt",
                        errorText: _nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: _validateName,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Brand
                  Semantics(
                    label: "Brand",
                    child: TextFormField(
                      controller: _brandController,
                      decoration: InputDecoration(
                        labelText: "Brand",
                        hintText: "e.g., Zara, Nike",
                        errorText: _brandError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: _validateBrand,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Purchase price
                  Semantics(
                    label: "Purchase price",
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: "Purchase Price",
                        hintText: "0.00",
                        errorText: _priceError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"^\d*\.?\d{0,2}"),
                        ),
                      ],
                      onChanged: _validatePrice,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Currency dropdown
                  Semantics(
                    label: "Currency",
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: "Currency",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: validCurrencies
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _currency = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Purchase date
                  Semantics(
                    label: "Purchase date",
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Purchase Date",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _purchaseDate ?? "Not set",
                          style: TextStyle(
                            color: _purchaseDate != null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80), // Space for sticky button
                ],
              ),
            ),
          ),

          // Sticky Save button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Semantics(
                label: "Save Item",
                child: ElevatedButton(
                  onPressed: _hasFormErrors || _isSaving ? null : _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Save Item",
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
    );
  }

  Widget _buildFailureBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF92400E), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "AI couldn't identify this item -- please set the details manually.",
              style: TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TagGroup> _buildTagGroups() {
    if (_isLoading) return [];
    return [
      TagGroup(
        label: "Category",
        value: _category != null ? [_category!] : [],
        options: validCategories,
        onChanged: (v) => setState(() => _category = v.isNotEmpty ? v.first : null),
      ),
      TagGroup(
        label: "Color",
        value: _color != null ? [_color!] : [],
        options: validColors,
        onChanged: (v) => setState(() => _color = v.isNotEmpty ? v.first : null),
      ),
      TagGroup(
        label: "Secondary Colors",
        value: _secondaryColors,
        options: validColors,
        isMultiSelect: true,
        onChanged: (v) => setState(() => _secondaryColors = v),
      ),
      TagGroup(
        label: "Pattern",
        value: _pattern != null ? [_pattern!] : [],
        options: validPatterns,
        onChanged: (v) => setState(() => _pattern = v.isNotEmpty ? v.first : null),
      ),
      TagGroup(
        label: "Material",
        value: _material != null ? [_material!] : [],
        options: validMaterials,
        onChanged: (v) => setState(() => _material = v.isNotEmpty ? v.first : null),
      ),
      TagGroup(
        label: "Style",
        value: _style != null ? [_style!] : [],
        options: validStyles,
        onChanged: (v) => setState(() => _style = v.isNotEmpty ? v.first : null),
      ),
      TagGroup(
        label: "Season",
        value: _season,
        options: validSeasons,
        isMultiSelect: true,
        onChanged: (v) => setState(() => _season = v),
      ),
      TagGroup(
        label: "Occasion",
        value: _occasion,
        options: validOccasions,
        isMultiSelect: true,
        onChanged: (v) => setState(() => _occasion = v),
      ),
    ];
  }
}
