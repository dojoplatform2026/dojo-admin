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
  late final BoundaryService _boundaryService = BoundaryService();

  final _nameController = TextEditingController();
  final _societyController = TextEditingController();
  final _pinCodeController = TextEditingController();

  GoogleMapController? _mapController;

  List<LatLng> _points = [];
  List<BoundaryCandidate> _candidates = [];
  List<Map<String, dynamic>> _locations = [];

  String? _state;
  String? _city;
  String? _locality;
  String? _selectedZoneId;
  String? _selectedBoundaryKey;

  bool _active = false;
  bool _saving = false;
  bool _loadingLocations = true;
  bool _searching = false;

  static const _orange = Color(0xFFF47721);
  static const _background = Color(0xFFF5F5F5);
  static const _center = LatLng(28.6150, 77.4350);

  CollectionReference<Map<String, dynamic>> get _zones =>
      _db.collection('zones');

  bool get _isEditing => _selectedZoneId != null;

  List<String> get _states {
    final values = _locations
        .map((e) => _str(e['state']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _cities {
    final values = _locations
        .where((e) => _str(e['state']) == _state)
        .map((e) => _str(e['city']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<String> get _localities {
    final values = _locations
        .where((e) =>
            _str(e['state']) == _state &&
            _str(e['city']) == _city)
        .map((e) => _str(e['locality']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  String _str(dynamic value) => value?.toString().trim() ?? '';

  String _key(BoundaryCandidate candidate) =>
      '${candidate.osmType}:${candidate.osmId}:${candidate.points.length}';

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _societyController.dispose();
    _pinCodeController.dispose();
    _mapController?.dispose();
    _boundaryService.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final snapshot = await _db.collection('location_catalog').get();
      if (!mounted) return;

      setState(() {
        _locations = snapshot.docs.map((doc) {
          return <String, dynamic>{...doc.data(), 'id': doc.id};
        }).toList();
        _loadingLocations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLocations = false);
      _message('Location list load nahi hui: $e', error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ));
  }

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
    if (controller == null || points.isEmpty) return;

    try {
      if (points.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
        return;
      }

      var minLat = points.first.latitude;
      var maxLat = minLat;
      var minLng = points.first.longitude;
      var maxLng = minLng;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      if (minLat == maxLat && minLng == maxLng) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
      } else {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            60,
          ),
        );
      }
    } catch (e) {
      debugPrint('Map focus failed: $e');
    }
  }

  void _resetForm() {
    if (_saving) return;
    setState(() {
      _selectedZoneId = null;
      _selectedBoundaryKey = null;
      _nameController.clear();
      _societyController.clear();
      _pinCodeController.clear();
      _state = null;
      _city = null;
      _locality = null;
      _points.clear();
      _candidates.clear();
      _active = false;
    });
  }

  void _startEdit(String id, Map<String, dynamic> data) {
    if (_saving) return;

    final state = _str(data['state']);
    final city = _str(data['city']);
    final locality = _str(data['locality']).isNotEmpty
        ? _str(data['locality'])
        : _str(data['area']);
    final points = _readCoordinates(data['coordinates']);

    setState(() {
      _selectedZoneId = id;
      _selectedBoundaryKey = null;
      _nameController.text = _str(data['name']);
      _societyController.text = _str(data['society']).isNotEmpty
          ? _str(data['society'])
          : _str(data['sector']);
      _pinCodeController.text = _str(data['pinCode']);

      _state = _states.contains(state) ? state : null;
      _city = _citiesFor(state).contains(city) ? city : null;
      _locality = _localitiesFor(state, city).contains(locality)
          ? locality
          : null;

      _active = data['isActive'] == true;
      _points = points;
    });

    _focusZone(points);
    _message('Edit mode ready.');
  }

  List<String> _citiesFor(String state) {
    final result = _locations
        .where((e) => _str(e['state']) == state)
        .map((e) => _str(e['city']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  List<String> _localitiesFor(String state, String city) {
    final result = _locations
        .where((e) =>
            _str(e['state']) == state &&
            _str(e['city']) == city)
        .map((e) => _str(e['locality']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  Future<void> _searchBoundaries() async {
    if (_saving || _searching) return;

    if (_state == null || _city == null || _locality == null) {
      _message('State, City aur Area select karo.', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _candidates = [];
      _selectedBoundaryKey = null;
    });

    try {
      final results = await _boundaryService.searchBoundaries(
        area: _locality!,
        city: _city!,
        state: _state!,
      );

      if (!mounted) return;
      setState(() => _candidates = results);

      _message(results.isEmpty
          ? 'Boundary nahi mili. Manual drawing use karo.'
          : '${results.length} results mile. Boundary ko verify karo.');
    } catch (e) {
      _message('Boundary search failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectBoundary(BoundaryCandidate candidate) async {
    if (_saving) return;

    setState(() {
      _selectedZoneId = null;
      _selectedBoundaryKey = _key(candidate);
      _points = List<LatLng>.from(candidate.points);
      _nameController.text = candidate.name;
      _active = false;
    });

    await _focusZone(candidate.points);
    _message('Boundary preview loaded. Save karne se pehle verify karo.');
  }

  Future<void> _saveZone() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final society = _societyController.text.trim();
    final pin = _pinCodeController.text.trim();

    if (name.isEmpty) {
      _message('Zone name zaroori hai.', error: true);
      return;
    }
    if (_state == null || _city == null || _locality == null) {
      _message('State, City aur Area select karo.', error: true);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _message('Valid 6-digit PIN code enter karo.', error: true);
      return;
    }
    if (_points.length < 3) {
      _message('Boundary ke liye kam se kam 3 points chahiye.',
          error: true);
      return;
    }

    final imported = !_isEditing && _selectedBoundaryKey != null;
    final editingId = _selectedZoneId;
    final wasEditing = _isEditing;
    final points = List<LatLng>.from(_points);

    if (imported) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save for review?'),
          content: const Text(
            'Imported boundary inactive save hogi. '
            'Activate karne se pehle map par boundary verify karo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'name': name,
        'state': _state,
        'city': _city,
        'locality': _locality,
        'area': _locality,
        'society': society,
        'sector': society,
        'pinCode': pin,
        'isActive': imported ? false : _active,
        'type': 'polygon',
        'coordinates': points.map((p) => {
          'latitude': p.latitude,
          'longitude': p.longitude,
        }).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (wasEditing && editingId != null) {
        await _zones.doc(editingId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();

        if (imported) {
          final matches = _candidates.where(
            (c) => _key(c) == _selectedBoundaryKey,
          );
          if (matches.isNotEmpty) {
            final c = matches.first;
            data['boundarySource'] = 'openstreetmap';
            data['osmType'] = c.osmType;
            data['osmId'] = c.osmId;
            data['osmDisplayName'] = c.displayName;
          }
        } else {
          data['boundarySource'] = 'manual';
        }

        await _zones.add(data);
      }

      if (!mounted) return;
      setState(() {
        _selectedZoneId = null;
        _selectedBoundaryKey = null;
        _nameController.clear();
        _societyController.clear();
        _pinCodeController.clear();
        _state = null;
        _city = null;
        _locality = null;
        _points.clear();
        _active = false;
      });

      _message(imported
          ? 'Boundary inactive save hui. Review ke baad activate karo.'
          : wasEditing
              ? 'Zone update ho gaya.'
              : 'Zone save ho gaya.');
    } on FirebaseException catch (e) {
      _message('Save failed (${e.code}): ${e.message}', error: true);
    } catch (e) {
      _message('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleZone(String id, bool current) async {
    try {
      await _zones.doc(id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message(current ? 'Zone inactive ho gaya.' : 'Zone active ho gaya.');
    } catch (e) {
      _message('Status update failed: $e', error: true);
    }
  }

  Future<void> _deleteZone(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete zone?'),
        content: Text('"$name" permanently delete karna hai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _zones.doc(id).delete();
      if (_selectedZoneId == id) _resetForm();
      _message('Zone delete ho gaya.');
    } catch (e) {
      _message('Delete failed: $e', error: true);
    }
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value != null && options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: options.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: _saving ? null : onChanged,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    int maxLength = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        keyboardType: keyboard,
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

  Set<Polygon> _polygons(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final result = <Polygon>{};

    for (final doc in docs) {
      final points = _readCoordinates(doc.data()['coordinates']);
      if (points.length < 3) continue;

      final active = doc.data()['isActive'] == true;
      final selected = doc.id == _selectedZoneId;

      result.add(Polygon(
        polygonId: PolygonId('saved-${doc.id}'),
        points: points,
        fillColor: (selected
                ? Colors.blue
                : active
                    ? Colors.green
                    : Colors.grey)
            .withValues(alpha: 0.16),
        strokeColor: selected
            ? Colors.blue
            : active
                ? Colors.green
                : Colors.grey,
        strokeWidth: selected ? 4 : 2,
      ));
    }

    if (_points.length >= 3) {
      result.add(Polygon(
        polygonId: const PolygonId('preview'),
        points: _points,
        fillColor: _orange.withValues(alpha: 0.18),
        strokeColor: _orange,
        strokeWidth: 3,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _zones.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final activeCount =
            docs.where((d) => d.data()['isActive'] == true).length;

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  const Icon(Icons.map, color: _orange, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Service Zones',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ]),
                Wrap(spacing: 8, children: [
                  Chip(label: Text('${docs.length} Total')),
                  Chip(label: Text('$activeCount Active')),
                  Chip(label: Text('${docs.length - activeCount} Inactive')),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 330,
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _center,
                      zoom: 13,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    onTap: _saving
                        ? null
                        : (p) => setState(() {
                              _points.add(p);
                              _selectedZoneId = null;
                              _selectedBoundaryKey = null;
                            }),
                    polygons: _polygons(docs),
                    markers: {
                      for (var i = 0; i < _points.length; i++)
                        Marker(
                          markerId: MarkerId('point-$i'),
                          position: _points[i],
                        ),
                    },
                    zoomControlsEnabled: true,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Green = Active • Blue = Saved selection • Orange = Preview'),
                const SizedBox(height: 20),
                const Text('Find Available Boundaries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_loadingLocations)
                  const LinearProgressIndicator()
                else if (_locations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'location_catalog empty hai. State, city aur locality ke records add karo.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                _dropdown(
                  label: 'State',
                  value: _state,
                  options: _states,
                  icon: Icons.map_outlined,
                  onChanged: (v) => setState(() {
                    _state = v;
                    _city = null;
                    _locality = null;
                  }),
                ),
                _dropdown(
                  label: 'City',
                  value: _city,
                  options: _cities,
                  icon: Icons.location_city,
                  onChanged: (v) => setState(() {
                    _city = v;
                    _locality = null;
                  }),
                ),
                _dropdown(
                  label: 'Area / Locality',
                  value: _locality,
                  options: _localities,
                  icon: Icons.place_outlined,
                  onChanged: (v) => setState(() => _locality = v),
                ),
                FilledButton.icon(
                  onPressed: _searching ? null : _searchBoundaries,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.travel_explore),
                  label: Text(_searching ? 'Searching...' : 'Search Boundaries'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                if (_candidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Select a boundary to preview'),
                  ..._candidates.map((c) => Card(
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Text(
                              '${c.osmType} ${c.osmId} • ${c.points.length} points'),
                          trailing: const Icon(Icons.visibility),
                          onTap: () => _selectBoundary(c),
                        ),
                      )),
                ],
                const SizedBox(height: 20),
                Text(_isEditing ? 'Edit Service Zone' : 'Add New Service Zone',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                _field(
                  controller: _nameController,
                  label: 'Zone Name',
                  hint: 'e.g. Gaur City 2',
                  icon: Icons.edit_location_alt,
                ),
                _field(
                  controller: _societyController,
                  label: 'Society / Sector (Optional)',
                  hint: 'e.g. Gaur City Sector 4',
                  icon: Icons.apartment,
                ),
                _field(
                  controller: _pinCodeController,
                  label: 'PIN Code',
                  hint: '6-digit PIN code',
                  icon: Icons.pin_drop_outlined,
                  keyboard: TextInputType.number,
                  maxLength: 6,
                ),
                SwitchListTile(
                  title: const Text('Zone Active'),
                  subtitle: Text(_active
                      ? 'Service enabled'
                      : 'Service disabled'),
                  value: _active,
                  activeThumbColor: _orange,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _points.isEmpty
                          ? null
                          : () => setState(() => _points.removeLast()),
                      icon: const Icon(Icons.undo),
                      label: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _points.isEmpty
                          ? null
                          : () => setState(() {
                                _points.clear();
                                _selectedBoundaryKey = null;
                              }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Boundary'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveZone,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Zone'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Manage Saved Zones',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (snapshot.hasError)
                  Text('Load failed: ${snapshot.error}')
                else if (!snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (docs.isEmpty)
                  const Text('Abhi koi saved zone nahi hai.')
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    final name = _str(data['name']).isEmpty
                        ? 'Unnamed Zone'
                        : _str(data['name']);
                    final enabled = data['isActive'] == true;
                    final coords = _readCoordinates(data['coordinates']);

                    return Card(
                      child: Column(children: [
                        ListTile(
                          title: Text(name),
                          subtitle: Text(
                            '${_str(data['city'])} • ${_str(data['locality']).isNotEmpty ? _str(data['locality']) : _str(data['area'])} • ${coords.length} points',
                          ),
                          onTap: () {
                            setState(() => _selectedZoneId = doc.id);
                            _focusZone(coords);
                          },
                        ),
                        Row(children: [
                          const SizedBox(width: 12),
                          Text(enabled ? 'Active' : 'Inactive'),
                          const Spacer(),
                          Switch(
                            value: enabled,
                            onChanged: (_) => _toggleZone(doc.id, enabled),
                          ),
                          IconButton(
                            onPressed: () => _startEdit(doc.id, data),
                            icon: const Icon(Icons.edit, color: _orange),
                          ),
                          IconButton(
                            onPressed: () => _deleteZone(doc.id, name),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ]),
                      ]),
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
