import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class PasswordResetScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authService
                      .sendPasswordResetEmail(emailController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Password reset email sent')));
                  Navigator.pop(context);
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.message}')));
                }
              },
              child: Text('Send Reset Email'),
            ),
          ],
        ),
      ),
    );
  }
}
