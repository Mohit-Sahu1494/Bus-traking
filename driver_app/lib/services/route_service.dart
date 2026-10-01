import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'route_geometry_service.dart';

/// Result of snapping a GPS point onto the predefined route geometry
class RouteSnapResult {
  final LatLng snappedPoint;
  final int edgeIndex;
  final double t;
  final double distanceMeters;

  const RouteSnapResult({
    required this.snappedPoint,
    required this.edgeIndex,
    required this.t,
    required this.distanceMeters,
  });
}

/// Unified road-following route service for DHSGU campus transit.
/// Ensures live tracking polylines strictly follow predefined road coordinates
/// and never draw direct straight cut lines from bus GPS to stops.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  List<LatLng>? _cachedCampusRoute;

  /// Predefined full campus circular route (Single Source of Truth)
  List<LatLng> get campusRouteCoordinates {
    if (_cachedCampusRoute != null && _cachedCampusRoute!.isNotEmpty) {
      return _cachedCampusRoute!;
    }
    final geom = RouteGeometryService.instance;
    final points = <LatLng>[];
    for (int seq = 1; seq <= 6; seq++) {
      final seg = geom.getSegment(seq, seq + 1);
      if (seg.isNotEmpty) {
        if (points.isNotEmpty) {
          points.addAll(seg.skip(1));
        } else {
          points.addAll(seg);
        }
      }
    }
    _cachedCampusRoute = List.unmodifiable(points);
    return _cachedCampusRoute!;
  }

  /// Calculates geodesic distance in meters between two LatLng coordinates
  double distanceMeters(LatLng a, LatLng b) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, a, b);
  }

  /// 1. Finds the nearest point on the predefined route
  /// Snaps/projects busLocation onto routePoints
  LatLng findNearestRoutePoint(LatLng busLocation, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return busLocation;
    if (routePoints.length == 1) return routePoints.first;
    final snap = snapToRoute(busLocation, routePoints);
    return snap.snappedPoint;
  }

  /// 2. Finds the nearest route index/position of the point on the route
  int findNearestRouteIndex(LatLng busLocation, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0;
    if (routePoints.length == 1) return 0;
    final snap = snapToRoute(busLocation, routePoints);
    return snap.t >= 0.5
        ? (snap.edgeIndex + 1).clamp(0, routePoints.length - 1)
        : snap.edgeIndex;
  }

  /// 3. Finds the route index corresponding to nextStopLocation
  int getNextStopIndex(
    List<LatLng> routePoints,
    LatLng nextStopLocation, {
    int startIndex = 0,
  }) {
    if (routePoints.isEmpty) return 0;
    if (routePoints.length == 1) return 0;

    int bestIdx = startIndex.clamp(0, routePoints.length - 1);
    double minDistance = double.infinity;

    final total = routePoints.length;
    for (int step = 0; step < total; step++) {
      final idx = (startIndex + step) % total;
      final dist = distanceMeters(routePoints[idx], nextStopLocation);
      if (dist < minDistance) {
        minDistance = dist;
        bestIdx = idx;
        if (dist < 1.0) break;
      }
    }
    return bestIdx;
  }

  /// 4. Checks whether the bus has reached or passed the given stop
  bool isStopPassed(
    LatLng busLocation,
    LatLng stopLocation, {
    List<LatLng>? routePoints,
    int? busRouteIndex,
    int? stopRouteIndex,
    double thresholdMeters = 40.0,
  }) {
    final dist = distanceMeters(busLocation, stopLocation);
    if (dist <= thresholdMeters) return true;

    if (busRouteIndex != null && stopRouteIndex != null) {
      if (busRouteIndex >= stopRouteIndex) return true;
    }
    return false;
  }

  /// Snaps a location onto routePoints with Euclidean projection in local metric space
  RouteSnapResult snapToRoute(LatLng point, List<LatLng> routePoints) {
    if (routePoints.isEmpty) {
      return RouteSnapResult(
        snappedPoint: point,
        edgeIndex: 0,
        t: 0.0,
        distanceMeters: 0.0,
      );
    }
    if (routePoints.length == 1) {
      return RouteSnapResult(
        snappedPoint: routePoints.first,
        edgeIndex: 0,
        t: 0.0,
        distanceMeters: distanceMeters(point, routePoints.first),
      );
    }

    const dLatScale = 111000.0;
    final cosLat = math.cos(point.latitude * math.pi / 180.0) * 111000.0;
    final bx = point.longitude * cosLat;
    final by = point.latitude * dLatScale;

    int bestEdgeIdx = 0;
    double minDistanceSq = double.infinity;
    double bestT = 0.0;
    LatLng bestProjPoint = routePoints[0];

    for (int i = 0; i < routePoints.length - 1; i++) {
      final p1 = routePoints[i];
      final p2 = routePoints[i + 1];

      final x1 = p1.longitude * cosLat;
      final y1 = p1.latitude * dLatScale;
      final x2 = p2.longitude * cosLat;
      final y2 = p2.latitude * dLatScale;

      final dx = x2 - x1;
      final dy = y2 - y1;
      final lenSq = dx * dx + dy * dy;

      double t;
      if (lenSq < 1e-10) {
        t = 0.0;
      } else {
        t = ((bx - x1) * dx + (by - y1) * dy) / lenSq;
        if (t < 0.0) t = 0.0;
        if (t > 1.0) t = 1.0;
      }

      final projX = x1 + t * dx;
      final projY = y1 + t * dy;
      final distSq = (bx - projX) * (bx - projX) + (by - projY) * (by - projY);

      if (distSq < minDistanceSq) {
        minDistanceSq = distSq;
        bestEdgeIdx = i;
        bestT = t;
        bestProjPoint = LatLng(
          p1.latitude + t * (p2.latitude - p1.latitude),
          p1.longitude + t * (p2.longitude - p1.longitude),
        );
      }
    }

    return RouteSnapResult(
      snappedPoint: bestProjPoint,
      edgeIndex: bestEdgeIdx,
      t: bestT,
      distanceMeters: math.sqrt(minDistanceSq),
    );
  }

  /// Extracts the remaining route coordinates between snapped bus position and next stop,
  /// strictly following the predefined road geometry without any straight cut lines.
  List<LatLng> getRemainingRoute({
    required LatLng? busLocation,
    required LatLng? nextStopLocation,
    List<LatLng>? routePoints,
    int? fromSequence,
    int? toSequence,
  }) {
    if (busLocation == null) return const [];

    List<LatLng> candidatePoints;
    if (routePoints != null) {
      candidatePoints = routePoints;
    } else if (fromSequence != null && toSequence != null && fromSequence > 0 && toSequence > 0) {
      int effectiveFrom = fromSequence;
      int effectiveTo = toSequence;
      if (effectiveTo <= 1) {
        // Approaching Stop 1 / Center Point from circular loop
        candidatePoints = RouteGeometryService.instance.getSegment(6, 7);
      } else {
        if (effectiveFrom >= effectiveTo) {
          effectiveFrom = effectiveTo - 1;
        }
        candidatePoints = RouteGeometryService.instance.getSegment(effectiveFrom, effectiveTo);
      }
    } else {
      candidatePoints = campusRouteCoordinates;
    }


    if (candidatePoints.length < 2) {
      return const [];
    }

    // Snap bus GPS onto candidate road geometry
    final snap = snapToRoute(busLocation, candidatePoints);
    final nearestRoutePoint = snap.snappedPoint;

    // Determine target end index (next stop)
    int targetIdx = candidatePoints.length - 1;
    if (nextStopLocation != null && candidatePoints.length > 2) {
      targetIdx = getNextStopIndex(candidatePoints, nextStopLocation, startIndex: snap.edgeIndex);
    }

    final remaining = <LatLng>[];
    // Start strictly from nearestRoutePoint (on the road geometry)
    remaining.add(nearestRoutePoint);

    if (snap.edgeIndex == 0 && snap.t <= 0.03) {
      for (int i = 0; i <= targetIdx; i++) {
        final pt = candidatePoints[i];
        if (remaining.isEmpty || distanceMeters(remaining.last, pt) > 0.8) {
          remaining.add(pt);
        }
      }
    } else {
      final startVertex = snap.edgeIndex + 1;
      if (startVertex <= targetIdx) {
        for (int i = startVertex; i <= targetIdx; i++) {
          final pt = candidatePoints[i];
          if (remaining.isEmpty || distanceMeters(remaining.last, pt) > 0.8) {
            remaining.add(pt);
          }
        }
      } else if (targetIdx < snap.edgeIndex && candidatePoints == campusRouteCoordinates) {
        // Circular wrap-around along the full route
        for (int i = startVertex; i < candidatePoints.length; i++) {
          final pt = candidatePoints[i];
          if (remaining.isEmpty || distanceMeters(remaining.last, pt) > 0.8) {
            remaining.add(pt);
          }
        }
        for (int i = 0; i <= targetIdx; i++) {
          final pt = candidatePoints[i];
          if (remaining.isEmpty || distanceMeters(remaining.last, pt) > 0.8) {
            remaining.add(pt);
          }
        }
      }
    }

    // Ensure the destination stop coordinate is included as the final point
    final destPoint = nextStopLocation ?? candidatePoints[targetIdx];
    if (remaining.isEmpty || distanceMeters(remaining.last, destPoint) > 1.5) {
      remaining.add(destPoint);
    }

    // Filter consecutive duplicate coordinates
    if (remaining.length >= 2) {
      final cleaned = <LatLng>[remaining.first];
      for (int i = 1; i < remaining.length; i++) {
        if (distanceMeters(cleaned.last, remaining[i]) > 0.5) {
          cleaned.add(remaining[i]);
        }
      }
      if (cleaned.length >= 2) return cleaned;
    }

    return remaining.length >= 2 ? remaining : const [];
  }
}
