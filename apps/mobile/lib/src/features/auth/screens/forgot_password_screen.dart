import "package:flutter/material.dart";

/// Screen for requesting a password reset email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    required this.onSendResetLink,
    this.onBackToSignIn,
    super.key,
  });

  /// Called with the email address when the form is submitted.
  /// Should call AuthService.sendPasswordResetEmail.
  final Future<void> Function(String email) onSendResetLink;

  /// Called when the user taps "Back to Sign In".
  final VoidCallback? onBackToSignIn;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    try {
      await widget.onSendResetLink(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Something went wrong. Please try again.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: widget.onBackToSignIn != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                onPressed: widget.onBackToSignIn,
              )
            : null,
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Color(0xFF1F2937)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // Description text
                const Text(
                  "Enter your email address and we'll send you a link to reset your password.",
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Success message
                if (_isSuccess) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        "If an account exists for this email, a reset link has been sent.",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Email field
                Semantics(
                  label: "Email address",
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: "Email",
                      hintText: "you@example.com",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                    validator: _validateEmail,
                  ),
                ),
                const SizedBox(height: 24),
                // Submit button
                SizedBox(
                  height: 50,
                  child: Semantics(
                    button: true,
                    label: "Send reset link",
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Send Reset Link"),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Back to sign in
                Semantics(
                  button: true,
                  label: "Back to Sign In",
                  child: TextButton(
                    onPressed: widget.onBackToSignIn,
                    child: const Text(
                      "Back to Sign In",
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
