import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/live_provider.dart';

class UpcomingStopsScreen extends StatelessWidget {
  const UpcomingStopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveProvider>();
    final auth = context.watch<AuthProvider>();
    final userPickup = auth.user?.pickupStop?.name;
    final stops = live.routeStops;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: const Text('Campus Route & Stops'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: stops.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading campus stops...', style: TextStyle(color: AppTheme.muted)),
                ],
              ),
            )
          : Column(
              children: [
                // Summary Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'CIRCULAR ROUTE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppTheme.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stops.length} Total Route Stops',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (live.busStatus == 'ACTIVE' && live.nextStop != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.accent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'ETA: ${live.etaLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Stop Timeline
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: stops.length,
                    itemBuilder: (context, i) {
                      final stop = stops[i];
                      final seq = stop.sequence;
                      final isSkipped = live.skippedSequences.contains(seq);
                      final isCompleted = live.completedSequences.contains(seq);
                      final isCurrent = (live.currentStop?.sequence == seq || live.currentSequence == seq);
                      final isNext = live.nextStop?.sequence == seq;
                      final isMyPickup = userPickup != null && stop.stop.name == userPickup;
                      final waiting = live.waitingAt(stop.stop.name);
                      final isLast = i == stops.length - 1;

                      // Status attributes
                      Color dotColor;
                      Widget dotChild;
                      String? badgeLabel;
                      Color? badgeBg;
                      Color? badgeTextColor;

                      if (isSkipped) {
                        dotColor = AppTheme.coral;
                        dotChild = const Icon(Icons.close_rounded, size: 12, color: Colors.white);
                        badgeLabel = 'SKIPPED';
                        badgeBg = const Color(0xFFFEE2E2);
                        badgeTextColor = AppTheme.coral;
                      } else if (isCurrent) {
                        dotColor = AppTheme.emerald;
                        dotChild = const Icon(Icons.directions_bus_rounded, size: 13, color: Colors.white);
                        badgeLabel = 'CURRENT STOP';
                        badgeBg = const Color(0xFFECFDF5);
                        badgeTextColor = const Color(0xFF065F46);
                      } else if (isNext) {
                        dotColor = AppTheme.amber;
                        dotChild = const Icon(Icons.star_rounded, size: 12, color: Colors.white);
                        badgeLabel = 'NEXT STOP';
                        badgeBg = const Color(0xFFFEF3C7);
                        badgeTextColor = const Color(0xFF92400E);
                      } else if (isCompleted) {
                        dotColor = const Color(0xFF94A3B8);
                        dotChild = const Icon(Icons.check_rounded, size: 12, color: Colors.white);
                        badgeLabel = 'COMPLETED';
                        badgeBg = const Color(0xFFF1F5F9);
                        badgeTextColor = const Color(0xFF475569);
                      } else {
                        dotColor = AppTheme.primary;
                        dotChild = Text(
                          '$seq',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800),
                        );
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline Pillar
                            SizedBox(
                              width: 32,
                              child: Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: dotColor.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(child: dotChild),
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

                            // Stop Information Card
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isCurrent || isNext ? Colors.white : const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppTheme.emerald
                                        : isNext
                                            ? AppTheme.amber
                                            : AppTheme.border,
                                    width: isCurrent || isNext ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isCurrent || isNext ? AppTheme.cardShadow : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stop.stop.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                                        if (badgeLabel != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: badgeTextColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.people_outline_rounded, size: 14, color: AppTheme.muted),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 3,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                '$waiting students waiting',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                                              ),
                                              if (stop.stop.code != null) ...[
                                                const Text('•', style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                                                Text(
                                                  'Stop Code: ${stop.stop.code}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                                                ),
                                              ],
                                              if (isMyPickup) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'YOUR STOP',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.accent,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
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
}
