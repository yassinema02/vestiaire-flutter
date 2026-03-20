import "package:flutter/material.dart";

/// Screen for new user registration with email and password.
class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({
    required this.onSignUp,
    this.onBackPressed,
    super.key,
  });

  /// Called with (email, password) when the form is valid and submitted.
  final Future<void> Function(String email, String password) onSignUp;
  final VoidCallback? onBackPressed;

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
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
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(value)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }
    if (value.length < 8) {
      return "Password must be at least 8 characters";
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
      await widget.onSignUp(
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
    if (message.contains("email-already-in-use")) {
      return "An account with this email already exists";
    }
    if (message.contains("weak-password")) {
      return "Password is too weak. Please choose a stronger password";
    }
    if (message.contains("invalid-email")) {
      return "Please enter a valid email address";
    }
    if (message.contains("network")) {
      return "Network error. Please check your connection and try again";
    }
    return "Something went wrong. Please try again";
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
          "Create Account",
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
                      hintText: "At least 8 characters",
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
                const SizedBox(height: 24),
                // Submit button
                SizedBox(
                  height: 50,
                  child: Semantics(
                    button: true,
                    label: "Create account",
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
                          : const Text("Create Account"),
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
