import 'package:latlong2/latlong.dart';

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
  static const computerScience = LatLng(23.824232252667205, 78.78215542847788);
  static const criminology = LatLng(23.823290586415027, 78.78310833763173);
  static const centerPoint = LatLng(23.826769418621495, 78.77207848833157);
  static const boysHostel = LatLng(23.8223332722968, 78.77027060622879);
  static const girlsHostel = LatLng(23.831797143673885, 78.78234670088726);

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
      'latitude': 23.826769418621495,
      'longitude': 78.77207848833157,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.826769418621495,
        'longitude': 78.77207848833157,
      },
    },
    {
      'id': 'rs_seq_2',
      'sequence': 2,
      'latitude': 23.824232252667205,
      'longitude': 78.78215542847788,
      'stop': {
        'id': 'stop_cs_dept',
        'name': 'Computer Science Department',
        'code': 'CS_DEPT',
        'latitude': 23.824232252667205,
        'longitude': 78.78215542847788,
      },
    },
    {
      'id': 'rs_seq_3',
      'sequence': 3,
      'latitude': 23.823290586415027,
      'longitude': 78.78310833763173,
      'stop': {
        'id': 'stop_criminology',
        'name': 'Criminology Department',
        'code': 'CRIMINOLOGY',
        'latitude': 23.823290586415027,
        'longitude': 78.78310833763173,
      },
    },
    {
      'id': 'rs_seq_4',
      'sequence': 4,
      'latitude': 23.826769418621495,
      'longitude': 78.77207848833157,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.826769418621495,
        'longitude': 78.77207848833157,
      },
    },
    {
      'id': 'rs_seq_5',
      'sequence': 5,
      'latitude': 23.8223332722968,
      'longitude': 78.77027060622879,
      'stop': {
        'id': 'stop_boys_hostel',
        'name': 'Boys Hostel',
        'code': 'BOYS_HOSTEL',
        'latitude': 23.8223332722968,
        'longitude': 78.77027060622879,
      },
    },
    {
      'id': 'rs_seq_6',
      'sequence': 6,
      'latitude': 23.831797143673885,
      'longitude': 78.78234670088726,
      'stop': {
        'id': 'stop_girls_hostel',
        'name': 'Girls Hostel',
        'code': 'GIRLS_HOSTEL',
        'latitude': 23.831797143673885,
        'longitude': 78.78234670088726,
      },
    },
    {
      'id': 'rs_seq_7',
      'sequence': 7,
      'latitude': 23.826769418621495,
      'longitude': 78.77207848833157,
      'stop': {
        'id': 'stop_center_point',
        'name': 'Center Point',
        'code': 'CENTER_POINT',
        'latitude': 23.826769418621495,
        'longitude': 78.77207848833157,
      },
    },
  ];
}
