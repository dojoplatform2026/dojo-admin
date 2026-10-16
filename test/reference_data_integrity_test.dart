import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_admin/data/reference/india_locations/india_states.dart';
import 'package:dojo_admin/data/reference/india_locations/india_districts.dart';
import 'package:dojo_admin/data/reference/india_locations/india_sub_districts.dart';
import 'package:dojo_admin/data/reference/india_locations/india_location_filters.dart';

void main() {
  group('India location reference data integrity', () {
    test('contains 36 unique State/UT LGD codes', () {
      expect(indiaStates, hasLength(36));
      final codes = indiaStates.map((state) => state.lgdCode).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('district LGD codes are unique', () {
      final codes = indiaDistricts.map((district) => district.districtCode).toList();
      expect(codes, isNotEmpty);
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('every district references an existing State/UT LGD code', () {
      final stateCodes = indiaStates.map((state) => state.lgdCode.toString()).toSet();
      final missingParents = indiaDistricts
          .where((district) => !stateCodes.contains(district.stateCode))
          .map((district) => '${district.stateCode}:${district.districtName}')
          .toList();

      expect(missingParents, isEmpty,
          reason: 'Districts must reference an existing State/UT code.');
    });

    test('district state names agree with their state-code parent', () {
      final statesByCode = {
        for (final state in indiaStates) state.lgdCode.toString(): state,
      };
      final mismatches = indiaDistricts.where((district) {
        final parent = statesByCode[district.stateCode];
        return parent == null ||
            parent.name.trim().toUpperCase() !=
                district.stateName.trim().toUpperCase();
      }).map((district) =>
          '${district.stateCode}:${district.stateName} / ${district.districtName}')
       .toList();

      expect(mismatches, isEmpty,
          reason: 'District state names must match the state-code parent.');
    });

    test('contains 7,151 sub-district records with unique LGD codes', () {
      expect(indiaSubDistricts, hasLength(7151));
      final codes = indiaSubDistricts.map((item) => item.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('every sub-district references an existing State + District pair', () {
      final districtKeys = indiaDistricts
          .map((district) => '${district.stateCode}:${district.districtCode}')
          .toSet();
      final missingParents = indiaSubDistricts.where((item) =>
          !districtKeys.contains('${item.stateCode}:${item.districtCode}'))
          .map((item) => '${item.stateCode}:${item.districtCode}:${item.name}')
          .toList();

      expect(missingParents, isEmpty,
          reason: 'Sub-districts must reference an existing state/district pair.');
    });

    test('sub-district state and district names match their parent records', () {
      final districtsByKey = {
        for (final district in indiaDistricts)
          '${district.stateCode}:${district.districtCode}': district,
      };
      final mismatches = indiaSubDistricts.where((item) {
        final parent = districtsByKey['${item.stateCode}:${item.districtCode}'];
        return parent == null ||
            parent.stateName.trim().toUpperCase() != item.stateName.trim().toUpperCase() ||
            parent.districtName.trim().toUpperCase() != item.districtName.trim().toUpperCase();
      }).map((item) =>
          '${item.stateCode}:${item.districtCode}:${item.name}')
       .toList();

      expect(mismatches, isEmpty,
          reason: 'Sub-district state/district names must match parent records.');
    });
  });

  group('India location hierarchy filters', () {
    test('State selection returns only districts for that State/UT', () {
      final districts = filterDistrictsForStateLgdCode(9); // Uttar Pradesh LGD code.
      expect(districts, hasLength(75));
      expect(districts, isNotEmpty);
      expect(districts.every((item) => item.stateCode == '9'), isTrue);
    });

    test('District selection returns only its sub-districts', () {
      final district = indiaDistricts.firstWhere(
        (item) =>
            item.stateCode == '9' &&
            item.districtName.toLowerCase() == 'gautam buddha nagar',
      );
      final items = filterSubDistrictsForStateAndDistrict(
        stateLgdCode: 9,
        districtLgdCode: district.districtCode,
      );

      expect(items, hasLength(3));
      expect(
        items.every((item) =>
            item.stateCode == '9' &&
            item.districtCode == district.districtCode),
        isTrue,
      );
    });

    test('same district code under a different State does not leak records', () {
      final district = indiaDistricts.first;
      final items = filterSubDistrictsForStateAndDistrict(
        stateLgdCode: int.parse(district.stateCode),
        districtLgdCode: district.districtCode,
      );

      expect(
        items.every((item) =>
            item.stateCode == district.stateCode &&
            item.districtCode == district.districtCode),
        isTrue,
      );
    });

    test('unknown State/UT code returns no districts', () {
      expect(filterDistrictsForStateLgdCode(-1), isEmpty);
    });
  });

}
