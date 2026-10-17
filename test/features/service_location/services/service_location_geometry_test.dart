import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_admin/features/service_location/services/service_location_geometry.dart';

GeoPoint p(double lat, double lng) => GeoPoint(lat, lng);

void main() {
  group('ServiceLocationGeometry.isValidPolygon', () {
    test('accepts a simple polygon', () {
      expect(
        ServiceLocationGeometry.isValidPolygon([
          p(0, 0),
          p(0, 2),
          p(2, 2),
          p(2, 0),
        ]),
        isTrue,
      );
    });

    test('rejects consecutive duplicate vertices that create a zero-length edge', () {
      expect(
        ServiceLocationGeometry.isValidPolygon([
          p(0, 0),
          p(0, 0),
          p(0, 2),
          p(2, 2),
          p(2, 0),
        ]),
        isFalse,
      );
    });

    test('rejects a self-intersecting polygon', () {
      expect(
        ServiceLocationGeometry.isValidPolygon([
          p(0, 0),
          p(2, 2),
          p(0, 2),
          p(2, 0),
        ]),
        isFalse,
      );
    });
  });

  group('ServiceLocationGeometry.isPolygonContained', () {
    final city = <GeoPoint>[
      p(0, 0),
      p(0, 10),
      p(10, 10),
      p(10, 0),
    ];

    test('accepts a polygon fully inside the city', () {
      final area = <GeoPoint>[
        p(2, 2),
        p(2, 4),
        p(4, 4),
        p(4, 2),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: city,
          child: area,
        ),
        isTrue,
      );
    });

    test('accepts an area sharing a city boundary edge', () {
      final area = <GeoPoint>[
        p(0, 2),
        p(0, 4),
        p(3, 4),
        p(3, 2),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: city,
          child: area,
        ),
        isTrue,
      );
    });

    test('rejects a tiny geographic gap outside the city', () {
      final area = <GeoPoint>[
        p(2, 2),
        p(2, 4),
        p(4, 4),
        p(4, 10.000001),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: city,
          child: area,
        ),
        isFalse,
      );
    });

    test('rejects a polygon with fewer than three distinct vertices', () {
      final invalid = <GeoPoint>[
        p(1, 1),
        p(1, 1),
        p(1, 1),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: city,
          child: invalid,
        ),
        isFalse,
      );
    });

    test('Firestore GeoPoint rejects out-of-range coordinates at construction',
        () {
      expect(() => p(91, 2), throwsAssertionError);
      expect(() => p(1, 181), throwsAssertionError);
    });

    test('rejects a self-intersecting child polygon', () {
      final bowTie = <GeoPoint>[
        p(1, 1),
        p(4, 4),
        p(1, 4),
        p(4, 1),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: city,
          child: bowTie,
        ),
        isFalse,
      );
    });

    test('rejects a self-intersecting parent polygon', () {
      final bowTieCity = <GeoPoint>[
        p(0, 0),
        p(10, 10),
        p(0, 10),
        p(10, 0),
      ];
      final area = <GeoPoint>[
        p(2, 2),
        p(2, 3),
        p(3, 3),
        p(3, 2),
      ];
      expect(
        ServiceLocationGeometry.isPolygonContained(
          parent: bowTieCity,
          child: area,
        ),
        isFalse,
      );
    });
  });
}
