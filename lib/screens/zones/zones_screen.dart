
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

  bool _active = true;
  bool _saving = false;
  bool _drawing = false;

  static const LatLng _center = LatLng(28.6150, 77.4350);

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _addPoint(LatLng point) {
    setState(() {
      _points.add(point);
      _drawing = true;
    });
  }

  void _undoPoint() {
    if (_points.isEmpty) return;

    setState(() {
      _points.removeLast();
      _drawing = _points.isNotEmpty;
    });
  }

  Future<void> _saveZone() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _message('Zone ka naam likho.');
      return;
    }

    if (_points.length < 3) {
      _message('Boundary banane ke liye kam se kam 3 points chahiye.');
      return;
    }

    setState(() => _saving = true);

    try {
      await _db.collection('zones').add({
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

      _nameController.clear();
      setState(() {
        _points.clear();
        _drawing = false;
      });

      _message('Zone successfully save ho gaya!');
    } catch (e) {
      _message('Save nahi hua. Firestore rules check karo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Set<Polygon> get _polygons {
    if (_points.length < 3) return {};

    return {
      Polygon(
        polygonId: const PolygonId('new-zone'),
        points: _points,
        fillColor: Colors.orange.withValues(alpha: 0.20),
        strokeColor: Colors.deepOrange,
        strokeWidth: 3,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            const SizedBox(height: 18),

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
                  onTap: _addPoint,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: false,
                  polygons: _polygons,
                  markers: {
                    for (int i = 0; i < _points.length; i++)
                      Marker(
                        markerId: MarkerId('point-$i'),
                        position: _points[i],
                        infoWindow: InfoWindow(
                          title: 'Boundary point ${i + 1}',
                        ),
                      ),
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              _drawing
                  ? 'Boundary points: ${_points.length} • Kam se kam 3 points'
                  : 'Map par tap karke zone ki boundary draw karo.',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Zone name',
                hintText: 'e.g. Gaur City Zone 1',
                prefixIcon: Icon(Icons.edit_location_alt),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zone Active'),
              subtitle: Text(
                _active ? 'Service enabled' : 'Service disabled',
              ),
              value: _active,
              activeThumbColor: Colors.deepOrange,
              onChanged: (value) {
                setState(() => _active = value);
              },
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _points.isEmpty ? null : _undoPoint,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo Point'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _points.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _points.clear();
                              _drawing = false;
                            });
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _saveZone,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Zone'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                minimumSize: const Size.fromHeight(50),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Saved Zones',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('zones').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Zones load nahi hue. Rules check karo.');
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Abhi koi zone save nahi hai.'),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final enabled = data['isActive'] == true;

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: enabled ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          data['name']?.toString() ?? 'Unnamed Zone',
                        ),
                        subtitle: Text(
                          '${data['area'] ?? 'Service area'} • '
                          '${data['pinCode'] ?? ''}',
                        ),
                        trailing: Chip(
                          label: Text(enabled ? 'Active' : 'Inactive'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
