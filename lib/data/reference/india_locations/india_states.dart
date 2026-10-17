/// DOJO WALK Admin — India States and Union Territories reference data.
/// Source: user-provided LGD district CSV (state fields deduplicated).
/// LGD codes are integers; Census 2011 codes remain Strings to preserve leading zeroes.
/// Note: localName and census2011Code preserve source values exactly. Some source local names
/// are uppercase English text, and values such as "00" or "NA" are source placeholders.

class IndiaState {
  final int lgdCode;
  final String name;
  final String localName;
  final String stateOrUT;
  final String census2011Code;

  const IndiaState({
    required this.lgdCode,
    required this.name,
    required this.localName,
    required this.stateOrUT,
    required this.census2011Code,
  });

  bool get isUnionTerritory => stateOrUT == 'Union Territory';
  String get displayName => localName.isNotEmpty && localName != name.toUpperCase()
      ? '$name ($localName)'
      : name;
}

/// Complete list: 28 States and 8 Union Territories.
const List<IndiaState> indiaStates = <IndiaState>[
  IndiaState(
    lgdCode: 1,
    name: 'Jammu And Kashmir',
    localName: 'JAMMU AND KASHMIR',
    stateOrUT: 'Union Territory',
    census2011Code: '01',
  ),
  IndiaState(
    lgdCode: 2,
    name: 'Himachal Pradesh',
    localName: 'HIMACHAL PRADESH',
    stateOrUT: 'State',
    census2011Code: '02',
  ),
  IndiaState(
    lgdCode: 3,
    name: 'Punjab',
    localName: 'PUNJAB',
    stateOrUT: 'State',
    census2011Code: '03',
  ),
  IndiaState(
    lgdCode: 4,
    name: 'Chandigarh',
    localName: 'CHANDIGARH',
    stateOrUT: 'Union Territory',
    census2011Code: '04',
  ),
  IndiaState(
    lgdCode: 5,
    name: 'Uttarakhand',
    localName: 'UTTARAKHAND',
    stateOrUT: 'State',
    census2011Code: '05',
  ),
  IndiaState(
    lgdCode: 6,
    name: 'Haryana',
    localName: 'HARYANA',
    stateOrUT: 'State',
    census2011Code: '06',
  ),
  IndiaState(
    lgdCode: 7,
    name: 'Delhi',
    localName: 'DELHI',
    stateOrUT: 'Union Territory',
    census2011Code: '07',
  ),
  IndiaState(
    lgdCode: 8,
    name: 'Rajasthan',
    localName: 'RAJASTHAN',
    stateOrUT: 'State',
    census2011Code: '08',
  ),
  IndiaState(
    lgdCode: 9,
    name: 'Uttar Pradesh',
    localName: 'UTTAR PRADESH',
    stateOrUT: 'State',
    census2011Code: '09',
  ),
  IndiaState(
    lgdCode: 10,
    name: 'Bihar',
    localName: 'BIHAR',
    stateOrUT: 'State',
    census2011Code: '10',
  ),
  IndiaState(
    lgdCode: 11,
    name: 'Sikkim',
    localName: 'SIKKIM',
    stateOrUT: 'State',
    census2011Code: '11',
  ),
  IndiaState(
    lgdCode: 12,
    name: 'Arunachal Pradesh',
    localName: 'ARUNACHAL PRADESH',
    stateOrUT: 'State',
    census2011Code: '12',
  ),
  IndiaState(
    lgdCode: 13,
    name: 'Nagaland',
    localName: 'NAGALAND',
    stateOrUT: 'State',
    census2011Code: '13',
  ),
  IndiaState(
    lgdCode: 14,
    name: 'Manipur',
    localName: 'MANIPUR',
    stateOrUT: 'State',
    census2011Code: '14',
  ),
  IndiaState(
    lgdCode: 15,
    name: 'Mizoram',
    localName: 'MIZORAM',
    stateOrUT: 'State',
    census2011Code: '15',
  ),
  IndiaState(
    lgdCode: 16,
    name: 'Tripura',
    localName: 'ত্রিপুরা',
    stateOrUT: 'State',
    census2011Code: '16',
  ),
  IndiaState(
    lgdCode: 17,
    name: 'Meghalaya',
    localName: 'MEGHALAYA',
    stateOrUT: 'State',
    census2011Code: '17',
  ),
  IndiaState(
    lgdCode: 18,
    name: 'Assam',
    localName: 'ASSAM',
    stateOrUT: 'State',
    census2011Code: '18',
  ),
  IndiaState(
    lgdCode: 19,
    name: 'West Bengal',
    localName: 'WEST BENGAL',
    stateOrUT: 'State',
    census2011Code: '19',
  ),
  IndiaState(
    lgdCode: 20,
    name: 'Jharkhand',
    localName: 'झारखंड',
    stateOrUT: 'State',
    census2011Code: '20',
  ),
  IndiaState(
    lgdCode: 21,
    name: 'Odisha',
    localName: 'ODISHA',
    stateOrUT: 'State',
    census2011Code: '21',
  ),
  IndiaState(
    lgdCode: 22,
    name: 'Chhattisgarh',
    localName: 'छत्तीसगढ़',
    stateOrUT: 'State',
    census2011Code: '22',
  ),
  IndiaState(
    lgdCode: 23,
    name: 'Madhya Pradesh',
    localName: 'MADHYA PRADESH',
    stateOrUT: 'State',
    census2011Code: '23',
  ),
  IndiaState(
    lgdCode: 24,
    name: 'Gujarat',
    localName: 'GUJARAT',
    stateOrUT: 'State',
    census2011Code: '24',
  ),
  IndiaState(
    lgdCode: 27,
    name: 'Maharashtra',
    localName: 'महाराष्ट्र',
    stateOrUT: 'State',
    census2011Code: '27',
  ),
  IndiaState(
    lgdCode: 28,
    name: 'Andhra Pradesh',
    localName: 'ANDHRA PRADESH',
    stateOrUT: 'State',
    census2011Code: '28',
  ),
  IndiaState(
    lgdCode: 29,
    name: 'Karnataka',
    localName: 'ಕರ್ನಾಟಕ',
    stateOrUT: 'State',
    census2011Code: '29',
  ),
  IndiaState(
    lgdCode: 30,
    name: 'Goa',
    localName: 'GOA',
    stateOrUT: 'State',
    census2011Code: '30',
  ),
  IndiaState(
    lgdCode: 31,
    name: 'Lakshadweep',
    localName: 'LAKSHADWEEP',
    stateOrUT: 'Union Territory',
    census2011Code: '31',
  ),
  IndiaState(
    lgdCode: 32,
    name: 'Kerala',
    localName: 'KERALA',
    stateOrUT: 'State',
    census2011Code: '32',
  ),
  IndiaState(
    lgdCode: 33,
    name: 'Tamil Nadu',
    localName: 'TAMIL NADU',
    stateOrUT: 'State',
    census2011Code: '33',
  ),
  IndiaState(
    lgdCode: 34,
    name: 'Puducherry',
    localName: 'PUDUCHERRY',
    stateOrUT: 'Union Territory',
    census2011Code: '34',
  ),
  IndiaState(
    lgdCode: 35,
    name: 'Andaman And Nicobar Islands',
    localName: 'ANDAMAN AND NICOBAR ISLANDS',
    stateOrUT: 'Union Territory',
    census2011Code: '35',
  ),
  IndiaState(
    lgdCode: 36,
    name: 'Telangana',
    localName: 'తెలంగాణ',
    stateOrUT: 'State',
    census2011Code: '00',
  ),
  IndiaState(
    lgdCode: 37,
    name: 'Ladakh',
    localName: 'Ladakh',
    stateOrUT: 'Union Territory',
    census2011Code: '00',
  ),
  IndiaState(
    lgdCode: 38,
    name: 'The Dadra And Nagar Haveli And Daman And Diu',
    localName: 'THE DADRA AND NAGAR HAVELI AND DAMAN AND DIU',
    stateOrUT: 'Union Territory',
    census2011Code: 'NA',
  ),
];

/// Finds a state/UT by its LGD code.
IndiaState? indiaStateByLgdCode(int lgdCode) {
  for (final state in indiaStates) {
    if (state.lgdCode == lgdCode) return state;
  }
  return null;
}

/// Case-insensitive search by English name or source local-name field.
List<IndiaState> searchIndiaStates(String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return const <IndiaState>[];
  return indiaStates.where((state) {
    return state.name.toLowerCase().contains(normalizedQuery) ||
        state.localName.toLowerCase().contains(normalizedQuery);
  }).toList(growable: false);
}
