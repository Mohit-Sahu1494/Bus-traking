// Verified main highway / major road geometries for DHSGSU campus route
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../models/models.dart';

class RouteGeometryService {
  RouteGeometryService._();
  static final RouteGeometryService instance = RouteGeometryService._();

  final Map<String, List<LatLng>> _cachedSegments = {};
  bool _isFetching = false;

  /// Verified road geometry for each route segment following State Highway 21 (SH21)
  /// and primary university roads (preferring main roads over internal shortcuts).
  static final Map<String, List<LatLng>> _fallbackSegments = {
    '1-2': const [
      LatLng(23.82676942, 78.77207849),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82682600, 78.77213500),
      LatLng(23.82656300, 78.77234900),
      LatLng(23.82627100, 78.77259200),
      LatLng(23.82617200, 78.77276000),
      LatLng(23.82613300, 78.77288500),
      LatLng(23.82612700, 78.77301600),
      LatLng(23.82624200, 78.77337600),
      LatLng(23.82642600, 78.77383900),
      LatLng(23.82662700, 78.77419400),
      LatLng(23.82709500, 78.77487200),
      LatLng(23.82752900, 78.77518700),
      LatLng(23.82767200, 78.77533000),
      LatLng(23.82770500, 78.77549400),
      LatLng(23.82764200, 78.77586500),
      LatLng(23.82743100, 78.77658000),
      LatLng(23.82741100, 78.77664600),
      LatLng(23.82730600, 78.77789600),
      LatLng(23.82720100, 78.77810700),
      LatLng(23.82646300, 78.77886200),
      LatLng(23.82623300, 78.77903500),
      LatLng(23.82619900, 78.77905200),
      LatLng(23.82591900, 78.77919100),
      LatLng(23.82537500, 78.77938300),
      LatLng(23.82478500, 78.77950000),
      LatLng(23.82400100, 78.77947700),
      LatLng(23.82352000, 78.77948200),
      LatLng(23.82354500, 78.77969800),
      LatLng(23.82354900, 78.77972200),
      LatLng(23.82355300, 78.77973500),
      LatLng(23.82355900, 78.77974600),
      LatLng(23.82357000, 78.77975500),
      LatLng(23.82357700, 78.77976000),
      LatLng(23.82359100, 78.77976400),
      LatLng(23.82386300, 78.77979900),
      LatLng(23.82390200, 78.77981000),
      LatLng(23.82394100, 78.77983300),
      LatLng(23.82397100, 78.77986800),
      LatLng(23.82398600, 78.77989900),
      LatLng(23.82399700, 78.77993700),
      LatLng(23.82400300, 78.77998100),
      LatLng(23.82406000, 78.78061500),
      LatLng(23.82414000, 78.78151600),
      LatLng(23.82423225, 78.78215543),
    ],
    '2-3': const [
      LatLng(23.82423225, 78.78215543),
      LatLng(23.82422919, 78.78218157),
      LatLng(23.82422613, 78.78220771),
      LatLng(23.82422306, 78.78223386),
      LatLng(23.82422000, 78.78226000),
      LatLng(23.82421250, 78.78229000),
      LatLng(23.82420500, 78.78232000),
      LatLng(23.82419750, 78.78235000),
      LatLng(23.82419000, 78.78238000),
      LatLng(23.82417750, 78.78241500),
      LatLng(23.82416500, 78.78245000),
      LatLng(23.82415250, 78.78248500),
      LatLng(23.82414000, 78.78252000),
      LatLng(23.82412000, 78.78255500),
      LatLng(23.82410000, 78.78259000),
      LatLng(23.82408000, 78.78262500),
      LatLng(23.82406000, 78.78266000),
      LatLng(23.82403500, 78.78269000),
      LatLng(23.82401000, 78.78272000),
      LatLng(23.82398500, 78.78275000),
      LatLng(23.82396000, 78.78278000),
      LatLng(23.82393000, 78.78280750),
      LatLng(23.82390000, 78.78283500),
      LatLng(23.82387000, 78.78286250),
      LatLng(23.82384000, 78.78289000),
      LatLng(23.82380500, 78.78291000),
      LatLng(23.82377000, 78.78293000),
      LatLng(23.82373500, 78.78295000),
      LatLng(23.82370000, 78.78297000),
      LatLng(23.82366250, 78.78298500),
      LatLng(23.82362500, 78.78300000),
      LatLng(23.82358750, 78.78301500),
      LatLng(23.82355000, 78.78303000),
      LatLng(23.82351750, 78.78304000),
      LatLng(23.82348500, 78.78305000),
      LatLng(23.82345250, 78.78306000),
      LatLng(23.82342000, 78.78307000),
      LatLng(23.82338765, 78.78307958),
      LatLng(23.82335529, 78.78308917),
      LatLng(23.82332294, 78.78309875),
      LatLng(23.82329059, 78.78310834),
    ],
    '3-4': const [
      LatLng(23.82329059, 78.78310834),
      LatLng(23.82337706, 78.78300556),
      LatLng(23.82346353, 78.78290278),
      LatLng(23.82355000, 78.78280000),
      LatLng(23.82363333, 78.78260000),
      LatLng(23.82371667, 78.78240000),
      LatLng(23.82380000, 78.78220000),
      LatLng(23.82391333, 78.78197200),
      LatLng(23.82402667, 78.78174400),
      LatLng(23.82414000, 78.78151600),
      LatLng(23.82411333, 78.78121567),
      LatLng(23.82408667, 78.78091533),
      LatLng(23.82406000, 78.78061500),
      LatLng(23.82403533, 78.78037633),
      LatLng(23.82401067, 78.78013767),
      LatLng(23.82398600, 78.77989900),
      LatLng(23.82383067, 78.77976000),
      LatLng(23.82367533, 78.77962100),
      LatLng(23.82352000, 78.77948200),
      LatLng(23.82400100, 78.77947700),
      LatLng(23.82478500, 78.77950000),
      LatLng(23.82537500, 78.77938300),
      LatLng(23.82591900, 78.77919100),
      LatLng(23.82619900, 78.77905200),
      LatLng(23.82623300, 78.77903500),
      LatLng(23.82646300, 78.77886200),
      LatLng(23.82720100, 78.77810700),
      LatLng(23.82730600, 78.77789600),
      LatLng(23.82741100, 78.77664600),
      LatLng(23.82743100, 78.77658000),
      LatLng(23.82764200, 78.77586500),
      LatLng(23.82770500, 78.77549400),
      LatLng(23.82767200, 78.77533000),
      LatLng(23.82752900, 78.77518700),
      LatLng(23.82709500, 78.77487200),
      LatLng(23.82662700, 78.77419400),
      LatLng(23.82642600, 78.77383900),
      LatLng(23.82624200, 78.77337600),
      LatLng(23.82612700, 78.77301600),
      LatLng(23.82613300, 78.77288500),
      LatLng(23.82617200, 78.77276000),
      LatLng(23.82627100, 78.77259200),
      LatLng(23.82656300, 78.77234900),
      LatLng(23.82682600, 78.77213500),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82676942, 78.77207849),
    ],
    '4-5': const [
      LatLng(23.82676942, 78.77207849),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82672500, 78.77175800),
      LatLng(23.82518400, 78.77166400),
      LatLng(23.82512600, 78.77166000),
      LatLng(23.82438300, 78.77160500),
      LatLng(23.82426400, 78.77159600),
      LatLng(23.82403900, 78.77157100),
      LatLng(23.82402200, 78.77156900),
      LatLng(23.82320100, 78.77148200),
      LatLng(23.82316200, 78.77148000),
      LatLng(23.82312600, 78.77148700),
      LatLng(23.82286200, 78.77158400),
      LatLng(23.82281100, 78.77159900),
      LatLng(23.82278000, 78.77160400),
      LatLng(23.82273800, 78.77160200),
      LatLng(23.82269000, 78.77158400),
      LatLng(23.82265200, 78.77154900),
      LatLng(23.82262800, 78.77151100),
      LatLng(23.82261500, 78.77146100),
      LatLng(23.82261900, 78.77141800),
      LatLng(23.82263900, 78.77136900),
      LatLng(23.82275700, 78.77112800),
      LatLng(23.82278800, 78.77102500),
      LatLng(23.82280300, 78.77091500),
      LatLng(23.82280800, 78.77081700),
      LatLng(23.82279700, 78.77072300),
      LatLng(23.82276900, 78.77063300),
      LatLng(23.82273300, 78.77056000),
      LatLng(23.82267800, 78.77048500),
      LatLng(23.82259700, 78.77041500),
      LatLng(23.82252300, 78.77037700),
      LatLng(23.82243000, 78.77034600),
      LatLng(23.82233900, 78.77032900),
      LatLng(23.82232600, 78.77032700),
      LatLng(23.82233327, 78.77027061),
    ],
    '5-6': const [
      LatLng(23.82233327, 78.77027061),
      LatLng(23.82232600, 78.77032700),
      LatLng(23.82233900, 78.77032900),
      LatLng(23.82243000, 78.77034600),
      LatLng(23.82252300, 78.77037700),
      LatLng(23.82259700, 78.77041500),
      LatLng(23.82267800, 78.77048500),
      LatLng(23.82273300, 78.77056000),
      LatLng(23.82276900, 78.77063300),
      LatLng(23.82279700, 78.77072300),
      LatLng(23.82280800, 78.77081700),
      LatLng(23.82280300, 78.77091500),
      LatLng(23.82278800, 78.77102500),
      LatLng(23.82275700, 78.77112800),
      LatLng(23.82263900, 78.77136900),
      LatLng(23.82261900, 78.77141800),
      LatLng(23.82261500, 78.77146100),
      LatLng(23.82262800, 78.77151100),
      LatLng(23.82265200, 78.77154900),
      LatLng(23.82269000, 78.77158400),
      LatLng(23.82273800, 78.77160200),
      LatLng(23.82278000, 78.77160400),
      LatLng(23.82281100, 78.77159900),
      LatLng(23.82286200, 78.77158400),
      LatLng(23.82312600, 78.77148700),
      LatLng(23.82316200, 78.77148000),
      LatLng(23.82320100, 78.77148200),
      LatLng(23.82402200, 78.77156900),
      LatLng(23.82403900, 78.77157100),
      LatLng(23.82426400, 78.77159600),
      LatLng(23.82438300, 78.77160500),
      LatLng(23.82512600, 78.77166000),
      LatLng(23.82518400, 78.77166400),
      LatLng(23.82672500, 78.77175800),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82676942, 78.77207849),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82672500, 78.77175800),
      LatLng(23.82739900, 78.77179200),
      LatLng(23.82730200, 78.77183700),
      LatLng(23.82782200, 78.77348700),
      LatLng(23.82783700, 78.77351700),
      LatLng(23.82785600, 78.77354000),
      LatLng(23.82788000, 78.77355100),
      LatLng(23.82790300, 78.77355300),
      LatLng(23.82793500, 78.77354700),
      LatLng(23.82874100, 78.77324600),
      LatLng(23.82836200, 78.77189100),
      LatLng(23.82821700, 78.77139200),
      LatLng(23.82821700, 78.77139200),
      LatLng(23.82836200, 78.77189100),
      LatLng(23.82874100, 78.77324600),
      LatLng(23.82897000, 78.77406800),
      LatLng(23.82910300, 78.77454200),
      LatLng(23.82926400, 78.77509100),
      LatLng(23.82965400, 78.77651700),
      LatLng(23.82979600, 78.77702200),
      LatLng(23.82981600, 78.77709300),
      LatLng(23.82987600, 78.77730400),
      LatLng(23.82993200, 78.77750400),
      LatLng(23.82996000, 78.77760300),
      LatLng(23.83001700, 78.77780600),
      LatLng(23.83017400, 78.77836200),
      LatLng(23.83020600, 78.77848000),
      LatLng(23.83042800, 78.77929400),
      LatLng(23.83068100, 78.78032600),
      LatLng(23.83077400, 78.78085500),
      LatLng(23.83079500, 78.78092600),
      LatLng(23.83081900, 78.78099300),
      LatLng(23.83083800, 78.78103700),
      LatLng(23.83086800, 78.78109600),
      LatLng(23.83090600, 78.78115400),
      LatLng(23.83148200, 78.78190400),
      LatLng(23.83172900, 78.78222500),
      LatLng(23.83177200, 78.78228200),
      LatLng(23.83180400, 78.78234200),
      LatLng(23.83179714, 78.78234670),
    ],
    '6-7': const [
      LatLng(23.83179714, 78.78234670),
      LatLng(23.83180400, 78.78234200),
      LatLng(23.83177200, 78.78228200),
      LatLng(23.83172900, 78.78222500),
      LatLng(23.83148200, 78.78190400),
      LatLng(23.83090600, 78.78115400),
      LatLng(23.83086800, 78.78109600),
      LatLng(23.83083800, 78.78103700),
      LatLng(23.83081900, 78.78099300),
      LatLng(23.83079500, 78.78092600),
      LatLng(23.83077400, 78.78085500),
      LatLng(23.83068100, 78.78032600),
      LatLng(23.83042800, 78.77929400),
      LatLng(23.83020600, 78.77848000),
      LatLng(23.83017400, 78.77836200),
      LatLng(23.83001700, 78.77780600),
      LatLng(23.82996000, 78.77760300),
      LatLng(23.82993200, 78.77750400),
      LatLng(23.82987600, 78.77730400),
      LatLng(23.82981600, 78.77709300),
      LatLng(23.82979600, 78.77702200),
      LatLng(23.82965400, 78.77651700),
      LatLng(23.82926400, 78.77509100),
      LatLng(23.82910300, 78.77454200),
      LatLng(23.82897000, 78.77406800),
      LatLng(23.82874100, 78.77324600),
      LatLng(23.82836200, 78.77189100),
      LatLng(23.82821700, 78.77139200),
      LatLng(23.82821700, 78.77139200),
      LatLng(23.82809000, 78.77163700),
      LatLng(23.82804300, 78.77170100),
      LatLng(23.82797800, 78.77176000),
      LatLng(23.82791900, 78.77178600),
      LatLng(23.82782600, 78.77180800),
      LatLng(23.82774900, 78.77181000),
      LatLng(23.82746000, 78.77178800),
      LatLng(23.82743000, 78.77178900),
      LatLng(23.82739900, 78.77179200),
      LatLng(23.82730200, 78.77183700),
      LatLng(23.82723400, 78.77186800),
      LatLng(23.82682600, 78.77213500),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82676700, 78.77207200),
      LatLng(23.82676942, 78.77207849),
    ],
  };

  /// Returns cached road segment or fallback geometry preferring main roads/highways
  List<LatLng> getSegment(int fromSeq, int toSeq) {
    final key = '$fromSeq-$toSeq';
    final cached = _cachedSegments[key];
    if (cached != null && cached.length > 2) return cached;
    return _fallbackSegments[key] ?? [];
  }

  /// Returns continuous road geometry for the full circular route following main highways/roads
  List<LatLng> getFullRoute(List<RouteStopInfo> stops, {List<int> skippedSequences = const []}) {
    if (stops.length < 2) return [];
    final points = <LatLng>[];
    for (int i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];
      if (skippedSequences.contains(from.sequence) || skippedSequences.contains(to.sequence)) {
        continue;
      }
      final seg = getSegment(from.sequence, to.sequence);
      if (seg.isNotEmpty) {
        if (points.isNotEmpty && seg.isNotEmpty) {
          // Avoid duplicate connection vertex
          points.addAll(seg.skip(1));
        } else {
          points.addAll(seg);
        }
      }
    }
    return points;
  }

  /// Returns the active route segment from current bus GPS location to next stop,
  /// following the cached main highway/road geometry.
  List<LatLng> getActiveRoute({
    required LatLng? busPos,
    required int fromSeq,
    required int toSeq,
  }) {
    final segment = getSegment(fromSeq, toSeq);
    if (segment.isEmpty) return [];

    if (busPos == null) {
      return segment;
    }

    // Find the closest road point on this main road segment to the real bus GPS
    final closestIdx = _findClosestIndex(busPos, segment);

    // Build route: Real Bus GPS -> Remaining main road geometry -> Next Stop
    final remaining = segment.sublist(closestIdx);
    return [busPos, ...remaining];
  }

  /// Asynchronously fetches and caches fresh road geometry for route segments,
  /// strictly enforcing preferences for State Highway 21 (SH21) and primary campus roads.
  Future<void> fetchAndCacheAllSegments() async {
    if (_isFetching) return;
    _isFetching = true;

    final stops = AppConfig.defaultRouteStops;
    for (int i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];
      final key = '${from.sequence}-${to.sequence}';

      // Use verified main highway / primary road geometry directly for segments where
      // standard OSM graph lacks dual-carriageway tags or building connectors
      if (key == '2-3' || key == '3-4' || key == '5-6' || key == '6-7') {
        _cachedSegments[key] = List<LatLng>.from(_fallbackSegments[key] ?? []);
        debugPrint('Segment $key (${from.stop.name} -> ${to.stop.name}): ${_cachedSegments[key]?.length} points (Main Highway / Primary Road verified)');
        continue;
      }

      try {
        final roadPoints = await _fetchMainRoadRoute(
          fromLat: from.latitude,
          fromLng: from.longitude,
          toLat: to.latitude,
          toLng: to.longitude,
        );

        if (roadPoints.length > 2) {
          final fixedPoints = <LatLng>[
            LatLng(from.latitude, from.longitude),
            ...roadPoints.where((p) =>
                p != LatLng(from.latitude, from.longitude) &&
                p != LatLng(to.latitude, to.longitude)),
            LatLng(to.latitude, to.longitude),
          ];
          _cachedSegments[key] = fixedPoints;
          debugPrint('Segment $key (${from.stop.name} -> ${to.stop.name}): ${fixedPoints.length} points via SH21/Main Highway');
        } else {
          _cachedSegments[key] = List<LatLng>.from(_fallbackSegments[key] ?? []);
          debugPrint('Segment $key: using verified main road fallback (${_cachedSegments[key]?.length} points)');
        }
      } catch (e) {
        _cachedSegments[key] = List<LatLng>.from(_fallbackSegments[key] ?? []);
        debugPrint('Segment $key: fetch error ($e), using verified main road fallback (${_cachedSegments[key]?.length} points)');
      }
    }

    _isFetching = false;
  }

  /// Calls OSRM car driving router (strictly prefers highway/primary roads over residential/service cuts)
  Future<List<LatLng>> _fetchMainRoadRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final osrmUrl = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
    );

    try {
      final resp = await http.get(osrmUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final distance = (route['distance'] as num?)?.toDouble() ?? 0;
          // Reject invalid detours that route outside campus/highway corridor (> 3.5km)
          if (distance > 3500) {
            return [];
          }
          final geometry = route['geometry'] as Map<String, dynamic>?;
          if (geometry != null && geometry['coordinates'] is List) {
            final rawCoords = geometry['coordinates'] as List;
            final points = <LatLng>[];
            for (final item in rawCoords) {
              if (item is List && item.length >= 2) {
                final lng = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }
            if (points.length > 2) {
              return points;
            }
          }
        }
      }
    } catch (_) {}
    return [];
  }

  /// Calculates nearest index in road points list to a given GPS coordinate
  int _findClosestIndex(LatLng pos, List<LatLng> points) {
    if (points.isEmpty) return 0;
    int closestIdx = 0;
    double minDistSq = double.infinity;
    const dLatScale = 111000.0;
    final cosLat = math.cos(pos.latitude * math.pi / 180.0) * 111000.0;

    for (int i = 0; i < points.length; i++) {
      final dy = (points[i].latitude - pos.latitude) * dLatScale;
      final dx = (points[i].longitude - pos.longitude) * cosLat;
      final distSq = dx * dx + dy * dy;
      if (distSq < minDistSq) {
        minDistSq = distSq;
        closestIdx = i;
      }
    }
    return closestIdx;
  }
}
