import 'package:cloud_firestore/cloud_firestore.dart';

/// DOJO WALK Admin
///
/// Boundary source types supported by the admin screen.
enum BoundarySourceType {
  governmentGis,
  governmentCadastralMap,
  importedGeoJson,
  manuallyDrawn,
}

/// Boundary verification lifecycle.
///
/// Firestore stores the enum name:
/// notAvailable, pending, verified, rejected.
enum BoundaryVerificationStatus {
  notAvailable,
  pending,
  verified,
  rejected,
}

/// Service location polygon boundary model.
///
/// Firestore collection:
/// service_location_boundaries
///
/// Important:
/// - A polygon requires at least three distinct valid points.
/// - Verified boundaries are read-only in the service layer.
/// - Boundary verification does not activate a service location.
class ServiceLocationBoundary {
  final String id;
  final String locationId;
  final String locationType;

  /// Polygon vertices stored as Firestore GeoPoints.
  final List<GeoPoint> points;

  final BoundarySourceType sourceType;
  final String sourceName;
  final String sourceReference;

  final BoundaryVerificationStatus verificationStatus;

  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? verificationNotes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceLocationBoundary({
    required this.id,
    required this.locationId,
    required this.locationType,
    required this.points,
    required this.sourceType,
    required this.sourceName,
    required this.sourceReference,
    required this.verificationStatus,
    required this.verifiedBy,
    required this.verifiedAt,
    required this.verificationNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this boundary has been verified.
  bool get isVerified =>
      verificationStatus == BoundaryVerificationStatus.verified;

  /// Converts Firestore timestamps and DateTime values safely.
  static DateTime _readDate(
    Object? value, {
    required DateTime fallback,
  }) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return fallback;
  }

  static DateTime? _readNullableDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static String? _readNullableString(Object? value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static BoundarySourceType _readSourceType(Object? value) {
    final name = value?.toString().trim();

    for (final type in BoundarySourceType.values) {
      if (type.name == name) {
        return type;
      }
    }

    return BoundarySourceType.manuallyDrawn;
  }

  static BoundaryVerificationStatus _readVerificationStatus(
    Object? value,
  ) {
    final name = value?.toString().trim().toLowerCase();

    for (final status in BoundaryVerificationStatus.values) {
      if (status.name.toLowerCase() == name) {
        return status;
      }
    }

    return BoundaryVerificationStatus.notAvailable;
  }

  /// Creates a model from a Firestore document.
  factory ServiceLocationBoundary.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final now = DateTime.now();

    final rawPoints = map['points'];
    final parsedPoints = <GeoPoint>[];

    if (rawPoints is Iterable) {
      for (final point in rawPoints) {
        if (point is GeoPoint) {
          parsedPoints.add(point);
        } else if (point is Map) {
          final latitude = point['latitude'];
          final longitude = point['longitude'];

          if (latitude is num && longitude is num) {
            final lat = latitude.toDouble();
            final lon = longitude.toDouble();
            // Firestore GeoPoint asserts on invalid coordinates. Validate
            // imported map data before constructing the GeoPoint.
            if (lat.isFinite &&
                lon.isFinite &&
                lat >= -90 &&
                lat <= 90 &&
                lon >= -180 &&
                lon <= 180) {
              parsedPoints.add(GeoPoint(lat, lon));
            }
          }
        }
      }
    }

    return ServiceLocationBoundary(
      id: id,
      locationId: map['locationId']?.toString() ?? '',
      locationType: map['locationType']?.toString() ?? '',
      points: List<GeoPoint>.unmodifiable(parsedPoints),
      sourceType: _readSourceType(map['sourceType']),
      sourceName: map['sourceName']?.toString() ?? '',
      sourceReference: map['sourceReference']?.toString() ?? '',
      verificationStatus: _readVerificationStatus(
        map['verificationStatus'],
      ),
      verifiedBy: _readNullableString(map['verifiedBy']),
      verifiedAt: _readNullableDate(map['verifiedAt']),
      verificationNotes: _readNullableString(
        map['verificationNotes'],
      ),
      createdAt: _readDate(
        map['createdAt'],
        fallback: now,
      ),
      updatedAt: _readDate(
        map['updatedAt'],
        fallback: now,
      ),
    );
  }

  static const double _geometryEpsilon = 1e-10;

  static bool _samePoint(GeoPoint a, GeoPoint b) =>
      (a.latitude - b.latitude).abs() <= _geometryEpsilon &&
      (a.longitude - b.longitude).abs() <= _geometryEpsilon;

  // Shoelace area in longitude/latitude coordinate space. This is a
  // degeneracy check, not a geodesic area calculation.
  static bool _hasZeroArea(List<GeoPoint> ring) {
    var twiceArea = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];
      twiceArea += current.longitude * next.latitude -
          next.longitude * current.latitude;
    }
    return twiceArea.abs() <= _geometryEpsilon;
  }

  static double _orientation(GeoPoint a, GeoPoint b, GeoPoint c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);

  static bool _onSegment(GeoPoint a, GeoPoint b, GeoPoint p) =>
      p.longitude >= _min(a.longitude, b.longitude) - _geometryEpsilon &&
      p.longitude <= _max(a.longitude, b.longitude) + _geometryEpsilon &&
      p.latitude >= _min(a.latitude, b.latitude) - _geometryEpsilon &&
      p.latitude <= _max(a.latitude, b.latitude) + _geometryEpsilon;

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;

  static bool _segmentsIntersect(
    GeoPoint a,
    GeoPoint b,
    GeoPoint c,
    GeoPoint d,
  ) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);

    if (((o1 > _geometryEpsilon && o2 < -_geometryEpsilon) ||
            (o1 < -_geometryEpsilon && o2 > _geometryEpsilon)) &&
        ((o3 > _geometryEpsilon && o4 < -_geometryEpsilon) ||
            (o3 < -_geometryEpsilon && o4 > _geometryEpsilon))) {
      return true;
    }

    if (o1.abs() <= _geometryEpsilon && _onSegment(a, b, c)) return true;
    if (o2.abs() <= _geometryEpsilon && _onSegment(a, b, d)) return true;
    if (o3.abs() <= _geometryEpsilon && _onSegment(c, d, a)) return true;
    if (o4.abs() <= _geometryEpsilon && _onSegment(c, d, b)) return true;
    return false;
  }

  static bool _hasSelfIntersection(List<GeoPoint> ring) {
    final count = ring.length;
    for (var i = 0; i < count; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % count];
      for (var j = i + 1; j < count; j++) {
        // Adjacent edges share a legitimate endpoint.
        if (j == i || j == i + 1 || (i == 0 && j == count - 1)) {
          continue;
        }
        final c = ring[j];
        final d = ring[(j + 1) % count];
        if (_segmentsIntersect(a, b, c, d)) return true;
      }
    }
    return false;
  }

  /// Returns whether this polygon lies inside or on the edge of [parent].
  ///
  /// Uses planar longitude/latitude geometry. This is a structural containment
  /// check only; it is not a geodesic or official-boundary verification.
  bool isContainedBy(ServiceLocationBoundary parent) {
    if (validate().isNotEmpty || parent.validate().isNotEmpty) {
      return false;
    }

    final childRing = _normalizedRing(points);
    final parentRing = _normalizedRing(parent.points);
    if (childRing.length < 3 || parentRing.length < 3) return false;

    // A child ring must not cross the parent's boundary. Boundary-touching
    // and shared collinear edges are allowed.
    for (var i = 0; i < childRing.length; i++) {
      final a = childRing[i];
      final b = childRing[(i + 1) % childRing.length];
      for (var j = 0; j < parentRing.length; j++) {
        final c = parentRing[j];
        final d = parentRing[(j + 1) % parentRing.length];
        final o1 = _orientation(a, b, c);
        final o2 = _orientation(a, b, d);
        final o3 = _orientation(c, d, a);
        final o4 = _orientation(c, d, b);
        final properCrossing =
            ((o1 > _geometryEpsilon && o2 < -_geometryEpsilon) ||
                (o1 < -_geometryEpsilon && o2 > _geometryEpsilon)) &&
            ((o3 > _geometryEpsilon && o4 < -_geometryEpsilon) ||
                (o3 < -_geometryEpsilon && o4 > _geometryEpsilon));
        if (properCrossing) return false;
      }
    }

    return childRing.every((point) => _pointInOrOnPolygon(point, parentRing));
  }

  static List<GeoPoint> _normalizedRing(List<GeoPoint> points) {
    final ring = List<GeoPoint>.from(points);
    if (ring.length > 3 && _samePoint(ring.first, ring.last)) {
      ring.removeLast();
    }
    return ring;
  }

  static bool _pointInOrOnPolygon(GeoPoint point, List<GeoPoint> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[j];
      final b = ring[i];
      if (_orientation(a, b, point).abs() <= _geometryEpsilon &&
          _onSegment(a, b, point)) {
        return true;
      }
      final straddles = (a.latitude > point.latitude) !=
          (b.latitude > point.latitude);
      if (straddles) {
        final crossingLongitude = a.longitude +
            (point.latitude - a.latitude) *
                (b.longitude - a.longitude) /
                (b.latitude - a.latitude);
        if (point.longitude < crossingLongitude) inside = !inside;
      }
    }
    return inside;
  }

  /// Validates the polygon and its required metadata.
  ///
  /// Returns a list of validation errors.
  List<String> validate() {
    final errors = <String>[];

    if (locationId.trim().isEmpty) {
      errors.add('Location ID is required.');
    }

    final normalizedType = locationType.trim().toLowerCase();

    if (!const {'city', 'area', 'locality'}.contains(
      normalizedType,
    )) {
      errors.add(
        'Location type must be city, area, or locality.',
      );
    }

    if (sourceName.trim().isEmpty) {
      errors.add('Boundary source name is required.');
    }

    if (sourceReference.trim().isEmpty) {
      errors.add('Boundary source reference is required.');
    }

    if (points.length < 3) {
      errors.add(
        'A polygon must contain at least three points.',
      );
    }

    final distinctPoints = <String>{};

    for (var i = 0; i < points.length; i++) {
      final point = points[i];

      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        errors.add('Boundary point ${i + 1} is invalid.');
        continue;
      }

      distinctPoints.add(
        '${point.latitude.toStringAsFixed(7)},'
        '${point.longitude.toStringAsFixed(7)}',
      );
    }

    if (distinctPoints.length < 3) {
      errors.add(
        'A polygon must contain at least three distinct points.',
      );
    } else if (points.length >= 3 &&
        points.every(
          (point) =>
              point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude >= -90 &&
              point.latitude <= 90 &&
              point.longitude >= -180 &&
              point.longitude <= 180,
        )) {
      final ring = List<GeoPoint>.from(points);

      // GeoJSON-style rings may repeat the first point at the end.
      if (ring.length > 3 &&
          _samePoint(ring.first, ring.last)) {
        ring.removeLast();
      }

      if (ring.length < 3) {
        errors.add('A polygon must contain at least three vertices.');
      } else {
        if (_hasZeroArea(ring)) {
          errors.add('A polygon must enclose a non-zero area.');
        }

        if (_hasSelfIntersection(ring)) {
          errors.add('A polygon must not self-intersect.');
        }

        for (var i = 0; i < ring.length; i++) {
          if (_samePoint(ring[i], ring[(i + 1) % ring.length])) {
            errors.add('A polygon must not contain duplicate adjacent points.');
            break;
          }
        }
      }
    }

    return errors.toSet().toList(growable: false);
  }
}
