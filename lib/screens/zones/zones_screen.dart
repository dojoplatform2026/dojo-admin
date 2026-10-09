
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();

  GoogleMapController? _mapController;
  final List<LatLng> _points = [];

  String? _selectedZoneId;
  bool _active = true;
  bool _saving = false;

  static const LatLng _center = LatLng(28.6150, 77.4350);

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
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
    if (points.isEmpty || _mapController == null) return;

    try {
      if (points.length == 1) {
        await _mapController!.animateCamera(
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
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(points.first, 16),
        );
        return;
      }

      await _mapController!.animateCamera(
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

  Future<void> _saveZone() async {
    if (_saving) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _message('Zone ka naam likho.', error: true);
      return;
    }

    if (_points.length < 3) {
      _message('Boundary ke liye kam se kam 3 points banao.',
          error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final doc = await _db.collection('zones').add({
        'name': name,
        'pinCode': '201009',
        'area': 'Gaur City / Crossing',
        'isActive': _active,
        'type': 'polygon',
        'coordinates': _points
            .map((p) => {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final savedPoints = List<LatLng>.from(_points);

      setState(() {
        _points.clear();
        _nameController.clear();
        _selectedZoneId = doc.id;
        _active = true;
      });

      await _focusZone(savedPoints);
      _message('Zone "$name" save ho gaya!');
    } on FirebaseException catch (e) {
      _message('Save failed (${e.code}): ${e.message}', error: true);
    } catch (e) {
      _message('Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleZone(
    String id,
    bool currentlyActive,
  ) async {
    try {
      await _db.collection('zones').doc(id).update({
        'isActive': !currentlyActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _message(
        currentlyActive ? 'Zone deactivate ho gaya.' : 'Zone activate ho gaya.',
      );
    } on FirebaseException catch (e) {
      _message('Update failed (${e.code}): ${e.message}', error: true);
    } catch (e) {
      _message('Update failed: $e', error: true);
    }
  }

  Future<void> _deleteZone(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone?'),
        content: Text('Kya "$name" ko permanently delete karna hai?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('zones').doc(id).delete();

      if (!mounted) return;

      if (_selectedZoneId == id) {
        setState(() => _selectedZoneId = null);
      }

      _message('Zone "$name" delete ho gaya.');
    } on FirebaseException catch (e) {
      _message('Delete failed (${e.code}): ${e.message}', error: true);
    } catch (e) {
      _message('Delete failed: $e', error: true);
    }
  }

  Set<Polygon> _buildPolygons(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final polygons = <Polygon>{};

    // Saved zones: always display their stored boundaries.
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

    // Boundary currently being drawn.
    if (_points.length >= 3) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('new-zone'),
          points: List<LatLng>.from(_points),
          fillColor: Colors.deepOrange.withValues(alpha: 0.20),
          strokeColor: Colors.deepOrange,
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
          infoWindow: InfoWindow(title: 'New point ${i + 1}'),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('zones').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F9),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: Colors.deepOrange,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
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
                          const Text(
                            'Gaur City • Crossing • PIN 201009',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

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
                      label: Text(
                        '${docs.where((d) => d.data()['isActive'] == true).length} Active',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 380,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _center,
                        zoom: 14,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: (point) {
                        setState(() {
                          _points.add(point);
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
                  'Green = active saved zone • Blue = selected zone • Orange = new boundary',
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'New zone name',
                    hintText: 'e.g. Gaur City Zone 1',
                    prefixIcon: Icon(Icons.edit_location_alt),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New Zone Active'),
                  subtitle: Text(
                    _active ? 'Service enabled' : 'Service disabled',
                  ),
                  value: _active,
                  activeThumbColor: Colors.deepOrange,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value),
                ),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || _points.isEmpty
                            ? null
                            : () => setState(() => _points.removeLast()),
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || _points.isEmpty
                            ? null
                            : () => setState(() => _points.clear()),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

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
                  label: Text(_saving ? 'Saving...' : 'Save New Zone'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Manage Saved Zones',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Zone select karo: map boundary par zoom hoga. '
                  'Switch se service on/off karo.',
                ),

                const SizedBox(height: 10),

                if (snapshot.hasError)
                  Text(
                    'Zones load error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  )
                else if (!snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (docs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Abhi koi saved zone nahi hai.'),
                    ),
                  )
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    final name =
                        data['name']?.toString() ?? 'Unnamed Zone';
                    final enabled = data['isActive'] == true;
                    final coordinates =
                        _readCoordinates(data['coordinates']);
                    final selected = doc.id == _selectedZoneId;

                    return Card(
                      color: selected
                          ? Colors.orange.withValues(alpha: 0.08)
                          : null,
                      child: Column(
                        children: [
                          ListTile(
                            onTap: () {
                              setState(() => _selectedZoneId = doc.id);
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
                            subtitle: Text(
                              '${data['area'] ?? 'Service area'} • '
                              '${data['pinCode'] ?? ''}\n'
                              '${coordinates.length} boundary points',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.my_location),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text('Service Active'),
                                ),
                                Switch(
                                  value: enabled,
                                  activeThumbColor: Colors.green,
                                  onChanged: (value) {
                                    _toggleZone(doc.id, enabled);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete zone',
                                  onPressed: () =>
                                      _deleteZone(doc.id, name),
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
