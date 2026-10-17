import 'package:flutter_test/flutter_test.dart';
import 'package:dojo_admin/features/service_location/services/location_csv_preview_parser.dart';

void main() {
  group('LocationCsvPreviewParser', () {
    final parser = LocationCsvPreviewParser();

    test('accepts required columns case-insensitively and counts valid rows', () {
      final result = parser.parse(
        'State,District,City,Area\nUttar Pradesh,Gautam Buddha Nagar,Greater Noida,Gaur City',
      );
      expect(result.fileErrors, isEmpty);
      expect(result.validRowCount, 1);
      expect(result.invalidRowCount, 0);
      expect(result.canProceed, isTrue);
    });

    test('supports quoted commas and escaped quotes', () {
      final result = parser.parse(
        'State,District,City,Area\nUttar Pradesh,Gautam Buddha Nagar,"Greater Noida, West","Area ""A"""',
      );
      expect(result.rows.single.values['city'], 'Greater Noida, West');
      expect(result.rows.single.values['area'], 'Area "A"');
      expect(result.canProceed, isTrue);
    });

    test('reports missing headers without producing rows', () {
      final result = parser.parse('State,City,Area\nUP,Noida,Sector 1');
      expect(result.fileErrors, contains('Required column missing: DISTRICT.'));
      expect(result.rows, isEmpty);
      expect(result.canProceed, isFalse);
    });

    test('reports missing cells, wrong field counts, and duplicate combinations', () {
      final result = parser.parse(
        'State,District,City,Area\nUP,GBN,Noida,\nUP,GBN,Noida,Sector 1\nUP,GBN,Noida,Sector 1,Extra',
      );
      expect(result.invalidRowCount, 2);
      expect(result.rows[0].errors, contains('Required value missing: AREA.'));
      expect(result.rows[2].errors, contains('Expected 4 columns but found 5.'));
      expect(result.rows[2].errors, contains('Duplicate State/District/City/Area combination in this file.'));
      expect(result.canProceed, isFalse);
    });

    test('rejects duplicate and empty headers', () {
      final duplicate = parser.parse('State,STATE,District,City,Area\na,b,c,d,e');
      expect(duplicate.fileErrors, contains('Header row contains duplicate column names.'));
      final empty = parser.parse('State,,District,City,Area\na,b,c,d,e');
      expect(empty.fileErrors, contains('Header row contains an empty column name.'));
    });

    test('rejects a quote inside an unquoted field', () {
      final result = parser.parse(
        'State,District,City,Area\nUP,GB"N,Noida,Sector 1',
      );
      expect(
        result.fileErrors,
        contains(
          'Malformed CSV near record 2: a quote must begin a field.',
        ),
      );
      expect(result.rows, isEmpty);
      expect(result.canProceed, isFalse);
    });

    test('rejects empty and malformed CSV input', () {
      expect(parser.parse('  ').fileErrors, contains('CSV file is empty.'));
      expect(
        parser.parse('State,District,City,Area\n"UP,GBN,Noida,Area').fileErrors,
        contains('Malformed CSV: an opening quote was not closed.'),
      );
    });
  });
}
