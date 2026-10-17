import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';

import '../models/service_location_models.dart';
import 'service_location_geometry.dart';

/// ===========================================================
/// DOJO WALK ADMIN
/// Service Location Service
///
/// Hierarchy:
/// Country -> State -> City/District -> Area/Sub-district
/// -> Locality/Village
///
/// City and Area activation requires a verified polygon stored
/// in service_location_boundaries.
///
/// Locality activation does not require its own polygon.
///
/// Unique names are enforced through transactional name indexes.
/// ===========================================================

class ServiceLocationService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  ServiceLocationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<void> _setTrustedStatus({
    required String locationType,
    required String locationId,
    required bool isActive,
  }) async {
    final callable = _functions.httpsCallable('setServiceLocationStatus');
    await callable.call<void>({
      'locationType': locationType,
      'locationId': locationId,
      'isActive': isActive,
    });
  }

  Future<void> _activateTrustedBoundaryLocation({
    required String locationType,
    required String locationId,
  }) async {
    final callable = _functions.httpsCallable('activateServiceLocation');
    await callable.call<void>({
      'locationType': locationType,
      'locationId': locationId,
    });
  }

  // ==========================================================
  // COLLECTIONS
  // ==========================================================

  CollectionReference<Map<String, dynamic>> get _countries =>
      _firestore.collection('service_countries');

  CollectionReference<Map<String, dynamic>> get _states =>
      _firestore.collection('service_states');

  CollectionReference<Map<String, dynamic>> get _cities =>
      _firestore.collection('service_cities');

  CollectionReference<Map<String, dynamic>> get _areas =>
      _firestore.collection('service_areas');

  CollectionReference<Map<String, dynamic>> get _localities =>
      _firestore.collection('service_localities');

  CollectionReference<Map<String, dynamic>> get _imports =>
      _firestore.collection('service_location_imports');

  CollectionReference<Map<String, dynamic>> get _nameIndexes =>
      _firestore.collection('service_location_name_indexes');

  CollectionReference<Map<String, dynamic>> get _boundaries =>
      _firestore.collection('service_location_boundaries');

  // ==========================================================
  // GENERAL HELPERS
  // ==========================================================

  String _required(
    String value,
    String fieldName,
  ) {
    final result = value.trim();

    if (result.isEmpty) {
      throw ArgumentError('$fieldName is required.');
    }

    return result;
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _nameIndexId({
    required String collectionPath,
    required List<String> parentIds,
    required String name,
  }) {
    final normalized = jsonEncode([
      collectionPath,
      parentIds.map((id) => id.trim()).toList(),
      _normalizeName(name),
    ]);

    return sha256.convert(utf8.encode(normalized)).toString();
  }

  List<GeoPoint> _readPoints(dynamic value) {
    final result = <GeoPoint>[];

    if (value is! List) return result;

    for (final item in value) {
      double? lat;
      double? lng;

      if (item is GeoPoint) {
        lat = item.latitude;
        lng = item.longitude;
      } else if (item is Map) {
        final latitude = item['latitude'];
        final longitude = item['longitude'];

        if (latitude is num && longitude is num) {
          lat = latitude.toDouble();
          lng = longitude.toDouble();
        }
      }

      if (lat == null || lng == null) continue;

      if (!lat.isFinite || !lng.isFinite) continue;

      if (lat < -90 || lat > 90) continue;

      if (lng < -180 || lng > 180) continue;

      result.add(GeoPoint(lat, lng));
    }

    return result;
  }

  bool _hasValidPolygon(dynamic value) {
    final points = _readPoints(value);

    if (points.length < 3) return false;

    final unique = points
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(7)},'
              '${point.longitude.toStringAsFixed(7)}',
        )
        .toSet();

    return unique.length >= 3;
  }

  // ==========================================================
  // UNIQUE NAME SAVE
  // ==========================================================

  Future<void> _saveUniqueNamedDocument({
    required CollectionReference<Map<String, dynamic>> collection,
    required String documentId,
    required String name,
    required List<String> parentIds,
    required Map<String, dynamic> data,
    required bool isNew,
  }) async {
    final normalizedName = _normalizeName(
      _required(name, 'Name'),
    );

    final target = collection.doc(documentId);

    final newIndexId = _nameIndexId(
      collectionPath: collection.path,
      parentIds: parentIds,
      name: normalizedName,
    );

    final newIndex = _nameIndexes.doc(newIndexId);

    await _firestore.runTransaction((transaction) async {
      final targetSnapshot = await transaction.get(target);
      final newIndexSnapshot = await transaction.get(newIndex);

      DocumentReference<Map<String, dynamic>>? oldIndex;
      DocumentSnapshot<Map<String, dynamic>>? oldIndexSnapshot;

      if (targetSnapshot.exists) {
        final oldData = targetSnapshot.data()!;

        final oldName = oldData['name']?.toString() ?? '';

        final oldParentIds = _parentIdsFromDocument(
          collection.path,
          oldData,
        );

        final oldIndexId = _nameIndexId(
          collectionPath: collection.path,
          parentIds: oldParentIds,
          name: oldName,
        );

        if (oldIndexId != newIndexId) {
          oldIndex = _nameIndexes.doc(oldIndexId);
          oldIndexSnapshot = await transaction.get(oldIndex);
        }
      }

      if (newIndexSnapshot.exists) {
        final indexData = newIndexSnapshot.data()!;

        final indexedDocumentId =
            indexData['documentId']?.toString() ?? '';

        if (indexedDocumentId != documentId) {
          throw StateError(
            '"$name" already exists at this hierarchy level.',
          );
        }
      }

      if (isNew && targetSnapshot.exists) {
        throw StateError(
          'This service location already exists.',
        );
      }

      // Complete all transaction reads before writing.

      if (oldIndex != null &&
          oldIndexSnapshot != null &&
          oldIndexSnapshot.exists) {
        final oldIndexData = oldIndexSnapshot.data()!;

        if (oldIndexData['documentId'] == documentId) {
          transaction.delete(oldIndex);
        }
      }

      transaction.set(
        newIndex,
        {
          'collectionPath': collection.path,
          'documentId': documentId,
          'name': normalizedName,
          'parentIds': parentIds,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final saveData = Map<String, dynamic>.from(data);

      if (!targetSnapshot.exists) {
        saveData['createdAt'] = FieldValue.serverTimestamp();
      }

      saveData['updatedAt'] = FieldValue.serverTimestamp();

      transaction.set(
        target,
        saveData,
        SetOptions(merge: true),
      );
    });
  }

  List<String> _parentIdsFromDocument(
    String collectionPath,
    Map<String, dynamic> data,
  ) {
    switch (collectionPath) {
      case 'service_countries':
        return const [];

      case 'service_states':
        return [
          data['countryId']?.toString() ?? '',
        ];

      case 'service_cities':
        return [
          data['countryId']?.toString() ?? '',
          data['stateId']?.toString() ?? '',
        ];

      case 'service_areas':
        return [
          data['countryId']?.toString() ?? '',
          data['stateId']?.toString() ?? '',
          data['cityId']?.toString() ?? '',
        ];

      case 'service_localities':
        return [
          data['countryId']?.toString() ?? '',
          data['stateId']?.toString() ?? '',
          data['cityId']?.toString() ?? '',
          data['areaId']?.toString() ?? '',
        ];

      default:
        return const [];
    }
  }

  // ==========================================================
  // DOCUMENT / HIERARCHY VALIDATION
  // ==========================================================

  Future<Map<String, dynamic>> _requireDocument(
    CollectionReference<Map<String, dynamic>> collection,
    String id,
    String label,
  ) async {
    final documentId = _required(id, '$label ID');

    final snapshot = await collection.doc(documentId).get();

    if (!snapshot.exists) {
      throw StateError('$label not found.');
    }

    return snapshot.data()!;
  }

  Future<void> _requireActiveCountry(
    String countryId,
  ) async {
    final data = await _requireDocument(
      _countries,
      countryId,
      'Country',
    );

    if (data['isActive'] != true) {
      throw StateError(
        'The selected country is not active.',
      );
    }
  }

  Future<void> _requireActiveState(
    String stateId,
    String countryId,
  ) async {
    final data = await _requireDocument(
      _states,
      stateId,
      'State',
    );

    if (data['countryId'] != countryId) {
      throw StateError(
        'The state does not belong to the selected country.',
      );
    }

    if (data['isActive'] != true) {
      throw StateError(
        'The selected state is not active.',
      );
    }
  }

  Future<void> _requireActiveCity(
    String cityId,
    String stateId,
  ) async {
    final data = await _requireDocument(
      _cities,
      cityId,
      'City',
    );

    if (data['stateId'] != stateId) {
      throw StateError(
        'The city does not belong to the selected state.',
      );
    }

    if (data['isServiceActive'] != true) {
      throw StateError(
        'The selected city is not active for service.',
      );
    }
  }

  Future<void> _requireActiveArea(
    String areaId,
    String cityId,
  ) async {
    final data = await _requireDocument(
      _areas,
      areaId,
      'Area',
    );

    if (data['cityId'] != cityId) {
      throw StateError(
        'The area does not belong to the selected city.',
      );
    }

    if (data['isServiceActive'] != true) {
      throw StateError(
        'The selected area is not active for service.',
      );
    }
  }

  Future<bool> _hasActiveChild({
    required String parentCollection,
    required String parentId,
  }) async {
    Query<Map<String, dynamic>> query;

    switch (parentCollection) {
      case 'service_countries':
        query = _states
            .where('countryId', isEqualTo: parentId)
            .where('isActive', isEqualTo: true);
        break;

      case 'service_states':
        query = _cities
            .where('stateId', isEqualTo: parentId)
            .where('isServiceActive', isEqualTo: true);
        break;

      case 'service_cities':
        query = _areas
            .where('cityId', isEqualTo: parentId)
            .where('isServiceActive', isEqualTo: true);
        break;

      case 'service_areas':
        query = _localities
            .where('areaId', isEqualTo: parentId)
            .where('isServiceActive', isEqualTo: true);
        break;

      default:
        return false;
    }

    final result = await query.limit(1).get();

    return result.docs.isNotEmpty;
  }

  Future<void> _ensureNoActiveChildren({
    required String parentCollection,
    required String parentId,
    required String label,
  }) async {
    if (await _hasActiveChild(
      parentCollection: parentCollection,
      parentId: parentId,
    )) {
      throw StateError(
        'Deactivate active child locations before deactivating $label.',
      );
    }
  }

  // ==========================================================
  // VERIFIED BOUNDARY LOOKUP
  // ==========================================================

  Future<String?> _findVerifiedBoundaryId({
    required String locationId,
    required String locationType,
  }) async {
    final id = locationId.trim();

    if (id.isEmpty) return null;

    final normalizedType = locationType.trim().toLowerCase();

    final snapshot = await _boundaries
        .where('locationId', isEqualTo: id)
        .where('locationType', isEqualTo: normalizedType)
        .where(
          'verificationStatus',
          isEqualTo: 'verified',
        )
        .get();

    for (final document in snapshot.docs) {
      final data = document.data();

      final points = _readPoints(data['points']);

      final sourceName =
          data['sourceName']?.toString().trim() ?? '';

      final sourceReference =
          data['sourceReference']?.toString().trim() ?? '';

      final verifiedBy =
          data['verifiedBy']?.toString().trim() ?? '';

      final verifiedAt = data['verifiedAt'];

      if (points.length < 3) continue;

      if (!_hasValidPolygon(points)) continue;

      if (sourceName.isEmpty) continue;

      if (sourceReference.isEmpty) continue;

      if (verifiedBy.isEmpty) continue;

      if (verifiedAt == null) continue;

      if (verifiedAt is! Timestamp &&
          verifiedAt is! DateTime) {
        continue;
      }

      return document.id;
    }

    return null;
  }

  Future<String> _requireVerifiedBoundary({
    required String locationId,
    required String locationType,
  }) async {
    final boundaryId = await _findVerifiedBoundaryId(
      locationId: locationId,
      locationType: locationType,
    );

    if (boundaryId == null) {
      throw StateError(
        'A verified polygon boundary is required before '
        'activating this $locationType.',
      );
    }

    return boundaryId;
  }

  Future<List<GeoPoint>> _requireVerifiedBoundaryPoints({
    required String boundaryId,
    required String locationId,
    required String locationType,
  }) async {
    final id = _required(boundaryId, 'Verified boundary ID');
    final snapshot = await _boundaries.doc(id).get();

    if (!snapshot.exists) {
      throw StateError('The verified $locationType boundary was not found.');
    }

    final data = snapshot.data()!;
    if (data['locationId']?.toString() != locationId ||
        data['locationType']?.toString().toLowerCase() !=
            locationType.toLowerCase() ||
        data['verificationStatus'] != 'verified') {
      throw StateError(
        'The selected boundary is not verified for this $locationType.',
      );
    }

    final points = _readPoints(data['points']);
    if (!_hasValidPolygon(points)) {
      throw StateError('The verified $locationType boundary polygon is invalid.');
    }

    return points;
  }

  // ==========================================================
  // COUNTRIES
  // ==========================================================

  Stream<List<ServiceCountry>> watchCountries() {
    return _countries
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceCountry.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> saveCountry(
    ServiceCountry country,
  ) async {
    final name = _required(country.name, 'Country name');

    if (country.id.trim().isEmpty && country.isActive) {
      throw StateError('Create a Country as inactive, then activate it separately.');
    }

    final code = _required(country.code, 'Country code')
        .toUpperCase();

    if (!RegExp(r'^[A-Z]{2,3}$').hasMatch(code)) {
      throw ArgumentError(
        'Country code must contain 2 or 3 letters.',
      );
    }

    final id = country.id.trim().isEmpty
        ? _countries.doc().id
        : country.id.trim();

    await _saveUniqueNamedDocument(
      collection: _countries,
      documentId: id,
      name: name,
      parentIds: const [],
      isNew: country.id.trim().isEmpty,
      data: {
        'name': name,
        'code': code,
        'isActive': country.isActive,
      },
    );
  }

  Future<void> setCountryStatus({
    required String countryId,
    required bool isActive,
  }) async {
    final id = _required(countryId, 'Country ID');

    if (!isActive) {
      await _ensureNoActiveChildren(
        parentCollection: 'service_countries',
        parentId: id,
        label: 'country',
      );
    }

    await _setTrustedStatus(
      locationType: 'country',
      locationId: id,
      isActive: isActive,
    );
  }

  // ==========================================================
  // STATES
  // ==========================================================

  Stream<List<ServiceState>> watchStates({
    String? countryId,
  }) {
    Query<Map<String, dynamic>> query = _states;

    if (countryId != null && countryId.trim().isNotEmpty) {
      query = query.where(
        'countryId',
        isEqualTo: countryId.trim(),
      );
    }

    return query.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceState.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> saveState(
    ServiceState state,
  ) async {
    final countryId = _required(
      state.countryId,
      'Country ID',
    );

    final name = _required(state.name, 'State name');

    if (state.id.trim().isEmpty && state.isActive) {
      throw StateError('Create a State as inactive, then activate it separately.');
    }

    await _requireDocument(
      _countries,
      countryId,
      'Country',
    );

    final oldId = state.id.trim();
    final id = oldId.isEmpty ? _states.doc().id : oldId;

    if (oldId.isNotEmpty) {
      final existing = await _states.doc(id).get();
      if (existing.exists &&
          existing.data()?['countryId']?.toString() != countryId) {
        throw StateError('A State parent cannot be changed after creation. Create a new State under the correct Country.');
      }
    }

    await _saveUniqueNamedDocument(
      collection: _states,
      documentId: id,
      name: name,
      parentIds: [countryId],
      isNew: state.id.trim().isEmpty,
      data: {
        'countryId': countryId,
        'name': name,
        'isActive': state.isActive,
      },
    );
  }

  Future<void> setStateStatus({
    required String stateId,
    required bool isActive,
  }) async {
    final id = _required(stateId, 'State ID');

    if (isActive) {
      final state = await _requireDocument(
        _states,
        id,
        'State',
      );

      await _requireActiveCountry(
        state['countryId']?.toString() ?? '',
      );
    } else {
      await _ensureNoActiveChildren(
        parentCollection: 'service_states',
        parentId: id,
        label: 'state',
      );
    }

    await _setTrustedStatus(
      locationType: 'state',
      locationId: id,
      isActive: isActive,
    );
  }

  // ==========================================================
  // SINGLE CITY LOOKUP
  // ==========================================================

  Future<ServiceCity?> getCity(String cityId) async {
    final id = _required(cityId, 'City ID');

    final snapshot = await _cities.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return ServiceCity.fromMap(
      snapshot.id,
      data,
    );
  }

  // ==========================================================
  // CITIES / DISTRICTS
  // ==========================================================

  Stream<List<ServiceCity>> watchCities({
    String? countryId,
    String? stateId,
    bool? activeOnly,
  }) {
    Query<Map<String, dynamic>> query = _cities;

    if (countryId != null && countryId.trim().isNotEmpty) {
      query = query.where(
        'countryId',
        isEqualTo: countryId.trim(),
      );
    }

    if (stateId != null && stateId.trim().isNotEmpty) {
      query = query.where(
        'stateId',
        isEqualTo: stateId.trim(),
      );
    }

    if (activeOnly == true) {
      query = query.where(
        'isServiceActive',
        isEqualTo: true,
      );
    }

    return query.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceCity.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> saveCity(
    ServiceCity city,
  ) async {
    final countryId = _required(
      city.countryId,
      'Country ID',
    );

    final stateId = _required(
      city.stateId,
      'State ID',
    );

    final name = _required(city.name, 'City name');

    final oldId = city.id.trim();

    if (oldId.isEmpty && city.isServiceActive) {
      throw StateError('Create a City as inactive; verify its boundary before activation.');
    }

    final id = oldId.isEmpty ? _cities.doc().id : oldId;

    await _requireDocument(
      _countries,
      countryId,
      'Country',
    );

    final stateData = await _requireDocument(
      _states,
      stateId,
      'State',
    );

    if (stateData['countryId'] != countryId) {
      throw StateError(
        'The state does not belong to the selected country.',
      );
    }

    String verifiedBoundaryId = city.verifiedBoundaryId.trim();

    if (city.isServiceActive) {
      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      verifiedBoundaryId = await _requireVerifiedBoundary(
        locationId: id,
        locationType: 'city',
      );
    }

    final existingSnapshot = await _cities.doc(id).get();

    if (existingSnapshot.exists) {
      final oldData = existingSnapshot.data()!;

      final oldCountryId = oldData['countryId']?.toString() ?? '';
      final oldStateId = oldData['stateId']?.toString() ?? '';

      if (oldCountryId != countryId || oldStateId != stateId) {
        throw StateError('A City parent cannot be changed after creation. Create a new City under the correct State.');
      }
    }

    final savedCity = city.copyWith(
      id: id,
      countryId: countryId,
      stateId: stateId,
      name: name,
      verifiedBoundaryId: verifiedBoundaryId,
    );

    await _saveUniqueNamedDocument(
      collection: _cities,
      documentId: id,
      name: name,
      parentIds: [countryId, stateId],
      isNew: oldId.isEmpty,
      data: savedCity.toMap(),
    );
  }

  Future<void> setCityServiceStatus({
    required String cityId,
    required bool isActive,
  }) async {
    final id = _required(cityId, 'City ID');

    final city = await _requireDocument(
      _cities,
      id,
      'City',
    );

    if (isActive) {
      final countryId =
          city['countryId']?.toString() ?? '';

      final stateId =
          city['stateId']?.toString() ?? '';

      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      await _requireVerifiedBoundary(
        locationId: id,
        locationType: 'city',
      );
    } else {
      await _ensureNoActiveChildren(
        parentCollection: 'service_cities',
        parentId: id,
        label: 'city',
      );
    }

    if (isActive) {
      await _activateTrustedBoundaryLocation(
        locationType: 'city',
        locationId: id,
      );
    } else {
      await _setTrustedStatus(
        locationType: 'city',
        locationId: id,
        isActive: false,
      );
    }
  }

  // ==========================================================
  // AREAS / SUB-DISTRICTS
  // ==========================================================

  Stream<List<ServiceArea>> watchAreas({
    String? countryId,
    String? stateId,
    String? cityId,
    bool? activeOnly,
  }) {
    Query<Map<String, dynamic>> query = _areas;

    if (countryId != null && countryId.trim().isNotEmpty) {
      query = query.where(
        'countryId',
        isEqualTo: countryId.trim(),
      );
    }

    if (stateId != null && stateId.trim().isNotEmpty) {
      query = query.where(
        'stateId',
        isEqualTo: stateId.trim(),
      );
    }

    if (cityId != null && cityId.trim().isNotEmpty) {
      query = query.where(
        'cityId',
        isEqualTo: cityId.trim(),
      );
    }

    if (activeOnly == true) {
      query = query.where(
        'isServiceActive',
        isEqualTo: true,
      );
    }

    return query.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceArea.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> saveArea(
    ServiceArea area,
  ) async {
    final cityId = _required(area.cityId, 'City ID');

    final name = _required(area.name, 'Area name');

    final oldId = area.id.trim();

    if (oldId.isEmpty && area.isServiceActive) {
      throw StateError('Create an Area as inactive; verify its boundary before activation.');
    }

    final id = oldId.isEmpty ? _areas.doc().id : oldId;

    final cityData = await _requireDocument(
      _cities,
      cityId,
      'City',
    );

    final countryId = area.countryId.trim().isNotEmpty
        ? area.countryId.trim()
        : cityData['countryId']?.toString() ?? '';

    final stateId = area.stateId.trim().isNotEmpty
        ? area.stateId.trim()
        : cityData['stateId']?.toString() ?? '';

    if (cityData['countryId'] != countryId ||
        cityData['stateId'] != stateId) {
      throw StateError(
        'The selected city does not match the country/state.',
      );
    }

    String verifiedBoundaryId = area.verifiedBoundaryId.trim();

    if (area.isServiceActive) {
      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      await _requireActiveCity(cityId, stateId);

      verifiedBoundaryId = await _requireVerifiedBoundary(
        locationId: id,
        locationType: 'area',
      );

      final city = await _requireDocument(
        _cities,
        cityId,
        'City',
      );
      final cityBoundaryId =
          city['verifiedBoundaryId']?.toString().trim() ?? '';
      final cityBoundaryPoints = await _requireVerifiedBoundaryPoints(
        boundaryId: cityBoundaryId,
        locationId: cityId,
        locationType: 'city',
      );
      final areaBoundaryPoints = await _requireVerifiedBoundaryPoints(
        boundaryId: verifiedBoundaryId,
        locationId: id,
        locationType: 'area',
      );

      if (!ServiceLocationGeometry.isPolygonContained(
        parent: cityBoundaryPoints,
        child: areaBoundaryPoints,
      )) {
        throw StateError(
          'The Area boundary must be fully inside or on the parent City boundary.',
        );
      }
    }

    final existingSnapshot = await _areas.doc(id).get();

    if (existingSnapshot.exists) {
      final oldData = existingSnapshot.data()!;

      final oldCountryId = oldData['countryId']?.toString() ?? '';
      final oldStateId = oldData['stateId']?.toString() ?? '';
      final oldCityId = oldData['cityId']?.toString() ?? '';

      if (oldCountryId != countryId || oldStateId != stateId || oldCityId != cityId) {
        throw StateError('An Area parent cannot be changed after creation. Create a new Area under the correct City.');
      }
    }

    final savedArea = area.copyWith(
      id: id,
      countryId: countryId,
      stateId: stateId,
      cityId: cityId,
      name: name,
      verifiedBoundaryId: verifiedBoundaryId,
    );

    await _saveUniqueNamedDocument(
      collection: _areas,
      documentId: id,
      name: name,
      parentIds: [countryId, stateId, cityId],
      isNew: oldId.isEmpty,
      data: savedArea.toMap(),
    );
  }

  Future<void> setAreaServiceStatus({
    required String areaId,
    required bool isActive,
  }) async {
    final id = _required(areaId, 'Area ID');

    final area = await _requireDocument(
      _areas,
      id,
      'Area',
    );

    if (isActive) {
      final countryId =
          area['countryId']?.toString() ?? '';

      final stateId =
          area['stateId']?.toString() ?? '';

      final cityId =
          area['cityId']?.toString() ?? '';

      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      await _requireActiveCity(cityId, stateId);

      await _requireVerifiedBoundary(
        locationId: id,
        locationType: 'area',
      );
    } else {
      await _ensureNoActiveChildren(
        parentCollection: 'service_areas',
        parentId: id,
        label: 'area',
      );
    }

    if (isActive) {
      await _activateTrustedBoundaryLocation(
        locationType: 'area',
        locationId: id,
      );
    } else {
      await _setTrustedStatus(
        locationType: 'area',
        locationId: id,
        isActive: false,
      );
    }
  }

  // ==========================================================
  // LOCALITIES / VILLAGES
  //
  // A locality does not need its own polygon.
  // Its parent Area must be active for activation.
  // ==========================================================

  Stream<List<ServiceLocality>> watchLocalities({
    String? countryId,
    String? stateId,
    String? cityId,
    String? areaId,
    bool? activeOnly,
  }) {
    Query<Map<String, dynamic>> query = _localities;

    if (countryId != null && countryId.trim().isNotEmpty) {
      query = query.where(
        'countryId',
        isEqualTo: countryId.trim(),
      );
    }

    if (stateId != null && stateId.trim().isNotEmpty) {
      query = query.where(
        'stateId',
        isEqualTo: stateId.trim(),
      );
    }

    if (cityId != null && cityId.trim().isNotEmpty) {
      query = query.where(
        'cityId',
        isEqualTo: cityId.trim(),
      );
    }

    if (areaId != null && areaId.trim().isNotEmpty) {
      query = query.where(
        'areaId',
        isEqualTo: areaId.trim(),
      );
    }

    if (activeOnly == true) {
      query = query.where(
        'isServiceActive',
        isEqualTo: true,
      );
    }

    return query.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceLocality.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<void> saveLocality(
    ServiceLocality locality,
  ) async {
    final areaId = _required(
      locality.areaId,
      'Area ID',
    );

    final name = _required(
      locality.name,
      'Locality name',
    );

    final oldId = locality.id.trim();

    if (oldId.isEmpty && locality.isServiceActive) {
      throw StateError('Create a Locality as inactive, then activate it separately.');
    }

    final id = oldId.isEmpty
        ? _localities.doc().id
        : oldId;

    final areaData = await _requireDocument(
      _areas,
      areaId,
      'Area',
    );

    final cityId = locality.cityId.trim().isNotEmpty
        ? locality.cityId.trim()
        : areaData['cityId']?.toString() ?? '';

    final countryId = locality.countryId.trim().isNotEmpty
        ? locality.countryId.trim()
        : areaData['countryId']?.toString() ?? '';

    final stateId = locality.stateId.trim().isNotEmpty
        ? locality.stateId.trim()
        : areaData['stateId']?.toString() ?? '';

    if (areaData['cityId'] != cityId ||
        areaData['countryId'] != countryId ||
        areaData['stateId'] != stateId) {
      throw StateError(
        'The selected Area does not match the location hierarchy.',
      );
    }

    if (locality.isServiceActive) {
      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      await _requireActiveCity(cityId, stateId);

      await _requireActiveArea(areaId, cityId);
    }

    // A locality polygon is optional.
    if (locality.boundary.isNotEmpty) {
      final validPoints = _readPoints(locality.boundary);

      if (validPoints.length != locality.boundary.length) {
        throw ArgumentError(
          'The optional locality boundary contains invalid coordinates.',
        );
      }
    }

    final existingSnapshot = await _localities.doc(id).get();

    if (existingSnapshot.exists) {
      final oldData = existingSnapshot.data()!;

      final oldCountryId = oldData['countryId']?.toString() ?? '';
      final oldStateId = oldData['stateId']?.toString() ?? '';
      final oldCityId = oldData['cityId']?.toString() ?? '';
      final oldAreaId = oldData['areaId']?.toString() ?? '';

      if (oldCountryId != countryId || oldStateId != stateId || oldCityId != cityId || oldAreaId != areaId) {
        throw StateError('A Locality parent cannot be changed after creation. Create a new Locality under the correct Area.');
      }
    }

    final savedLocality = locality.copyWith(
      id: id,
      countryId: countryId,
      stateId: stateId,
      cityId: cityId,
      areaId: areaId,
      name: name,
    );

    await _saveUniqueNamedDocument(
      collection: _localities,
      documentId: id,
      name: name,
      parentIds: [
        countryId,
        stateId,
        cityId,
        areaId,
      ],
      isNew: oldId.isEmpty,
      data: savedLocality.toMap(),
    );
  }

  Future<void> setLocalityServiceStatus({
    required String localityId,
    required bool isActive,
  }) async {
    final id = _required(localityId, 'Locality ID');

    final locality = await _requireDocument(
      _localities,
      id,
      'Locality',
    );

    if (isActive) {
      final countryId =
          locality['countryId']?.toString() ?? '';

      final stateId =
          locality['stateId']?.toString() ?? '';

      final cityId =
          locality['cityId']?.toString() ?? '';

      final areaId =
          locality['areaId']?.toString() ?? '';

      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      await _requireActiveCity(cityId, stateId);

      await _requireActiveArea(areaId, cityId);
    }

    // No locality polygon requirement; the server validates ancestry.
    await _setTrustedStatus(
      locationType: 'locality',
      locationId: id,
      isActive: isActive,
    );
  }

  // ==========================================================
  // LOCATION IMPORTS
  // ==========================================================

  Stream<List<ServiceLocationImport>> watchImports() {
    return _imports
        .orderBy('importedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ServiceLocationImport.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  Future<String> saveImport(
    ServiceLocationImport importRecord,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null || currentUserId.trim().isEmpty) {
      throw StateError('Sign in as an admin before recording an import.');
    }

    if (importRecord.importedBy.trim() != currentUserId) {
      throw StateError('The import actor must match the signed-in admin.');
    }

    final id = importRecord.id.trim().isEmpty
        ? _imports.doc().id
        : importRecord.id.trim();

    final reference = _imports.doc(id);

    final data = <String, dynamic>{
      'source': _required(
        importRecord.source,
        'Import source',
      ),
      'fileName': _required(
        importRecord.fileName,
        'Import file name',
      ),
      'status': _required(
        importRecord.status,
        'Import status',
      ),
      'importedBy': currentUserId,
      'importedAt': FieldValue.serverTimestamp(),
      'verificationStatus': _required(
        importRecord.verificationStatus,
        'Import verification status',
      ),
    };

    final snapshot = await reference.get();

    if (snapshot.exists) {
      throw StateError(
        'An import record cannot be overwritten.',
      );
    }

    await reference.set(data);

    return id;
  }
}
