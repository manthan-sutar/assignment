import 'package:flutter/material.dart';
import 'phone_input_page.dart';

/**
 * Sign In Page
 * Redirects to phone input page for phone authentication
 */
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneInputPage();
  }
}
