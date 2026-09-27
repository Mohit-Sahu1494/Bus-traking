import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/bus_selection_sheet.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trip = context.watch<TripProvider>();
    final p = auth.profile;

    if (p == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final initial = p.name.isNotEmpty ? p.name[0].toUpperCase() : 'D';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Driver Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.navy),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Certified Campus Driver',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.email,
                        style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          p.phone,
                          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Assigned Vehicle Card
          // Assigned Vehicle Card (Sections 5, 34, 35)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.directions_bus, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASSIGNED BUS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip.busNumber.isNotEmpty ? trip.busNumber : p.busNumber,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.navy),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'VALID FLEET',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.border, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Change Bus', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    onPressed: () => showBusSelectionSheet(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Lifetime Statistics (Requirement #25)
          const Text(
            'STATISTICS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _statBox('Total Trips', '${p.totalTrips}', AppTheme.primary, Icons.route),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox('Completed', '${p.completedTrips}', AppTheme.emerald, Icons.check_circle_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statBox('Skipped Stops', '${p.skippedStops}', AppTheme.coral, Icons.warning_amber),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Settings Tile
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 20),
              ),
              title: const Text('Operational Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: const Text('GPS tracking interval and audio alerts', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Operational settings: GPS emits every 2.0s with high accuracy.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.coral,
                side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Logout'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out of the Driver App? Any active trip should be ended first.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                await trip.stop();
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Dr. Harisingh Gour University • Driver Portal v1.0.0',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
