import 'package:flutter/material.dart';
import '../screens/landing_screen.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _isForceLogoutInProgress = false;

  void forceLogoutToLanding() {
    if (_isForceLogoutInProgress) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _isForceLogoutInProgress = true;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    ).whenComplete(() {
      _isForceLogoutInProgress = false;
    });
  }
}
