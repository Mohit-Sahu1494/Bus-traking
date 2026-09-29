import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../services/device_location.dart';
import '../services/route_geometry_service.dart';
import '../widgets/bus_selection_sheet.dart';
import 'route_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TripProvider>().checkGpsStatus();
      }
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
      context.read<TripProvider>().onAppResumed();
    }
  }

  void _recenterBus(LatLng? busPos) {
    if (busPos != null) {
      _mapController.move(busPos, 16.0);
    } else {
      _mapController.move(_campusCenter, 15.0);
    }
  }

  void _recenterCampus() {
    _mapController.move(_campusCenter, 14.8);
  }

  List<Polyline> _buildPolylines(TripProvider trip) {
    final polylines = <Polyline>[];
    final routeService = RouteGeometryService.instance;
    final stops = trip.routeStops;
    if (stops.length < 2) return polylines;

    // Full road-following route (subtle blue)
    final fullRoad = routeService.getFullRoute(stops, skippedSequences: trip.skipped);
    if (fullRoad.length >= 2) {
      polylines.add(
        Polyline(
          points: fullRoad,
          color: const Color(0xFF93C5FD),
          strokeWidth: 3.5,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      );
    }

    // Active segment to next stop (highlighted royal blue)
    if (trip.isActive && trip.live?['nextStop'] != null) {
      final nextSeq = (trip.live!['nextStop']['sequence'] as num?)?.toInt() ?? (trip.currentSequence + 1);
      final fromSeq = trip.currentSequence > 0 ? trip.currentSequence : (nextSeq > 1 ? nextSeq - 1 : 1);
      final activeSegment = routeService.getActiveRoute(
        busPos: trip.currentLatLng,
        fromSeq: fromSeq,
        toSeq: nextSeq,
      );
      if (activeSegment.length >= 2) {
        polylines.add(
          Polyline(
            points: activeSegment,
            color: const Color(0xFF1D4ED8),
            strokeWidth: 5.0,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        );
      }
    }

    return polylines;
  }

  List<Marker> _buildMarkers(TripProvider trip) {
    final markers = <Marker>[];
    final stops = trip.routeStops;

    for (final s in stops) {
      final lat = (s['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (s['longitude'] as num?)?.toDouble() ?? 0.0;
      final seq = (s['sequence'] as num?)?.toInt() ?? 0;
      final isCurrent = trip.currentSequence == seq;
      final isNext = trip.live?['nextStop']?['sequence'] == seq;
      final isSkipped = trip.skipped.contains(seq);
      final isCompleted = trip.completed.contains(seq);

      if (lat == 0 || lng == 0) continue;

      Color badgeBg;
      if (isSkipped) {
        badgeBg = AppTheme.coral;
      } else if (isCurrent) {
        badgeBg = AppTheme.emerald;
      } else if (isNext) {
        badgeBg = const Color(0xFF1D4ED8);
      } else if (isCompleted) {
        badgeBg = const Color(0xFF94A3B8);
      } else {
        badgeBg = AppTheme.primary;
      }

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Center(
              child: isCurrent
                  ? const Icon(Icons.directions_bus, size: 16, color: Colors.white)
                  : Text(
                      '$seq',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    // Bus Marker
    final busPos = trip.currentLatLng;
    if (busPos != null) {
      markers.add(
        Marker(
          point: busPos,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.emerald,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(
              Icons.directions_bus_filled,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final driverName = auth.profile?.name ?? 'Campus Driver';
    final busNum = trip.busNumber.isNotEmpty ? trip.busNumber : (auth.profile?.busNumber ?? 'BUS-04');

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            // Compact Driver Header (Section 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Campus Bus',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                busNum,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusPill(trip.tripStatus),
                            ],
                          ),
                          const SizedBox(height: 3),
                          _gpsPill(trip.gpsOn, trip.gpsError != null),
                        ],
                      ),
                    ],
                  ),
                  if (trip.gpsError != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.coral),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              trip.gpsError!,
                              style: const TextStyle(color: AppTheme.coral, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: trip.isActive || trip.isPaused
                    ? _buildActiveDashboard(context, trip, busNum)
                    : _buildBeforeDashboard(context, trip, busNum, driverName),
              ),
            ),

            // Bottom Actions Panel
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: _buildBottomActions(context, trip),
            ),
          ],
        ),
      ),
    );
  }

  // --- BEFORE TRIP VIEW (Sections 3, 30) ---
  Widget _buildBeforeDashboard(BuildContext context, TripProvider trip, String busNum, String driverName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assigned Vehicle Card with Change Bus Option
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_bus, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ASSIGNED BUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 0.8)),
                              Text(busNum, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.navy), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => showBusSelectionSheet(context),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppTheme.border),
              Row(
                children: [
                  Expanded(
                    child: _metricBox('GPS State', trip.gpsOn ? 'Ready' : 'Standby', trip.gpsOn ? AppTheme.emerald : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricBox("Today's Trips", '${trip.tripsToday} recorded', AppTheme.navy),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Route Map Preview Card (Sections 23, 24)
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _campusCenter,
                  initialZoom: 14.8,
                  minZoom: 13.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ac.in.dhsgu.driver_app',
                  ),
                  PolylineLayer(polylines: _buildPolylines(trip)),
                  MarkerLayer(markers: _buildMarkers(trip)),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alt_route, size: 14, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Campus Circular Route (7 Stops)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Route Stops Sequence Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'ROUTE ORDER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 1.0),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RouteScreen())),
                    child: const Text('View Timeline →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '1 Center Point → 2 CS Dept → 3 Criminology → 4 Center Point → 5 Boys Hostel → 6 Girls Hostel → 7 Center Point',
                style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- ACTIVE TRIP DASHBOARD (Sections 3, 10, 11, 23, 29, 31, 32) ---
  Widget _buildActiveDashboard(BuildContext context, TripProvider trip, String busNum) {
    final nextName = trip.nextStopName ?? 'Center Point (Final)';
    final currentName = trip.currentStopName ?? 'Route in progress';
    final waitingNext = trip.waitingFor(nextName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Final Stop Banner (Section 29)
        if (trip.isFinalStopReached)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_circle, color: Color(0xFF1D4ED8), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🏁 Final Stop Reached',
                        style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A), fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You have reached Center Point. Confirm to end the trip.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Paused Banner
        if (trip.isPaused)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pause_circle_filled, color: AppTheme.amber, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🟡 TRIP PAUSED', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                      if (trip.pauseReason != null)
                        Text('Reason: ${trip.pauseReason}', style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Hero Status Card (Current Location, Stop, Next Stop, ETA)
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
              // Current GPS Location (Section 11)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 12, color: AppTheme.emerald),
                        SizedBox(width: 4),
                        Text('BUS GPS LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.emerald)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.currentAreaDescription,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: AppTheme.border),

              // Current Stop
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.radio_button_checked, color: AppTheme.muted, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CURRENT STOP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 0.8)),
                        Text(currentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.navy)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Next Stop & ETA
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.flag, color: Color(0xFF1D4ED8), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NEXT STOP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted, letterSpacing: 0.8)),
                        Text(
                          nextName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ETA: ${trip.etaLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),

              if (waitingNext > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$waitingNext student${waitingNext > 1 ? "s" : ""} waiting at $nextName',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Live Road-Following Map Cockpit (Section 23, 24)
        Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: trip.currentLatLng ?? _campusCenter,
                  initialZoom: 15.5,
                  minZoom: 13.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ac.in.dhsgu.driver_app',
                  ),
                  PolylineLayer(polylines: _buildPolylines(trip)),
                  MarkerLayer(markers: _buildMarkers(trip)),
                ],
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'recenter_bus',
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      onPressed: () => _recenterBus(trip.currentLatLng),
                      child: const Icon(Icons.my_location, size: 18),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'recenter_campus',
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      onPressed: _recenterCampus,
                      child: const Icon(Icons.crop_free, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Route Progression List (Section 33)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: trip.routeStops.map((stop) {
              final name = stop['stop']?['name']?.toString() ?? 'Stop';
              final seq = (stop['sequence'] as num?)?.toInt() ?? 0;
              final waiting = trip.waitingFor(name);
              final isCurrent = trip.currentSequence == seq;
              final isNext = trip.live?['nextStop']?['sequence'] == seq;
              final isSkipped = trip.skipped.contains(seq);
              final isCompleted = trip.completed.contains(seq);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSkipped
                            ? AppTheme.coral
                            : isCurrent
                                ? AppTheme.emerald
                                : isNext
                                    ? const Color(0xFF1D4ED8)
                                    : isCompleted
                                        ? const Color(0xFFCBD5E1)
                                        : AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$seq',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
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
                    if (waiting > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$waiting wait',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- BOTTOM ACTION BUTTONS (Sections 25, 27, 28, 51, 53) ---
  Widget _buildBottomActions(BuildContext context, TripProvider trip) {
    if (trip.tripStatus == 'NOT_STARTED' || trip.tripStatus == 'COMPLETED' || trip.tripStatus == 'CANCELLED') {
      final isLoading = trip.isStartingTrip;
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isLoading ? const Color(0xFF94A3B8) : AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.play_arrow_rounded, size: 26),
          label: Text(
            isLoading ? 'STARTING TRIP...' : 'START TRIP',
            style: const TextStyle(fontSize: 17, letterSpacing: 0.5, fontWeight: FontWeight.w800),
          ),
          onPressed: isLoading ? null : () => _handleStartTrip(context, trip),
        ),
      );
    }

    if (trip.isActive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.amber,
                      side: const BorderSide(color: AppTheme.amber, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.skip_next, size: 20),
                    label: const Text('SKIP STOP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    onPressed: () => _confirmSkip(context, trip),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.pause, size: 20),
                    label: const Text('PAUSE TRIP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    onPressed: () => _pause(context, trip),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 22),
              label: Text(
                trip.isFinalStopReached ? 'CONFIRM & END TRIP' : 'END TRIP',
                style: const TextStyle(fontSize: 15, letterSpacing: 0.5, fontWeight: FontWeight.w800),
              ),
              onPressed: () => _confirmEnd(context, trip),
            ),
          ),
        ],
      );
    }

    if (trip.isPaused) {
      return Row(
        children: [
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text('RESUME TRIP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                onPressed: () => _run(context, trip.resumeTrip),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.coral,
                  side: const BorderSide(color: AppTheme.coral, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop, size: 20),
                label: const Text('END TRIP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                onPressed: () => _confirmEnd(context, trip),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.muted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF64748B);
    String label = 'NOT STARTED';

    if (status == 'ACTIVE') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF065F46);
      label = '● ACTIVE';
    } else if (status == 'PAUSED') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = '● PAUSED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _gpsPill(bool gpsOn, bool hasError) {
    Color bg = gpsOn ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    Color fg = gpsOn ? AppTheme.emerald : AppTheme.coral;
    String text = gpsOn ? 'GPS: LIVE' : 'GPS: OFF';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Future<void> _handleStartTrip(BuildContext context, TripProvider trip) async {
    if (trip.isStartingTrip) return;

    final locationService = DeviceLocationService();
    final isGpsOn = await locationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: AppTheme.coral),
              SizedBox(width: 8),
              Text('GPS is Turned Off'),
            ],
          ),
          content: const Text(
            'GPS/Location services are disabled on your device. Live bus tracking requires GPS to be enabled.\n\nPlease enable Location in settings and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                Navigator.pop(ctx);
                locationService.openLocationServiceSettings();
              },
              child: const Text('Enable Location'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await trip.startTrip();
    } catch (e) {
      if (!context.mounted) return;
      if (e is GpsDisabledException) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('GPS Required'),
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  locationService.openLocationServiceSettings();
                },
                child: const Text('Enable Location'),
              ),
            ],
          ),
        );
      } else if (e is LocationPermissionException && e.permanentlyDenied) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Required'),
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  locationService.openSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(humanizeError(e)),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(humanizeError(e)),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmSkip(BuildContext context, TripProvider trip) async {
    final nextName = trip.nextStopName ?? 'the next stop';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Skip $nextName?'),
        content: Text('Are you sure you want to skip $nextName? Students waiting at this stop will be immediately notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.amber),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Skip'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, trip.skipStop);
  }

  Future<void> _pause(BuildContext context, TripProvider trip) async {
    const reasons = {
      'TRAFFIC': 'Heavy Traffic',
      'TEMPORARY_ISSUE': 'Temporary Issue',
      'BREAKDOWN': 'Mechanical Breakdown',
      'OPERATIONAL_PAUSE': 'Operational Pause',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Pause Reason', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.navy)),
              const SizedBox(height: 12),
              ...reasons.entries.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.pop(ctx, e.key),
                  )),
            ],
          ),
        ),
      ),
    );
    if (reason != null && context.mounted) {
      await _run(context, () => trip.pauseTrip(reason));
    }
  }

  Future<void> _confirmEnd(BuildContext context, TripProvider trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text('Are you sure you want to end the current trip? This will stop live GPS broadcasting and record this trip in your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, trip.endTrip);
  }
}
