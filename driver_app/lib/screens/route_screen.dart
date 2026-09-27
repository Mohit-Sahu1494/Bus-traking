import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/trip_provider.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final stops = trip.routeStops;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Route Timeline'),
      ),
      body: stops.isEmpty
          ? const Center(
              child: Text(
                'No route loaded yet.\nStart a trip to see the live timeline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROUTE PROGRESS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${trip.completed.length} of ${stops.length} Stops Completed',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.navy),
                          ),
                        ],
                      ),
                      if (trip.skipped.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${trip.skipped.length} Skipped',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.coral),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.border),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: stops.length,
                    itemBuilder: (context, i) {
                      final stop = stops[i];
                      final seq = (stop['sequence'] as num?)?.toInt() ?? 0;
                      final name = stop['stop']?['name']?.toString() ?? 'Stop';
                      final isCurrent = trip.currentSequence == seq;
                      final isNext = trip.live?['nextStop']?['sequence'] == seq;
                      final isSkipped = trip.skipped.contains(seq);
                      final isCompleted = trip.completed.contains(seq);
                      final waiting = trip.waitingFor(name);
                      final pickup = trip.selectedFor(name);
                      final isLast = i == stops.length - 1;

                      Color nodeColor;
                      Widget nodeIcon;
                      String? badge;
                      Color? badgeBg;
                      Color? badgeFg;

                      if (isSkipped) {
                        nodeColor = AppTheme.coral;
                        nodeIcon = const Icon(Icons.close, size: 12, color: Colors.white);
                        badge = 'SKIPPED';
                        badgeBg = const Color(0xFFFEE2E2);
                        badgeFg = AppTheme.coral;
                      } else if (isCurrent) {
                        nodeColor = AppTheme.emerald;
                        nodeIcon = const Icon(Icons.directions_bus, size: 13, color: Colors.white);
                        badge = 'CURRENT';
                        badgeBg = const Color(0xFFECFDF5);
                        badgeFg = const Color(0xFF065F46);
                      } else if (isNext) {
                        nodeColor = AppTheme.amber;
                        nodeIcon = const Icon(Icons.star, size: 12, color: Colors.white);
                        badge = 'NEXT STOP';
                        badgeBg = const Color(0xFFFEF3C7);
                        badgeFg = const Color(0xFF92400E);
                      } else if (isCompleted) {
                        nodeColor = const Color(0xFF94A3B8);
                        nodeIcon = const Icon(Icons.check, size: 12, color: Colors.white);
                        badge = 'COMPLETED';
                        badgeBg = const Color(0xFFF1F5F9);
                        badgeFg = const Color(0xFF475569);
                      } else {
                        nodeColor = AppTheme.primaryLight;
                        nodeIcon = Text(
                          '$seq',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 32,
                              child: Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: nodeColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: nodeColor.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(child: nodeIcon),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrent || isNext ? Colors.white : const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.emerald
                                        : isNext
                                            ? AppTheme.amber
                                            : AppTheme.border,
                                    width: isCurrent || isNext ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isCurrent || isNext ? FontWeight.w800 : FontWeight.w600,
                                              color: isSkipped
                                                  ? AppTheme.coral
                                                  : isCompleted
                                                      ? AppTheme.muted
                                                      : AppTheme.navy,
                                              decoration: isSkipped ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        if (badge != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                            child: Text(
                                              badge,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeFg),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _statBadge(Icons.person_pin, 'Pickup: $pickup'),
                                        const SizedBox(width: 10),
                                        _statBadge(
                                          Icons.access_time,
                                          'Waiting: $waiting',
                                          highlight: waiting > 0,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statBadge(IconData icon, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: highlight ? AppTheme.primary : AppTheme.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppTheme.primary : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
