import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/live_provider.dart';
import '../widgets/status_chip.dart';
import 'notifications_screen.dart';
import 'pickup_stop_screen.dart';
import 'upcoming_stops_screen.dart';
import '../services/route_geometry_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();

  static const LatLng _campusCenter = LatLng(
    AppConfig.campusCenterLat,
    AppConfig.campusCenterLng,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RouteGeometryService.instance.fetchAndCacheAllSegments().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<LiveProvider>().onAppResumed();
    }
  }

  void _recenterCampus() {
    _mapController.move(_campusCenter, 15.2);
  }

  void _focusBus(LatLng? busPos) {
    if (busPos != null) {
      _mapController.move(busPos, 16.5);
    } else {
      _recenterCampus();
    }
  }

  /// Builds road-following polylines:
  /// 1. Completed segments — subtle grey following campus roads
  /// 2. Active segment (current bus GPS → next stop) — highlighted royal blue following road geometry
  /// 3. Upcoming route — subtle pale blue following campus roads
  List<Polyline> _buildRoutePolylines(LiveProvider live) {
    final stops = live.routeStops;
    if (stops.length < 2) return [];

    final busPos = live.busLatLng;
    final nextStop = live.nextStop;
    final currentSeq = live.currentSequence ?? 0;
    final skipped = live.skippedSequences;
    final routeService = RouteGeometryService.instance;

    final polylines = <Polyline>[];

    // When trip is inactive or there is no next stop, show entire circular route following roads
    if (live.busStatus == 'INACTIVE' || nextStop == null) {
      final fullRoadPoints = routeService.getFullRoute(stops, skippedSequences: skipped);
      if (fullRoadPoints.length >= 2) {
        polylines.add(
          Polyline(
            points: fullRoadPoints,
            color: const Color(0xFF93C5FD), // subtle pale blue
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        );
      }
      return polylines;
    }

    // --- 1. Completed segments: stops with sequence <= currentSeq following roads ---
    final completedRoadPoints = <LatLng>[];
    for (int i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];
      if (to.sequence <= currentSeq &&
          !skipped.contains(from.sequence) &&
          !skipped.contains(to.sequence)) {
        final seg = routeService.getSegment(from.sequence, to.sequence);
        if (completedRoadPoints.isNotEmpty && seg.isNotEmpty) {
          completedRoadPoints.addAll(seg.skip(1));
        } else {
          completedRoadPoints.addAll(seg);
        }
      }
    }
    if (completedRoadPoints.length >= 2) {
      polylines.add(Polyline(
        points: completedRoadPoints,
        color: const Color(0xFFCBD5E1), // subtle grey
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    // --- 2. Upcoming route: stops from next stop's sequence onwards following roads ---
    final upcomingRoadPoints = <LatLng>[];
    for (int i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];
      if (from.sequence >= nextStop.sequence &&
          !skipped.contains(from.sequence) &&
          !skipped.contains(to.sequence)) {
        final seg = routeService.getSegment(from.sequence, to.sequence);
        if (upcomingRoadPoints.isNotEmpty && seg.isNotEmpty) {
          upcomingRoadPoints.addAll(seg.skip(1));
        } else {
          upcomingRoadPoints.addAll(seg);
        }
      }
    }
    if (upcomingRoadPoints.length >= 2) {
      polylines.add(Polyline(
        points: upcomingRoadPoints,
        color: const Color(0xFF93C5FD), // subtle pale blue
        strokeWidth: 3.5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ));
    }

    // --- 3. ACTIVE / HIGHLIGHTED SEGMENT: REAL BUS GPS → ROAD GEOMETRY → NEXT STOP ---
    // Finds previous stop sequence (or nextStop.sequence - 1)
    final fromSeq = (currentSeq > 0 && currentSeq < nextStop.sequence)
        ? currentSeq
        : (nextStop.sequence > 1 ? nextStop.sequence - 1 : 1);
    final activeRoadPoints = routeService.getActiveRoute(
      busPos: busPos,
      fromSeq: fromSeq,
      toSeq: nextStop.sequence,
    );

    final isOffline = live.isBusOffline;
    if (activeRoadPoints.length >= 2) {
      if (isOffline) {
        // Muted dashed/subdued line when bus is offline
        polylines.add(Polyline(
          points: activeRoadPoints,
          color: const Color(0xFF94A3B8), // muted slate grey
          strokeWidth: 4.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ));
      } else {
        // Outer glow underlay for prominent visibility
        polylines.add(Polyline(
          points: activeRoadPoints,
          color: const Color(0x551E3A8A), // dark blue glow
          strokeWidth: 10.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ));

        // Core highlighted route line from bus to next stop in bold Dark Blue
        polylines.add(Polyline(
          points: activeRoadPoints,
          color: const Color(0xFF1E3A8A), // deep dark blue
          strokeWidth: 6.0,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ));
      }
    }

    return polylines;
  }

  void _showRouteTimelineSheet(BuildContext context, LiveProvider live) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.90,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppTheme.sheetShadow,
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'CAMPUS ROUTE & STOPS',
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
                            '${live.routeStops.length} Stops • Circular Route',
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
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.open_in_full_rounded, size: 18, color: AppTheme.muted),
                      tooltip: 'Full Screen',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      splashRadius: 20,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const UpcomingStopsScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.muted),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      splashRadius: 22,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),

              // Route Timeline List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: live.routeStops.length,
                  itemBuilder: (_, i) {
                    final stop = live.routeStops[i];
                    final seq = stop.sequence;
                    final isSkipped = live.skippedSequences.contains(seq);
                    final isCompleted = live.completedSequences.contains(seq);
                    final isCurrent = (live.currentStop?.sequence == seq || live.currentSequence == seq);
                    final isNext = live.nextStop?.sequence == seq;
                    final waiting = live.waitingAt(stop.stop.name);
                    final isLast = i == live.routeStops.length - 1;

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
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrent || isNext ? Colors.white : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppTheme.emerald
                                      : isNext
                                          ? AppTheme.amber
                                          : const Color(0xFFE2E8F0),
                                  width: isCurrent || isNext ? 1.5 : 1.0,
                                ),
                                boxShadow: isCurrent || isNext
                                    ? [
                                        BoxShadow(
                                          color: (isCurrent ? AppTheme.emerald : AppTheme.amber).withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
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
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.people_outline_rounded, size: 13, color: AppTheme.muted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '$waiting students waiting',
                                              style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                                            ),
                                            if (stop.stop.code != null) ...[
                                              const Text('•', style: TextStyle(fontSize: 11.5, color: AppTheme.muted)),
                                              Text(
                                                'Stop Code: ${stop.stop.code}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final pickupName = user?.pickupStop?.name;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Campus Bus',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Dr. Harisingh Gour University',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    status: live.busStatus,
                    busNumber: live.busNumber ?? 'BUS-04',
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppTheme.navy),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                      ),
                      if (live.unreadNotificationsCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.coral,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '${live.unreadNotificationsCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Connection drop banner
            if (!live.socketConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFFFF7ED),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.amber),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reconnecting to campus live stream...',
                      style: TextStyle(color: Color(0xFF9A3412), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

            // Skipped Stop Banner
            if (live.skipBanner != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.coral, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                          children: [
                            const TextSpan(text: 'Stop Skipped: ', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: '${live.skipBanner} has been skipped by the driver.'),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: live.dismissSkipBanner,
                    ),
                  ],
                ),
              ),

            // Pause Banner
            if (live.pauseMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_outline, color: AppTheme.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        live.pauseMessage!,
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF92400E)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: live.dismissPauseBanner,
                    ),
                  ],
                ),
              ),

            // Driver Network Offline Warning Banner
            if (live.isBusOffline && live.busLatLng != null && live.busStatus != 'INACTIVE')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0FDC2626), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.wifi_off_rounded, color: AppTheme.coral, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Driver Network Offline',
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Last seen: ${live.lastSeenText}',
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Map is displaying the last known coordinates. The bus is not actively broadcasting live GPS right now.',
                            style: TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Map Area (Map-First)
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _campusCenter,
                      initialZoom: 15.2,
                      minZoom: 13.5,
                      maxZoom: 18.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ac.in.dhsgu.student_app',
                      ),

                      // Route Polylines: completed (grey), upcoming (subtle blue), active (highlighted)
                      if (live.routeStops.length >= 2)
                        PolylineLayer(
                          polylines: _buildRoutePolylines(live),
                        ),

                      // Stop Markers (Numbered 1-7, differentiated states, sequence-based)
                      MarkerLayer(
                        markers: [
                          for (final stop in live.routeStops)
                            Marker(
                              point: LatLng(stop.latitude, stop.longitude),
                              width: 84,
                              height: 62,
                              alignment: Alignment.center,
                              child: _StopMarker(
                                stop: stop,
                                isNext: live.nextStop?.sequence == stop.sequence,
                                isCurrent: (live.currentStop?.sequence == stop.sequence ||
                                    live.currentSequence == stop.sequence),
                                isSkipped: live.skippedSequences.contains(stop.sequence),
                                isCompleted: live.completedSequences.contains(stop.sequence),
                              ),
                            ),

                          // Student Location Marker
                          if (live.studentLatLng != null)
                            Marker(
                              point: live.studentLatLng!,
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Bus Location Marker (Active or Last Known)
                          if (live.busLatLng != null && live.busStatus != 'INACTIVE')
                            Marker(
                              point: live.busLatLng!,
                              width: live.isBusOffline ? 120 : 64,
                              height: 64,
                              child: _BusMarker(
                                busNumber: live.busNumber ?? 'BUS-04',
                                isStale: live.isBusOffline,
                                lastSeenText: live.lastSeenText,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Floating Map Action Buttons (48px touch targets, rounded corners, subtle shadows, blue icons)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Column(
                      children: [
                        _MapButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Refresh',
                          isLoading: live.isRefreshing,
                          onTap: live.refresh,
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.school_outlined,
                          tooltip: 'Recenter Campus',
                          onTap: _recenterCampus,
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: Icons.my_location_rounded,
                          tooltip: 'My Location',
                          onTap: () {
                            if (live.studentLatLng != null) {
                              _mapController.move(live.studentLatLng!, 16.5);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Locating student device...'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                        if (live.busLatLng != null && live.busStatus != 'INACTIVE') ...[
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.directions_bus_rounded,
                            tooltip: 'Focus Bus',
                            iconColor: AppTheme.emerald,
                            onTap: () => _focusBus(live.busLatLng),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Next Stop Bottom Card
            _NextStopCard(
              live: live,
              pickupName: pickupName,
              onSelectPickup: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PickupStopScreen()),
                );
              },
              onViewAllStops: () => _showRouteTimelineSheet(context, live),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.floatingShadow,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                  )
                : Icon(
                    icon,
                    size: 22,
                    color: iconColor ?? AppTheme.accent,
                  ),
          ),
        ),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.isNext,
    required this.isCurrent,
    required this.isSkipped,
    required this.isCompleted,
  });

  final dynamic stop;
  final bool isNext;
  final bool isCurrent;
  final bool isSkipped;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    Color color;
    Widget icon;

    if (isSkipped) {
      color = AppTheme.coral;
      icon = const Icon(Icons.close_rounded, size: 13, color: Colors.white);
    } else if (isCurrent) {
      color = AppTheme.emerald;
      icon = const Icon(Icons.directions_bus_rounded, size: 14, color: Colors.white);
    } else if (isNext) {
      color = AppTheme.amber;
      icon = const Icon(Icons.star_rounded, size: 14, color: Colors.white);
    } else if (isCompleted) {
      color = const Color(0xFF94A3B8);
      icon = const Icon(Icons.check_rounded, size: 13, color: Colors.white);
    } else {
      color = AppTheme.primary;
      icon = Text(
        '${stop.sequence}',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      );
    }

    final pinSize = isCurrent || isNext ? 28.0 : 25.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: pinSize,
          height: pinSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: isCurrent ? 8 : 4,
                spreadRadius: isCurrent ? 1.5 : 0.5,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNext || isCurrent ? color.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            stop.stop.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isNext || isCurrent ? FontWeight.w800 : FontWeight.w600,
              color: isSkipped
                  ? AppTheme.coral
                  : isCompleted
                      ? AppTheme.muted
                      : (isCurrent || isNext ? color : AppTheme.navy),
            ),
          ),
        ),
      ],
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({
    required this.busNumber,
    this.isStale = false,
    this.lastSeenText,
  });

  final String busNumber;
  final bool isStale;
  final String? lastSeenText;

  @override
  Widget build(BuildContext context) {
    final bgColor = isStale ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A);
    final badgeColor = isStale ? const Color(0xFF991B1B) : AppTheme.navy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isStale ? const Color(0xFFFECACA) : Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isStale ? const Color(0x55DC2626) : const Color(0x401E3A8A),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
            if (isStale)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF991B1B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
            border: isStale ? Border.all(color: const Color(0xFFFECACA), width: 0.8) : null,
            boxShadow: const [
              BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Text(
            isStale
                ? '$busNumber • LAST KNOWN (${lastSeenText ?? 'OFFLINE'})'
                : busNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({
    required this.live,
    required this.pickupName,
    required this.onSelectPickup,
    required this.onViewAllStops,
  });

  final LiveProvider live;
  final String? pickupName;
  final VoidCallback onSelectPickup;
  final VoidCallback onViewAllStops;

  @override
  Widget build(BuildContext context) {
    final isOffline = live.isBusOffline;
    final nextName = live.nextStop?.stop.name ??
        (live.busStatus == 'ACTIVE' ? 'Final Stop reached' : (isOffline ? 'Tracking Paused' : 'No active bus trip'));
    final currentName = live.currentStop?.stop.name;
    final waiting = live.waitingAt(pickupName);

    // Format Distance
    String? distanceText;
    if (live.distanceToNextStopM != null) {
      final distM = live.distanceToNextStopM!;
      distanceText = distM < 1000
          ? '${distM.round()} m away'
          : '${(distM / 1000).toStringAsFixed(1)} km away';
    }

    // Format ETA
    final isEtaCalculating = live.etaLabel.toLowerCase().contains('calculating');
    String etaDisplay = live.etaLabel;
    if (etaDisplay.contains('(')) {
      etaDisplay = etaDisplay.split('(').first.trim();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: AppTheme.sheetShadow,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row: NEXT STOP + Current Stop badge + ETA Pill
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'NEXT STOP',
                      style: TextStyle(
                        letterSpacing: 1.1,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.muted,
                      ),
                    ),
                    if (currentName != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'At $currentName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (live.nextStop != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: isOffline
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 12, color: AppTheme.coral),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Signal Paused',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.coral,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: isEtaCalculating ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isEtaCalculating ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isEtaCalculating) ...[
                                const SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.muted),
                                ),
                                const SizedBox(width: 5),
                                const Flexible(
                                  child: Text(
                                    'ETA Calculating...',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.accent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '◷ $etaDisplay',
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
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Destination Name (large, bold text)
          Text(
            nextName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
              letterSpacing: -0.3,
            ),
          ),

          // Distance info if available
          if (distanceText != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isOffline ? Icons.history_rounded : Icons.near_me_outlined,
                  size: 13,
                  color: isOffline ? AppTheme.coral : AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isOffline
                        ? '📍 ~$distanceText • Last seen ${live.lastSeenText} (Not live)'
                        : '📍 $distanceText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isOffline ? const Color(0xFFB91C1C) : AppTheme.muted,
                      fontWeight: isOffline ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (isOffline) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.coral),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Driver network disconnected. Live tracking paused.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // PICKUP STOP SELECTION CARD (Requirement 6)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: pickupName != null ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 17,
                    color: pickupName != null ? AppTheme.accent : AppTheme.coral,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICKUP STOP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        pickupName ?? 'No pickup stop selected',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: pickupName != null ? AppTheme.navy : AppTheme.coral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pickupName != null)
                        Text(
                          '$waiting students waiting at this stop',
                          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (pickupName == null)
                  FilledButton.tonal(
                    onPressed: onSelectPickup,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: onSelectPickup,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.navy),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons: View Stops & I'M WAITING
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    onPressed: onViewAllStops,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Stops',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: live.isWaiting ? const Color(0xFF059669) : AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                      ),
                    ),
                    onPressed: (live.isTogglingWaiting)
                        ? null
                        : (pickupName == null
                            ? onSelectPickup
                            : () async {
                                try {
                                  if (live.isWaiting) {
                                    await live.cancelWaiting();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Waiting status cancelled.'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } else {
                                    await live.imWaiting();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("You're marked as waiting at $pickupName."),
                                          backgroundColor: AppTheme.emerald,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: AppTheme.coral,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              }),
                    child: live.isTogglingWaiting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                live.isWaiting ? Icons.check_circle_rounded : Icons.directions_bus_rounded,
                                size: 17,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                live.isWaiting ? "YOU'RE WAITING" : "I'M WAITING",
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
