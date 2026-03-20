import "package:flutter/material.dart";

/// Screen displayed when a user has signed up with email but has not
/// yet verified their email address.
class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({
    required this.email,
    required this.onCheckVerification,
    required this.onResendEmail,
    required this.onSignOut,
    super.key,
  });

  final String email;
  final Future<bool> Function() onCheckVerification;
  final Future<void> Function() onResendEmail;
  final VoidCallback onSignOut;

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _isError = false;

  Future<void> _checkVerification() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    try {
      final verified = await widget.onCheckVerification();
      if (!verified && mounted) {
        setState(() {
          _message = "Email not yet verified. Please check your inbox.";
          _isError = true;
        });
      }
      // If verified, the parent will handle navigation.
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = "Could not check verification status. Please try again.";
          _isError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      await widget.onResendEmail();
      if (mounted) {
        setState(() {
          _message = "Verification email sent! Check your inbox.";
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = "Could not send verification email. Please try again.";
          _isError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  "Verify your email",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF1F2937),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "We sent a verification link to\n${widget.email}",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Please check your inbox and tap the link to continue.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9CA3AF),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Status message
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isError ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // "I've verified my email" button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  button: true,
                  label: "I've verified my email",
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("I've verified my email"),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Resend verification email button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  button: true,
                  label: "Resend verification email",
                  child: OutlinedButton(
                    onPressed: _isResending ? null : _resendEmail,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Resend verification email"),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Sign out / use different account
              Semantics(
                button: true,
                label: "Use a different account",
                child: TextButton(
                  onPressed: widget.onSignOut,
                  child: const Text(
                    "Use a different account",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
