import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dojo_admin/features/service_location/services/service_location_boundary_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedInUser implements User {
  @override
  String get uid => 'boundary-reviewer';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedInAuth implements FirebaseAuth {
  @override
  User? get currentUser => _SignedInUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _cityPoints = [
  GeoPoint(28.0, 77.0),
  GeoPoint(28.0, 78.0),
  GeoPoint(29.0, 78.0),
  GeoPoint(29.0, 77.0),
];

const _insideAreaPoints = [
  GeoPoint(28.2, 77.2),
  GeoPoint(28.2, 77.4),
  GeoPoint(28.4, 77.4),
  GeoPoint(28.4, 77.2),
];

const _outsideAreaPoints = [
  GeoPoint(28.2, 77.2),
  GeoPoint(28.2, 78.2),
  GeoPoint(28.4, 78.2),
  GeoPoint(28.4, 77.2),
];

Map<String, dynamic> _boundaryData({
  required String locationId,
  required String locationType,
  required List<GeoPoint> points,
  String status = 'pending',
}) => {
  'locationId': locationId,
  'locationType': locationType,
  'points': points,
  'sourceType': 'governmentGis',
  'sourceName': 'Integration test fixture',
  'sourceReference': 'test://boundary-fixture',
  'verificationStatus': status,
  'verifiedBy': status == 'verified' ? 'boundary-reviewer' : null,
  'verifiedAt': status == 'verified' ? Timestamp.now() : null,
  'verificationNotes': null,
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
};

void main() {
  group('Boundary verification parent-containment guard', () {
    late FakeFirebaseFirestore db;
    late ServiceLocationBoundaryService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      service = ServiceLocationBoundaryService(
        firestore: db,
        auth: _SignedInAuth(),
      );
    });

    Future<void> seedVerifiedCity() async {
      await db.collection('service_cities').doc('city-1').set({
        'name': 'Test City',
        'verifiedBoundaryId': 'city-boundary',
      });
      await db.collection('service_location_boundaries')
          .doc('city-boundary')
          .set(_boundaryData(
            locationId: 'city-1',
            locationType: 'city',
            points: _cityPoints,
            status: 'verified',
          ));
    }

    Future<void> seedArea({
      required List<GeoPoint> points,
    }) async {
      await db.collection('service_areas').doc('area-1').set({
        'name': 'Test Area',
        'cityId': 'city-1',
      });
      await db.collection('service_location_boundaries')
          .doc('area-boundary')
          .set(_boundaryData(
            locationId: 'area-1',
            locationType: 'area',
            points: points,
          ));
    }

    test('verifies an Area contained by its verified City boundary', () async {
      await seedVerifiedCity();
      await seedArea(points: _insideAreaPoints);

      await service.markVerified(
        boundaryId: 'area-boundary',
        verificationNotes: 'Containment test passed',
      );

      final saved = await db.collection('service_location_boundaries')
          .doc('area-boundary').get();
      expect(saved.data()?['verificationStatus'], 'verified');
      expect(saved.data()?['verifiedBy'], 'boundary-reviewer');
    });

    test('rejects an Area outside City and leaves it pending', () async {
      await seedVerifiedCity();
      await seedArea(points: _outsideAreaPoints);

      await expectLater(
        service.markVerified(
          boundaryId: 'area-boundary',
          verificationNotes: 'Should fail containment',
        ),
        throwsA(isA<StateError>()),
      );

      final saved = await db.collection('service_location_boundaries')
          .doc('area-boundary').get();
      expect(saved.data()?['verificationStatus'], 'pending');
      expect(saved.data()?['verifiedBy'], isNull);
    });

    test('rejects Area verification when City has no verified boundary', () async {
      await db.collection('service_cities').doc('city-1').set({
        'name': 'Test City',
      });
      await seedArea(points: _insideAreaPoints);

      await expectLater(
        service.markVerified(
          boundaryId: 'area-boundary',
          verificationNotes: 'Parent boundary missing',
        ),
        throwsA(isA<StateError>()),
      );

      final saved = await db.collection('service_location_boundaries')
          .doc('area-boundary').get();
      expect(saved.data()?['verificationStatus'], 'pending');
    });

    test('verifies Locality only when contained by its verified Area', () async {
      await seedVerifiedCity();
      await db.collection('service_areas').doc('area-1').set({
        'name': 'Test Area',
        'cityId': 'city-1',
        'verifiedBoundaryId': 'area-parent-boundary',
      });
      await db.collection('service_location_boundaries')
          .doc('area-parent-boundary')
          .set(_boundaryData(
            locationId: 'area-1',
            locationType: 'area',
            points: _insideAreaPoints,
            status: 'verified',
          ));
      await db.collection('service_localities').doc('locality-1').set({
        'name': 'Test Locality',
        'areaId': 'area-1',
      });
      await db.collection('service_location_boundaries')
          .doc('locality-boundary')
          .set(_boundaryData(
            locationId: 'locality-1',
            locationType: 'locality',
            points: const [
              GeoPoint(28.25, 77.25),
              GeoPoint(28.25, 77.3),
              GeoPoint(28.3, 77.3),
              GeoPoint(28.3, 77.25),
            ],
          ));

      await service.markVerified(
        boundaryId: 'locality-boundary',
        verificationNotes: 'Locality contained by Area',
      );

      final saved = await db.collection('service_location_boundaries')
          .doc('locality-boundary').get();
      expect(saved.data()?['verificationStatus'], 'verified');
    });

    test('rejects a parent boundary reference for the wrong location', () async {
      await db.collection('service_cities').doc('city-1').set({
        'name': 'Test City',
        'verifiedBoundaryId': 'wrong-boundary',
      });
      await db.collection('service_location_boundaries')
          .doc('wrong-boundary')
          .set(_boundaryData(
            locationId: 'another-city',
            locationType: 'city',
            points: _cityPoints,
            status: 'verified',
          ));
      await seedArea(points: _insideAreaPoints);

      await expectLater(
        service.markVerified(
          boundaryId: 'area-boundary',
          verificationNotes: 'Wrong parent reference',
        ),
        throwsA(isA<StateError>()),
      );

      final saved = await db.collection('service_location_boundaries')
          .doc('area-boundary').get();
      expect(saved.data()?['verificationStatus'], 'pending');
    });
  });
}
