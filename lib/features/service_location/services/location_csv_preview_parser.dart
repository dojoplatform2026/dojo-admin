/// Read-only CSV preview parser for the Service Location import workflow.
///
/// This file deliberately has no Firebase dependency and performs no writes.
/// Expected header columns are State, District, City, and Area. Header matching
/// is case-insensitive and ignores spaces, underscores, and hyphens.
class LocationCsvRow {
  final int lineNumber;
  final Map<String, String> values;
  final List<String> errors;

  const LocationCsvRow({
    required this.lineNumber,
    required this.values,
    required this.errors,
  });

  bool get isValid => errors.isEmpty;
}

class LocationCsvPreview {
  final List<String> headers;
  final List<LocationCsvRow> rows;
  final List<String> fileErrors;

  const LocationCsvPreview({
    required this.headers,
    required this.rows,
    required this.fileErrors,
  });

  int get validRowCount => rows.where((row) => row.isValid).length;
  int get invalidRowCount => rows.length - validRowCount;
  bool get canProceed => fileErrors.isEmpty && rows.isNotEmpty && invalidRowCount == 0;
}

class LocationCsvPreviewParser {
  static const requiredHeaders = <String>[
    'state',
    'district',
    'city',
    'area',
  ];

  static String _normalizeHeader(String value) => value
      .replaceAll('\uFEFF', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[ _-]+'), '');

  LocationCsvPreview parse(String input) {
    final source = input.replaceFirst('\uFEFF', '');
    if (source.trim().isEmpty) {
      return const LocationCsvPreview(
        headers: [],
        rows: [],
        fileErrors: ['CSV file is empty.'],
      );
    }

    final parsed = _parseRecords(source);
    if (parsed.error != null) {
      return LocationCsvPreview(
        headers: const [],
        rows: const [],
        fileErrors: [parsed.error!],
      );
    }
    final records = parsed.records;
    if (records.isEmpty) {
      return const LocationCsvPreview(
        headers: [],
        rows: [],
        fileErrors: ['CSV file has no header row.'],
      );
    }

    final headers = records.first.map((value) => value.trim()).toList();
    final normalized = headers.map(_normalizeHeader).toList();
    final fileErrors = <String>[];
    if (normalized.any((header) => header.isEmpty)) {
      fileErrors.add('Header row contains an empty column name.');
    }
    if (normalized.toSet().length != normalized.length) {
      fileErrors.add('Header row contains duplicate column names.');
    }
    for (final required in requiredHeaders) {
      if (!normalized.contains(required)) {
        fileErrors.add('Required column missing: ${required.toUpperCase()}.');
      }
    }
    if (fileErrors.isNotEmpty) {
      return LocationCsvPreview(
        headers: headers,
        rows: const [],
        fileErrors: fileErrors,
      );
    }

    final indexes = <String, int>{
      for (var i = 0; i < normalized.length; i++) normalized[i]: i,
    };
    final seen = <String>{};
    final rows = <LocationCsvRow>[];
    for (var i = 1; i < records.length; i++) {
      final values = records[i];
      if (values.length == 1 && values.first.trim().isEmpty) continue;
      final errors = <String>[];
      if (values.length != headers.length) {
        errors.add('Expected ${headers.length} columns but found ${values.length}.');
      }
      final mapped = <String, String>{};
      for (final required in requiredHeaders) {
        final index = indexes[required]!;
        final value = index < values.length ? values[index].trim() : '';
        mapped[required] = value;
        if (value.isEmpty) {
          errors.add('Required value missing: ${required.toUpperCase()}.');
        }
      }
      final duplicateKey = requiredHeaders
          .map((header) => mapped[header]!.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
          .join('|');
      if (!seen.add(duplicateKey)) {
        errors.add('Duplicate State/District/City/Area combination in this file.');
      }
      rows.add(LocationCsvRow(
        lineNumber: i + 1,
        values: mapped,
        errors: errors,
      ));
    }
    if (rows.isEmpty) {
      fileErrors.add('CSV has a header but no data rows.');
    }
    return LocationCsvPreview(headers: headers, rows: rows, fileErrors: fileErrors);
  }

  _CsvParseResult _parseRecords(String source) {
    final records = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    var afterQuote = false;
    var recordNumber = 1;

    void finishField() {
      row.add(field.toString());
      field.clear();
      afterQuote = false;
    }

    void finishRecord() {
      finishField();
      records.add(row);
      row = <String>[];
      recordNumber++;
    }

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            afterQuote = true;
          }
        } else {
          field.write(char);
        }
        continue;
      }
      if (afterQuote && char != ',' && char != '\n' && char != '\r' && char.trim().isNotEmpty) {
        return _CsvParseResult([], 'Malformed CSV near record $recordNumber: unexpected text after a closing quote.');
      }
      if (char == '"' && field.isEmpty && !afterQuote) {
        quoted = true;
      } else if (char == '"') {
        return _CsvParseResult(
          [],
          'Malformed CSV near record $recordNumber: a quote must begin a field.',
        );
      } else if (char == ',') {
        finishField();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
        finishRecord();
      } else {
        field.write(char);
      }
    }
    if (quoted) {
      return _CsvParseResult([], 'Malformed CSV: an opening quote was not closed.');
    }
    if (field.isNotEmpty || row.isNotEmpty || afterQuote) finishRecord();
    return _CsvParseResult(records, null);
  }
}

class _CsvParseResult {
  final List<List<String>> records;
  final String? error;
  const _CsvParseResult(this.records, this.error);
}
