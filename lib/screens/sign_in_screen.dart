import 'package:appuser_sp/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'sign_up_screen.dart';
import 'password_reset_screen.dart';

class SignInScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'images/bg.png',
              fit: BoxFit.fill,
            ),
          ),
          
          // Foreground content
          SingleChildScrollView(
            
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const Text(
                    'DeteClass',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please login to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email Address',
                          textAlign: TextAlign.left,
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'email@email.com',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.blue.withOpacity(0.1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Password',
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: '**************',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.blue.withOpacity(0.1),
                            suffixIcon: Icon(Icons.visibility_off),
                          ),
                          obscureText: true,
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PasswordResetScreen(),
                                ),
                              ),
                              child: Text('Forgot Password?'),
                            ),
                          ],
                        ),
                        Center(
                          child: SizedBox(
                          width: double.infinity, // Adjust the width as needed
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await authService.signIn(
                                    emailController.text, passwordController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Signed in successfully')));
                                    Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => HomeScreen()), // Replace HomeScreen with your homepage screen
                              );
                              } on FirebaseAuthException catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.message}')));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              disabledForegroundColor: Colors.white.withOpacity(0.38),
                              disabledBackgroundColor: Colors.white.withOpacity(0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(color: Colors.white),
                              ),
                           ),
                          ),
                        ),
                        Center(
                          child: SizedBox(
                          child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpScreen()),
                    ),
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),
                  ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Or',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await authService.signInWithGoogle();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signed in with Google')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'images/google_icon.png',
                        height: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
