import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/boundary_service.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BoundaryService _boundaryService = BoundaryService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _societyController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();

  GoogleMapController? _mapController;

  final List<LatLng> _points = [];
  List<BoundaryCandidate> _boundaryCandidates = [];

  String? _selectedZoneId;
  String? _selectedBoundaryKey;

  bool _active = false;
  bool _saving = false;
  bool _searchingBoundaries = false;

  static const Color _orange = Color(0xFFF47721);
  static const Color _background = Color(0xFFF5F5F5);
  static const LatLng _center = LatLng(28.6150, 77.4350);

  bool get _isEditing => _selectedZoneId != null;

  CollectionReference<Map<String, dynamic>> get _zones =>
      _db.collection('zones');

  String _boundaryKey(BoundaryCandidate item) =>
      '${item.osmType}:${item.osmId}:${item.points.length}';

  @override
  void dispose() {
    _nameController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _localityController.dispose();
    _societyController.dispose();
    _pinCodeController.dispose();
    _mapController?.dispose();
    _boundaryService.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  List<LatLng> _readCoordinates(dynamic value) {
    if (value is! List) return [];

    final result = <LatLng>[];

    for (final item in value) {
      if (item is GeoPoint) {
        result.add(LatLng(item.latitude, item.longitude));
      } else if (item is Map) {
        final lat = item['latitude'];
        final lng = item['longitude'];

        if (lat is num && lng is num) {
          result.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    return result;
  }

  Future<void> _focusZone(List<LatLng> points) async {
    final controller = _mapController;

    if (points.isEmpty || controller == null) return;

    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
        return;
      }

      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLng = points.first.longitude;
      var maxLng = points.first.longitude;

      for (final point in points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      if (minLat == maxLat && minLng == maxLng) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
        return;
      }

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          65,
        ),
      );
    } catch (e) {
      debugPrint('MAP FOCUS ERROR: $e');
    }
  }

  void _resetForm() {
    if (_saving) return;

    setState(() {
      _selectedZoneId = null;
      _selectedBoundaryKey = null;

      _nameController.clear();
      _stateController.clear();
      _cityController.clear();
      _localityController.clear();
      _societyController.clear();
      _pinCodeController.clear();

      _points.clear();
      _active = false;
    });
  }

  void _startEdit(String id, Map<String, dynamic> data) {
    if (_saving) return;

    final coordinates = _readCoordinates(data['coordinates']);

    setState(() {
      _selectedZoneId = id;
      _selectedBoundaryKey = null;

      _nameController.text = _text(data['name']);
      _stateController.text = _text(data['state']);
      _cityController.text = _text(data['city']);

      _localityController.text = _text(data['locality']).isNotEmpty
          ? _text(data['locality'])
          : _text(data['area']);

      _societyController.text = _text(data['society']).isNotEmpty
          ? _text(data['society'])
          : _text(data['sector']);

      _pinCodeController.text = _text(data['pinCode']);
      _active = data['isActive'] == true;

      _points
        ..clear()
        ..addAll(coordinates);
    });

    _focusZone(coordinates);
    _message('Zone edit mode mein khul gaya.');
  }

  // Search OSM for available polygon boundaries.
  Future<void> _searchBoundaries() async {
    if (_searchingBoundaries || _saving) return;

    final area = _localityController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();

    if (area.isEmpty || city.isEmpty || state.isEmpty) {
      _message(
        'Search ke liye Locality, City aur State bharo.',
        error: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _searchingBoundaries = true;
      _boundaryCandidates = [];
      _selectedBoundaryKey = null;
    });

    try {
      final results = await _boundaryService.searchBoundaries(
        area: area,
        city: city,
        state: state,
      );

      if (!mounted) return;

      setState(() {
        _boundaryCandidates = results;
      });

      if (results.isEmpty) {
        _message(
          'Koi polygon boundary nahi mili. Manual drawing use karo.',
          error: true,
        );
      } else {
        _message(
          '${results.length} boundary candidates mile. Map par review karo.',
        );
      }
    } catch (e) {
      if (mounted) {
        _message('Boundary search failed: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _searchingBoundaries = false);
      }
    }
  }

  // Load a candidate into the map for review.
  Future<void> _selectBoundary(BoundaryCandidate candidate) async {
    if (_saving) return;

    setState(() {
      _selectedZoneId = null;
      _selectedBoundaryKey = _boundaryKey(candidate);

      _points
        ..clear()
        ..addAll(candidate.points);

      _nameController.text = candidate.name;

      // Keep the user's search location as the locality.
      // The OSM result name is used as the initial zone name.
      _active = false;
    });

    await _focusZone(candidate.points);

    if (mounted) {
      _message(
        'Boundary preview ready. Details check karo; zone abhi publish nahi hua.',
      );
    }
  }

  Future<void> _saveZone() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final state = _stateController.text.trim();
    final city = _cityController.text.trim();
    final locality = _localityController.text.trim();
    final society = _societyController.text.trim();
    final pinCode = _pinCodeController.text.trim();

    if (name.isEmpty) {
      _message('Zone ka naam likho.', error: true);
      return;
    }

    if (state.isEmpty || city.isEmpty || locality.isEmpty) {
      _message(
        'State, City aur Locality zaroori hain.',
        error: true,
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pinCode)) {
      _message('Valid 6-digit PIN code likho.', error: true);
      return;
    }

    if (_points.length < 3) {
      _message(
        'Boundary ke liye kam se kam 3 points chahiye.',
        error: true,
      );
      return;
    }

    // New OSM boundaries must be saved inactive first.
    // Admin can review the saved polygon and activate it separately.
    final bool importedBoundary =
        !_isEditing && _selectedBoundaryKey != null;

    final bool activeToSave = importedBoundary ? false : _active;

    if (importedBoundary) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save boundary for review?'),
          content: const Text(
            'Ye boundary inactive save hogi. Map aur details check '
            'karne ke baad Manage Saved Zones se activate kar sakte ho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save for Review'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;
    }

    final wasEditing = _isEditing;
    final editingId = _selectedZoneId;
    final savedPoints = List<LatLng>.from(_points);

    setState(() => _saving = true);

    try {
      final zoneData = <String, dynamic>{
        'name': name,
        'state': state,
        'city': city,
        'locality': locality,
        'society': society,
        'sector': society,
        'area': locality,
        'pinCode': pinCode,
        'isActive': activeToSave,
        'type': 'polygon',
        'coordinates': savedPoints
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String savedId;

      if (wasEditing && editingId != null) {
        await _zones.doc(editingId).update(zoneData);
        savedId = editingId;
      } else {
        zoneData['createdAt'] = FieldValue.serverTimestamp();

        // Record the source for audit/debugging.
        if (importedBoundary) {
          final selectedCandidate = _boundaryCandidates.where(
            (candidate) =>
                _boundaryKey(candidate) == _selectedBoundaryKey,
          );

          if (selectedCandidate.isNotEmpty) {
            final candidate = selectedCandidate.first;

            zoneData['boundarySource'] = 'openstreetmap';
            zoneData['osmType'] = candidate.osmType;
            zoneData['osmId'] = candidate.osmId;
            zoneData['osmDisplayName'] = candidate.displayName;
          }
        } else {
          zoneData['boundarySource'] = 'manual';
        }

        final doc = await _zones.add(zoneData);
        savedId = doc.id;
      }

      if (!mounted) return;

      setState(() {
        // Clear the form after saving, so the next save creates a new zone.
        _selectedZoneId = null;
        _selectedBoundaryKey = null;

        _nameController.clear();
        _stateController.clear();
        _cityController.clear();
        _localityController.clear();
        _societyController.clear();
        _pinCodeController.clear();

        _points.clear();
        _active = false;
      });

      await _focusZone(savedPoints);

      _message(
        importedBoundary
            ? 'Boundary review ke liye inactive save ho gayi (ID: $savedId).'
            : wasEditing
                ? 'Zone "$name" update ho gaya!'
                : 'Zone "$name" save ho gaya!',
      );
    } on FirebaseException catch (e) {
      _message(
        'Save failed (${e.code}): ${e.message}',
        error: true,
      );
    } catch (e) {
      _message('Save failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleZone(String id, bool currentlyActive) async {
    try {
      await _zones.doc(id).update({
        'isActive': !currentlyActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _message(
        currentlyActive
            ? 'Zone deactivate ho gaya.'
            : 'Zone activate ho gaya.',
      );
    } on FirebaseException catch (e) {
      _message(
        'Update failed (${e.code}): ${e.message}',
        error: true,
      );
    } catch (e) {
      _message('Update failed: $e', error: true);
    }
  }

  Future<void> _deleteZone(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Zone?'),
        content: Text(
          'Kya "$name" ko permanently delete karna hai?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _zones.doc(id).delete();

      if (!mounted) return;

      if (_selectedZoneId == id) {
        _resetForm();
      }

      _message('Zone "$name" delete ho gaya.');
    } on FirebaseException catch (e) {
      _message(
        'Delete failed (${e.code}): ${e.message}',
        error: true,
      );
    } catch (e) {
      _message('Delete failed: $e', error: true);
    }
  }

  Set<Polygon> _buildPolygons(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final polygons = <Polygon>{};

    for (final doc in docs) {
      final data = doc.data();
      final coordinates = _readCoordinates(data['coordinates']);

      if (coordinates.length < 3) continue;

      final selected = doc.id == _selectedZoneId;
      final enabled = data['isActive'] == true;

      polygons.add(
        Polygon(
          polygonId: PolygonId('saved-${doc.id}'),
          points: coordinates,
          fillColor: selected
              ? Colors.blue.withValues(alpha: 0.22)
              : enabled
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
          strokeColor: selected
              ? Colors.blue
              : enabled
                  ? Colors.green
                  : Colors.grey,
          strokeWidth: selected ? 5 : 3,
          consumeTapEvents: true,
          onTap: () {
            setState(() => _selectedZoneId = doc.id);
            _focusZone(coordinates);
          },
        ),
      );
    }

    // The selected search result is displayed as the orange preview.
    if (_points.length >= 3) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('new-zone'),
          points: List<LatLng>.from(_points),
          fillColor: _orange.withValues(alpha: 0.20),
          strokeColor: _orange,
          strokeWidth: 3,
        ),
      );
    }

    return polygons;
  }

  Set<Marker> _buildMarkers() {
    return {
      for (int i = 0; i < _points.length; i++)
        Marker(
          markerId: MarkerId('new-point-$i'),
          position: _points[i],
          infoWindow: InfoWindow(title: 'Boundary point ${i + 1}'),
        ),
    };
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF202124),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.words,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildBoundarySearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Find Available Boundaries'),
            const Text(
              'Area, City aur State bharo. Available OSM polygons '
              'milne par unhe map par preview kar sakte ho.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _searchingBoundaries || _saving
                  ? null
                  : _searchBoundaries,
              icon: _searchingBoundaries
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.travel_explore),
              label: Text(
                _searchingBoundaries
                    ? 'Searching Boundaries...'
                    : 'Search Available Boundaries',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (_boundaryCandidates.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Boundary Candidates'),
              const Text(
                'Result select karne se map par preview aayega. '
                'Har result exact society boundary ho, zaroori nahi.',
              ),
              const SizedBox(height: 8),
              ..._boundaryCandidates.map((candidate) {
                final key = _boundaryKey(candidate);
                final selected = key == _selectedBoundaryKey;

                return Card(
                  color: selected
                      ? _orange.withValues(alpha: 0.10)
                      : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.pentagon_outlined,
                      color: selected ? _orange : Colors.grey,
                    ),
                    title: Text(candidate.name),
                    subtitle: Text(
                      '${candidate.osmType} • ${candidate.osmId}\n'
                      '${candidate.points.length} boundary points',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.visibility_outlined),
                    onTap: _saving
                        ? null
                        : () => _selectBoundary(candidate),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _zones.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final activeCount = docs
            .where((doc) => doc.data()['isActive'] == true)
            .length;

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: _orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Zones',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('Manage service coverage areas'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add new zone',
                      onPressed: _saving ? null : _resetForm,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: _orange,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.map, size: 18),
                      label: Text('${docs.length} Total Zones'),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      label: Text('$activeCount Active'),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.pause_circle_outline,
                        size: 18,
                      ),
                      label: Text('${docs.length - activeCount} Inactive'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 340,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _center,
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;

                        final selectedId = _selectedZoneId;
                        if (selectedId != null) {
                          for (final doc in docs) {
                            if (doc.id == selectedId) {
                              _focusZone(
                                _readCoordinates(doc.data()['coordinates']),
                              );
                              break;
                            }
                          }
                        } else if (_points.isNotEmpty) {
                          _focusZone(List<LatLng>.from(_points));
                        }
                      },
                      onTap: _saving
                          ? null
                          : (point) {
                              setState(() {
                                _points.add(point);
                                _selectedZoneId = null;
                              });
                            },
                      mapType: MapType.normal,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                      polygons: _buildPolygons(docs),
                      markers: _buildMarkers(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Green = Active • Blue = Selected • Orange = New/Preview',
                  style: TextStyle(
                    color: Color(0xFF707070),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),

                // Boundary search controls.
                _buildBoundarySearchSection(),

                const SizedBox(height: 20),
                _sectionTitle(
                  _isEditing ? 'Edit Service Zone' : 'Add New Service Zone',
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _textField(
                          controller: _nameController,
                          label: 'Zone Name',
                          hint: 'e.g. Gaur City Zone 1',
                          icon: Icons.edit_location_alt,
                        ),
                        _textField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'e.g. Uttar Pradesh',
                          icon: Icons.map_outlined,
                        ),
                        _textField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g. Greater Noida',
                          icon: Icons.location_city,
                        ),
                        _textField(
                          controller: _localityController,
                          label: 'Locality / Area',
                          hint: 'e.g. Gaur City / Crossing',
                          icon: Icons.place_outlined,
                        ),
                        _textField(
                          controller: _societyController,
                          label: 'Society / Sector (Optional)',
                          hint: 'e.g. Gaur City Sector 4',
                          icon: Icons.apartment,
                        ),
                        _textField(
                          controller: _pinCodeController,
                          label: 'PIN Code',
                          hint: '6-digit PIN code',
                          icon: Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Zone Active',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _active
                                ? 'Service enabled after save'
                                : 'Service disabled',
                          ),
                          value: _active,
                          activeThumbColor: _orange,
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() => _active = value);
                                },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Draw / Review Zone Boundary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Manual boundary ke liye map par tap karo. '
                          'Search result select karne par uska polygon preview hoga. '
                          'Manual taps points add karte hain.',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _saving || _points.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _points.removeLast();
                                        });
                                      },
                                icon: const Icon(Icons.undo),
                                label: const Text('Undo'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _saving || _points.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _points.clear();
                                          _selectedBoundaryKey = null;
                                        });
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Clear Boundary'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveZone,
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
                            _saving
                                ? 'Saving...'
                                : _isEditing
                                    ? 'Update Zone'
                                    : _selectedBoundaryKey != null
                                        ? 'Save Boundary for Review'
                                        : 'Save New Zone',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _resetForm,
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel Edit'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Manage Saved Zones'),
                const Text(
                  'Saved zone select karo. Edit se details badlo, '
                  'switch se service on/off karo.',
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Zones load error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                else if (!snapshot.hasData)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (docs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Abhi koi saved zone nahi hai. '
                        'Boundary banao ya search karo, phir save karo.',
                      ),
                    ),
                  )
                else
                  ...docs.map((doc) {
                    final data = doc.data();

                    final name = _text(data['name']).isNotEmpty
                        ? _text(data['name'])
                        : 'Unnamed Zone';

                    final state = _text(data['state']);
                    final city = _text(data['city']);
                    final locality = _text(data['locality']).isNotEmpty
                        ? _text(data['locality'])
                        : _text(data['area']);

                    final society = _text(data['society']).isNotEmpty
                        ? _text(data['society'])
                        : _text(data['sector']);

                    final pinCode = _text(data['pinCode']);
                    final enabled = data['isActive'] == true;
                    final coordinates = _readCoordinates(data['coordinates']);
                    final selected = doc.id == _selectedZoneId;

                    final locationDetails = [
                      if (state.isNotEmpty) state,
                      if (city.isNotEmpty) city,
                      if (locality.isNotEmpty) locality,
                      if (society.isNotEmpty) society,
                      if (pinCode.isNotEmpty) 'PIN $pinCode',
                    ].join(' • ');

                    return Card(
                      color: selected
                          ? _orange.withValues(alpha: 0.08)
                          : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            onTap: () {
                              setState(() {
                                _selectedZoneId = doc.id;
                              });
                              _focusZone(coordinates);
                            },
                            leading: Icon(
                              Icons.location_on,
                              color: selected
                                  ? Colors.blue
                                  : enabled
                                      ? Colors.green
                                      : Colors.grey,
                              size: 30,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                '${locationDetails.isEmpty ? 'Location details not set' : locationDetails}\n'
                                '${coordinates.length} boundary points',
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.my_location,
                              color: selected ? _orange : null,
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    enabled ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: enabled
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: enabled,
                                  activeThumbColor: Colors.green,
                                  onChanged: (value) {
                                    _toggleZone(doc.id, enabled);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Edit zone',
                                  onPressed: () {
                                    _startEdit(doc.id, data);
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: _orange,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete zone',
                                  onPressed: () {
                                    _deleteZone(doc.id, name);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
