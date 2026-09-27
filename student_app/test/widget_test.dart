import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/core/config.dart';
import 'package:student_app/models/models.dart';
import 'package:student_app/screens/splash_screen.dart';
import 'package:student_app/services/route_geometry_service.dart';

void main() {
  group('Verified Stop Coordinates Tests', () {
    test('Verified bus stop coordinates match exact requirements', () {
      expect(AppConfig.computerScience, const LatLng(23.824232252667205, 78.78215542847788));
      expect(AppConfig.criminology, const LatLng(23.823290586415027, 78.78310833763173));
      expect(AppConfig.centerPoint, const LatLng(23.826769418621495, 78.77207848833157));
      expect(AppConfig.boysHostel, const LatLng(23.8223332722968, 78.77027060622879));
      expect(AppConfig.girlsHostel, const LatLng(23.831797143673885, 78.78234670088726));
    });

    test('Route order has exactly 7 stops with unique sequences', () {
      final stops = AppConfig.defaultRouteStops;
      expect(stops.length, 7);
      expect(stops[0].sequence, 1);
      expect(stops[0].stop.name, 'Center Point');
      expect(stops[1].sequence, 2);
      expect(stops[1].stop.name, 'Computer Science Department');
      expect(stops[2].sequence, 3);
      expect(stops[2].stop.name, 'Criminology Department');
      expect(stops[3].sequence, 4);
      expect(stops[3].stop.name, 'Center Point');
      expect(stops[4].sequence, 5);
      expect(stops[4].stop.name, 'Boys Hostel');
      expect(stops[5].sequence, 6);
      expect(stops[5].stop.name, 'Girls Hostel');
      expect(stops[6].sequence, 7);
      expect(stops[6].stop.name, 'Center Point');
    });

    RouteStopInfo? resolveNext(List<RouteStopInfo> stops, int currentSeq, List<int> skipped) {
      final skippedSet = skipped.toSet();
      final ordered = List<RouteStopInfo>.from(stops)
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      for (final rs in ordered) {
        if (rs.sequence > currentSeq && !skippedSet.contains(rs.sequence)) {
          return rs;
        }
      }
      return null;
    }

    test('Sequence-based next stop progression correctly handles Center Point duplicates', () {
      final stops = AppConfig.defaultRouteStops;

      // Start: sequence 0 -> next is Sequence 1 (Center Point #1)
      expect(resolveNext(stops, 0, [])?.sequence, 1);
      expect(resolveNext(stops, 0, [])?.stop.name, 'Center Point');

      // Sequence 1 -> next is Sequence 2 (Computer Science)
      expect(resolveNext(stops, 1, [])?.sequence, 2);
      expect(resolveNext(stops, 1, [])?.stop.name, 'Computer Science Department');

      // Sequence 2 -> next is Sequence 3 (Criminology)
      expect(resolveNext(stops, 2, [])?.sequence, 3);
      expect(resolveNext(stops, 2, [])?.stop.name, 'Criminology Department');

      // Sequence 3 -> next is Sequence 4 (Center Point #2)
      expect(resolveNext(stops, 3, [])?.sequence, 4);
      expect(resolveNext(stops, 3, [])?.stop.name, 'Center Point');

      // Sequence 4 -> next is Sequence 5 (Boys Hostel)
      expect(resolveNext(stops, 4, [])?.sequence, 5);
      expect(resolveNext(stops, 4, [])?.stop.name, 'Boys Hostel');

      // Sequence 5 -> next is Sequence 6 (Girls Hostel)
      expect(resolveNext(stops, 5, [])?.sequence, 6);
      expect(resolveNext(stops, 5, [])?.stop.name, 'Girls Hostel');

      // Sequence 6 -> next is Sequence 7 (Center Point #3)
      expect(resolveNext(stops, 6, [])?.sequence, 7);
      expect(resolveNext(stops, 6, [])?.stop.name, 'Center Point');

      // Sequence 7 -> completed (no more stops)
      expect(resolveNext(stops, 7, []), isNull);
    });

    test('Skipped stop immediately advances to next valid sequence', () {
      final stops = AppConfig.defaultRouteStops;

      // When at sequence 1 and sequence 2 (CS) is skipped: next is Sequence 3 (Criminology)
      final nextWithSkip = resolveNext(stops, 1, [2]);
      expect(nextWithSkip?.sequence, 3);
      expect(nextWithSkip?.stop.name, 'Criminology Department');

      // When at sequence 3 and sequence 4 (Center Point) is skipped: next is Sequence 5 (Boys Hostel)
      final nextSkipCp = resolveNext(stops, 3, [4]);
      expect(nextSkipCp?.sequence, 5);
      expect(nextSkipCp?.stop.name, 'Boys Hostel');
    });
  });

  group('Route Road Geometry & Polyline Tests', () {
    final routeService = RouteGeometryService.instance;

    test('Every route segment contains rich road coordinates (> 25 points, none is 2 points)', () {
      final segments = [
        {'key': '1-2', 'from': 1, 'to': 2, 'name': 'Center Point -> Computer Science'},
        {'key': '2-3', 'from': 2, 'to': 3, 'name': 'Computer Science -> Criminology'},
        {'key': '3-4', 'from': 3, 'to': 4, 'name': 'Criminology -> Center Point'},
        {'key': '4-5', 'from': 4, 'to': 5, 'name': 'Center Point -> Boys Hostel'},
        {'key': '5-6', 'from': 5, 'to': 6, 'name': 'Boys Hostel -> Girls Hostel'},
        {'key': '6-7', 'from': 6, 'to': 7, 'name': 'Girls Hostel -> Center Point'},
      ];

      for (final s in segments) {
        final pts = routeService.getSegment(s['from'] as int, s['to'] as int);
        // Verify points count is rich and NOT a 2-point straight line
        expect(pts.length, greaterThanOrEqualTo(30),
            reason: '${s['name']} must contain road points, found ${pts.length}');
        expect(pts.length, isNot(equals(2)),
            reason: '${s['name']} cannot be a 2-point straight line');

        // Verify coordinates are valid latitude and longitude (no reversed lat/lng)
        for (final p in pts) {
          expect(p.latitude, greaterThan(23.80));
          expect(p.latitude, lessThan(23.85));
          expect(p.longitude, greaterThan(78.75));
          expect(p.longitude, lessThan(78.80));
        }
      }
    });

    test('Full route combines all segments into continuous road geometry (> 200 points)', () {
      final stops = AppConfig.defaultRouteStops;
      final fullRoute = routeService.getFullRoute(stops);

      // Verify total points count
      expect(fullRoute.length, greaterThanOrEqualTo(250),
          reason: 'Full route must contain many road points');

      // Verify first point is Center Point and last point is Center Point
      expect(fullRoute.first.latitude, closeTo(AppConfig.centerPoint.latitude, 0.0001));
      expect(fullRoute.first.longitude, closeTo(AppConfig.centerPoint.longitude, 0.0001));
      expect(fullRoute.last.latitude, closeTo(AppConfig.centerPoint.latitude, 0.0001));
      expect(fullRoute.last.longitude, closeTo(AppConfig.centerPoint.longitude, 0.0001));
    });

    test('Active route from bus GPS follows road geometry toward next stop', () {
      // Test when bus is at a GPS point between Center Point and Computer Science
      const busGps = LatLng(23.826627, 78.774194);
      final activeRoute = routeService.getActiveRoute(
        busPos: busGps,
        fromSeq: 1,
        toSeq: 2,
      );

      // Must start at real bus GPS location
      expect(activeRoute.first, busGps);
      // Must contain intermediate road points
      expect(activeRoute.length, greaterThan(10));
      // Must end at Computer Science Department coordinates
      expect(activeRoute.last.latitude, closeTo(AppConfig.computerScience.latitude, 0.0001));
      expect(activeRoute.last.longitude, closeTo(AppConfig.computerScience.longitude, 0.0001));
    });
  });

  group('Route & Stops Sheet Header Responsive Layout Tests', () {
    Widget buildHeaderWidget({required String etaLabel, bool hasNextStop = true}) {
      return MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CAMPUS ROUTE & STOPS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        '7 Stops • Circular Route',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasNextStop) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'ETA: $etaLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];

    for (final width in screenWidths) {
      testWidgets('Renders without overflow on width: $width px with Calculating ETA', (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildHeaderWidget(etaLabel: 'Calculating...'));
        expect(tester.takeException(), isNull);
        expect(find.text('CAMPUS ROUTE & STOPS'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
      });

      testWidgets('Renders without overflow on width: $width px with standard ETA', (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildHeaderWidget(etaLabel: '12 mins'));
        expect(tester.takeException(), isNull);
        expect(find.text('CAMPUS ROUTE & STOPS'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      });
    }
  });

  group('Route Card Responsive Layout Tests', () {
    Widget buildCardWidget({
      required String stopName,
      required String badgeLabel,
      required String stopCode,
      required int waiting,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          stopName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        child: Text(badgeLabel, style: const TextStyle(fontSize: 9.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('$waiting students waiting', style: const TextStyle(fontSize: 11.5)),
                            const Text('•', style: TextStyle(fontSize: 11.5)),
                            Text(
                              'Stop Code: $stopCode',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final screenWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];

    for (final width in screenWidths) {
      testWidgets('Route Card renders without overflow on width $width px for long stop name', (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildCardWidget(
          stopName: 'Computer Science Department',
          badgeLabel: 'NEXT STOP',
          stopCode: 'COMPUTER_SCIENCE',
          waiting: 5,
        ));

        expect(tester.takeException(), isNull);
        expect(find.text('Computer Science Department'), findsOneWidget);
        expect(find.text('NEXT STOP'), findsOneWidget);
        expect(find.text('Stop Code: COMPUTER_SCIENCE'), findsOneWidget);
      });

      testWidgets('Route Card renders without overflow on width $width px for Center Point with badges', (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildCardWidget(
          stopName: 'Center Point',
          badgeLabel: 'CURRENT',
          stopCode: 'CENTER_POINT',
          waiting: 12,
        ));

        expect(tester.takeException(), isNull);
        expect(find.text('Center Point'), findsOneWidget);
        expect(find.text('Stop Code: CENTER_POINT'), findsOneWidget);
      });
    }
  });

  group('SplashScreen Responsive Layout Tests', () {
    final screenWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];

    for (final width in screenWidths) {
      testWidgets('Student SplashScreen renders without overflow at ${width}px', (tester) async {
        tester.view.physicalSize = Size(width, 800.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: SplashScreen(),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Campus Bus'), findsOneWidget);
        expect(find.text('Dr. Harisingh Gour Vishwavidyalaya, Sagar'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }
  });
}

