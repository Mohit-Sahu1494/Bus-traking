import 'package:latlong2/latlong.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/$'), '');
    }

    //https://bus-traking-production.up.railway.app
    return 'https://bus-traking-production.up.railway.app';
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
  static const List<Map<String, dynamic>> defaultRouteStops = [
    {
      'id': 'rs_seq_1',
      'sequence': 1,
      'latitude': 23.826803182208682,
      'longitude': 78.77196190502646,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.826803182208682,
        'longitude': 78.77196190502646,
      },
    },
    {
      'id': 'rs_seq_2',
      'sequence': 2,
      'latitude': 23.824607044488115,
      'longitude': 78.78210767766332,
      'stop': {
        'id': 'stop_cs_dept',
        'name': 'Computer Science Department',
        'code': 'CS_DEPT',
        'latitude': 23.824607044488115,
        'longitude': 78.78210767766332,
      },
    },
    {
      'id': 'rs_seq_3',
      'sequence': 3,
      'latitude': 23.823539099418205,
      'longitude': 78.78306732002264,
      'stop': {
        'id': 'stop_criminology',
        'name': 'Criminology Department',
        'code': 'CRIMINOLOGY',
        'latitude': 23.823539099418205,
        'longitude': 78.78306732002264,
      },
    },
    {
      'id': 'rs_seq_4',
      'sequence': 4,
      'latitude': 23.82665450787519,
      'longitude': 78.77178170834694,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.82665450787519,
        'longitude': 78.77178170834694,
      },
    },
    {
      'id': 'rs_seq_5',
      'sequence': 5,
      'latitude': 23.821345891404626,
      'longitude': 78.7700572856471,
      'stop': {
        'id': 'stop_boys_hostel',
        'name': 'Boys Hostel',
        'code': 'BOYS_HOSTEL',
        'latitude': 23.821345891404626,
        'longitude': 78.7700572856471,
      },
    },
    {
      'id': 'rs_seq_6',
      'sequence': 6,
      'latitude': 23.830215356429985,
      'longitude': 78.77840351072815,
      'stop': {
        'id': 'stop_girls_hostel',
        'name': 'Girls Hostel',
        'code': 'GIRLS_HOSTEL',
        'latitude': 23.830215356429985,
        'longitude': 78.77840351072815,
      },
    },
    {
      'id': 'rs_seq_7',
      'sequence': 7,
      'latitude': 23.82679396278914,
      'longitude': 78.77201469954832,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.82679396278914,
        'longitude': 78.77201469954832,
      },
    },
  ];
}
