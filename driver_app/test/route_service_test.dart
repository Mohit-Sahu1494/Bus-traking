import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:driver_app/core/config.dart';
import 'package:driver_app/services/route_geometry_service.dart';
import 'package:driver_app/services/route_service.dart';

void main() {
  group('Driver App - RouteService & Polyline Route-Following Tests', () {
    final routeService = RouteService.instance;
    final geometryService = RouteGeometryService.instance;

    test('campusRouteCoordinates contains rich continuous road geometry (> 350 points)', () {
      final coords = routeService.campusRouteCoordinates;
      expect(coords.length, greaterThan(350));
      expect(coords.first.latitude, closeTo(AppConfig.centerPoint.latitude, 0.0001));
      expect(coords.first.longitude, closeTo(AppConfig.centerPoint.longitude, 0.0001));
    });

    test('findNearestRoutePoint projects off-route GPS onto the road geometry', () {
      final segment12 = geometryService.getSegment(1, 2);
      final roadPoint = segment12[5];

      // Simulate GPS slightly offset by ~15 meters (0.0001 deg)
      final offRoadGps = LatLng(roadPoint.latitude + 0.00012, roadPoint.longitude + 0.00012);

      final nearest = routeService.findNearestRoutePoint(offRoadGps, segment12);

      // Snapped point must be closer to the road than the raw GPS
      expect(nearest, isNot(equals(offRoadGps)));
      expect(nearest.latitude, closeTo(roadPoint.latitude, 0.0002));
      expect(nearest.longitude, closeTo(roadPoint.longitude, 0.0002));
    });

    test('findNearestRoutePoint with on-route GPS returns exact coordinate', () {
      final segment12 = geometryService.getSegment(1, 2);
      final exactPoint = segment12[5];

      final nearest = routeService.findNearestRoutePoint(exactPoint, segment12);
      expect(nearest.latitude, closeTo(exactPoint.latitude, 0.000001));
      expect(nearest.longitude, closeTo(exactPoint.longitude, 0.000001));
    });

    test('getRemainingRoute starts strictly at nearestRoutePoint and terminates at next stop', () {
      final segment12 = geometryService.getSegment(1, 2);
      final midPoint = segment12[4];
      final offRoadGps = LatLng(midPoint.latitude + 0.0001, midPoint.longitude + 0.0001);

      final remaining = routeService.getRemainingRoute(
        busLocation: offRoadGps,
        nextStopLocation: AppConfig.computerScience,
        fromSequence: 1,
        toSequence: 2,
      );

      expect(remaining.length, greaterThan(3));
      // First point MUST be snapped onto road, NEVER raw off-road GPS
      expect(remaining.first, isNot(equals(offRoadGps)));
      expect(remaining.first.latitude, closeTo(midPoint.latitude, 0.0002));

      // Last point MUST be the destination stop
      expect(remaining.last.latitude, closeTo(AppConfig.computerScience.latitude, 0.0001));
      expect(remaining.last.longitude, closeTo(AppConfig.computerScience.longitude, 0.0001));

      // Must NOT be a direct straight 2-point line
      expect(remaining.length, isNot(equals(2)));
    });

    test('getNextStopIndex finds matching stop index with wrap-around', () {
      final coords = routeService.campusRouteCoordinates;
      final csStop = AppConfig.computerScience;

      final idx = routeService.getNextStopIndex(coords, csStop);
      expect(idx, greaterThan(5));
      expect(coords[idx].latitude, closeTo(csStop.latitude, 0.0005));
    });

    test('isStopPassed returns true when bus is within threshold distance', () {
      final stop = AppConfig.computerScience;
      // Bus at 20 meters from stop
      final nearBus = LatLng(stop.latitude + 0.0001, stop.longitude);
      expect(routeService.isStopPassed(nearBus, stop, thresholdMeters: 40.0), isTrue);

      // Bus far away (500 meters)
      final farBus = LatLng(stop.latitude + 0.005, stop.longitude);
      expect(routeService.isStopPassed(farBus, stop, thresholdMeters: 40.0), isFalse);
    });

    test('Edge cases: null or empty routes return empty list without crashing', () {
      expect(routeService.getRemainingRoute(busLocation: null, nextStopLocation: null), isEmpty);
      expect(
        routeService.getRemainingRoute(
          busLocation: const LatLng(23.8267, 78.7762),
          nextStopLocation: const LatLng(23.8246, 78.7821),
          routePoints: [],
        ),
        isEmpty,
      );
      expect(
        routeService.getRemainingRoute(
          busLocation: const LatLng(23.8267, 78.7762),
          nextStopLocation: const LatLng(23.8246, 78.7821),
          routePoints: [const LatLng(23.8267, 78.7762)],
        ),
        isEmpty,
      );
    });
  });
}
