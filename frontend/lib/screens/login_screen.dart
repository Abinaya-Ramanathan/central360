import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    setState(() => _isSubmitting = true);
    
    try {
      final response = await ApiService.login(username, password);
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        
        final sectorCode = response['sectorCode'] as String?;
        final responseUsername = response['username'] as String? ?? username;
        final isAdmin = response['isAdmin'] as bool? ?? false;
        final isMainAdmin = response['isMainAdmin'] as bool? ?? false;
        
        // Store auth data for use across the app
        AuthService.setAuthData(
          username: responseUsername,
          isAdmin: isAdmin,
          isMainAdmin: isMainAdmin,
          initialSector: sectorCode,
        );
        
        // Navigate to home screen after successful login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              username: responseUsername,
              initialSector: sectorCode,
              isAdmin: isAdmin,
              isMainAdmin: isMainAdmin,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image with gradient fallback
          Container(
            decoration: const BoxDecoration(
              // Fallback gradient (shown if image fails)
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF8C42), // Warm orange
                  Color(0xFFFF6B35), // Deep orange
                  Color(0xFFFFA500), // Golden orange
                  Color(0xFFFF8C00), // Dark orange
                ],
              ),
            ),
            child: Image.asset(
              'assets/brand/c360-background.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                // If image fails, return empty so gradient shows through
                return const SizedBox.shrink();
              },
            ),
          ),
          // Content overlay - positioned lower to not hide C360 text
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 100.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Transparent container instead of white card
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Enter Admin or Employee',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                filled: false,
                                prefixIcon: const Icon(Icons.person, color: Color(0xFFFF8C42)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFF8C42), width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                ),
                                labelStyle: const TextStyle(color: Color(0xFFFF8C42)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter password',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  filled: false,
                                  prefixIcon: const Icon(Icons.lock, color: Color(0xFFFF8C42)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      color: const Color(0xFFFF8C42),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFF8C42), width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                                  ),
                                  labelStyle: const TextStyle(color: Color(0xFFFF8C42)),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B35),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


