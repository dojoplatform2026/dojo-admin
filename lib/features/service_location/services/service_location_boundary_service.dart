import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_location_boundary.dart';

/// DOJO WALK Admin
///
/// Service Location Boundary Service.
///
/// Lifecycle:
/// Pending -> Verified
/// Pending -> Rejected
/// Rejected -> Pending (resubmission)
///
/// Security:
/// - Firestore Security Rules remain authoritative.
/// - Verified boundaries cannot be edited or deleted.
/// - Only pending boundaries can be verified or rejected.
/// - Rejected boundaries may be edited and resubmitted.

class ServiceLocationBoundaryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ServiceLocationBoundaryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _boundaries =>
      _firestore.collection('service_location_boundaries');

  String get _currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Please sign in before managing service boundaries.',
      );
    }

    return user.uid;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _required(String value, String field) {
    final result = value.trim();

    if (result.isEmpty) {
      throw ArgumentError('$field is required.');
    }

    return result;
  }

  bool _isSupportedLocationType(String value) {
    return const {'city', 'area', 'locality'}
        .contains(value.trim().toLowerCase());
  }

  Map<String, dynamic> _serializePoints(
    List<GeoPoint> points,
  ) {
    return {
      'points': points
          .map(
            (point) => GeoPoint(
              point.latitude,
              point.longitude,
            ),
          )
          .toList(),
    };
  }

  void _validateLocation({
    required String locationId,
    required String locationType,
  }) {
    _required(locationId, 'Location ID');

    if (!_isSupportedLocationType(locationType)) {
      throw ArgumentError(
        'Location type must be city, area, or locality.',
      );
    }
  }

  List<String> _validationErrors(
    ServiceLocationBoundary boundary,
  ) {
    final errors = <String>[
      ...boundary.validate(),
    ];

    if (boundary.locationId.trim().isEmpty) {
      errors.add('Location ID is required.');
    }

    if (!_isSupportedLocationType(boundary.locationType)) {
      errors.add(
        'Location type must be city, area, or locality.',
      );
    }

    if (boundary.sourceName.trim().isEmpty) {
      errors.add('Boundary source name is required.');
    }

    if (boundary.sourceReference.trim().isEmpty) {
      errors.add('Boundary source reference is required.');
    }

    if (boundary.points.length < 3) {
      errors.add(
        'A polygon must contain at least three points.',
      );
    }

    return errors.toSet().toList();
  }

  void _throwIfInvalid(
    ServiceLocationBoundary boundary,
  ) {
    final errors = _validationErrors(boundary);

    if (errors.isNotEmpty) {
      throw ArgumentError(
        'Boundary validation failed:\n${errors.join('\n')}',
      );
    }
  }

  void _requireEditableStatus(String status) {
    if (status == BoundaryVerificationStatus.verified.name) {
      throw StateError(
        'Verified boundaries cannot be edited.',
      );
    }

    if (status != BoundaryVerificationStatus.pending.name &&
        status != BoundaryVerificationStatus.rejected.name) {
      throw StateError(
        'Only pending or rejected boundaries can be edited.',
      );
    }
  }

  // ============================================================
  // GET BOUNDARY
  // ============================================================

  Future<ServiceLocationBoundary?> getById(
    String boundaryId,
  ) async {
    _currentUid;

    final id = _required(boundaryId, 'Boundary ID');
    final snapshot = await _boundaries.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return ServiceLocationBoundary.fromMap(
      snapshot.id,
      data,
    );
  }

  // ============================================================
  // WATCH BOUNDARIES FOR A LOCATION
  // ============================================================

  Stream<List<ServiceLocationBoundary>> watchForLocation(
    String locationId, {
    String? locationType,
  }) {
    final id = locationId.trim();

    if (id.isEmpty) {
      return Stream.value(
        <ServiceLocationBoundary>[],
      );
    }

    final normalizedType = locationType?.trim().toLowerCase();

    return _boundaries
        .where('locationId', isEqualTo: id)
        .snapshots()
        .map((snapshot) {
      final results = <ServiceLocationBoundary>[];

      for (final document in snapshot.docs) {
        final boundary = ServiceLocationBoundary.fromMap(
          document.id,
          document.data(),
        );

        if (normalizedType != null &&
            boundary.locationType.toLowerCase() != normalizedType) {
          continue;
        }

        results.add(boundary);
      }

      results.sort((a, b) {
        final dateComparison = b.updatedAt.compareTo(a.updatedAt);

        if (dateComparison != 0) {
          return dateComparison;
        }

        return b.id.compareTo(a.id);
      });

      return results;
    });
  }

  // ============================================================
  // SAVE / UPDATE BOUNDARY
  // ============================================================

  Future<String> saveDraft(
    ServiceLocationBoundary boundary,
  ) async {
    _currentUid;

    final locationId = _required(
      boundary.locationId,
      'Location ID',
    );

    final locationType = _required(
      boundary.locationType,
      'Location type',
    ).toLowerCase();

    _validateLocation(
      locationId: locationId,
      locationType: locationType,
    );

    if (boundary.isVerified) {
      throw StateError(
        'A verified boundary cannot be saved as a draft.',
      );
    }

    _throwIfInvalid(boundary);

    final document = boundary.id.trim().isEmpty
        ? _boundaries.doc()
        : _boundaries.doc(boundary.id.trim());

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final existing = snapshot.data();

      if (snapshot.exists && existing != null) {
        final existingStatus =
            existing['verificationStatus']?.toString() ?? '';

        _requireEditableStatus(existingStatus);

        final existingLocationId =
            existing['locationId']?.toString() ?? '';

        final existingLocationType =
            existing['locationType']?.toString() ?? '';

        if (existingLocationId != locationId ||
            existingLocationType != locationType) {
          throw StateError(
            'An existing boundary cannot be reassigned '
            'to another location.',
          );
        }
      }

      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'locationId': locationId,
        'locationType': locationType,
        ..._serializePoints(boundary.points),
        'sourceType': boundary.sourceType.name,
        'sourceName': boundary.sourceName.trim(),
        'sourceReference': boundary.sourceReference.trim(),
        'verificationStatus':
            BoundaryVerificationStatus.pending.name,
        'verifiedBy': null,
        'verifiedAt': null,
        // Required by the current Firestore create/update Rules.
        'verificationNotes': null,
        'updatedAt': now,
      };

      if (!snapshot.exists) {
        data['createdAt'] = now;
      }

      transaction.set(
        document,
        data,
        SetOptions(merge: true),
      );
    });

    return document.id;
  }

  // ============================================================
  // REQUEST VERIFICATION / RESUBMIT
  // ============================================================

  Future<void> requestVerification(
    String boundaryId,
  ) async {
    _currentUid;

    final id = _required(boundaryId, 'Boundary ID');
    final reference = _boundaries.doc(id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Boundary not found.');
      }

      final data = snapshot.data()!;

      final status =
          data['verificationStatus']?.toString() ?? '';

      if (status == BoundaryVerificationStatus.verified.name) {
        throw StateError(
          'This boundary is already verified.',
        );
      }

      if (status != BoundaryVerificationStatus.pending.name &&
          status != BoundaryVerificationStatus.rejected.name) {
        throw StateError(
          'Only pending or rejected boundaries can be submitted.',
        );
      }

      final boundary = ServiceLocationBoundary.fromMap(
        snapshot.id,
        data,
      );

      _throwIfInvalid(boundary);

      transaction.update(reference, {
        'verificationStatus':
            BoundaryVerificationStatus.pending.name,
        'verifiedBy': null,
        'verifiedAt': null,
        // The current Rules require null when returning to pending.
        'verificationNotes': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================================
  // MARK VERIFIED
  // ============================================================

  Future<void> markVerified({
    required String boundaryId,
    String? reviewerId,
    required String verificationNotes,
  }) async {
    final uid = _currentUid;

    if (reviewerId != null &&
        reviewerId.trim().isNotEmpty &&
        reviewerId.trim() != uid) {
      throw StateError(
        'Reviewer ID must match the signed-in user.',
      );
    }

    final notes = _required(
      verificationNotes,
      'Verification notes',
    );

    final id = _required(boundaryId, 'Boundary ID');
    final reference = _boundaries.doc(id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Boundary not found.');
      }

      final data = snapshot.data()!;

      if (data['verificationStatus'] !=
          BoundaryVerificationStatus.pending.name) {
        throw StateError(
          'Only pending boundaries can be verified.',
        );
      }

      final boundary = ServiceLocationBoundary.fromMap(
        snapshot.id,
        data,
      );

      _throwIfInvalid(boundary);

      // Enforce parent containment at the point of verification, not just
      // in UI code. Read the location and its verified parent boundary
      // before any transaction writes.
      final locationType = boundary.locationType.trim().toLowerCase();
      if (locationType == 'area' || locationType == 'locality') {
        final locationReference = locationType == 'area'
            ? _firestore.collection('service_areas').doc(boundary.locationId)
            : _firestore.collection('service_localities').doc(boundary.locationId);
        final locationSnapshot = await transaction.get(locationReference);
        if (!locationSnapshot.exists || locationSnapshot.data() == null) {
          throw StateError('The location linked to this boundary was not found.');
        }

        final locationData = locationSnapshot.data()!;
        final parentType = locationType == 'area' ? 'city' : 'area';
        final parentLocationId = (locationType == 'area'
                ? locationData['cityId']
                : locationData['areaId'])
            ?.toString()
            .trim() ?? '';
        if (parentLocationId.isEmpty) {
          throw StateError('The parent $parentType ID is missing.');
        }

        final parentLocationReference = locationType == 'area'
            ? _firestore.collection('service_cities').doc(parentLocationId)
            : _firestore.collection('service_areas').doc(parentLocationId);
        final parentLocationSnapshot =
            await transaction.get(parentLocationReference);
        if (!parentLocationSnapshot.exists ||
            parentLocationSnapshot.data() == null) {
          throw StateError('The parent $parentType location was not found.');
        }

        final parentBoundaryId =
            parentLocationSnapshot.data()!['verifiedBoundaryId']
                ?.toString()
                .trim() ?? '';
        if (parentBoundaryId.isEmpty) {
          throw StateError(
            'The parent $parentType must have a verified boundary first.',
          );
        }

        final parentBoundaryReference = _boundaries.doc(parentBoundaryId);
        final parentBoundarySnapshot =
            await transaction.get(parentBoundaryReference);
        if (!parentBoundarySnapshot.exists ||
            parentBoundarySnapshot.data() == null) {
          throw StateError('The verified parent boundary document is missing.');
        }

        final parentBoundary = ServiceLocationBoundary.fromMap(
          parentBoundarySnapshot.id,
          parentBoundarySnapshot.data()!,
        );
        if (!parentBoundary.isVerified ||
            parentBoundary.locationId != parentLocationId ||
            parentBoundary.locationType.toLowerCase() != parentType) {
          throw StateError(
            'The parent boundary reference is not a verified boundary for this location.',
          );
        }

        if (!boundary.isContainedBy(parentBoundary)) {
          throw StateError(
            'Boundary rejected: the $locationType polygon must remain inside its verified $parentType boundary.',
          );
        }
      }

      transaction.update(reference, {
        'verificationStatus':
            BoundaryVerificationStatus.verified.name,
        'verifiedBy': uid,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================================
  // REJECT BOUNDARY
  // ============================================================

  Future<void> rejectBoundary({
    required String boundaryId,
    String? reviewerId,
    required String reason,
  }) async {
    final uid = _currentUid;

    if (reviewerId != null &&
        reviewerId.trim().isNotEmpty &&
        reviewerId.trim() != uid) {
      throw StateError(
        'Reviewer ID must match the signed-in user.',
      );
    }

    final rejectionReason = _required(reason, 'Rejection reason');
    final id = _required(boundaryId, 'Boundary ID');
    final reference = _boundaries.doc(id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Boundary not found.');
      }

      final data = snapshot.data()!;

      if (data['verificationStatus'] !=
          BoundaryVerificationStatus.pending.name) {
        throw StateError(
          'Only pending boundaries can be rejected.',
        );
      }

      transaction.update(reference, {
        'verificationStatus':
            BoundaryVerificationStatus.rejected.name,
        'verifiedBy': uid,
        'verifiedAt': null,
        'verificationNotes': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================================
  // DELETE PENDING / REJECTED BOUNDARY
  // ============================================================

  Future<void> deleteDraft(
    String boundaryId,
  ) async {
    _currentUid;

    final id = _required(boundaryId, 'Boundary ID');
    final reference = _boundaries.doc(id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data()!;

      if (data['verificationStatus'] ==
          BoundaryVerificationStatus.verified.name) {
        throw StateError(
          'Verified boundaries cannot be deleted.',
        );
      }

      transaction.delete(reference);
    });
  }
}
