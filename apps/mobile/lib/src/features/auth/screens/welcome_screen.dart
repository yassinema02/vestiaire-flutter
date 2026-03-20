import "package:flutter/material.dart";

/// Callback types for sign-in actions.
typedef VoidCallback = void Function();

/// The unauthenticated entry point / welcome screen.
///
/// Displays the Vestiaire branding, value proposition, and three
/// sign-in options: Apple, Google, and Email sign-up, plus a
/// link to sign in for existing users.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.onSignInWithApple,
    required this.onSignInWithGoogle,
    required this.onSignUpWithEmail,
    required this.onSignIn,
    this.isLoading = false,
    this.errorMessage,
    super.key,
  });

  final Future<void> Function() onSignInWithApple;
  final Future<void> Function() onSignInWithGoogle;
  final VoidCallback onSignUpWithEmail;
  final VoidCallback onSignIn;
  final bool isLoading;
  final String? errorMessage;

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
              // Branding
              Semantics(
                header: true,
                child: Text(
                  "Vestiaire",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: const Color(0xFF1F2937),
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your AI-powered wardrobe assistant",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // Error message
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Apple Sign-In button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  button: true,
                  label: "Continue with Apple",
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onSignInWithApple,
                    icon: const Icon(Icons.apple, size: 24),
                    label: const Text("Continue with Apple"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Google Sign-In button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  button: true,
                  label: "Continue with Google",
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : onSignInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text("Continue with Google"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F2937),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Email Sign-Up button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: Semantics(
                  button: true,
                  label: "Sign up with Email",
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSignUpWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Sign up with Email"),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const CircularProgressIndicator()
              else
                // "Already have an account? Sign in" link
                Semantics(
                  button: true,
                  label: "Already have an account? Sign in",
                  child: TextButton(
                    onPressed: onSignIn,
                    child: const Text(
                      "Already have an account? Sign in",
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
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
