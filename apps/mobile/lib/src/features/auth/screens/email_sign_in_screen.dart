import "package:flutter/material.dart";

/// Screen for existing user sign-in with email and password.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({
    required this.onSignIn,
    this.onBackPressed,
    this.onForgotPassword,
    super.key,
  });

  /// Called with (email, password) when the form is valid and submitted.
  final Future<void> Function(String email, String password) onSignIn;
  final VoidCallback? onBackPressed;
  final VoidCallback? onForgotPassword;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSignIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapError(e);
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

  String _mapError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains("user-not-found")) {
      return "No account found with this email";
    }
    if (message.contains("wrong-password") ||
        message.contains("invalid-credential")) {
      return "Incorrect password. Please try again";
    }
    if (message.contains("invalid-email")) {
      return "Please enter a valid email address";
    }
    if (message.contains("too-many-requests")) {
      return "Too many attempts. Please try again later";
    }
    if (message.contains("network")) {
      return "Network error. Please check your connection and try again";
    }
    return "Sign-in failed. Please try again";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                onPressed: widget.onBackPressed,
              )
            : null,
        title: const Text(
          "Sign In",
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
                const SizedBox(height: 16),
                // Password field
                Semantics(
                  label: "Password",
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      hintText: "Enter your password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                ),
                const SizedBox(height: 8),
                // Forgot password link
                if (widget.onForgotPassword != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Semantics(
                      button: true,
                      label: "Forgot password",
                      child: TextButton(
                        onPressed: widget.onForgotPassword,
                        child: const Text(
                          "Forgot password?",
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Submit button
                SizedBox(
                  height: 50,
                  child: Semantics(
                    button: true,
                    label: "Sign in",
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
                          : const Text("Sign In"),
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
