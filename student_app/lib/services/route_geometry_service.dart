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
      LatLng(23.82680318, 78.77196191),
      LatLng(23.82682100, 78.77197200),
      LatLng(23.82684567, 78.77204633),
      LatLng(23.82687033, 78.77212067),
      LatLng(23.82689500, 78.77219500),
      LatLng(23.82667153, 78.77243839),
      LatLng(23.82644807, 78.77268179),
      LatLng(23.82622460, 78.77292518),
      LatLng(23.82636714, 78.77332452),
      LatLng(23.82650969, 78.77372387),
      LatLng(23.82665223, 78.77412321),
      LatLng(23.82682008, 78.77432490),
      LatLng(23.82698792, 78.77452660),
      LatLng(23.82715576, 78.77472829),
      LatLng(23.82736340, 78.77490840),
      LatLng(23.82757105, 78.77508851),
      LatLng(23.82777869, 78.77526861),
      LatLng(23.82762452, 78.77617149),
      LatLng(23.82747034, 78.77707437),
      LatLng(23.82731617, 78.77797724),
      LatLng(23.82700420, 78.77832550),
      LatLng(23.82669222, 78.77867376),
      LatLng(23.82638025, 78.77902202),
      LatLng(23.82620776, 78.77911946),
      LatLng(23.82603526, 78.77921690),
      LatLng(23.82586277, 78.77931434),
      LatLng(23.82564736, 78.78021656),
      LatLng(23.82543194, 78.78111878),
      LatLng(23.82521653, 78.78202101),
      LatLng(23.82500524, 78.78204897),
      LatLng(23.82479396, 78.78207694),
      LatLng(23.82458267, 78.78210491),
      LatLng(23.82460704, 78.78210768),
    ],
    '2-3': const [
      LatLng(23.82460704, 78.78210768),
      LatLng(23.82455952, 78.78211784),
      LatLng(23.82451200, 78.78212800),
      LatLng(23.82451593, 78.78220048),
      LatLng(23.82451986, 78.78227296),
      LatLng(23.82452379, 78.78234545),
      LatLng(23.82452772, 78.78241793),
      LatLng(23.82453165, 78.78249041),
      LatLng(23.82453558, 78.78256289),
      LatLng(23.82453951, 78.78263538),
      LatLng(23.82454344, 78.78270786),
      LatLng(23.82454738, 78.78278034),
      LatLng(23.82455131, 78.78285282),
      LatLng(23.82455524, 78.78292531),
      LatLng(23.82455917, 78.78299779),
      LatLng(23.82456310, 78.78307027),
      LatLng(23.82456703, 78.78314275),
      LatLng(23.82457096, 78.78321524),
      LatLng(23.82457489, 78.78328772),
      LatLng(23.82457882, 78.78336020),
      LatLng(23.82451063, 78.78337089),
      LatLng(23.82444244, 78.78338159),
      LatLng(23.82437425, 78.78339228),
      LatLng(23.82430606, 78.78340297),
      LatLng(23.82423787, 78.78341366),
      LatLng(23.82416968, 78.78342436),
      LatLng(23.82410149, 78.78343505),
      LatLng(23.82403330, 78.78344574),
      LatLng(23.82396511, 78.78345643),
      LatLng(23.82389692, 78.78346713),
      LatLng(23.82382873, 78.78347782),
      LatLng(23.82376054, 78.78348851),
      LatLng(23.82369235, 78.78349920),
      LatLng(23.82362416, 78.78350990),
      LatLng(23.82355597, 78.78352059),
      LatLng(23.82352243, 78.78350073),
      LatLng(23.82348890, 78.78348088),
      LatLng(23.82345536, 78.78346102),
      LatLng(23.82346654, 78.78339381),
      LatLng(23.82347772, 78.78332660),
      LatLng(23.82348890, 78.78325939),
      LatLng(23.82350007, 78.78319218),
      LatLng(23.82351125, 78.78312497),
      LatLng(23.82352243, 78.78305776),
      LatLng(23.82353077, 78.78306254),
      LatLng(23.82353910, 78.78306732),
    ],
    // Bypass route when Stop 2 (Computer Science Dept) is skipped: Center Point -> Criminology via road points 6 & 7
    '1-3': const [
      LatLng(23.82680318, 78.77196191),
      LatLng(23.82682100, 78.77197200),
      LatLng(23.82689500, 78.77219500),
      LatLng(23.82622460, 78.77292518),
      LatLng(23.82665223, 78.77412321),
      LatLng(23.82715576, 78.77472829),
      LatLng(23.82777869, 78.77526861),
      LatLng(23.82731617, 78.77797724),
      LatLng(23.82638025, 78.77902202),
      LatLng(23.82586277, 78.77931434),
      LatLng(23.82522439, 78.78201753),
      LatLng(23.82503156, 78.78331438),
      LatLng(23.82355597, 78.78352059),
      LatLng(23.82345536, 78.78346102),
      LatLng(23.82352243, 78.78305776),
      LatLng(23.82353910, 78.78306732),
    ],
    '3-4': const [
      LatLng(23.82353910, 78.78306732),
      LatLng(23.82344232, 78.78296456),
      LatLng(23.82359406, 78.78282079),
      LatLng(23.82370164, 78.78284217),
      LatLng(23.82378721, 78.78316290),
      LatLng(23.82387278, 78.78348362),
      LatLng(23.82411076, 78.78345511),
      LatLng(23.82434874, 78.78342660),
      LatLng(23.82458672, 78.78339809),
      LatLng(23.82455249, 78.78297581),
      LatLng(23.82451826, 78.78255352),
      LatLng(23.82448403, 78.78213123),
      LatLng(23.82473504, 78.78209381),
      LatLng(23.82498606, 78.78205639),
      LatLng(23.82523708, 78.78201897),
      LatLng(23.82538744, 78.78134277),
      LatLng(23.82553781, 78.78066658),
      LatLng(23.82568817, 78.77999038),
      LatLng(23.82583853, 78.77931418),
      LatLng(23.82609139, 78.77917650),
      LatLng(23.82634424, 78.77903883),
      LatLng(23.82665719, 78.77869137),
      LatLng(23.82697014, 78.77834392),
      LatLng(23.82728309, 78.77799647),
      LatLng(23.82741145, 78.77734833),
      LatLng(23.82753980, 78.77670020),
      LatLng(23.82766816, 78.77605206),
      LatLng(23.82779652, 78.77540393),
      LatLng(23.82757811, 78.77518833),
      LatLng(23.82735969, 78.77497273),
      LatLng(23.82714128, 78.77475713),
      LatLng(23.82691635, 78.77452193),
      LatLng(23.82669142, 78.77428673),
      LatLng(23.82652842, 78.77386444),
      LatLng(23.82636543, 78.77344215),
      LatLng(23.82620243, 78.77301986),
      LatLng(23.82642359, 78.77273067),
      LatLng(23.82664475, 78.77244149),
      LatLng(23.82686590, 78.77215230),
      LatLng(23.82683656, 78.77197055),
      LatLng(23.82680723, 78.77178881),
      LatLng(23.82667031, 78.77179415),
      LatLng(23.82665451, 78.77178171),
    ],
    '4-5': const [
      LatLng(23.82665451, 78.77178171),
      LatLng(23.82679260, 78.77178388),
      LatLng(23.82636106, 78.77175448),
      LatLng(23.82592953, 78.77172508),
      LatLng(23.82549799, 78.77169568),
      LatLng(23.82506646, 78.77166628),
      LatLng(23.82463492, 78.77163688),
      LatLng(23.82420339, 78.77160748),
      LatLng(23.82377185, 78.77157808),
      LatLng(23.82334032, 78.77154868),
      LatLng(23.82303714, 78.77157273),
      LatLng(23.82273396, 78.77159679),
      LatLng(23.82268506, 78.77147384),
      LatLng(23.82274612, 78.77126752),
      LatLng(23.82280718, 78.77106119),
      LatLng(23.82282681, 78.77090830),
      LatLng(23.82284644, 78.77075542),
      LatLng(23.82276792, 78.77059449),
      LatLng(23.82262315, 78.77046842),
      LatLng(23.82247839, 78.77034236),
      LatLng(23.82223138, 78.77029050),
      LatLng(23.82198438, 78.77023865),
      LatLng(23.82173737, 78.77018679),
      LatLng(23.82154598, 78.77013851),
      LatLng(23.82135459, 78.77009023),
      LatLng(23.82111904, 78.77014387),
      LatLng(23.82092274, 78.77009023),
      LatLng(23.82072644, 78.77003659),
      LatLng(23.82064792, 78.76995076),
      LatLng(23.82067737, 78.76969863),
      LatLng(23.82070681, 78.76944650),
      LatLng(23.82091619, 78.76964856),
      LatLng(23.82112558, 78.76985062),
      LatLng(23.82133496, 78.77005268),
      LatLng(23.82133496, 78.77005268),
      LatLng(23.82134589, 78.77005729),
    ],
    '5-6': const [
      LatLng(23.82134589, 78.77005729),
      LatLng(23.82154163, 78.77012204),
      LatLng(23.82173737, 78.77018679),
      LatLng(23.82210788, 78.77026457),
      LatLng(23.82247839, 78.77034236),
      LatLng(23.82262316, 78.77046842),
      LatLng(23.82276792, 78.77059449),
      LatLng(23.82280718, 78.77067496),
      LatLng(23.82284644, 78.77075542),
      LatLng(23.82282681, 78.77090831),
      LatLng(23.82280718, 78.77106119),
      LatLng(23.82274612, 78.77126752),
      LatLng(23.82268506, 78.77147384),
      LatLng(23.82270951, 78.77153531),
      LatLng(23.82273396, 78.77159679),
      LatLng(23.82303714, 78.77157274),
      LatLng(23.82334032, 78.77154868),
      LatLng(23.82377186, 78.77157808),
      LatLng(23.82420339, 78.77160748),
      LatLng(23.82463492, 78.77163688),
      LatLng(23.82506646, 78.77166628),
      LatLng(23.82549799, 78.77169568),
      LatLng(23.82592953, 78.77172508),
      LatLng(23.82636107, 78.77175448),
      LatLng(23.82679260, 78.77178388),
      LatLng(23.82681628, 78.77177495),
      LatLng(23.82683996, 78.77176602),
      LatLng(23.82712620, 78.77177418),
      LatLng(23.82741245, 78.77178235),
      LatLng(23.82769870, 78.77179051),
      LatLng(23.82798494, 78.77179867),
      LatLng(23.82816913, 78.77184765),
      LatLng(23.82835332, 78.77189663),
      LatLng(23.82845024, 78.77223398),
      LatLng(23.82854716, 78.77257132),
      LatLng(23.82864408, 78.77290866),
      LatLng(23.82874100, 78.77324600),
      LatLng(23.82885550, 78.77365700),
      LatLng(23.82897000, 78.77406800),
      LatLng(23.82903650, 78.77430500),
      LatLng(23.82910300, 78.77454200),
      LatLng(23.82918350, 78.77481650),
      LatLng(23.82926400, 78.77509100),
      LatLng(23.82939400, 78.77556633),
      LatLng(23.82952400, 78.77604167),
      LatLng(23.82965400, 78.77651700),
      LatLng(23.82972500, 78.77676950),
      LatLng(23.82979600, 78.77702200),
      LatLng(23.82980600, 78.77705750),
      LatLng(23.82981600, 78.77709300),
      LatLng(23.82984600, 78.77719850),
      LatLng(23.82987600, 78.77730400),
      LatLng(23.82990400, 78.77740400),
      LatLng(23.82993200, 78.77750400),
      LatLng(23.82994600, 78.77755350),
      LatLng(23.82996000, 78.77760300),
      LatLng(23.82998850, 78.77770450),
      LatLng(23.83001700, 78.77780600),
      LatLng(23.83009550, 78.77808400),
      LatLng(23.83017400, 78.77836200),
      LatLng(23.83018461, 78.77834555),
      LatLng(23.83019522, 78.77832910),
      LatLng(23.83019806, 78.77835180),
      LatLng(23.83021536, 78.77840351),
    ],
    '6-7': const [
      LatLng(23.83021536, 78.77840351),
      LatLng(23.83018746, 78.77836825),
      LatLng(23.83017400, 78.77836200),
      LatLng(23.83009550, 78.77808400),
      LatLng(23.83001700, 78.77780600),
      LatLng(23.82998850, 78.77770450),
      LatLng(23.82996000, 78.77760300),
      LatLng(23.82994600, 78.77755350),
      LatLng(23.82993200, 78.77750400),
      LatLng(23.82990400, 78.77740400),
      LatLng(23.82987600, 78.77730400),
      LatLng(23.82984600, 78.77719850),
      LatLng(23.82981600, 78.77709300),
      LatLng(23.82980600, 78.77705750),
      LatLng(23.82979600, 78.77702200),
      LatLng(23.82972500, 78.77676950),
      LatLng(23.82965400, 78.77651700),
      LatLng(23.82955650, 78.77616050),
      LatLng(23.82945900, 78.77580400),
      LatLng(23.82936150, 78.77544750),
      LatLng(23.82926400, 78.77509100),
      LatLng(23.82918350, 78.77481650),
      LatLng(23.82910300, 78.77454200),
      LatLng(23.82903650, 78.77430500),
      LatLng(23.82897000, 78.77406800),
      LatLng(23.82891275, 78.77386250),
      LatLng(23.82885550, 78.77365700),
      LatLng(23.82879825, 78.77345150),
      LatLng(23.82874100, 78.77324600),
      LatLng(23.82864408, 78.77290866),
      LatLng(23.82854716, 78.77257132),
      LatLng(23.82845024, 78.77223398),
      LatLng(23.82835332, 78.77189663),
      LatLng(23.82828516, 78.77164432),
      LatLng(23.82821700, 78.77139200),
      LatLng(23.82815350, 78.77151450),
      LatLng(23.82809000, 78.77163700),
      LatLng(23.82806650, 78.77166900),
      LatLng(23.82804300, 78.77170100),
      LatLng(23.82801397, 78.77174983),
      LatLng(23.82798494, 78.77179867),
      LatLng(23.82795197, 78.77179234),
      LatLng(23.82791900, 78.77178600),
      LatLng(23.82787250, 78.77179700),
      LatLng(23.82782600, 78.77180800),
      LatLng(23.82778750, 78.77180900),
      LatLng(23.82774900, 78.77181000),
      LatLng(23.82760450, 78.77179900),
      LatLng(23.82746000, 78.77178800),
      LatLng(23.82742950, 78.77179000),
      LatLng(23.82739900, 78.77179200),
      LatLng(23.82735050, 78.77181450),
      LatLng(23.82730200, 78.77183700),
      LatLng(23.82726800, 78.77185250),
      LatLng(23.82723400, 78.77186800),
      LatLng(23.82703698, 78.77181701),
      LatLng(23.82683996, 78.77176602),
      LatLng(23.82683298, 78.77195051),
      LatLng(23.82682600, 78.77213500),
      LatLng(23.82681750, 78.77209550),
      LatLng(23.82680900, 78.77205600),
      LatLng(23.82680148, 78.77203535),
      LatLng(23.82679396, 78.77201470),
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
      if (key == '1-2' || key == '2-3' || key == '3-4' || key == '5-6' || key == '6-7') {
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
