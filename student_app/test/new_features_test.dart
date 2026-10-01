import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/models/models.dart';
import 'package:student_app/services/route_geometry_service.dart';

void main() {
  group('Student Notification Settings Models & Logic', () {
    test('NotificationSettings defaults to all true', () {
      final settings = NotificationSettings();
      expect(settings.busApproaching, isTrue);
      expect(settings.busArrived, isTrue);
      expect(settings.stopSkipped, isTrue);
      expect(settings.tripEnded, isTrue);
      expect(settings.paused, isTrue);
    });

    test('NotificationSettings parses and serializes correctly', () {
      final json = {
        'busApproaching': false,
        'busArrived': true,
        'stopSkipped': false,
        'tripEnded': true,
        'paused': false,
      };
      final parsed = NotificationSettings.fromJson(json);
      expect(parsed.busApproaching, isFalse);
      expect(parsed.busArrived, isTrue);
      expect(parsed.stopSkipped, isFalse);
      expect(parsed.tripEnded, isTrue);
      expect(parsed.paused, isFalse);

      final serialized = parsed.toJson();
      expect(serialized['busApproaching'], isFalse);
      expect(serialized['busArrived'], isTrue);
      expect(serialized['stopSkipped'], isFalse);
    });

    test('StudentUser parses and serializes notificationSettings', () {
      final userJson = {
        'id': 'stu-123',
        'name': 'Test Student',
        'email': 'student@dhsgu.ac.in',
        'notificationSettings': {
          'busApproaching': false,
          'busArrived': false,
          'stopSkipped': true,
          'tripEnded': false,
          'paused': false,
        },
      };
      final user = StudentUser.fromJson(userJson);
      expect(user.notificationSettings.busApproaching, isFalse);
      expect(user.notificationSettings.busArrived, isFalse);
      expect(user.notificationSettings.stopSkipped, isTrue);

      final userMap = user.toJson();
      expect(userMap['notificationSettings']['busApproaching'], isFalse);
    });
  });

  group('RouteGeometryService Active Route and Slicing Logic', () {
    final routeService = RouteGeometryService.instance;

    test('getActiveRoute handles next stop 1 (Center Point approach) gracefully', () {
      final busPos = const LatLng(23.8267, 78.7720);
      final active = routeService.getActiveRoute(busPos: busPos, fromSeq: 0, toSeq: 1);
      expect(active, isNotEmpty);
      expect(active.first.latitude, closeTo(busPos.latitude, 0.0005));
      expect(active.first.longitude, closeTo(busPos.longitude, 0.0005));
    });

    test('getActiveRoute slices segment forward from bus GPS without backward vertices', () {
      // Segment 1-2 points: starts at ~23.8268, ends at ~23.8246
      final segment = routeService.getSegment(1, 2);
      expect(segment.length, greaterThan(10));

      // Place the bus halfway along the segment (at index 5)
      final midPoint = segment[5];
      // Bus slightly off road near index 5
      final busPos = LatLng(midPoint.latitude + 0.00005, midPoint.longitude + 0.00005);

      final active = routeService.getActiveRoute(busPos: busPos, fromSeq: 1, toSeq: 2);
      expect(active, isNotEmpty);
      // Snapped to road point rather than off-road busPos
      expect(active.first.latitude, closeTo(midPoint.latitude, 0.0001));
      expect(active.first.longitude, closeTo(midPoint.longitude, 0.0001));

      // Active route MUST NOT contain earlier vertices that the bus has already passed
      final passedVertex = segment[0];
      expect(active.contains(passedVertex), isFalse);

      // Active route MUST terminate at the next stop (the last point of segment 1-2)
      expect(active.last, equals(segment.last));
    });


    test('getSegment chains multiple consecutive segments for skipped stops', () {
      // Direct segment 1-2 and 2-3
      final seg12 = routeService.getSegment(1, 2);
      final seg23 = routeService.getSegment(2, 3);
      expect(seg12, isNotEmpty);
      expect(seg23, isNotEmpty);

      // Chained segment from sequence 1 to 3
      final seg13 = routeService.getSegment(1, 3);
      expect(seg13, isNotEmpty);
      // Chained route ends at Stop 3
      expect(seg13.last, equals(seg23.last));
    });
  });
}
