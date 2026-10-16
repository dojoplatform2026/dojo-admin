import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/service_location_boundary.dart';
import '../services/service_location_boundary_service.dart';
import 'service_boundary_editor.dart';

const Color _orange = Color(0xFFFF7900);
const Color _background = Color(0xFFFFFAF5);

/// Creates and saves a service-location boundary draft.
///
/// Saving creates a pending boundary only.
/// It does not activate the location or verify its boundary.
class ServiceBoundaryDialog extends StatefulWidget {
  const ServiceBoundaryDialog({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.locationType,
    this.initialPoints = const [],
    this.service,
  });

  final String locationId;
  final String locationName;

  /// Examples: city, area, locality, village.
  final String locationType;

  final List<LatLng> initialPoints;
  final ServiceLocationBoundaryService? service;

  static Future<String?> show({
    required BuildContext context,
    required String locationId,
    required String locationName,
    required String locationType,
    List<LatLng> initialPoints = const [],
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceBoundaryDialog(
        locationId: locationId,
        locationName: locationName,
        locationType: locationType,
        initialPoints: initialPoints,
      ),
    );
  }

  @override
  State<ServiceBoundaryDialog> createState() =>
      _ServiceBoundaryDialogState();
}

class _ServiceBoundaryDialogState
    extends State<ServiceBoundaryDialog> {
  final _formKey = GlobalKey<FormState>();

  final _sourceNameController = TextEditingController();
  final _sourceReferenceController = TextEditingController();
  final _notesController = TextEditingController();

  late final ServiceLocationBoundaryService _service;

  List<GeoPoint> _points = [];
  BoundarySourceType _sourceType =
      BoundarySourceType.importedGeoJson;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? ServiceLocationBoundaryService();

    _points = widget.initialPoints
        .map(
          (point) => GeoPoint(
            point.latitude,
            point.longitude,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _sourceReferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_points.length < 3) {
      _showMessage('पहले मैप पर कम-से-कम 3 पॉइंट जोड़ें।');
      return;
    }

    final now = DateTime.now();

    final boundary = ServiceLocationBoundary(
      id: '',
      locationId: widget.locationId,
      locationType: widget.locationType,
      points: List.unmodifiable(_points),
      sourceType: _sourceType,
      sourceName: _sourceNameController.text.trim(),
      sourceReference: _sourceReferenceController.text.trim(),
      verificationStatus: BoundaryVerificationStatus.pending,
      verifiedBy: null,
      verifiedAt: null,
      verificationNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final errors = boundary.validate();

    if (errors.isNotEmpty) {
      _showMessage(errors.join('\n'));
      return;
    }

    setState(() => _saving = true);

    try {
      final id = await _service.saveDraft(boundary);

      if (!mounted) return;

      Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;

      _showMessage('Boundary सेव नहीं हुई: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _background,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1100,
          maxHeight: 850,
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLocationSummary(),
                      const SizedBox(height: 16),
                      ServiceBoundaryEditor(
                        initialPoints: widget.initialPoints,
                        initialCenter: const LatLng(
                          28.4744,
                          77.5040,
                        ),
                        initialZoom: 12,
                        onBoundaryChanged: (points) {
                          setState(() {
                            _points = points
                                .map(
                                  (point) => GeoPoint(
                                    point.latitude,
                                    point.longitude,
                                  ),
                                )
                                .toList();
                          });
                        },
                        onSaveRequested: (points) {
                          setState(() {
                            _points = List.of(points);
                          });

                          _saveDraft();
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildSourceFields(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText:
                              'Boundary source या review के बारे में जानकारी',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'यह रिकॉर्ड Pending रहेगा। केवल मैप पर पॉइंट '
                        'बनाने से सीमा सरकारी रूप से Verified नहीं होती।',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFFFE0C2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_searching,
            color: _orange,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Service Boundary Setup',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDFC2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.locationName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text('Location ID: ${widget.locationId}'),
          Text('Type: ${widget.locationType}'),
          Text('Boundary points: ${_points.length}'),
        ],
      ),
    );
  }

  Widget _buildSourceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Boundary Source',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<BoundarySourceType>(
          initialValue: _sourceType,
          decoration: const InputDecoration(
            labelText: 'Source Type',
            border: OutlineInputBorder(),
          ),
          items: BoundarySourceType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_sourceLabel(type)),
            );
          }).toList(),
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _sourceType = value);
                  }
                },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sourceNameController,
          decoration: const InputDecoration(
            labelText: 'Source Name',
            hintText: 'जैसे सरकारी GIS पोर्टल',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Source Name जरूरी है।';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sourceReferenceController,
          decoration: const InputDecoration(
            labelText: 'Source Reference',
            hintText: 'Official URL या dataset reference',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Source Reference जरूरी है।';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFFFE0C2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _saving
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            onPressed: _saving ? null : _saveDraft,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Saving...' : 'Save Pending Boundary',
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(BoundarySourceType type) {
    switch (type) {
      case BoundarySourceType.governmentGis:
        return 'Government GIS';
      case BoundarySourceType.governmentCadastralMap:
        return 'Government Cadastral Map';
      case BoundarySourceType.importedGeoJson:
        return 'Imported GeoJSON';
      case BoundarySourceType.manuallyDrawn:
        return 'Manually Drawn';
    }
  }
}
