import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: isWide
          ? _wideLayout(authState)
          : _narrowLayout(authState),
    );
  }

  // ── Wide layout: left brand panel + right form ─────────────────────────────

  Widget _wideLayout(AuthState authState) {
    return Row(children: [
      // Left: brand panel
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [GemColors.darkSurface, Color(0xFF0F1F0F)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/gem_logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'TSI Task Manager',
                style: TextStyle(
                  color: GemColors.green,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Streamline your team\'s workflow',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 48),
              // Feature bullets
              ...[
                (Icons.assignment_turned_in_outlined,
                    'Assign & track tasks'),
                (Icons.people_alt_outlined, 'Team workload visibility'),
                (Icons.bar_chart_outlined, 'Real-time reports'),
              ].map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.$1,
                            color:
                                GemColors.green.withOpacity(0.8),
                            size: 18),
                        const SizedBox(width: 10),
                        Text(f.$2,
                            style: TextStyle(
                                color:
                                    Colors.white.withOpacity(0.65),
                                fontSize: 13)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
      // Right: form
      SizedBox(
        width: 460,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _loginForm(authState),
          ),
        ),
      ),
    ]);
  }

  // ── Narrow layout: centred card ────────────────────────────────────────────

  Widget _narrowLayout(AuthState authState) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _loginForm(authState),
        ),
      ),
    );
  }

  // ── Shared login form ──────────────────────────────────────────────────────

  Widget _loginForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo (narrow only) / Header
          Center(
            child: Image.asset(
              'assets/images/gem_logo.png',
              height: 72,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Welcome back',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Sign in to TSI Task Manager',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 32),

          // Email or Username
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email or Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your email or username'
                : null,
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Enter your password'
                : null,
            onFieldSubmitted: (_) =>
                authState.isLoading ? null : _handleLogin(),
          ),
          const SizedBox(height: 24),

          // Login button
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed:
                  authState.isLoading ? null : _handleLogin,
              style: FilledButton.styleFrom(
                backgroundColor: GemColors.green,
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Sign In',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
            ),
          ),

          // Error
          if (authState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.error_outline,
                    color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(authState.error!,
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ),
        ],
      ),
    );
  }
}
