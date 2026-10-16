import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_admin/features/service_location/models/service_location_models.dart';

void main() {
  group('Service location LGD code compatibility', () {
    test('legacy State records without lgdCode still load', () {
      final state = ServiceState.fromMap('state-1', {
        'countryId': 'country-1',
        'name': 'Uttar Pradesh',
        'isActive': true,
      });

      expect(state.id, 'state-1');
      expect(state.name, 'Uttar Pradesh');
      expect(state.lgdCode, isNull);
      expect(state.isActive, isTrue);
    });

    test('State LGD code survives serialization and reload', () {
      final state = ServiceState(
        countryId: 'country-1',
        name: 'Uttar Pradesh',
        lgdCode: 9,
      );

      final saved = state.toMap();
      expect(saved['lgdCode'], 9);

      final loaded = ServiceState.fromMap('state-2', {
        ...saved,
        'updatedAt': null,
      });
      expect(loaded.lgdCode, 9);
      expect(loaded.copyWith(name: 'UP').lgdCode, 9);
    });

    test('legacy District records without lgdCode still load', () {
      final city = ServiceCity.fromMap('district-1', {
        'countryId': 'country-1',
        'stateId': 'state-1',
        'name': 'Gautam Buddha Nagar',
      });

      expect(city.name, 'Gautam Buddha Nagar');
      expect(city.lgdCode, isNull);
    });

    test('District LGD code survives serialization without losing leading zeros', () {
      final city = ServiceCity(
        countryId: 'country-1',
        stateId: 'state-1',
        name: 'Example District',
        lgdCode: '009',
      );

      final saved = city.toMap();
      expect(saved['lgdCode'], '009');

      final loaded = ServiceCity.fromMap('district-2', {
        ...saved,
        'updatedAt': null,
      });
      expect(loaded.lgdCode, '009');
      expect(loaded.copyWith(name: 'Renamed District').lgdCode, '009');
    });

    test('legacy Area records without lgdCode still load', () {
      final area = ServiceArea.fromMap('area-1', {
        'cityId': 'district-1',
        'name': 'Dadri',
      });

      expect(area.name, 'Dadri');
      expect(area.lgdCode, isNull);
    });

    test('Sub-district LGD code survives serialization and reload', () {
      final area = ServiceArea(
        stateId: 'state-1',
        cityId: 'district-1',
        name: 'Dadri',
        lgdCode: '12345',
      );

      final saved = area.toMap();
      expect(saved['lgdCode'], '12345');

      final loaded = ServiceArea.fromMap('area-2', {
        ...saved,
        'updatedAt': null,
      });
      expect(loaded.lgdCode, '12345');
      expect(loaded.copyWith(name: 'Renamed Area').lgdCode, '12345');
    });

    test('null LGD codes are omitted from new writes', () {
      final state = ServiceState(countryId: 'country-1', name: 'Legacy');
      final city = ServiceCity(
        countryId: 'country-1',
        stateId: 'state-1',
        name: 'Legacy District',
      );
      final area = ServiceArea(cityId: 'district-1', name: 'Legacy Area');

      expect(state.toMap().containsKey('lgdCode'), isFalse);
      expect(city.toMap().containsKey('lgdCode'), isFalse);
      expect(area.toMap().containsKey('lgdCode'), isFalse);
    });
  });
}
