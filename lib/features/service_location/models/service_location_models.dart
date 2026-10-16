import 'package:cloud_firestore/cloud_firestore.dart';

/// ===========================================================
/// DOJO WALK ADMIN
/// Service Location Models
///
/// Hierarchy:
/// Country -> State -> City/District -> Area/Sub-district
/// -> Locality/Village
///
/// Compatibility:
/// - Legacy embedded boundary fields are retained.
/// - City and Area support verifiedBoundaryId.
/// - Locality does not require its own polygon.
/// ===========================================================

DateTime? _readLocationDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}

List<GeoPoint> _readLocationBoundary(dynamic value) {
  final points = <GeoPoint>[];

  if (value is! List) return points;

  for (final point in value) {
    if (point is GeoPoint) {
      final lat = point.latitude;
      final lng = point.longitude;

      if (lat.isFinite &&
          lng.isFinite &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        points.add(GeoPoint(lat, lng));
      }
    } else if (point is Map) {
      final lat = point['latitude'];
      final lng = point['longitude'];

      if (lat is num && lng is num) {
        final latitude = lat.toDouble();
        final longitude = lng.toDouble();

        if (latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          points.add(GeoPoint(latitude, longitude));
        }
      }
    }
  }

  return points;
}

/// ===========================================================
/// 1. SERVICE COUNTRY
/// Collection: service_countries
/// ===========================================================

class ServiceCountry {
  final String id;
  final String name;
  final String code;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceCountry({
    this.id = '',
    required this.name,
    required this.code,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({
    bool includeCreatedAt = false,
  }) {
    return {
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (includeCreatedAt)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ServiceCountry.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceCountry(
      id: id,
      name: data['name']?.toString() ?? '',
      code: data['code']?.toString() ?? '',
      isActive: data['isActive'] == true,
      createdAt: _readLocationDate(data['createdAt']),
      updatedAt: _readLocationDate(data['updatedAt']),
    );
  }

  ServiceCountry copyWith({
    String? id,
    String? name,
    String? code,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceCountry(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ===========================================================
/// 2. SERVICE STATE
/// Collection: service_states
/// ===========================================================

class ServiceState {
  final String id;
  final String countryId;
  final String name;
  final int? lgdCode;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceState({
    this.id = '',
    required this.countryId,
    required this.name,
    this.lgdCode,
    this.isActive = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({
    bool includeCreatedAt = false,
  }) {
    return {
      'countryId': countryId.trim(),
      'name': name.trim(),
      if (lgdCode != null) 'lgdCode': lgdCode,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (includeCreatedAt)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ServiceState.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceState(
      id: id,
      countryId: data['countryId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      lgdCode: int.tryParse(data['lgdCode']?.toString() ?? ''),
      isActive: data['isActive'] == true,
      createdAt: _readLocationDate(data['createdAt']),
      updatedAt: _readLocationDate(data['updatedAt']),
    );
  }

  ServiceState copyWith({
    String? id,
    String? countryId,
    String? name,
    int? lgdCode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceState(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      name: name ?? this.name,
      lgdCode: lgdCode ?? this.lgdCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ===========================================================
/// 3. SERVICE CITY / DISTRICT
/// Collection: service_cities
///
/// verifiedBoundaryId links the City to the exact boundary
/// document used for activation.
/// ===========================================================

class ServiceCity {
  final String id;
  final String countryId;
  final String stateId;
  final String name;
  final String? lgdCode;

  /// Retained for compatibility with existing documents.
  final List<GeoPoint> boundary;
  final String boundarySource;
  final bool boundaryVerified;

  /// ID of the verified document in
  /// service_location_boundaries.
  final String verifiedBoundaryId;

  final bool isServiceActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceCity({
    this.id = '',
    required this.countryId,
    required this.stateId,
    required this.name,
    this.lgdCode,
    this.boundary = const [],
    this.boundarySource = '',
    this.boundaryVerified = false,
    this.verifiedBoundaryId = '',
    this.isServiceActive = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({
    bool includeCreatedAt = false,
  }) {
    return {
      'countryId': countryId.trim(),
      'stateId': stateId.trim(),
      'name': name.trim(),
      if (lgdCode != null) 'lgdCode': lgdCode!.trim(),

      // Legacy fields retained.
      'boundary': boundary,
      'boundarySource': boundarySource.trim(),
      'boundaryVerified': boundaryVerified,

      // New authoritative boundary reference.
      'verifiedBoundaryId': verifiedBoundaryId.trim(),

      'isServiceActive': isServiceActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (includeCreatedAt)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ServiceCity.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceCity(
      id: id,
      countryId: data['countryId']?.toString() ?? '',
      stateId: data['stateId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      lgdCode: data['lgdCode']?.toString(),
      boundary: _readLocationBoundary(data['boundary']),
      boundarySource: data['boundarySource']?.toString() ?? '',
      boundaryVerified: data['boundaryVerified'] == true,
      verifiedBoundaryId:
          data['verifiedBoundaryId']?.toString() ?? '',
      isServiceActive: data['isServiceActive'] == true,
      createdAt: _readLocationDate(data['createdAt']),
      updatedAt: _readLocationDate(data['updatedAt']),
    );
  }

  ServiceCity copyWith({
    String? id,
    String? countryId,
    String? stateId,
    String? name,
    String? lgdCode,
    List<GeoPoint>? boundary,
    String? boundarySource,
    bool? boundaryVerified,
    String? verifiedBoundaryId,
    bool? isServiceActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceCity(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      name: name ?? this.name,
      lgdCode: lgdCode ?? this.lgdCode,
      boundary: boundary ?? this.boundary,
      boundarySource: boundarySource ?? this.boundarySource,
      boundaryVerified: boundaryVerified ?? this.boundaryVerified,
      verifiedBoundaryId:
          verifiedBoundaryId ?? this.verifiedBoundaryId,
      isServiceActive: isServiceActive ?? this.isServiceActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ===========================================================
/// 4. SERVICE AREA / SUB-DISTRICT
/// Collection: service_areas
///
/// verifiedBoundaryId links the Area to its verified polygon.
/// ===========================================================

class ServiceArea {
  final String id;
  final String countryId;
  final String stateId;
  final String cityId;
  final String name;
  final String? lgdCode;

  /// Retained for legacy compatibility.
  final List<GeoPoint> boundary;
  final String boundarySource;
  final bool boundaryVerified;

  /// ID of the verified document in
  /// service_location_boundaries.
  final String verifiedBoundaryId;

  final bool isServiceActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceArea({
    this.id = '',
    this.countryId = '',
    this.stateId = '',
    required this.cityId,
    required this.name,
    this.lgdCode,
    this.boundary = const [],
    this.boundarySource = '',
    this.boundaryVerified = false,
    this.verifiedBoundaryId = '',
    this.isServiceActive = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({
    bool includeCreatedAt = false,
  }) {
    return {
      'countryId': countryId.trim(),
      'stateId': stateId.trim(),
      'cityId': cityId.trim(),
      'name': name.trim(),
      if (lgdCode != null) 'lgdCode': lgdCode!.trim(),

      // Legacy fields retained.
      'boundary': boundary,
      'boundarySource': boundarySource.trim(),
      'boundaryVerified': boundaryVerified,

      // New authoritative boundary reference.
      'verifiedBoundaryId': verifiedBoundaryId.trim(),

      'isServiceActive': isServiceActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (includeCreatedAt)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ServiceArea.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceArea(
      id: id,
      countryId: data['countryId']?.toString() ?? '',
      stateId: data['stateId']?.toString() ?? '',
      cityId: data['cityId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      lgdCode: data['lgdCode']?.toString(),
      boundary: _readLocationBoundary(data['boundary']),
      boundarySource: data['boundarySource']?.toString() ?? '',
      boundaryVerified: data['boundaryVerified'] == true,
      verifiedBoundaryId:
          data['verifiedBoundaryId']?.toString() ?? '',
      isServiceActive: data['isServiceActive'] == true,
      createdAt: _readLocationDate(data['createdAt']),
      updatedAt: _readLocationDate(data['updatedAt']),
    );
  }

  ServiceArea copyWith({
    String? id,
    String? countryId,
    String? stateId,
    String? cityId,
    String? name,
    String? lgdCode,
    List<GeoPoint>? boundary,
    String? boundarySource,
    bool? boundaryVerified,
    String? verifiedBoundaryId,
    bool? isServiceActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceArea(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      lgdCode: lgdCode ?? this.lgdCode,
      boundary: boundary ?? this.boundary,
      boundarySource: boundarySource ?? this.boundarySource,
      boundaryVerified: boundaryVerified ?? this.boundaryVerified,
      verifiedBoundaryId:
          verifiedBoundaryId ?? this.verifiedBoundaryId,
      isServiceActive: isServiceActive ?? this.isServiceActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ===========================================================
/// 5. SERVICE LOCALITY / VILLAGE
/// Collection: service_localities
///
/// An individual locality polygon is optional.
/// ===========================================================

class ServiceLocality {
  final String id;
  final String countryId;
  final String stateId;
  final String cityId;
  final String areaId;
  final String name;
  final String pincode;

  /// Optional legacy boundary information.
  final List<GeoPoint> boundary;
  final String boundarySource;
  final bool boundaryVerified;

  final bool isServiceActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ServiceLocality({
    this.id = '',
    this.countryId = '',
    this.stateId = '',
    required this.cityId,
    required this.areaId,
    required this.name,
    this.pincode = '',
    this.boundary = const [],
    this.boundarySource = '',
    this.boundaryVerified = false,
    this.isServiceActive = false,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap({
    bool includeCreatedAt = false,
  }) {
    return {
      'countryId': countryId.trim(),
      'stateId': stateId.trim(),
      'cityId': cityId.trim(),
      'areaId': areaId.trim(),
      'name': name.trim(),
      'pincode': pincode.trim(),

      // Optional legacy boundary fields.
      'boundary': boundary,
      'boundarySource': boundarySource.trim(),
      'boundaryVerified': boundaryVerified,

      'isServiceActive': isServiceActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (includeCreatedAt)
        'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ServiceLocality.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceLocality(
      id: id,
      countryId: data['countryId']?.toString() ?? '',
      stateId: data['stateId']?.toString() ?? '',
      cityId: data['cityId']?.toString() ?? '',
      areaId: data['areaId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      pincode: data['pincode']?.toString() ?? '',
      boundary: _readLocationBoundary(data['boundary']),
      boundarySource: data['boundarySource']?.toString() ?? '',
      boundaryVerified: data['boundaryVerified'] == true,
      isServiceActive: data['isServiceActive'] == true,
      createdAt: _readLocationDate(data['createdAt']),
      updatedAt: _readLocationDate(data['updatedAt']),
    );
  }

  ServiceLocality copyWith({
    String? id,
    String? countryId,
    String? stateId,
    String? cityId,
    String? areaId,
    String? name,
    String? pincode,
    List<GeoPoint>? boundary,
    String? boundarySource,
    bool? boundaryVerified,
    bool? isServiceActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceLocality(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      stateId: stateId ?? this.stateId,
      cityId: cityId ?? this.cityId,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      pincode: pincode ?? this.pincode,
      boundary: boundary ?? this.boundary,
      boundarySource: boundarySource ?? this.boundarySource,
      boundaryVerified: boundaryVerified ?? this.boundaryVerified,
      isServiceActive: isServiceActive ?? this.isServiceActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ===========================================================
/// 6. SERVICE LOCATION IMPORT
/// Collection: service_location_imports
/// ===========================================================

class ServiceLocationImport {
  final String id;
  final String source;
  final String fileName;
  final String status;
  final String importedBy;
  final DateTime? importedAt;
  final String verificationStatus;

  const ServiceLocationImport({
    this.id = '',
    required this.source,
    required this.fileName,
    required this.status,
    required this.importedBy,
    this.importedAt,
    required this.verificationStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source.trim(),
      'fileName': fileName.trim(),
      'status': status.trim(),
      'importedBy': importedBy.trim(),
      'importedAt': FieldValue.serverTimestamp(),
      'verificationStatus': verificationStatus.trim(),
    };
  }

  factory ServiceLocationImport.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ServiceLocationImport(
      id: id,
      source: data['source']?.toString() ?? '',
      fileName: data['fileName']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      importedBy: data['importedBy']?.toString() ?? '',
      importedAt: _readLocationDate(data['importedAt']),
      verificationStatus:
          data['verificationStatus']?.toString() ?? '',
    );
  }

  ServiceLocationImport copyWith({
    String? id,
    String? source,
    String? fileName,
    String? status,
    String? importedBy,
    DateTime? importedAt,
    String? verificationStatus,
  }) {
    return ServiceLocationImport(
      id: id ?? this.id,
      source: source ?? this.source,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      importedBy: importedBy ?? this.importedBy,
      importedAt: importedAt ?? this.importedAt,
      verificationStatus:
          verificationStatus ?? this.verificationStatus,
    );
  }
}
