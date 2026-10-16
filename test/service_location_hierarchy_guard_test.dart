import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dojo_admin/features/service_location/models/service_location_models.dart';
import 'package:dojo_admin/features/service_location/services/service_location_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Service location hierarchy safety', () {
    Future<void> seedBase(FirebaseFirestore db, String suffix) async {
      await db.collection('service_countries').doc('c-$suffix').set({
        'name': 'Country $suffix', 'code': 'TST', 'isActive': true,
      });
      await db.collection('service_states').doc('s-$suffix').set({
        'name': 'State $suffix', 'countryId': 'c-$suffix', 'isActive': true,
      });
      for (final city in ['city-a-$suffix', 'city-b-$suffix']) {
        await db.collection('service_cities').doc(city).set({
          'name': city, 'countryId': 'c-$suffix', 'stateId': 's-$suffix',
          'isServiceActive': true,
        });
      }
    }

    test('Area cannot be deactivated while an active Locality exists', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_areas').doc('area-$suffix').set({
        'name': 'Area $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'isServiceActive': true,
      });
      await db.collection('service_localities').doc('loc-$suffix').set({
        'name': 'Locality $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'areaId': 'area-$suffix', 'isServiceActive': true,
      });

      await expectLater(
        service.setAreaServiceStatus(areaId: 'area-$suffix', isActive: false),
        throwsA(isA<StateError>()),
      );
      final area = await db.collection('service_areas').doc('area-$suffix').get();
      expect(area.data()?['isServiceActive'], isTrue);
    });

    test('Area cannot be moved to another City while child Localities exist', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_areas').doc('area-$suffix').set({
        'name': 'Area $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'isServiceActive': false,
      });
      await db.collection('service_localities').doc('loc-$suffix').set({
        'name': 'Locality $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'areaId': 'area-$suffix', 'isServiceActive': false,
      });

      await expectLater(
        service.saveArea(ServiceArea(
          id: 'area-$suffix', countryId: 'c-$suffix',
          stateId: 's-$suffix', cityId: 'city-b-$suffix',
          name: 'Area $suffix',
        )),
        throwsA(isA<StateError>()),
      );
      final area = await db.collection('service_areas').doc('area-$suffix').get();
      expect(area.data()?['cityId'], 'city-a-$suffix');
    });

    test('Locality save rejects an Area whose parent chain does not match', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_areas').doc('area-$suffix').set({
        'name': 'Area $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'isServiceActive': false,
      });

      await expectLater(
        service.saveLocality(ServiceLocality(
          id: 'loc-$suffix', countryId: 'c-$suffix',
          stateId: 's-$suffix', cityId: 'city-b-$suffix',
          areaId: 'area-$suffix', name: 'Locality $suffix',
        )),
        throwsA(isA<StateError>()),
      );
      final locality = await db.collection('service_localities').doc('loc-$suffix').get();
      expect(locality.exists, isFalse);
    });

    test('Country cannot be deactivated while an active State exists', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);

      await expectLater(
        service.setCountryStatus(countryId: 'c-$suffix', isActive: false),
        throwsA(isA<StateError>()),
      );
      final country = await db.collection('service_countries').doc('c-$suffix').get();
      expect(country.data()?['isActive'], isTrue);
    });

    test('State cannot be deactivated while an active City exists', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);

      await expectLater(
        service.setStateStatus(stateId: 's-$suffix', isActive: false),
        throwsA(isA<StateError>()),
      );
      final state = await db.collection('service_states').doc('s-$suffix').get();
      expect(state.data()?['isActive'], isTrue);
    });

    test('State cannot be activated when its Country is inactive', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await db.collection('service_countries').doc('c-$suffix').set({
        'name': 'Country $suffix', 'code': 'TST', 'isActive': false,
      });
      await db.collection('service_states').doc('s-$suffix').set({
        'name': 'State $suffix', 'countryId': 'c-$suffix', 'isActive': false,
      });

      await expectLater(
        service.setStateStatus(stateId: 's-$suffix', isActive: true),
        throwsA(isA<StateError>()),
      );
      final state = await db.collection('service_states').doc('s-$suffix').get();
      expect(state.data()?['isActive'], isFalse);
    });

    test('City cannot be deactivated while an active Area exists', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_areas').doc('area-$suffix').set({
        'name': 'Area $suffix', 'countryId': 'c-$suffix',
        'stateId': 's-$suffix', 'cityId': 'city-a-$suffix',
        'isServiceActive': true,
      });

      await expectLater(
        service.setCityServiceStatus(cityId: 'city-a-$suffix', isActive: false),
        throwsA(isA<StateError>()),
      );
      final city = await db.collection('service_cities').doc('city-a-$suffix').get();
      expect(city.data()?['isServiceActive'], isTrue);
    });

    test('City save rejects a State belonging to another Country', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_countries').doc('other-country-$suffix').set({
        'name': 'Other Country $suffix', 'code': 'OTH', 'isActive': true,
      });

      await expectLater(
        service.saveCity(ServiceCity(
          id: 'wrong-city-$suffix',
          countryId: 'other-country-$suffix',
          stateId: 's-$suffix',
          name: 'Wrong City $suffix',
        )),
        throwsA(isA<StateError>()),
      );
      final city = await db.collection('service_cities').doc('wrong-city-$suffix').get();
      expect(city.exists, isFalse);
    });

    test('State cannot be moved to another Country while child Cities exist', () async {
      final db = FakeFirebaseFirestore();
      final service = ServiceLocationService(firestore: db);
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      await seedBase(db, suffix);
      await db.collection('service_countries').doc('other-country-$suffix').set({
        'name': 'Other Country $suffix', 'code': 'OTH', 'isActive': true,
      });

      await expectLater(
        service.saveState(ServiceState(
          id: 's-$suffix',
          countryId: 'other-country-$suffix',
          name: 'State $suffix',
          isActive: true,
        )),
        throwsA(isA<StateError>()),
      );
      final state = await db.collection('service_states').doc('s-$suffix').get();
      expect(state.data()?['countryId'], 'c-$suffix');
    });
  });
}
