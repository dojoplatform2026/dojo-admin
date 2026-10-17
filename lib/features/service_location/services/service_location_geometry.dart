import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure geometry checks for service-location polygons.
///
/// Coordinates are treated in a local latitude/longitude plane. This is
/// appropriate for the small, local service areas used by DOJO WALK, but is
/// not a replacement for authoritative GIS topology validation.
class ServiceLocationGeometry {
  ServiceLocationGeometry._();

  static const double _epsilon = 1e-9;

  /// True when [points] form a valid simple polygon ring.
  ///
  /// Rejects invalid coordinates, fewer than three distinct vertices, and
  /// self-intersections or non-adjacent edge touches.
  static bool isValidPolygon(List<GeoPoint> points) => _isValidRing(points);

  /// True when [child] is a valid polygon contained by [parent].
  ///
  /// Points on the parent edge are accepted (shared borders are allowed).
  /// Rejects invalid coordinates, degenerate rings, vertices outside the
  /// parent, child edges whose midpoints are outside, and proper crossings
  /// of parent edges.
  static bool isPolygonContained({
    required List<GeoPoint> parent,
    required List<GeoPoint> child,
  }) {
    if (!_isValidRing(parent) || !_isValidRing(child)) return false;

    for (final point in child) {
      if (!_pointInOrOnPolygon(point, parent)) return false;
    }

    for (var i = 0; i < child.length; i++) {
      final a = child[i];
      final b = child[(i + 1) % child.length];
      final midpoint = GeoPoint(
        (a.latitude + b.latitude) / 2,
        (a.longitude + b.longitude) / 2,
      );
      if (!_pointInOrOnPolygon(midpoint, parent)) return false;

      for (var j = 0; j < parent.length; j++) {
        final c = parent[j];
        final d = parent[(j + 1) % parent.length];
        if (_properSegmentsIntersect(a, b, c, d)) return false;
      }
    }
    return true;
  }

  static bool _isValidRing(List<GeoPoint> points) {
    if (points.length < 3) return false;
    final unique = <String>{};
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final next = points[(i + 1) % points.length];
      if (!p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude < -90 ||
          p.latitude > 90 ||
          p.longitude < -180 ||
          p.longitude > 180) {
        return false;
      }

      // A zero-length edge is invalid even if the ring has three or more
      // other distinct vertices. Reject repeated consecutive points rather
      // than allowing a degenerate segment into verification/containment.
      if ((p.latitude - next.latitude).abs() <= _epsilon &&
          (p.longitude - next.longitude).abs() <= _epsilon) {
        return false;
      }

      unique.add(
        '${p.latitude.toStringAsFixed(7)},'
        '${p.longitude.toStringAsFixed(7)}',
      );
    }
    return unique.length >= 3 && !_hasSelfIntersection(points);
  }

  /// Rejects non-adjacent edges that cross or touch. Adjacent edges share
  /// their common vertex by design and are skipped.
  static bool _hasSelfIntersection(List<GeoPoint> points) {
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      for (var j = i + 1; j < points.length; j++) {
        // Edges that are adjacent in the ring are expected to share a vertex.
        if (j == i || j == i + 1 || (i == 0 && j == points.length - 1)) {
          continue;
        }
        final c = points[j];
        final d = points[(j + 1) % points.length];
        if (_segmentsIntersect(a, b, c, d)) return true;
      }
    }
    return false;
  }

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
    final crosses = ((o1 > _epsilon && o2 < -_epsilon) ||
            (o1 < -_epsilon && o2 > _epsilon)) &&
        ((o3 > _epsilon && o4 < -_epsilon) ||
            (o3 < -_epsilon && o4 > _epsilon));
    if (crosses) return true;
    if (o1.abs() <= _epsilon && _pointOnSegment(c, a, b)) return true;
    if (o2.abs() <= _epsilon && _pointOnSegment(d, a, b)) return true;
    if (o3.abs() <= _epsilon && _pointOnSegment(a, c, d)) return true;
    if (o4.abs() <= _epsilon && _pointOnSegment(b, c, d)) return true;
    return false;
  }

  static bool _pointInOrOnPolygon(GeoPoint point, List<GeoPoint> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[j];
      final b = polygon[i];
      if (_pointOnSegment(point, a, b)) return true;

      final crosses = (a.latitude > point.latitude) !=
          (b.latitude > point.latitude);
      if (crosses) {
        final longitudeAtLatitude = a.longitude +
            (point.latitude - a.latitude) *
                (b.longitude - a.longitude) /
                (b.latitude - a.latitude);
        if (point.longitude < longitudeAtLatitude) inside = !inside;
      }
    }
    return inside;
  }

  static bool _pointOnSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
    final cross = (p.longitude - a.longitude) *
            (b.latitude - a.latitude) -
        (p.latitude - a.latitude) * (b.longitude - a.longitude);
    if (cross.abs() > _epsilon) return false;

    return p.latitude >= _min(a.latitude, b.latitude) - _epsilon &&
        p.latitude <= _max(a.latitude, b.latitude) + _epsilon &&
        p.longitude >= _min(a.longitude, b.longitude) - _epsilon &&
        p.longitude <= _max(a.longitude, b.longitude) + _epsilon;
  }

  static bool _properSegmentsIntersect(
    GeoPoint a,
    GeoPoint b,
    GeoPoint c,
    GeoPoint d,
  ) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    return ((o1 > _epsilon && o2 < -_epsilon) ||
            (o1 < -_epsilon && o2 > _epsilon)) &&
        ((o3 > _epsilon && o4 < -_epsilon) ||
            (o3 < -_epsilon && o4 > _epsilon));
  }

  static double _orientation(GeoPoint a, GeoPoint b, GeoPoint c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
