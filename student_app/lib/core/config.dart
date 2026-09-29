import 'package:latlong2/latlong.dart';

import '../models/models.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/$'), '');
    }
    //https://bus-traking-production.up.railway.app
    return 'http://localhost:4000';
  }

  // Dr. Harisingh Gour Vishwavidyalaya, Sagar Centroid
  static const campusCenterLat = 23.8267;
  static const campusCenterLng = 78.7762;

  // Verified University Bus Stop Coordinates (Single Source of Truth)
  static const computerScience = LatLng(23.824607044488115, 78.78210767766332);
  static const criminology = LatLng(23.823539099418205, 78.78306732002264);
  static const centerPoint = LatLng(23.826803182208682, 78.77196190502646);
  static const centerPointSeq4 = LatLng(23.82665450787519, 78.77178170834694);
  static const centerPointSeq7 = LatLng(23.82679396278914, 78.77201469954832);
  static const boysHostel = LatLng(23.821345891404626, 78.7700572856471);
  static const girlsHostel = LatLng(23.830215356429985, 78.77840351072815);

  /// Default 7-stop fixed circular route with unique sequences:
  /// Sequence 1 -> Center Point
  /// Sequence 2 -> Computer Science Department
  /// Sequence 3 -> Criminology Department
  /// Sequence 4 -> Center Point
  /// Sequence 5 -> Boys Hostel
  /// Sequence 6 -> Girls Hostel
  /// Sequence 7 -> Center Point
  static List<RouteStopInfo> get defaultRouteStops => [
    RouteStopInfo(
      id: 'rs_seq_1',
      sequence: 1,
      latitude: centerPoint.latitude,
      longitude: centerPoint.longitude,
      stop: StopInfo(
        id: 'stop_center_point',
        name: 'Center Point',
        code: 'CENTER_POINT',
        latitude: centerPoint.latitude,
        longitude: centerPoint.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_2',
      sequence: 2,
      latitude: computerScience.latitude,
      longitude: computerScience.longitude,
      stop: StopInfo(
        id: 'stop_cs_dept',
        name: 'Computer Science Department',
        code: 'CS_DEPT',
        latitude: computerScience.latitude,
        longitude: computerScience.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_3',
      sequence: 3,
      latitude: criminology.latitude,
      longitude: criminology.longitude,
      stop: StopInfo(
        id: 'stop_criminology',
        name: 'Criminology Department',
        code: 'CRIMINOLOGY',
        latitude: criminology.latitude,
        longitude: criminology.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_4',
      sequence: 4,
      latitude: centerPointSeq4.latitude,
      longitude: centerPointSeq4.longitude,
      stop: StopInfo(
        id: 'stop_center_point',
        name: 'Center Point',
        code: 'CENTER_POINT',
        latitude: centerPointSeq4.latitude,
        longitude: centerPointSeq4.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_5',
      sequence: 5,
      latitude: boysHostel.latitude,
      longitude: boysHostel.longitude,
      stop: StopInfo(
        id: 'stop_boys_hostel',
        name: 'Boys Hostel',
        code: 'BOYS_HOSTEL',
        latitude: boysHostel.latitude,
        longitude: boysHostel.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_6',
      sequence: 6,
      latitude: girlsHostel.latitude,
      longitude: girlsHostel.longitude,
      stop: StopInfo(
        id: 'stop_girls_hostel',
        name: 'Girls Hostel',
        code: 'GIRLS_HOSTEL',
        latitude: girlsHostel.latitude,
        longitude: girlsHostel.longitude,
      ),
    ),
    RouteStopInfo(
      id: 'rs_seq_7',
      sequence: 7,
      latitude: centerPointSeq7.latitude,
      longitude: centerPointSeq7.longitude,
      stop: StopInfo(
        id: 'stop_center_point',
        name: 'Center Point',
        code: 'CENTER_POINT',
        latitude: centerPointSeq7.latitude,
        longitude: centerPointSeq7.longitude,
      ),
    ),
  ];
}
