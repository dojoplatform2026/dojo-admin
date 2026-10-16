import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dojo_admin/features/service_location/models/service_location_models.dart';
import 'package:dojo_admin/features/service_location/services/service_location_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Service location activation guards', () {
    Future<void> seedParents(
      FirebaseFirestore firestore, {
      required String suffix,
      bool countryActive = true,
      bool stateActive = true,
      bool cityActive = false,
    }) async {
      await firestore.collection('service_countries').doc('c-$suffix').set({
        'name': 'Country $suffix',
        'code': 'TST-$suffix',
        'isActive': countryActive,
      });
      await firestore.collection('service_states').doc('s-$suffix').set({
        'name': 'State $suffix',
        'countryId': 'c-$suffix',
        'isActive': stateActive,
      });
      await firestore.collection('service_cities').doc('city-$suffix').set({
        'name': 'City $suffix',
        'countryId': 'c-$suffix',
        'stateId': 's-$suffix',
        'isServiceActive': cityActive,
      });
    }

    Future<void> seedVerifiedBoundary(
      FirebaseFirestore firestore, {
      required String locationId,
      required String locationType,
    }) async {
      await firestore.collection('service_location_boundaries')
          .doc('boundary-$locationId')
          .set({
        'locationId': locationId,
        'locationType': locationType,
        'points': const [
          GeoPoint(28.0, 77.0),
          GeoPoint(28.1, 77.0),
          GeoPoint(28.1, 77.1),
        ],
        'sourceType': 'importedGeoJson',
        'sourceName': 'Test source',
        'sourceReference': 'test://boundary',
        'verificationStatus': 'verified',
        'verifiedBy': 'test-admin',
        'verifiedAt': Timestamp.now(),
      });
    }

    test(
      'City activation is rejected when no verified boundary exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix);
        await expectLater(
          service.setCityServiceStatus(cityId: 'city-$suffix', isActive: true),
          throwsA(isA<StateError>()),
        );
        final snapshot = await firestore.collection('service_cities')
            .doc('city-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isNot(true));
      },
    );

    test(
      'City activation is rejected when its State is inactive',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix, stateActive: false);
        await seedVerifiedBoundary(
          firestore,
          locationId: 'city-$suffix',
          locationType: 'city',
        );
        await expectLater(
          service.setCityServiceStatus(cityId: 'city-$suffix', isActive: true),
          throwsA(isA<StateError>()),
        );
        final snapshot = await firestore.collection('service_cities')
            .doc('city-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isNot(true));
      },
    );

    test(
      'Area activation is rejected when no verified boundary exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix);
        await seedVerifiedBoundary(
          firestore,
          locationId: 'city-$suffix',
          locationType: 'city',
        );
        await service.setCityServiceStatus(cityId: 'city-$suffix', isActive: true);
        await firestore.collection('service_areas').doc('area-$suffix').set({
          'name': 'Area $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'isServiceActive': false,
        });
        await expectLater(
          service.setAreaServiceStatus(areaId: 'area-$suffix', isActive: true),
          throwsA(isA<StateError>()),
        );
        final snapshot = await firestore.collection('service_areas')
            .doc('area-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isNot(true));
      },
    );

    test(
      'City activation succeeds with a verified City boundary',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix);
        await seedVerifiedBoundary(
          firestore,
          locationId: 'city-$suffix',
          locationType: 'city',
        );

        await service.setCityServiceStatus(
          cityId: 'city-$suffix',
          isActive: true,
        );

        final snapshot = await firestore.collection('service_cities')
            .doc('city-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isTrue);
        expect(
          snapshot.data()?['verifiedBoundaryId'],
          'boundary-city-$suffix',
        );
      },
    );

    test(
      'City activation rejects a verified boundary belonging to another location type',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix);
        await seedVerifiedBoundary(
          firestore,
          locationId: 'city-$suffix',
          locationType: 'area',
        );

        await expectLater(
          service.setCityServiceStatus(
            cityId: 'city-$suffix',
            isActive: true,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'Locality can activate without its own polygon when its parent Area is active',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix, cityActive: true);
        await firestore.collection('service_areas').doc('area-$suffix').set({
          'name': 'Area $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'isServiceActive': true,
        });
        await firestore.collection('service_localities').doc('locality-$suffix').set({
          'name': 'Locality $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'areaId': 'area-$suffix',
          'isServiceActive': false,
        });

        await service.setLocalityServiceStatus(
          localityId: 'locality-$suffix',
          isActive: true,
        );

        final snapshot = await firestore.collection('service_localities')
            .doc('locality-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isTrue);
      },
    );

    test(
      'Locality activation is rejected when parent Area is inactive',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix, cityActive: true);
        await firestore.collection('service_areas').doc('area-$suffix').set({
          'name': 'Area $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'isServiceActive': false,
        });
        await firestore.collection('service_localities').doc('locality-$suffix').set({
          'name': 'Locality $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'areaId': 'area-$suffix',
          'isServiceActive': false,
        });

        await expectLater(
          service.setLocalityServiceStatus(
            localityId: 'locality-$suffix',
            isActive: true,
          ),
          throwsA(isA<StateError>()),
        );
        final snapshot = await firestore.collection('service_localities')
            .doc('locality-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isFalse);
      },
    );

    test(
      'City deactivation is rejected while an active Area exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        await seedParents(firestore, suffix: suffix, cityActive: true);
        await firestore.collection('service_areas').doc('area-$suffix').set({
          'name': 'Area $suffix',
          'countryId': 'c-$suffix',
          'stateId': 's-$suffix',
          'cityId': 'city-$suffix',
          'isServiceActive': true,
        });
        await expectLater(
          service.setCityServiceStatus(cityId: 'city-$suffix', isActive: false),
          throwsA(isA<StateError>()),
        );
        final snapshot = await firestore.collection('service_cities')
            .doc('city-$suffix').get();
        expect(snapshot.data()?['isServiceActive'], isTrue);
      },
    );
  });

  group('Service location Firestore service persistence', () {
    test(
      'saves, reloads, and clears LGD codes for State, District, and Area',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ServiceLocationService(firestore: firestore);
        final suffix = DateTime.now().microsecondsSinceEpoch.toString();
        final countryId = 'test-country-$suffix';
        final stateId = 'test-state-$suffix';
        final cityId = 'test-district-$suffix';
        final areaId = 'test-area-$suffix';

        await firestore.collection('service_countries').doc(countryId).set({
          'name': 'Test Country $suffix',
          'code': 'TST$suffix',
          'isActive': false,
        });

        await service.saveState(ServiceState(
          id: stateId,
          countryId: countryId,
          name: 'Test State $suffix',
          lgdCode: 9,
        ));
        var stateSnapshot =
            await firestore.collection('service_states').doc(stateId).get();
        expect(ServiceState.fromMap(stateId, stateSnapshot.data()!).lgdCode, 9);

        await service.saveState(ServiceState(
          id: stateId,
          countryId: countryId,
          name: 'Test State $suffix',
        ));
        stateSnapshot =
            await firestore.collection('service_states').doc(stateId).get();
        expect(
          ServiceState.fromMap(stateId, stateSnapshot.data()!).lgdCode,
          isNull,
          reason: 'A merge save must not retain a previous State LGD code.',
        );

        await service.saveCity(ServiceCity(
          id: cityId,
          countryId: countryId,
          stateId: stateId,
          name: 'Test District $suffix',
          lgdCode: '009',
        ));
        var citySnapshot =
            await firestore.collection('service_cities').doc(cityId).get();
        expect(ServiceCity.fromMap(cityId, citySnapshot.data()!).lgdCode, '009');

        await service.saveCity(ServiceCity(
          id: cityId,
          countryId: countryId,
          stateId: stateId,
          name: 'Test District $suffix',
        ));
        citySnapshot =
            await firestore.collection('service_cities').doc(cityId).get();
        expect(
          ServiceCity.fromMap(cityId, citySnapshot.data()!).lgdCode,
          isNull,
          reason: 'A merge save must not retain a previous District LGD code.',
        );

        await service.saveArea(ServiceArea(
          id: areaId,
          countryId: countryId,
          stateId: stateId,
          cityId: cityId,
          name: 'Test Sub-district $suffix',
          lgdCode: '12345',
        ));
        var areaSnapshot =
            await firestore.collection('service_areas').doc(areaId).get();
        expect(ServiceArea.fromMap(areaId, areaSnapshot.data()!).lgdCode, '12345');

        await service.saveArea(ServiceArea(
          id: areaId,
          countryId: countryId,
          stateId: stateId,
          cityId: cityId,
          name: 'Test Sub-district $suffix',
        ));
        areaSnapshot =
            await firestore.collection('service_areas').doc(areaId).get();
        expect(
          ServiceArea.fromMap(areaId, areaSnapshot.data()!).lgdCode,
          isNull,
          reason: 'A merge save must not retain a previous Sub-district LGD code.',
        );
      },
    );
  });
}
