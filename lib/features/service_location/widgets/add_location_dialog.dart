import 'package:flutter/material.dart';

import '../../../data/reference/india_locations/india_districts.dart';
import '../../../data/reference/india_locations/india_location_filters.dart';
import '../../../data/reference/india_locations/india_states.dart';
import '../../../data/reference/india_locations/india_sub_districts.dart';
import '../models/service_location_models.dart';
import '../services/service_location_service.dart';

const Color _addLocationOrange = Color(0xFFFF7900);

class AddLocationDialog extends StatefulWidget {
  const AddLocationDialog({
    super.key,
    required this.service,
    required this.onSaved,
  });

  final ServiceLocationService service;
  final ValueChanged<int> onSaved;

  @override
  State<AddLocationDialog> createState() =>
      _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _pincodeController = TextEditingController();

  int _level = 0;

  String? _countryId;
  String? _stateId;
  String? _cityId;
  String? _areaId;
  IndiaState? _referenceState;
  IndiaDistrict? _referenceDistrict;
  IndiaSubDistrict? _referenceSubDistrict;

  bool _saving = false;

  static const List<String> _locationTypes = [
    'Country',
    'State',
    'City / District',
    'Area / Sub-district',
    'Locality / Village',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  String get _levelName => _locationTypes[_level];

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();

      switch (_level) {
        case 0:
          await widget.service.saveCountry(
            ServiceCountry(
              name: name,
              code: _codeController.text.trim().toUpperCase(),
              isActive: false,
            ),
          );
          break;

        case 1:
          await widget.service.saveState(
            ServiceState(
              countryId: _countryId!,
              name: name,
              lgdCode: _referenceState?.lgdCode,
              isActive: false,
            ),
          );
          break;

        case 2:
          await widget.service.saveCity(
            ServiceCity(
              countryId: _countryId!,
              stateId: _stateId!,
              name: name,
              lgdCode: _referenceDistrict?.districtCode,
              isServiceActive: false,
            ),
          );
          break;

        case 3:
          final city = await widget.service.getCity(_cityId!);

          if (city == null) {
            throw StateError(
              'Selected city/district no longer exists.',
            );
          }

          await widget.service.saveArea(
            ServiceArea(
              countryId: city.countryId,
              stateId: city.stateId,
              cityId: city.id,
              name: name,
              lgdCode: _referenceSubDistrict?.code,
              isServiceActive: false,
            ),
          );
          break;

        case 4:
          final city = await widget.service.getCity(_cityId!);

          if (city == null) {
            throw StateError(
              'Selected city/district no longer exists.',
            );
          }

          await widget.service.saveLocality(
            ServiceLocality(
              countryId: city.countryId,
              stateId: city.stateId,
              cityId: city.id,
              areaId: _areaId!,
              name: name,
              pincode: _pincodeController.text.trim(),
              isServiceActive: false,
            ),
          );
          break;
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onSaved(_level);
    } catch (error) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unable to save location'),
          content: SelectableText(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: items,
        onChanged: _saving ? null : onChanged,
        validator: (value) =>
            value == null ? 'Please select $label' : null,
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return StreamBuilder<List<ServiceCountry>>(
      stream: widget.service.watchCountries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _dropdown<String>(
            label: 'Country',
            value: null,
            items: const [],
            onChanged: (_) {},
          );
        }

        final countries = snapshot.data ?? [];

        return _dropdown<String>(
          label: 'Country',
          value: _countryId,
          items: countries
              .map(
                (country) => DropdownMenuItem<String>(
                  value: country.id,
                  child: Text(
                    '${country.name} (${country.code})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _countryId = value;
              _stateId = null;
              _cityId = null;
              _areaId = null;
              _referenceDistrict = null;
              _referenceSubDistrict = null;
            });
          },
        );
      },
    );
  }

  Widget _buildIndiaReferenceStateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: _referenceState?.lgdCode,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'India State / UT reference',
          helperText: 'Select a reference record; verify source data before production use.',
          border: OutlineInputBorder(),
        ),
        items: indiaStates
            .map(
              (state) => DropdownMenuItem<int>(
                value: state.lgdCode,
                child: Text(state.displayName),
              ),
            )
            .toList(growable: false),
        onChanged: _saving
            ? null
            : (code) {
                if (code == null) return;
                final selected = indiaStates.firstWhere(
                  (state) => state.lgdCode == code,
                );
                setState(() {
                  _referenceState = selected;
                  _nameController.text = selected.name;
                });
              },
      ),
    );
  }

  Widget _buildStateDropdown() {
    if (_countryId == null) {
      return _dropdown<String>(
        label: 'State',
        value: null,
        items: const [],
        onChanged: (_) {},
      );
    }

    return StreamBuilder<List<ServiceState>>(
      stream: widget.service.watchStates(countryId: _countryId!),
      builder: (context, snapshot) {
        final states = snapshot.data ?? [];

        return _dropdown<String>(
          label: 'State',
          value: _stateId,
          items: states
              .map(
                (state) => DropdownMenuItem<String>(
                  value: state.id,
                  child: Text(state.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _stateId = value;
              _cityId = null;
              _areaId = null;
              _referenceDistrict = null;
              _referenceSubDistrict = null;
            });
          },
        );
      },
    );
  }

  Widget _buildIndiaReferenceDistrictDropdown() {
    if (_countryId == null || _stateId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<ServiceState>>(
      stream: widget.service.watchStates(countryId: _countryId!),
      builder: (context, snapshot) {
        final states = snapshot.data ?? [];
        final matchingStates = states.where((state) => state.id == _stateId);
        if (matchingStates.isEmpty || matchingStates.first.lgdCode == null) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'District reference list requires a State selected from the India reference list. You can still enter the name manually.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          );
        }

        final districts = filterDistrictsForStateLgdCode(
          matchingStates.first.lgdCode!,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _referenceDistrict?.districtCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'India District reference (optional)',
              helperText: 'Filtered by the selected State / UT.',
              border: OutlineInputBorder(),
            ),
            items: districts
                .map(
                  (district) => DropdownMenuItem<String>(
                    value: district.districtCode,
                    child: Text(district.districtName),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (code) {
                    if (code == null) return;
                    final selected = districts.firstWhere(
                      (district) => district.districtCode == code,
                    );
                    setState(() {
                      _referenceDistrict = selected;
                      _nameController.text = selected.districtName;
                    });
                  },
          ),
        );
      },
    );
  }

  Widget _buildCityDropdown() {
    if (_countryId == null || _stateId == null) {
      return _dropdown<String>(
        label: 'City / District',
        value: null,
        items: const [],
        onChanged: (_) {},
      );
    }

    return StreamBuilder<List<ServiceCity>>(
      stream: widget.service.watchCities(
        countryId: _countryId,
        stateId: _stateId,
      ),
      builder: (context, snapshot) {
        final cities = snapshot.data ?? [];

        return _dropdown<String>(
          label: 'City / District',
          value: _cityId,
          items: cities
              .map(
                (city) => DropdownMenuItem<String>(
                  value: city.id,
                  child: Text(city.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _cityId = value;
              _areaId = null;
              _referenceSubDistrict = null;
            });
          },
        );
      },
    );
  }

  Widget _buildIndiaReferenceSubDistrictDropdown() {
    if (_cityId == null) return const SizedBox.shrink();

    return FutureBuilder<ServiceCity?>(
      future: widget.service.getCity(_cityId!),
      builder: (context, citySnapshot) {
        final city = citySnapshot.data;
        if (city == null || citySnapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sub-district reference list needs a saved District with an LGD code. Manual entry remains available.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          );
        }

        return StreamBuilder<List<ServiceState>>(
          stream: widget.service.watchStates(countryId: city.countryId),
          builder: (context, stateSnapshot) {
            final matching = (stateSnapshot.data ?? [])
                .where((state) => state.id == city.stateId);
            if (matching.isEmpty ||
                matching.first.lgdCode == null ||
                city.lgdCode == null ||
                city.lgdCode!.trim().isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sub-district reference list needs LGD codes on both the selected State and District. Manual entry remains available.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              );
            }

            final subDistricts = filterSubDistrictsForStateAndDistrict(
              stateLgdCode: matching.first.lgdCode!,
              districtLgdCode: city.lgdCode!,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _referenceSubDistrict?.code,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'India Sub-district reference (optional)',
                  helperText: 'Filtered by both State and District LGD codes.',
                  border: OutlineInputBorder(),
                ),
                items: subDistricts
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.code,
                        child: Text(item.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (code) {
                        if (code == null) return;
                        final selected = subDistricts.firstWhere(
                          (item) => item.code == code,
                        );
                        setState(() {
                          _referenceSubDistrict = selected;
                          _nameController.text = selected.name;
                        });
                      },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAreaDropdown() {
    if (_cityId == null) {
      return _dropdown<String>(
        label: 'Area / Sub-district',
        value: null,
        items: const [],
        onChanged: (_) {},
      );
    }

    return StreamBuilder<List<ServiceArea>>(
      stream: widget.service.watchAreas(cityId: _cityId!),
      builder: (context, snapshot) {
        final areas = snapshot.data ?? [];

        return _dropdown<String>(
          label: 'Area / Sub-district',
          value: _areaId,
          items: areas
              .map(
                (area) => DropdownMenuItem<String>(
                  value: area.id,
                  child: Text(area.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _areaId = value);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Location'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _level,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Location type',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    _locationTypes.length,
                    (index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text(_locationTypes[index]),
                    ),
                  ),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _level = value;
                            _countryId = null;
                            _stateId = null;
                            _cityId = null;
                            _areaId = null;
                            _referenceState = null;
                            _referenceDistrict = null;
                            _referenceSubDistrict = null;

                            _nameController.clear();
                            _codeController.clear();
                            _pincodeController.clear();
                          });
                        },
                ),

                const SizedBox(height: 12),

                if (_level >= 1) _buildCountryDropdown(),

                if (_level == 1) _buildIndiaReferenceStateDropdown(),

                if (_level >= 2) _buildStateDropdown(),

                if (_level == 2) _buildIndiaReferenceDistrictDropdown(),

                if (_level == 3) _buildIndiaReferenceSubDistrictDropdown(),

                if (_level >= 3) _buildCityDropdown(),

                if (_level >= 4) _buildAreaDropdown(),

                const SizedBox(height: 4),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '$_levelName name',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter $_levelName name';
                    }
                    return null;
                  },
                ),

                if (_level == 0) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Country code (e.g. IN)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter country code';
                      }
                      return null;
                    },
                  ),
                ],

                if (_level == 4) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN code (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This location will be saved as inactive. '
                    'City, Area and Locality require a verified '
                    'geographic boundary before activation. '
                    'This form does not verify geographic boundaries.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(
            _saving ? 'Saving...' : 'Save Location',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _addLocationOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
