import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';
import 'dashboard_screen.dart';
import '../live/live_operations_screen.dart';
import '../bookings/bookings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final AuthService _authService = AuthService();

  final List<_AdminMenuItem> _menuItems = const [
    _AdminMenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    _AdminMenuItem(
      title: 'Live',
      icon: Icons.location_on_outlined,
    ),
    _AdminMenuItem(
      title: 'Bookings',
      icon: Icons.calendar_month_outlined,
    ),
    _AdminMenuItem(
      title: 'Walkers',
      icon: Icons.directions_walk_outlined,
    ),
    _AdminMenuItem(
      title: 'Customers',
      icon: Icons.people_outline,
    ),
    _AdminMenuItem(
      title: 'Pets',
      icon: Icons.pets_outlined,
    ),
    _AdminMenuItem(
      title: 'Zones',
      icon: Icons.map_outlined,
    ),
    _AdminMenuItem(
      title: 'Payments',
      icon: Icons.credit_card_outlined,
    ),
    _AdminMenuItem(
      title: 'Earnings',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _AdminMenuItem(
      title: 'Notifications',
      icon: Icons.notifications_none_outlined,
    ),
    _AdminMenuItem(
      title: 'Support',
      icon: Icons.support_agent_outlined,
    ),
    _AdminMenuItem(
      title: 'Analytics',
      icon: Icons.analytics_outlined,
    ),
    _AdminMenuItem(
      title: 'Reports',
      icon: Icons.description_outlined,
    ),
    _AdminMenuItem(
      title: 'Audit Logs',
      icon: Icons.security_outlined,
    ),
    _AdminMenuItem(
      title: 'Admin Users',
      icon: Icons.admin_panel_settings_outlined,
    ),
    _AdminMenuItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
    ),
  ];

  Future<void> _logout() async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileLayout();
        }

        return _buildDesktopLayout();
      },
    );
  }

  // DESKTOP LAYOUT

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // MOBILE LAYOUT

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'DOJO WALK',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: _buildDrawerContent(),
        ),
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildMobileBottomBar(),
    );
  }

  // DESKTOP SIDEBAR

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFEAEAEA),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'D',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DOJO WALK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final selected = _selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor:
                          const Color(0xFFFF6A00)
                              .withValues(alpha: 0.10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        item.icon,
                        color: selected
                            ? const Color(0xFFFF6A00)
                            : Colors.grey.shade700,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? const Color(0xFFFF6A00)
                              : Colors.grey.shade800,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // MOBILE DRAWER

  Widget _buildDrawerContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6A00),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Text(
            'D',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'DOJO WALK',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          'ADMIN',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.builder(
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              final selected = _selectedIndex == index;

              return ListTile(
                selected: selected,
                selectedTileColor:
                    const Color(0xFFFF6A00)
                        .withValues(alpha: 0.10),
                leading: Icon(
                  item.icon,
                  color: selected
                      ? const Color(0xFFFF6A00)
                      : Colors.grey.shade700,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected
                        ? const Color(0xFFFF6A00)
                        : Colors.grey.shade800,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: _logout,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // TOP BAR

  Widget _buildTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEAEAEA),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            _menuItems[_selectedIndex].title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFFF6A00),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              FirebaseAuth.instance.currentUser?.email ?? 'Admin',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CONTENT ROUTER

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return const DashboardScreen();
    }

    if (_selectedIndex == 1) {
      return const LiveOperationsScreen();
    }

    if (_selectedIndex == 2) {
      return const BookingsScreen();
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          '${_menuItems[_selectedIndex].title} Screen',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // MOBILE BOTTOM NAVIGATION

  Widget _buildMobileBottomBar() {
    final items = [
      _menuItems[0],
      _menuItems[1],
      _menuItems[2],
      _menuItems[3],
    ];

    final selectedIndex =
        _selectedIndex >= 0 && _selectedIndex <= 3
            ? _selectedIndex
            : 0;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: items.map((item) {
        return NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.icon),
          label: item.title,
        );
      }).toList(),
    );
  }
}

class _AdminMenuItem {
  final String title;
  final IconData icon;

  const _AdminMenuItem({
    required this.title,
    required this.icon,
  });
}
