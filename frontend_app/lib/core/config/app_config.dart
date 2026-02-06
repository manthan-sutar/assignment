/**
 * App Configuration
 * Centralized configuration constants
 */
class AppConfig {
  // Backend API base URL
  // For Android emulator, use 10.0.2.2 instead of localhost
  // For iOS simulator, use localhost
  // For physical device, use your computer's IP address (e.g., http://192.168.1.100:3000)
  static const String baseUrl = 'http://10.0.2.2:3000'; // Android emulator
  // static const String baseUrl = 'http://localhost:3000'; // iOS simulator
  // static const String baseUrl = 'http://192.168.1.100:3000'; // Physical device (replace with your IP)

  // API endpoints
  static const String signInEndpoint = '/auth/sign-in';
  static const String signUpEndpoint = '/auth/sign-up';
  static const String verifyTokenEndpoint = '/auth/verify-token';
  static const String meEndpoint = '/auth/me';
  static const String reelsEndpoint = '/reels';
}
