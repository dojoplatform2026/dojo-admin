import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Stream<int> _count(String collection) {
    return FirebaseFirestore.instance
        .collection(collection)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good morning, Admin 👋',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Here is what is happening across DOJO WALK today.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              int columns = 4;

              if (width < 1100) {
                columns = 2;
              }

              if (width < 600) {
                columns = 1;
              }

              final cardWidth =
                  (width - ((columns - 1) * 16)) / columns;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Total Bookings',
                      icon: Icons.calendar_month_outlined,
                      valueStream: _count('bookings'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Customers',
                      icon: Icons.people_outline,
                      valueStream: _count('customers'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Walkers',
                      icon: Icons.directions_walk_outlined,
                      valueStream: _count('walkers'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _StatCard(
                      title: 'Pets',
                      icon: Icons.pets_outlined,
                      valueStream: _count('pets'),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return Column(
                  children: [
                    _buildLiveOverview(),
                    const SizedBox(height: 20),
                    _buildRecentBookings(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLiveOverview(),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildRecentBookings(),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          _buildActivityFeed(),
        ],
      ),
    );
  }

  Widget _buildLiveOverview() {
    return _DashboardCard(
      title: 'Live Operations',
      icon: Icons.location_on_outlined,
      child: Column(
        children: [
          _LiveRow(
            label: 'Active Walks',
            value: '0',
            icon: Icons.directions_walk,
          ),
          const Divider(),
          _LiveRow(
            label: 'Available Walkers',
            value: '0',
            icon: Icons.person_outline,
          ),
          const Divider(),
          _LiveRow(
            label: 'Waiting Assignment',
            value: '0',
            icon: Icons.hourglass_empty,
          ),
          const Divider(),
          _LiveRow(
            label: 'GPS Alerts',
            value: '0',
            icon: Icons.gps_off,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBookings() {
    return _DashboardCard(
      title: 'Recent Bookings',
      icon: Icons.receipt_long_outlined,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Unable to load bookings.',
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No bookings yet.',
              ),
            );
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data();

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFFFF6A00)
                          .withValues(alpha: 0.10),
                  child: const Icon(
                    Icons.pets,
                    color: Color(0xFFFF6A00),
                  ),
                ),
                title: Text(
                  'Booking #${doc.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  data['status']?.toString() ?? 'Pending',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildActivityFeed() {
    return _DashboardCard(
      title: 'System Activity',
      icon: Icons.bolt_outlined,
      child: Column(
        children: const [
          _ActivityItem(
            title: 'Dashboard connected',
            subtitle: 'Firebase realtime connection ready',
            icon: Icons.cloud_done_outlined,
          ),
          Divider(),
          _ActivityItem(
            title: 'Admin security active',
            subtitle: 'Role verification enabled',
            icon: Icons.security_outlined,
          ),
          Divider(),
          _ActivityItem(
            title: 'Live operations',
            subtitle: 'Waiting for active walks',
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Stream<int> valueStream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.valueStream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A00)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF6A00),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                StreamBuilder<int>(
                  stream: valueStream,
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data ?? 0}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFFF6A00),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _LiveRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFFF6A00),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
