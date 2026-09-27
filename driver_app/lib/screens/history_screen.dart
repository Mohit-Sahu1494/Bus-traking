import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/trip_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<TripProvider>().loadHistory();
    if (mounted) setState(() => _loading = false);
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '—';
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final mins = (ms / 60000).round();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return '${hrs}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final history = trip.history;

    // Filter today's trips
    final now = DateTime.now();
    final todayTrips = history.where((t) {
      final start = DateTime.tryParse(t['startTime']?.toString() ?? '');
      if (start == null) return false;
      return start.year == now.year && start.month == now.month && start.day == now.day;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history, size: 48, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No trips today',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.navy),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Start your first campus bus trip to record GPS tracking, completed stops, and passenger history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Today Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TODAY',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 1.0),
                          ),
                          Text(
                            '${todayTrips.length} ${todayTrips.length == 1 ? 'Trip' : 'Trips'}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.navy),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Trip List
                    ...history.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final t = entry.value;
                      final tripNum = history.length - idx;
                      final status = t['status']?.toString() ?? 'COMPLETED';
                      final start = DateTime.tryParse(t['startTime']?.toString() ?? '');
                      final end = DateTime.tryParse(t['endTime']?.toString() ?? '');
                      final durMs = (t['duration'] as num?)?.toInt();
                      final completedStops = (t['completedStops'] as List?)?.length ?? 0;
                      final skippedStops = (t['skippedStops'] as List?)?.length ?? 0;

                      final isCompleted = status == 'COMPLETED';
                      final color = isCompleted ? AppTheme.emerald : (status == 'ACTIVE' ? AppTheme.primary : AppTheme.coral);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showTripDetails(context, t, tripNum),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Trip #${tripNum.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.navy),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 14, color: AppTheme.muted),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_formatTime(start)} — ${_formatTime(end)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                    if (durMs != null) ...[
                                      const SizedBox(width: 8),
                                      Text('(${_formatDuration(durMs)})', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Stops: $completedStops completed', style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
                                    if (skippedStops > 0) ...[
                                      const SizedBox(width: 8),
                                      Text('• $skippedStops skipped', style: const TextStyle(fontSize: 12, color: AppTheme.coral, fontWeight: FontWeight.w600)),
                                    ],
                                    const Spacer(),
                                    const Text('Details →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  void _showTripDetails(BuildContext context, Map<String, dynamic> t, int tripNum) {
    final start = DateTime.tryParse(t['startTime']?.toString() ?? '');
    final end = DateTime.tryParse(t['endTime']?.toString() ?? '');
    final durMs = (t['duration'] as num?)?.toInt();
    final busNumber = t['busNumber']?.toString() ?? 'BUS-04';
    final completed = (t['completedStops'] as List?) ?? [];
    final skipped = (t['skippedStops'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trip #${tripNum.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                  child: Text(t['status']?.toString() ?? 'COMPLETED', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Bus Assigned', busNumber),
            _detailRow('Start Time', _formatTime(start)),
            _detailRow('End Time', _formatTime(end)),
            _detailRow('Duration', _formatDuration(durMs)),
            _detailRow('Completed Stops', '${completed.length} stops (${completed.join(', ')})'),
            _detailRow('Skipped Stops', skipped.isEmpty ? 'None' : '${skipped.length} stops (${skipped.join(', ')})'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.muted, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy)),
          ),
        ],
      ),
    );
  }
}
