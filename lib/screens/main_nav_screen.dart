// Navigation principale avec BottomNavigationBar
// Issues #19, #20, #22, #27, #28 - Accueil, Carte, Favoris, Notifications, Profil
import 'dart:async';

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => MainNavScreenState();
}

class MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  int _unreadNotifs = 0;
  Timer? _notifPollingTimer;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _mapKey = GlobalKey<MapScreenState>();
  final _favKey = GlobalKey<FavoritesScreenState>();
  final _notifKey = GlobalKey<NotificationsScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(key: _homeKey),
      MapScreen(key: _mapKey),
      FavoritesScreen(key: _favKey),
      NotificationsScreen(key: _notifKey),
      ProfileScreen(key: _profileKey),
    ];
    _loadUnreadCount();
    _notifPollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _notifPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService().getUnreadCount();
    if (!mounted) return;
    setState(() => _unreadNotifs = count);
  }

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
    _refreshTab(index);
  }

  void _onTabTapped(int index) {
    switchToTab(index);
  }

  void _refreshTab(int index) {
    _loadUnreadCount();
    switch (index) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 1:
        _mapKey.currentState?.refresh();
        break;
      case 2:
        _favKey.currentState?.refresh();
        break;
      case 3:
        _notifKey.currentState?.refresh();
        break;
      case 4:
        _profileKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Carte',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoris',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _unreadNotifs > 0,
              label: Text(
                _unreadNotifs.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: _unreadNotifs > 0,
              label: Text(
                _unreadNotifs.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
