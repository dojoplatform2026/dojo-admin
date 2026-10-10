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
}

class BoundaryService {
  BoundaryService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<BoundaryCandidate>> searchBoundaries({
    required String area,
    required String city,
    required String state,
    String country = 'India',
  }) async {
    final query = [
      area.trim(),
      city.trim(),
      state.trim(),
      country.trim(),
    ].where((value) => value.isNotEmpty).join(', ');

    if (query.isEmpty) {
      throw ArgumentError('Area details are required.');
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'jsonv2',
        'polygon_geojson': '1',
        'limit': '10',
        'addressdetails': '1',
      },
    );

    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'DOJOWalkAdmin/1.0',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'Boundary search failed (${response.statusCode}). '
        'Please try again later.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw const FormatException('Unexpected boundary response.');
    }

    final results = <BoundaryCandidate>[];

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      final geo = item['geojson'];
      if (geo is! Map<String, dynamic>) continue;

      final type = geo['type'];
      final coordinates = geo['coordinates'];

      if (coordinates is! List) continue;

      final rings = _extractOuterRings(type, coordinates);

      for (final ring in rings) {
        final points = _parseRing(ring);

        // Only accept valid polygons.
        if (points.length < 3 || points.length > 500) {
          continue;
        }

        final osmId = int.tryParse('${item['osm_id']}');
        if (osmId == null) continue;

        results.add(
          BoundaryCandidate(
            name: (item['name'] ?? item['display_name'] ?? 'Unnamed area')
                .toString(),
            displayName: (item['display_name'] ?? '').toString(),
            osmType: (item['osm_type'] ?? '').toString(),
            osmId: osmId,
            points: List<LatLng>.unmodifiable(points),
          ),
        );
      }
    }

    // Avoid duplicate candidates with the same OSM object and polygon.
    final unique = <String, BoundaryCandidate>{};

    for (final candidate in results) {
      final key =
          '${candidate.osmType}:${candidate.osmId}:${candidate.points.length}';
      unique.putIfAbsent(key, () => candidate);
    }

    return unique.values.toList(growable: false);
  }

  List<dynamic> _extractOuterRings(
    Object? type,
    List<dynamic> coordinates,
  ) {
    if (type == 'Polygon') {
      if (coordinates.isEmpty || coordinates.first is! List) {
        return const [];
      }

      // First ring is the exterior; remaining rings are holes.
      return [coordinates.first];
    }

    if (type == 'MultiPolygon') {
      final rings = <dynamic>[];

      for (final polygon in coordinates) {
        if (polygon is List &&
            polygon.isNotEmpty &&
            polygon.first is List) {
          // First ring is the exterior of this polygon.
          rings.add(polygon.first);
        }
      }

      return rings;
    }

    // Points and lines are not area boundaries.
    return const [];
  }

  List<LatLng> _parseRing(dynamic ring) {
    if (ring is! List) return const [];

    final points = <LatLng>[];

    for (final coordinate in ring) {
      if (coordinate is! List || coordinate.length < 2) continue;

      // GeoJSON order is longitude, latitude.
      final longitude = (coordinate[0] as num?)?.toDouble();
      final latitude = (coordinate[1] as num?)?.toDouble();

      if (latitude == null || longitude == null) continue;
      if (latitude < -90 || latitude > 90) continue;
      if (longitude < -180 || longitude > 180) continue;

      final point = LatLng(latitude, longitude);

      if (points.isEmpty ||
          points.last.latitude != point.latitude ||
          points.last.longitude != point.longitude) {
        points.add(point);
      }
    }

    // GeoJSON often repeats the first point at the end.
    if (points.length > 1 &&
        points.first.latitude == points.last.latitude &&
        points.first.longitude == points.last.longitude) {
      points.removeLast();
    }

    return points;
  }

  @visibleForTesting
  List<LatLng> parseCoordinatesForTesting(dynamic ring) {
    return _parseRing(ring);
  }

  void dispose() {
    _client.close();
  }
}
