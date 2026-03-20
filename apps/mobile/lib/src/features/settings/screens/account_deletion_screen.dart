import "package:flutter/material.dart";

/// Screen for account deletion with GDPR right to erasure.
///
/// Displays a warning about permanent data deletion and requires
/// the user to type "DELETE" to confirm the action.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    required this.onAccountDeleted,
    required this.onDeleteRequested,
    this.onCancel,
    super.key,
  });

  /// Called after the API deletion succeeds to trigger session cleanup.
  final VoidCallback onAccountDeleted;

  /// Called to perform the actual API deletion. Returns a Future that
  /// completes on success or throws on failure.
  final Future<void> Function() onDeleteRequested;

  /// Called when the user taps Cancel. If null, Navigator.pop is used.
  final VoidCallback? onCancel;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isLoading = false;

  Future<void> _showConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ConfirmationDialog(),
    );

    if (confirmed == true && mounted) {
      await _performDeletion();
    }
  }

  Future<void> _performDeletion() async {
    setState(() => _isLoading = true);

    try {
      await widget.onDeleteRequested();
      if (mounted) {
        widget.onAccountDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete account. Please try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Delete Account"),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 64,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Delete Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Deleting your account will permanently remove:",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeletionItem("Your profile and personal information"),
                _buildDeletionItem("All wardrobe items and photos"),
                _buildDeletionItem("Notification preferences"),
                _buildDeletionItem("Your sign-in credentials"),
                const SizedBox(height: 24),
                const Text(
                  "This action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  Semantics(
                    label: "Delete My Account",
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _showConfirmationDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Delete My Account",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: "Cancel",
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (widget.onCancel != null) {
                                widget.onCancel!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeletionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "\u2022 ",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1F2937),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationDialog extends StatefulWidget {
  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isDeleteTyped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final typed = _controller.text.trim().toUpperCase() == "DELETE";
      if (typed != _isDeleteTyped) {
        setState(() => _isDeleteTyped = typed);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Semantics(
        label: "Are you sure?",
        child: const Text("Are you sure?"),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type DELETE to confirm account deletion.'),
          const SizedBox(height: 16),
          Semantics(
            label: "Type DELETE to confirm",
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "DELETE",
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Semantics(
          label: "Cancel confirmation",
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
        ),
        Semantics(
          label: "Confirm account deletion",
          child: TextButton(
            onPressed: _isDeleteTyped
                ? () => Navigator.of(context).pop(true)
                : null,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text("Confirm"),
          ),
        ),
      ],
    );
  }
}
