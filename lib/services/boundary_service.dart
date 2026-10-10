import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class BoundaryCandidate {
  const BoundaryCandidate({
    required this.name,
    required this.displayName,
    required this.osmType,
    required this.osmId,
    required this.points,
  });

  final String name;
  final String displayName;
  final String osmType;
  final int osmId;
  final List<LatLng> points;

  String get key => '$osmType:$osmId';
}

class BoundaryService {
  BoundaryService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BoundaryCandidate>> searchBoundaries({
    required String area,
    required String city,
    required String state,
    String country = 'India',
  }) async {
    final a = area.trim();
    final c = city.trim();
    final s = state.trim();
    final co = country.trim();

    if (a.isEmpty || c.isEmpty || s.isEmpty) {
      throw ArgumentError('Area, city and state are required.');
    }

    final queries = <String>[
      '$a, $c, $s, $co',
      '$a, $c, $co',
      '$a, $s, $co',
      '$a, $co',
    ];

    final found = <String, BoundaryCandidate>{};

    for (final query in queries) {
      try {
        final candidates = await _searchNominatim(query);

        for (final candidate in candidates) {
          found.putIfAbsent(candidate.key, () => candidate);
        }

        if (found.isNotEmpty) {
          return found.values.toList(growable: false);
        }
      } on FormatException {
        rethrow;
      } catch (_) {
        // Try the next query if a particular request fails.
      }
    }

    // Fallback: search named polygon ways in OSM using Overpass.
    try {
      final candidates = await _searchOverpassWays(
        area: a,
        city: c,
        state: s,
      );

      for (final candidate in candidates) {
        found.putIfAbsent(candidate.key, () => candidate);
      }
    } catch (_) {
      // The caller can still offer manual drawing.
    }

    return found.values.toList(growable: false);
  }

  Future<List<BoundaryCandidate>> _searchNominatim(
    String query,
  ) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'jsonv2',
        'polygon_geojson': '1',
        'limit': '10',
        'addressdetails': '1',
        'namedetails': '1',
      },
    );

    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('Nominatim HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected Nominatim response.');
    }

    final results = <BoundaryCandidate>[];

    for (final raw in decoded) {
      if (raw is! Map<String, dynamic>) continue;

      final geo = raw['geojson'];
      if (geo is! Map<String, dynamic>) continue;

      final coordinates = geo['coordinates'];
      if (coordinates is! List) continue;

      final rings = _extractOuterRings(
        geo['type'],
        coordinates,
      );

      for (final ring in rings) {
        final points = _parseRing(ring);
        if (points.length < 3 || points.length > 500) continue;

        final id = int.tryParse('${raw['osm_id']}');
        if (id == null) continue;

        results.add(
          BoundaryCandidate(
            name: '${raw['name'] ?? raw['display_name'] ?? 'Unnamed area'}',
            displayName: '${raw['display_name'] ?? ''}',
            osmType: '${raw['osm_type'] ?? ''}',
            osmId: id,
            points: List.unmodifiable(points),
          ),
        );
      }
    }

    return results;
  }

  Future<List<BoundaryCandidate>> _searchOverpassWays({
    required String area,
    required String city,
    required String state,
  }) async {
    // Search exact area names, plus common OSM place/boundary tags.
    final safeName = area.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

    final query = '''
[out:json][timeout:20];
(
  way["name"="$safeName"]["boundary"](area);
  way["name"="$safeName"]["place"](area);
);
out geom;
''';

    // This query needs a geographic area ID; use Nominatim to resolve it.
    final lookupUri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': '$city, $state, India',
        'format': 'jsonv2',
        'limit': '1',
        'addressdetails': '1',
      },
    );

    final lookup = await _client
        .get(lookupUri, headers: _headers)
        .timeout(const Duration(seconds: 20));

    if (lookup.statusCode != 200) return const [];

    final places = jsonDecode(lookup.body);
    if (places is! List || places.isEmpty || places.first is! Map) {
      return const [];
    }

    final first = places.first as Map;
    final osmId = int.tryParse('${first['osm_id']}');
    final osmType = '${first['osm_type'] ?? ''}';

    if (osmId == null || osmType != 'relation') {
      // Without a reliable area relation, don't run a broad global query.
      return const [];
    }

    final areaId = 3600000000 + osmId;
    final scopedQuery = query.replaceAll('(area);', '(area:$areaId);');

    final response = await _client
        .post(
          Uri.https('overpass-api.de', '/api/interpreter'),
          headers: const {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': scopedQuery},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Overpass HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['elements'] is! List) {
      return const [];
    }

    final results = <BoundaryCandidate>[];

    for (final raw in decoded['elements'] as List) {
      if (raw is! Map || raw['type'] != 'way') continue;

      final geometry = raw['geometry'];
      if (geometry is! List) continue;

      final points = _parseRing(
        geometry
            .whereType<Map>()
            .map((p) => [p['lon'], p['lat']])
            .toList(),
      );

      if (points.length < 3 || points.length > 500) continue;

      final id = int.tryParse('${raw['id']}');
      if (id == null) continue;

      final tags = raw['tags'];
      final name = tags is Map
          ? '${tags['name'] ?? area}'
          : area;

      results.add(
        BoundaryCandidate(
          name: name,
          displayName: '$name, $city, $state',
          osmType: 'way',
          osmId: id,
          points: List.unmodifiable(points),
        ),
      );
    }

    return results;
  }

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'DOJOWalkAdmin/1.0',
  };

  List<dynamic> _extractOuterRings(
    Object? type,
    List<dynamic> coordinates,
  ) {
    if (type == 'Polygon') {
      if (coordinates.isEmpty || coordinates.first is! List) {
        return const [];
      }
      return [coordinates.first];
    }

    if (type == 'MultiPolygon') {
      return coordinates
          .whereType<List>()
          .where((polygon) => polygon.isNotEmpty)
          .map((polygon) => polygon.first)
          .toList();
    }

    return const [];
  }

  List<LatLng> _parseRing(dynamic ring) {
    if (ring is! List) return const [];

    final points = <LatLng>[];

    for (final coordinate in ring) {
      if (coordinate is! List || coordinate.length < 2) continue;

      final longitude = (coordinate[0] as num?)?.toDouble();
      final latitude = (coordinate[1] as num?)?.toDouble();

      if (longitude == null || latitude == null) continue;
      if (latitude < -90 || latitude > 90) continue;
      if (longitude < -180 || longitude > 180) continue;

      final point = LatLng(latitude, longitude);

      if (points.isEmpty ||
          points.last.latitude != point.latitude ||
          points.last.longitude != point.longitude) {
        points.add(point);
      }
    }

    if (points.length > 1 &&
        points.first.latitude == points.last.latitude &&
        points.first.longitude == points.last.longitude) {
      points.removeLast();
    }

    return points;
  }

  @visibleForTesting
  List<LatLng> parseCoordinatesForTesting(dynamic ring) =>
      _parseRing(ring);

  void dispose() => _client.close();
}
