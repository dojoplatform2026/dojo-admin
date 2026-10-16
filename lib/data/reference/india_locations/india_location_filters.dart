import 'india_districts.dart';
import 'india_sub_districts.dart';

/// Returns the districts whose State/UT LGD code matches [stateLgdCode].
///
/// State reference records store LGD codes as integers while district records
/// store them as strings, so the comparison intentionally normalizes to text.
List<IndiaDistrict> filterDistrictsForStateLgdCode(int stateLgdCode) {
  final code = stateLgdCode.toString();
  return indiaDistricts
      .where((district) => district.stateCode.trim() == code)
      .toList(growable: false);
}

/// Returns sub-districts matching both the State/UT and district LGD codes.
///
/// Matching both parent codes prevents records with reused or malformed
/// district codes from leaking across states.
List<IndiaSubDistrict> filterSubDistrictsForStateAndDistrict({
  required int stateLgdCode,
  required String districtLgdCode,
}) {
  final stateCode = stateLgdCode.toString();
  final districtCode = districtLgdCode.trim();
  return indiaSubDistricts
      .where((item) =>
          item.stateCode.trim() == stateCode &&
          item.districtCode.trim() == districtCode)
      .toList(growable: false);
}
