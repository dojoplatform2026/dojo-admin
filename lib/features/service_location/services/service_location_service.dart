import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../models/service_location_models.dart';

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

  ServiceLocationService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<void> _ensureNoChildrenForReparent({
    required String parentCollection,
    required String parentId,
    required String label,
  }) async {
    Query<Map<String, dynamic>> query;

    switch (parentCollection) {
      case 'service_countries':
        query = _states.where(
          'countryId',
          isEqualTo: parentId,
        );
        break;

      case 'service_states':
        query = _cities.where(
          'stateId',
          isEqualTo: parentId,
        );
        break;

      case 'service_cities':
        query = _areas.where(
          'cityId',
          isEqualTo: parentId,
        );
        break;

      case 'service_areas':
        query = _localities.where(
          'areaId',
          isEqualTo: parentId,
        );
        break;

      default:
        return;
    }

    final result = await query.limit(1).get();

    if (result.docs.isNotEmpty) {
      throw StateError(
        'Cannot move this $label while child locations exist.',
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

    await _countries.doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

    await _requireDocument(
      _countries,
      countryId,
      'Country',
    );

    final oldId = state.id.trim();
    final id = oldId.isEmpty ? _states.doc().id : oldId;

    // A State with child Cities must not be reparented: their saved
    // country/state chain would otherwise become inconsistent.
    if (oldId.isNotEmpty) {
      final existingSnapshot = await _states.doc(id).get();
      if (existingSnapshot.exists) {
        final oldCountryId =
            existingSnapshot.data()?['countryId']?.toString() ?? '';
        if (oldCountryId != countryId) {
          await _ensureNoChildrenForReparent(
            parentCollection: 'service_states',
            parentId: id,
            label: 'state',
          );
        }
      }
    }

    await _saveUniqueNamedDocument(
      collection: _states,
      documentId: id,
      name: name,
      parentIds: [countryId],
      isNew: oldId.isEmpty,
      data: {
        'countryId': countryId,
        'name': name,
        'lgdCode': state.lgdCode,
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

    await _states.doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

      final oldStateId =
          oldData['stateId']?.toString() ?? '';

      if (oldStateId != stateId) {
        await _ensureNoChildrenForReparent(
          parentCollection: 'service_cities',
          parentId: id,
          label: 'city',
        );
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
      data: {
        ...savedCity.toMap(),
        // Merge writes must explicitly clear a stale reference code.
        'lgdCode': savedCity.lgdCode,
      },
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

    String? verifiedBoundaryId;

    if (isActive) {
      final countryId =
          city['countryId']?.toString() ?? '';

      final stateId =
          city['stateId']?.toString() ?? '';

      await _requireActiveCountry(countryId);

      await _requireActiveState(stateId, countryId);

      verifiedBoundaryId = await _requireVerifiedBoundary(
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

    final update = <String, dynamic>{
      'isServiceActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (verifiedBoundaryId != null) {
      update['verifiedBoundaryId'] = verifiedBoundaryId;
    }

    await _cities.doc(id).update(update);
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
    }

    final existingSnapshot = await _areas.doc(id).get();

    if (existingSnapshot.exists) {
      final oldData = existingSnapshot.data()!;

      final oldCityId =
          oldData['cityId']?.toString() ?? '';

      if (oldCityId != cityId) {
        await _ensureNoChildrenForReparent(
          parentCollection: 'service_areas',
          parentId: id,
          label: 'area',
        );
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
      data: {
        ...savedArea.toMap(),
        // Merge writes must explicitly clear a stale reference code.
        'lgdCode': savedArea.lgdCode,
      },
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

    String? verifiedBoundaryId;

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

      verifiedBoundaryId = await _requireVerifiedBoundary(
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

    final update = <String, dynamic>{
      'isServiceActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (verifiedBoundaryId != null) {
      update['verifiedBoundaryId'] = verifiedBoundaryId;
    }

    await _areas.doc(id).update(update);
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

      final oldAreaId =
          oldData['areaId']?.toString() ?? '';

      if (oldAreaId != areaId) {
        await _ensureNoChildrenForReparent(
          parentCollection: 'service_localities',
          parentId: id,
          label: 'locality',
        );
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

    // No locality polygon requirement.
    await _localities.doc(id).update({
      'isServiceActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      'importedBy': _required(
        importRecord.importedBy,
        'Importer ID',
      ),
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
