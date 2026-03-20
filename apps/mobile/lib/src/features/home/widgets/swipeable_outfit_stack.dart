import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../outfits/models/outfit_suggestion.dart";
import "outfit_suggestion_card.dart";

/// A swipeable card stack displaying outfit suggestions.
///
/// Users can swipe right to save or left to skip each suggestion.
/// Provides Save/Skip buttons as an accessible alternative to swiping.
class SwipeableOutfitStack extends StatefulWidget {
  const SwipeableOutfitStack({
    required this.suggestions,
    required this.onSave,
    this.onAllReviewed,
    super.key,
  });

  /// The list of outfit suggestions to display.
  final List<OutfitSuggestion> suggestions;

  /// Called when the user swipes right or taps Save.
  /// Returns true if save succeeded, false if failed.
  final Future<bool> Function(OutfitSuggestion) onSave;

  /// Called when all suggestions have been reviewed.
  final VoidCallback? onAllReviewed;

  @override
  State<SwipeableOutfitStack> createState() => SwipeableOutfitStackState();
}

/// Visible for testing.
class SwipeableOutfitStackState extends State<SwipeableOutfitStack>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragOffset = 0.0;
  bool _isSaving = false;
  int _savedCount = 0;

  late AnimationController _exitController;
  late AnimationController _springController;
  Animation<Offset>? _exitAnimation;
  Animation<double>? _springAnimation;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(SwipeableOutfitStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset when suggestions change (e.g., pull to refresh)
    if (oldWidget.suggestions != widget.suggestions) {
      setState(() {
        _currentIndex = 0;
        _dragOffset = 0.0;
        _isSaving = false;
        _savedCount = 0;
      });
      _exitController.reset();
      _springController.reset();
    }
  }

  @override
  void dispose() {
    _exitController.dispose();
    _springController.dispose();
    super.dispose();
  }

  bool get _isCompleted => _currentIndex >= widget.suggestions.length;

  OutfitSuggestion get _currentSuggestion =>
      widget.suggestions[_currentIndex];

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isSaving) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isSaving) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.4;

    if (_dragOffset > threshold) {
      _animateExit(isRight: true);
    } else if (_dragOffset < -threshold) {
      _animateExit(isRight: false);
    } else {
      _animateSpringBack();
    }
  }

  void _animateExit({required bool isRight}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = isRight ? screenWidth * 1.5 : -screenWidth * 1.5;

    _exitAnimation = Tween<Offset>(
      begin: Offset(_dragOffset, 0),
      end: Offset(targetX, 0),
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeOut,
    ));

    _exitController.reset();
    _exitController.forward().then((_) {
      if (!mounted) return;
      if (isRight) {
        _handleSaveAction();
      } else {
        _handleSkipAction();
      }
    });
  }

  void _animateSpringBack() {
    _springAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.easeOutBack,
    ));

    _springController.reset();
    _springController.addListener(_springListener);
    _springController.forward().then((_) {
      _springController.removeListener(_springListener);
    });
  }

  void _springListener() {
    if (!mounted) return;
    setState(() {
      _dragOffset = _springAnimation?.value ?? 0.0;
    });
  }

  Future<void> _handleSaveAction() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // _isSaving may already be true if triggered by button tap
    if (!_isSaving) {
      setState(() {
        _isSaving = true;
      });
    }

    final success = await widget.onSave(_currentSuggestion);

    if (!mounted) return;

    if (success) {
      setState(() {
        _savedCount++;
        _currentIndex++;
        _dragOffset = 0.0;
        _isSaving = false;
      });
      _exitController.reset();
      if (_isCompleted) {
        widget.onAllReviewed?.call();
      }
    } else {
      // Save failed -- spring back
      setState(() {
        _dragOffset = 0.0;
        _isSaving = false;
      });
      _exitController.reset();
    }
  }

  void _handleSkipAction() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex++;
      _dragOffset = 0.0;
    });
    _exitController.reset();
    if (_isCompleted) {
      widget.onAllReviewed?.call();
    }
  }

  void _onSaveButtonTap() {
    if (_isSaving || _isCompleted) return;
    setState(() {
      _isSaving = true;
    });
    _animateExit(isRight: true);
  }

  void _onSkipButtonTap() {
    if (_isSaving || _isCompleted) return;
    _animateExit(isRight: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCompletionState();
    }

    return Column(
      children: [
        _buildCardStack(),
        const SizedBox(height: 8),
        _buildPositionIndicator(),
        const SizedBox(height: 12),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildCardStack() {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.4;

    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Next card behind (if available)
          if (_currentIndex + 1 < widget.suggestions.length)
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(0, 8),
                child: Transform.scale(
                  scale: 0.95,
                  child: OutfitSuggestionCard(
                    suggestion: widget.suggestions[_currentIndex + 1],
                  ),
                ),
              ),
            ),

          // Current card
          AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) {
              Offset offset;
              if (_exitController.isAnimating && _exitAnimation != null) {
                offset = _exitAnimation!.value;
              } else {
                offset = Offset(_dragOffset, 0);
              }

              final rotation = (offset.dx / screenWidth) *
                  0.001 *
                  screenWidth.clamp(0, double.infinity);
              final clampedRotation = rotation.clamp(-0.15, 0.15);

              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: clampedRotation,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Semantics(
                label:
                    "Outfit suggestion ${_currentIndex + 1} of ${widget.suggestions.length}: ${_currentSuggestion.name}. Swipe right to save, swipe left to skip.",
                child: Stack(
                  children: [
                    OutfitSuggestionCard(
                      suggestion: _currentSuggestion,
                    ),
                    // Swipe overlay
                    _buildSwipeOverlay(threshold),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeOverlay(double threshold) {
    if (_dragOffset.abs() < 20) return const SizedBox.shrink();

    final opacity = min(1.0, _dragOffset.abs() / threshold);
    final isRight = _dragOffset > 0;

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isRight
              ? Color.fromRGBO(16, 185, 129, opacity * 0.7)
              : Color.fromRGBO(239, 68, 68, opacity * 0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRight ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  isRight ? "Save" : "Skip",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionIndicator() {
    return Text(
      "${_currentIndex + 1} of ${widget.suggestions.length}",
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF6B7280),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          label: "Skip outfit: ${_currentSuggestion.name}",
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _onSkipButtonTap,
            icon: const Icon(Icons.close, size: 18),
            label: const Text("Skip"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Semantics(
          label: "Save outfit: ${_currentSuggestion.name}",
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _onSaveButtonTap,
            icon: const Icon(Icons.check, size: 18),
            label: const Text("Save"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 48,
            color: Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          const Text(
            "All suggestions reviewed",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You saved $_savedCount outfit${_savedCount == 1 ? '' : 's'} today",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pull to refresh for new suggestions",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
