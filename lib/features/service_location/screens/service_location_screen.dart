/// DOJO WALK Admin
///
/// Service Locations management screen.
///
/// Boundary lifecycle supported by the current Firestore Rules:
/// Pending -> Verified
/// Pending -> Rejected -> Edit and resubmit
///
/// Important:
/// - New boundaries are saved directly as Pending.
/// - A separate persisted Draft status is not supported by
///   the current Firestore Rules.
/// - Verified boundaries are read-only.
/// - Boundary verification and service activation are separate.
/// - City and Area activation use ServiceLocationService.
/// - Locality activation does not require its own polygon.
/// - Legacy Zones are not modified.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/service_location_boundary.dart';
import '../models/service_location_models.dart';
import '../services/location_csv_preview_parser.dart';
import '../services/service_location_boundary_service.dart';
import '../services/service_location_service.dart';
import '../widgets/add_location_dialog.dart';
import '../widgets/service_boundary_editor.dart';

const Color _locationOrange = Color(0xFFFF7900);
const Color _locationBackground = Color(0xFFFFFAF5);

const LatLng _defaultMapCenter = LatLng(28.4744, 77.5040);

class ServiceLocationScreen extends StatefulWidget {
  const ServiceLocationScreen({super.key});

  @override
  State<ServiceLocationScreen> createState() =>
      _ServiceLocationScreenState();
}

class _ServiceLocationScreenState
    extends State<ServiceLocationScreen> {
  final ServiceLocationService _service =
      ServiceLocationService();

  final ServiceLocationBoundaryService _boundaryService =
      ServiceLocationBoundaryService();

  final TextEditingController _searchController =
      TextEditingController();

  int _selectedTab = 0;
  String _search = '';

  GoogleMapController? _mapController;
  late Future<Set<Polygon>> _activeBoundaryPolygonsFuture;
  Set<Polygon> _loadedActiveBoundaryPolygons = <Polygon>{};
  String? _lastFittedPolygonSignature;

  static const List<String> _tabNames = [
    'Countries',
    'States',
    'Cities / Districts',
    'Areas / Sub-districts',
    'Localities / Villages',
    'Import History',
  ];

  @override
  void initState() {
    super.initState();
    _activeBoundaryPolygonsFuture = _loadActiveBoundaryPolygons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showError(Object error) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Action could not be completed'),
        content: SelectableText(error.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _matches(String value) {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) return true;

    return value.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: _locationBackground,
      appBar: AppBar(
        title: const Text(
          'Service Locations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showAddLocationDialog,
            icon: const Icon(
              Icons.add_location_alt,
              color: _locationOrange,
            ),
            label: const Text(
              'Add Location',
              style: TextStyle(
                color: _locationOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: isMobile ? 180 : 220,
              child: _buildMapPreview(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _search = value.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search State, City or Area',
                prefixIcon: const Icon(
                  Icons.search,
                  color: _locationOrange,
                ),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          _buildTabs(),
          const Divider(height: 1),
          Expanded(child: _buildSelectedList()),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _locationOrange.withValues(alpha: 0.20),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Hierarchy',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Country → State → City/District → '
            'Area/Sub-district → Locality/Village',
          ),
          SizedBox(height: 8),
          Text(
            'Pending Review → Verified / Rejected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _locationOrange,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'मौजूदा Firestore Rules में नई Boundary सीधे '
            'Pending Review में जाती है। Verified Boundary '
            'अपने आप service को active नहीं करती।',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP PREVIEW
  // ============================================================

  Future<Set<Polygon>> _loadActiveBoundaryPolygons() async {
    final cities = await _service.watchCities().first;
    final areas = await _service.watchAreas().first;
    final boundarySnapshot = await FirebaseFirestore.instance
        .collection('service_location_boundaries')
        .where('verificationStatus', isEqualTo: 'verified')
        .get();
    final boundariesById = {
      for (final document in boundarySnapshot.docs)
        document.id: ServiceLocationBoundary.fromMap(
          document.id,
          document.data(),
        ),
    };
    final polygons = <Polygon>{};

    for (final city in cities.where((item) => item.isServiceActive)) {
      final boundaryId = city.verifiedBoundaryId.trim();
      if (boundaryId.isEmpty) continue;

      final boundary = boundariesById[boundaryId];
      if (boundary == null ||
          !boundary.isVerified ||
          boundary.locationId != city.id ||
          boundary.locationType.toLowerCase() != 'city' ||
          boundary.points.length < 3) {
        continue;
      }

      polygons.add(
        Polygon(
          polygonId: PolygonId('service-city-${city.id}'),
          points: boundary.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
          strokeColor: _locationOrange,
          strokeWidth: 2,
          fillColor: _locationOrange.withValues(alpha: 0.05),
          consumeTapEvents: true,
          onTap: () => _showMessage('Active city boundary: ${city.name}'),
        ),
      );
    }

    for (final area in areas.where((item) => item.isServiceActive)) {
      final boundaryId = area.verifiedBoundaryId.trim();
      if (boundaryId.isEmpty) continue;

      final boundary = boundariesById[boundaryId];
      if (boundary == null ||
          !boundary.isVerified ||
          boundary.locationId != area.id ||
          boundary.locationType.toLowerCase() != 'area' ||
          boundary.points.length < 3) {
        continue;
      }

      polygons.add(
        Polygon(
          polygonId: PolygonId('service-area-${area.id}'),
          points: boundary.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
          strokeColor: _locationOrange,
          strokeWidth: 2,
          fillColor: _locationOrange.withValues(alpha: 0.18),
          consumeTapEvents: true,
          onTap: () => _showMessage('Active service area: ${area.name}'),
        ),
      );
    }

    return polygons;
  }

  Future<void> _fitMapToActiveBoundaries(Set<Polygon> polygons) async {
    final controller = _mapController;
    if (controller == null || polygons.isEmpty) return;

    final ids = polygons.map((polygon) => polygon.polygonId.value).toList()
      ..sort();
    final signature = ids.join('|');
    if (signature == _lastFittedPolygonSignature) return;
    _lastFittedPolygonSignature = signature;

    final points = polygons.expand((polygon) => polygon.points).toList();
    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat) {
      minLat -= 0.001;
      maxLat += 0.001;
    }
    if (minLng == maxLng) {
      minLng -= 0.001;
      maxLng += 0.001;
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          24,
        ),
      );
    } catch (_) {
      // A map can still be usable even if the camera cannot fit its bounds.
    }
  }

  Widget _buildMapPreview() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _locationOrange.withValues(alpha: 0.25),
        ),
      ),
      child: FutureBuilder<Set<Polygon>>(
        future: _activeBoundaryPolygonsFuture,
        builder: (context, snapshot) {
          final polygons = snapshot.data ?? <Polygon>{};
          _loadedActiveBoundaryPolygons = polygons;
          if (snapshot.hasData && polygons.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitMapToActiveBoundaries(polygons);
            });
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultMapCenter,
                  zoom: 11,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_loadedActiveBoundaryPolygons.isNotEmpty) {
                    _fitMapToActiveBoundaries(_loadedActiveBoundaryPolygons);
                  }
                },
                polygons: polygons,
                mapType: MapType.normal,
                myLocationButtonEnabled: false,
                myLocationEnabled: false,
                zoomControlsEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: false,
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: _locationOrange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Loading active boundaries…'
                            : 'Active boundaries: ${polygons.length}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Refresh active boundaries',
                    onPressed: () {
                      setState(() {
                        _lastFittedPolygonSignature = null;
                        _activeBoundaryPolygonsFuture =
                            _loadActiveBoundaryPolygons();
                      });
                    },
                    icon: const Icon(Icons.refresh, color: _locationOrange),
                  ),
                ),
              ),
              if (snapshot.hasError)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 54,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'Unable to load active boundaries: ${snapshot.error}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'Orange outlines show active verified City/Area boundaries. '
                    'Tap a polygon to identify it; use Manage Boundary to review details.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: _tabNames.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ChoiceChip(
            label: Text(_tabNames[index]),
            selected: _selectedTab == index,
            selectedColor:
                _locationOrange.withValues(alpha: 0.18),
            onSelected: (_) {
              setState(() => _selectedTab = index);
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedList() {
    switch (_selectedTab) {
      case 0:
        return _buildCountries();
      case 1:
        return _buildStates();
      case 2:
        return _buildCities();
      case 3:
        return _buildAreas();
      case 4:
        return _buildLocalities();
      case 5:
        return _buildImports();
      default:
        return _buildCountries();
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_searching,
              size: 44,
              color: _locationOrange,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _locationOrange,
      ),
    );
  }

  // ============================================================
  // COUNTRIES
  // ============================================================

  Widget _buildCountries() {
    return StreamBuilder<List<ServiceCountry>>(
      stream: _service.watchCountries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyState(
            'Unable to load countries:\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return _loadingState();
        }

        final items = snapshot.data!
            .where(
              (item) => _matches(
                '${item.id} ${item.name} ${item.code}',
              ),
            )
            .toList();

        if (items.isEmpty) {
          return _emptyState('No countries found.');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            return _locationCard(
              title: item.name,
              subtitle:
                  'ID: ${item.id} · Code: ${item.code}',
              active: item.isActive,
              icon: Icons.public,
              onToggle: (value) async {
                try {
                  await _service.setCountryStatus(
                    countryId: item.id,
                    isActive: value,
                  );
                } catch (error) {
                  await _showError(error);
                }
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // STATES
  // ============================================================

  Widget _buildStates() {
    return StreamBuilder<List<ServiceCountry>>(
      stream: _service.watchCountries(),
      builder: (context, countrySnapshot) {
        if (countrySnapshot.hasError) {
          return _emptyState('${countrySnapshot.error}');
        }

        if (!countrySnapshot.hasData) {
          return _loadingState();
        }

        final countries = countrySnapshot.data!;

        if (countries.isEmpty) {
          return _emptyState('Add a country first.');
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final country in countries)
              StreamBuilder<List<ServiceState>>(
                stream: _service.watchStates(
                  countryId: country.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final items = snapshot.data!
                      .where(
                        (item) => _matches(
                          '${item.id} ${item.name} '
                          '${country.id} ${country.name}',
                        ),
                      )
                      .toList();

                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(country.name),
                      for (final item in items)
                        _locationCard(
                          title: item.name,
                          subtitle:
                              'ID: ${item.id} · Country: ${country.name}',
                          active: item.isActive,
                          icon: Icons.map_outlined,
                          onToggle: (value) async {
                            try {
                              await _service.setStateStatus(
                                stateId: item.id,
                                isActive: value,
                              );
                            } catch (error) {
                              await _showError(error);
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CITIES / DISTRICTS
  // ============================================================

  Widget _buildCities() {
    return StreamBuilder<List<ServiceCountry>>(
      stream: _service.watchCountries(),
      builder: (context, countrySnapshot) {
        if (countrySnapshot.hasError) {
          return _emptyState('${countrySnapshot.error}');
        }

        if (!countrySnapshot.hasData) {
          return _loadingState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final country in countrySnapshot.data!)
              StreamBuilder<List<ServiceState>>(
                stream: _service.watchStates(
                  countryId: country.id,
                ),
                builder: (context, stateSnapshot) {
                  if (stateSnapshot.hasError ||
                      !stateSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      for (final state in stateSnapshot.data!)
                        StreamBuilder<List<ServiceCity>>(
                          stream: _service.watchCities(
                            countryId: country.id,
                            stateId: state.id,
                          ),
                          builder: (context, citySnapshot) {
                            if (citySnapshot.hasError ||
                                !citySnapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final cities = citySnapshot.data!
                                .where(
                                  (item) => _matches(
                                    '${item.id} ${item.name} '
                                    '${state.id} ${state.name} '
                                    '${country.id} ${country.name}',
                                  ),
                                )
                                .toList();

                            if (cities.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  '${state.name} · ${country.name}',
                                ),
                                for (final item in cities)
                                  _locationCard(
                                    title: item.name,
                                    subtitle:
                                        'ID: ${item.id}\n'
                                        'Legacy boundary points: '
                                        '${item.boundary.length}\n'
                                        'Legacy verified: '
                                        '${item.boundaryVerified ? "Yes" : "No"}\n'
                                        'Service: ${item.isServiceActive ? "Active" : "Inactive"}',
                                    active: item.isServiceActive,
                                    icon: Icons.location_city,
                                    onManageBoundary: () =>
                                        _manageBoundary(
                                      locationId: item.id,
                                      locationName: item.name,
                                      locationType: 'city',
                                    ),
                                    onToggle: (value) async {
                                      try {
                                        await _service
                                            .setCityServiceStatus(
                                          cityId: item.id,
                                          isActive: value,
                                        );

                                        _showMessage(
                                          value
                                              ? 'City service activated.'
                                              : 'City service deactivated.',
                                        );
                                      } catch (error) {
                                        await _showError(error);
                                      }
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // AREAS / SUB-DISTRICTS
  // ============================================================

  Widget _buildAreas() {
    return StreamBuilder<List<ServiceCity>>(
      stream: _service.watchCities(),
      builder: (context, citySnapshot) {
        if (citySnapshot.hasError) {
          return _emptyState('${citySnapshot.error}');
        }

        if (!citySnapshot.hasData) {
          return _loadingState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final city in citySnapshot.data!)
              StreamBuilder<List<ServiceArea>>(
                stream: _service.watchAreas(
                  cityId: city.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final areas = snapshot.data!
                      .where(
                        (item) => _matches(
                          '${item.id} ${item.name} '
                          '${city.id} ${city.name}',
                        ),
                      )
                      .toList();

                  if (areas.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(city.name),
                      for (final item in areas)
                        _locationCard(
                          title: item.name,
                          subtitle:
                              'ID: ${item.id}\n'
                              'City/District: ${city.name}\n'
                              'Legacy boundary points: '
                              '${item.boundary.length} · '
                              'Legacy verified: '
                              '${item.boundaryVerified ? "Yes" : "No"}\n'
                              'Service: ${item.isServiceActive ? "Active" : "Inactive"}',
                          active: item.isServiceActive,
                          icon: Icons.grid_view,
                          onManageBoundary: () =>
                              _manageBoundary(
                            locationId: item.id,
                            locationName: item.name,
                            locationType: 'area',
                          ),
                          onToggle: (value) async {
                            try {
                              await _service.setAreaServiceStatus(
                                areaId: item.id,
                                isActive: value,
                              );

                              _showMessage(
                                value
                                    ? 'Area service activated.'
                                    : 'Area service deactivated.',
                              );
                            } catch (error) {
                              await _showError(error);
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOCALITIES / VILLAGES
  // ============================================================

  Widget _buildLocalities() {
    return StreamBuilder<List<ServiceCity>>(
      stream: _service.watchCities(),
      builder: (context, citySnapshot) {
        if (citySnapshot.hasError) {
          return _emptyState('${citySnapshot.error}');
        }

        if (!citySnapshot.hasData) {
          return _loadingState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final city in citySnapshot.data!)
              StreamBuilder<List<ServiceArea>>(
                stream: _service.watchAreas(
                  cityId: city.id,
                ),
                builder: (context, areaSnapshot) {
                  if (areaSnapshot.hasError ||
                      !areaSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      for (final area in areaSnapshot.data!)
                        StreamBuilder<List<ServiceLocality>>(
                          stream: _service.watchLocalities(
                            cityId: city.id,
                            areaId: area.id,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasError ||
                                !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final items = snapshot.data!
                                .where(
                                  (item) => _matches(
                                    '${item.id} ${item.name} '
                                    '${item.pincode} ${item.areaId} '
                                    '${area.name} ${item.cityId} '
                                    '${city.name}',
                                  ),
                                )
                                .toList();

                            if (items.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  '${city.name} · ${area.name}',
                                ),
                                for (final item in items)
                                  _locationCard(
                                    title: item.name,
                                    subtitle:
                                        'ID: ${item.id}\n'
                                        '${city.name} · ${area.name}'
                                        '${item.pincode.isEmpty ? "" : " · PIN ${item.pincode}"}\n'
                                        'Legacy boundary: '
                                        '${item.boundaryVerified ? "Verified" : "Not verified"}\n'
                                        'Service: ${item.isServiceActive ? "Active" : "Inactive"}',
                                    active: item.isServiceActive,
                                    icon: Icons.place_outlined,
                                    onToggle: (value) async {
                                      try {
                                        await _service
                                            .setLocalityServiceStatus(
                                          localityId: item.id,
                                          isActive: value,
                                        );

                                        _showMessage(
                                          value
                                              ? 'Locality service activated.'
                                              : 'Locality service deactivated.',
                                        );
                                      } catch (error) {
                                        await _showError(error);
                                      }
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // READ-ONLY CSV PREVIEW
  // ============================================================

  Future<void> _showCsvPreviewDialog() async {
    final controller = TextEditingController();
    final parser = LocationCsvPreviewParser();
    LocationCsvPreview? preview;
    List<String> mappingReport = [];
    bool checkingParents = false;

    String normalizeLocationName(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    Future<void> checkParentMapping(StateSetter setDialogState) async {
      final currentPreview = preview;
      if (currentPreview == null || !currentPreview.canProceed) {
        setDialogState(() {
          mappingReport = ['Run a clean CSV validation before checking parents.'];
        });
        return;
      }

      setDialogState(() {
        checkingParents = true;
        mappingReport = [];
      });

      try {
        final states = await _service.watchStates().first;
        final cities = await _service.watchCities().first;
        final areas = await _service.watchAreas().first;
        final report = <String>[];
        var matched = 0;

        for (final row in currentPreview.rows) {
          final stateName = row.values['state'] ?? '';
          final cityName = row.values['city'] ?? '';
          final areaName = row.values['area'] ?? '';

          final stateMatches = states.where(
            (item) => normalizeLocationName(item.name) ==
                normalizeLocationName(stateName),
          ).toList();

          if (stateMatches.length != 1) {
            report.add(
              'Line ${row.lineNumber}: State "$stateName" '
              '${stateMatches.isEmpty ? 'not found' : 'is ambiguous'} '
              'in existing Service Locations.',
            );
            continue;
          }

          final state = stateMatches.single;
          final cityMatches = cities.where(
            (item) =>
                item.stateId == state.id &&
                normalizeLocationName(item.name) ==
                    normalizeLocationName(cityName),
          ).toList();

          if (cityMatches.length != 1) {
            report.add(
              'Line ${row.lineNumber}: City "$cityName" under '
              '$stateName ${cityMatches.isEmpty ? 'not found' : 'is ambiguous'}.',
            );
            continue;
          }

          final city = cityMatches.single;
          final areaMatches = areas.where(
            (item) =>
                item.cityId == city.id &&
                normalizeLocationName(item.name) ==
                    normalizeLocationName(areaName),
          ).toList();

          if (areaMatches.length != 1) {
            report.add(
              'Line ${row.lineNumber}: Area "$areaName" under '
              '$cityName ${areaMatches.isEmpty ? 'not found' : 'is ambiguous'}.',
            );
            continue;
          }

          matched++;
        }

        report.insert(
          0,
          'Existing State/City/Area name matches: $matched / ${currentPreview.rows.length} rows. District is not validated.',
        );
        report.insert(
          1,
          'Schema warning: CSV District "${currentPreview.rows.first.values['district']}" '
          'is not a separate level in the current Country → State → City → Area '
          'Firestore hierarchy. District-to-City mapping must be explicitly reviewed '
          'before import; this check never writes data.',
        );

        setDialogState(() {
          mappingReport = report;
        });
      } catch (error) {
        setDialogState(() {
          mappingReport = ['Could not read existing parent records: $error'];
        });
      } finally {
        setDialogState(() {
          checkingParents = false;
        });
      }
    }

    Future<void> pickCsvFile(StateSetter setDialogState) async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['csv'],
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;

        final file = result.files.single;
        final bytes = file.bytes;
        if (bytes == null) {
          throw const FormatException(
            'CSV file bytes are unavailable. Please try another file.',
          );
        }

        final contents = utf8.decode(bytes, allowMalformed: false);
        controller.text = contents;
        setDialogState(() {
          preview = parser.parse(contents);
        });
      } catch (error) {
        setDialogState(() {
          preview = LocationCsvPreview(
            headers: const [],
            rows: const [],
            fileErrors: ['Could not read selected CSV: $error'],
          );
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Preview location CSV'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste CSV text below. Required columns: State, District, City, Area. '
                    'This preview does not save or activate any locations.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => pickCsvFile(setDialogState),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Choose CSV file'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    minLines: 6,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: 'State,District,City,Area\n'
                          'Uttar Pradesh,Gautam Buddha Nagar,Greater Noida,Gaur City',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (preview != null) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Rows: ${preview!.rows.length}')),
                        Chip(label: Text('Valid: ${preview!.validRowCount}')),
                        Chip(label: Text('Invalid: ${preview!.invalidRowCount}')),
                      ],
                    ),
                    for (final error in preview!.fileErrors)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    for (final row in preview!.rows.take(20))
                      Card(
                        margin: const EdgeInsets.only(top: 6),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            row.isValid ? Icons.check_circle_outline : Icons.error_outline,
                            color: row.isValid ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            'Line ${row.lineNumber}: ${row.values['state']} · '
                            '${row.values['district']} · ${row.values['city']} · '
                            '${row.values['area']}',
                          ),
                          subtitle: row.errors.isEmpty
                              ? const Text('Validation passed')
                              : Text(row.errors.join('\n')),
                        ),
                      ),
                    if (preview!.rows.length > 20)
                      Text('Showing first 20 of ${preview!.rows.length} rows.'),
                    if (preview!.canProceed)
                      const Text(
                        'CSV checks passed. Parent mapping and explicit import confirmation are still required.',
                        style: TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: checkingParents
                          ? null
                          : () => checkParentMapping(setDialogState),
                      icon: checkingParents
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.account_tree_outlined),
                      label: Text(
                        checkingParents
                            ? 'Checking existing parents…'
                            : 'Check Existing Parent Mapping',
                      ),
                    ),
                    for (final line in mappingReport)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: line.startsWith('Existing State/City/Area name matches')
                                ? Colors.green.shade800
                                : Colors.deepOrange.shade800,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDialogState(() {
                controller.clear();
                preview = null;
              }),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () => setDialogState(() {
                preview = parser.parse(controller.text);
              }),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Validate CSV'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  // ============================================================
  // IMPORT HISTORY
  // ============================================================

  Widget _buildImports() {
    return StreamBuilder<List<ServiceLocationImport>>(
      stream: _service.watchImports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _emptyState(
            'Unable to load import history:\n${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return _loadingState();
        }

        final items = snapshot.data!
            .where(
              (item) => _matches(
                '${item.id} ${item.fileName} ${item.source} '
                '${item.status} ${item.verificationStatus}',
              ),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CSV Import Preview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Validate State, District, City and Area rows before any future import. '
                      'Preview only — no Firestore writes or activation.',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _showCsvPreviewDialog,
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('Paste CSV and Preview'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _locationOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No import history records found yet.'),
              ),
            for (final item in items)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.file_present, color: _locationOrange),
                  title: Text(item.fileName),
                  subtitle: Text(
                    'ID: ${item.id}\n'
                    'Source: ${item.source}\n'
                    'Status: ${item.status}\n'
                    'Verification: ${item.verificationStatus}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        );

      },
    );
  }

  // ============================================================
  // BOUNDARY MANAGEMENT
  // ============================================================

  Future<void> _manageBoundary({
    required String locationId,
    required String locationName,
    required String locationType,
  }) async {
    try {
      final boundaries = await _boundaryService
          .watchForLocation(
            locationId,
            locationType: locationType,
          )
          .first;

      if (!mounted) return;

      final verified = boundaries
          .where((boundary) => boundary.isVerified)
          .toList();

      final existing = verified.isNotEmpty
          ? verified.first
          : boundaries.isNotEmpty
              ? boundaries.first
              : null;

      final initialPoints = existing == null
          ? <LatLng>[]
          : existing.points
              .map(
                (point) => LatLng(
                  point.latitude,
                  point.longitude,
                ),
              )
              .toList();

      await _showBoundaryEditor(
        locationId: locationId,
        locationName: locationName,
        locationType: locationType,
        existingBoundary: existing,
        initialPoints: initialPoints,
      );
    } catch (error) {
      await _showError(error);
    }
  }

  Future<void> _showBoundaryEditor({
    required String locationId,
    required String locationName,
    required String locationType,
    required ServiceLocationBoundary? existingBoundary,
    required List<LatLng> initialPoints,
  }) async {
    final sourceNameController = TextEditingController(
      text: existingBoundary?.sourceName ?? '',
    );

    final sourceReferenceController = TextEditingController(
      text: existingBoundary?.sourceReference ?? '',
    );

    final notesController = TextEditingController();

    var sourceType = existingBoundary?.sourceType ??
        BoundarySourceType.manuallyDrawn;

    var currentPoints = List<LatLng>.of(initialPoints);
    var isSaving = false;

    final isVerified =
        existingBoundary?.verificationStatus ==
            BoundaryVerificationStatus.verified;

    final isRejected =
        existingBoundary?.verificationStatus ==
            BoundaryVerificationStatus.rejected;

    final isPending =
        existingBoundary?.verificationStatus ==
            BoundaryVerificationStatus.pending;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveBoundary(
                List<GeoPoint> points,
              ) async {
                if (isVerified) {
                  _showMessage(
                    'Verified Boundary read-only है।',
                  );
                  return;
                }

                if (isSaving) return;

                final sourceName =
                    sourceNameController.text.trim();

                final sourceReference =
                    sourceReferenceController.text.trim();

                if (sourceName.isEmpty ||
                    sourceReference.isEmpty) {
                  _showMessage(
                    'Source name और source reference भरें।',
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                try {
                  final now = DateTime.now();

                  final boundary = ServiceLocationBoundary(
                    id: existingBoundary?.id ?? '',
                    locationId: locationId,
                    locationType: locationType,
                    points: List<GeoPoint>.of(points),
                    sourceType: sourceType,
                    sourceName: sourceName,
                    sourceReference: sourceReference,
                    verificationStatus:
                        BoundaryVerificationStatus.pending,
                    verifiedBy: null,
                    verifiedAt: null,
                    verificationNotes: null,
                    createdAt:
                        existingBoundary?.createdAt ?? now,
                    updatedAt: now,
                  );

                  final errors = boundary.validate();

                  if (errors.isNotEmpty) {
                    throw ArgumentError(errors.join('\n'));
                  }

                  await _boundaryService.saveDraft(boundary);

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop();

                  _showMessage(
                    isRejected
                        ? 'Boundary के बदलाव सेव हो गए और Boundary Pending Review में भेज दी गई।'
                        : isPending
                            ? 'Boundary अपडेट हो गई। इसका status Pending Review है।'
                            : 'Boundary सेव हो गई और Pending Review में भेज दी गई।',
                  );
                } catch (error) {
                  if (dialogContext.mounted) {
                    setDialogState(() => isSaving = false);
                  }

                  await _showError(error);
                }
              }

              return AlertDialog(
                title: Text('Manage Boundary · $locationName'),
                content: SizedBox(
                  width: 900,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Location type: $locationType',
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _boundaryStatusBanner(existingBoundary),

                        const SizedBox(height: 12),

                        if (isRejected) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              'Previous rejection reason:\n'
                              '${existingBoundary?.verificationNotes?.trim().isNotEmpty == true ? existingBoundary!.verificationNotes : "No rejection reason recorded."}',
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (!isVerified) ...[
                          DropdownButtonFormField<BoundarySourceType>(
                            initialValue: sourceType,
                            decoration: const InputDecoration(
                              labelText: 'Boundary source type',
                              border: OutlineInputBorder(),
                            ),
                            items: BoundarySourceType.values
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      _sourceTypeLabel(type),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setDialogState(() {
                                sourceType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: sourceNameController,
                            decoration: const InputDecoration(
                              labelText: 'Source name *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: sourceReferenceController,
                            decoration: const InputDecoration(
                              labelText: 'Source reference *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Save करने पर Boundary Pending Review में जाएगी।',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        ServiceBoundaryEditor(
                          initialPoints: currentPoints,
                          initialCenter: _defaultMapCenter,
                          initialZoom: 12,
                          readOnly: isVerified,
                          onBoundaryChanged: (points) {
                            currentPoints = List<LatLng>.of(points);
                          },
                          onSaveRequested: saveBoundary,
                        ),

                        if (existingBoundary != null) ...[
                          const SizedBox(height: 16),
                          _boundaryDetails(existingBoundary),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (isRejected &&
                      existingBoundary != null &&
                      existingBoundary.id.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              try {
                                final latest =
                                    await _boundaryService.getById(
                                  existingBoundary.id,
                                );

                                if (latest == null) {
                                  throw StateError(
                                    'Boundary नहीं मिली।',
                                  );
                                }

                                if (latest.verificationStatus !=
                                    BoundaryVerificationStatus.rejected) {
                                  throw StateError(
                                    'Boundary अब Rejected status में नहीं है।',
                                  );
                                }

                                if (!dialogContext.mounted) return;

                                final confirmed =
                                    await _confirmResubmit(
                                  locationName,
                                );

                                if (confirmed != true) return;

                                await _boundaryService
                                    .requestVerification(latest.id);

                                if (!dialogContext.mounted) return;

                                Navigator.of(dialogContext).pop();

                                _showMessage(
                                  'Boundary Review के लिए भेज दी गई।',
                                );
                              } catch (error) {
                                await _showError(error);
                              }
                            },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Resubmit for Review'),
                    ),

                  if (isPending && existingBoundary != null)
                    TextButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              try {
                                final latest =
                                    await _boundaryService.getById(
                                  existingBoundary.id,
                                );

                                if (latest == null ||
                                    latest.verificationStatus !=
                                        BoundaryVerificationStatus.pending) {
                                  throw StateError(
                                    'केवल Pending Boundary को Reject किया जा सकता है।',
                                  );
                                }

                                if (!dialogContext.mounted) return;

                                final reason =
                                    await _askForReviewNotes(
                                  approve: false,
                                );

                                if (reason == null) return;

                                await _boundaryService.rejectBoundary(
                                  boundaryId: latest.id,
                                  reason: reason,
                                );

                                if (!dialogContext.mounted) return;

                                Navigator.of(dialogContext).pop();

                                _showMessage(
                                  'Boundary Reject कर दी गई।',
                                );
                              } catch (error) {
                                await _showError(error);
                              }
                            },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  if (isPending && existingBoundary != null)
                    FilledButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              try {
                                final latest =
                                    await _boundaryService.getById(
                                  existingBoundary.id,
                                );

                                if (latest == null ||
                                    latest.verificationStatus !=
                                        BoundaryVerificationStatus.pending) {
                                  throw StateError(
                                    'केवल Pending Boundary Verify हो सकती है।',
                                  );
                                }

                                final errors = latest.validate();

                                if (errors.isNotEmpty) {
                                  throw StateError(
                                    errors.join('\n'),
                                  );
                                }

                                if (!dialogContext.mounted) return;

                                final notes =
                                    await _askForReviewNotes(
                                  approve: true,
                                );

                                if (notes == null) return;

                                await _boundaryService.markVerified(
                                  boundaryId: latest.id,
                                  verificationNotes: notes,
                                );

                                if (!dialogContext.mounted) return;

                                Navigator.of(dialogContext).pop();

                                _showMessage(
                                  'Boundary Verified हो गई। Service activation अलग से होगी।',
                                );
                              } catch (error) {
                                await _showError(error);
                              }
                            },
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Verify'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),

                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      sourceNameController.dispose();
      sourceReferenceController.dispose();
      notesController.dispose();
    }
  }

  Future<bool?> _confirmResubmit(String locationName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resubmit Boundary?'),
        content: Text(
          '$locationName की Boundary Review में भेजी जाएगी। '
          'क्या आपने polygon और source details जाँच लिए हैं?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOUNDARY STATUS
  // ============================================================

  Widget _boundaryStatusBanner(
    ServiceLocationBoundary? boundary,
  ) {
    if (boundary == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'नई Boundary बनाएँ और source details भरें। '
          'Save करने पर वह Pending Review में जाएगी।',
        ),
      );
    }

    final status = boundary.verificationStatus;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (status) {
      case BoundaryVerificationStatus.notAvailable:
        statusColor = Colors.grey;
        statusLabel = 'Not available';
        statusIcon = Icons.help_outline;
        break;

      case BoundaryVerificationStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'Pending review';
        statusIcon = Icons.hourglass_top;
        break;

      case BoundaryVerificationStatus.verified:
        statusColor = Colors.green;
        statusLabel = 'Verified';
        statusIcon = Icons.verified;
        break;

      case BoundaryVerificationStatus.rejected:
        statusColor = Colors.red;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Boundary ID: ${boundary.id}'),
          Text('Vertices: ${boundary.points.length}'),
          Text('Source: ${boundary.sourceName}'),
          if (boundary.verificationNotes != null &&
              boundary.verificationNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              status == BoundaryVerificationStatus.rejected
                  ? 'Rejection reason: ${boundary.verificationNotes}'
                  : 'Review notes: ${boundary.verificationNotes}',
            ),
          ],
          if (boundary.verifiedBy != null)
            Text('Reviewer UID: ${boundary.verifiedBy}'),
          if (boundary.verifiedAt != null)
            Text(
              'Reviewed: ${boundary.verifiedAt!.toLocal()}',
            ),
          if (boundary.isVerified) ...[
            const SizedBox(height: 8),
            const Text(
              'Verified Boundary read-only है।',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _boundaryDetails(
    ServiceLocationBoundary boundary,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boundary review information',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Source type: ${_sourceTypeLabel(boundary.sourceType)}',
          ),
          Text('Source name: ${boundary.sourceName}'),
          Text('Source reference: ${boundary.sourceReference}'),
          Text('Status: ${boundary.verificationStatus.name}'),
          if (boundary.verificationNotes != null &&
              boundary.verificationNotes!.isNotEmpty)
            Text('Notes: ${boundary.verificationNotes}'),
        ],
      ),
    );
  }

  Future<String?> _askForReviewNotes({
    required bool approve,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            approve ? 'Verify Boundary' : 'Reject Boundary',
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  approve
                      ? 'Source और polygon जाँचने के बाद verification notes लिखें।'
                      : 'Boundary Reject करने का स्पष्ट कारण लिखें।',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: approve
                        ? 'Verification notes *'
                        : 'Rejection reason *',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red,
              ),
              onPressed: () {
                final notes = controller.text.trim();

                if (notes.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'कृपया टिप्पणी या कारण लिखें।',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, notes);
              },
              child: Text(approve ? 'Verify' : 'Reject'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _sourceTypeLabel(BoundarySourceType type) {
    switch (type) {
      case BoundarySourceType.governmentGis:
        return 'Government GIS';
      case BoundarySourceType.governmentCadastralMap:
        return 'Government cadastral map';
      case BoundarySourceType.importedGeoJson:
        return 'Imported GeoJSON';
      case BoundarySourceType.manuallyDrawn:
        return 'Manually drawn';
    }
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _locationOrange,
          ),
        ),
      ),
    );
  }

  Widget _locationCard({
    required String title,
    required String subtitle,
    required bool active,
    required IconData icon,
    required ValueChanged<bool> onToggle,
    VoidCallback? onManageBoundary,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              _locationOrange.withValues(alpha: 0.12),
          child: Icon(icon, color: _locationOrange),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        isThreeLine: subtitle.contains('\n'),
        trailing: SizedBox(
          width: onManageBoundary == null ? 65 : 190,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onManageBoundary != null)
                IconButton(
                  tooltip: 'Manage Boundary',
                  onPressed: onManageBoundary,
                  icon: const Icon(
                    Icons.edit_location_alt_outlined,
                    color: _locationOrange,
                  ),
                ),
              Switch(
                value: active,
                activeThumbColor: _locationOrange,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD LOCATION
  // ============================================================

  Future<void> _showAddLocationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddLocationDialog(
        service: _service,
        onSaved: (tab) {
          if (!mounted) return;

          setState(() => _selectedTab = tab);
          _showMessage('Location saved successfully.');
        },
      ),
    );
  }
}
