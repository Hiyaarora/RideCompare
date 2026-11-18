/// A trimmed-down response in the exact shape of POST /api/v1/compare.
Map<String, dynamic> sampleComparisonJson() => {
  'requestId': 'test',
  'generatedAt': '2026-11-13T07:37:20.142Z',
  'dataMode': 'live',
  'pickup': {'name': 'MG Road', 'lat': 12.9755, 'lng': 77.6068},
  'drop': {'name': 'HSR Layout', 'lat': 12.9121, 'lng': 77.6446},
  'route': {
    'distanceKm': 11,
    'durationMin': 28,
    'source': 'demo',
    'polyline': [
      {'lat': 12.9755, 'lng': 77.6068},
      {'lat': 12.9121, 'lng': 77.6446},
    ],
  },
  'providers': [
    {'id': 'uber', 'name': 'Uber', 'status': 'ok', 'live': true, 'optionCount': 2},
    {'id': 'ola', 'name': 'Ola', 'status': 'ok', 'live': true, 'optionCount': 2},
    {
      'id': 'rapido',
      'name': 'Rapido',
      'status': 'unavailable',
      'live': false,
      'optionCount': 0,
      'message': 'Live pricing unavailable',
      'reason': 'Rapido has no official fare API',
    },
  ],
  'options': [
    _opt('ola:bike', 'ola', 'Ola Bike', 'bike', 83, 83, eta: 1, trip: 22, upfront: true),
    _opt('uber:moto', 'uber', 'Uber Moto', 'bike', 95, 110, eta: 3, trip: 22),
    _opt('ola:auto', 'ola', 'Ola Auto', 'auto', 195, 195, eta: 6, trip: 29, upfront: true),
    _opt('uber:go', 'uber', 'Uber Go', 'car', 295, 325, eta: 4, trip: 28, surge: 1.1),
  ],
  'cheapestOptionId': 'ola:bike',
  'fastestOptionId': 'ola:bike',
};

Map<String, dynamic> _opt(
  String id,
  String provider,
  String name,
  String category,
  int min,
  int max, {
  required int eta,
  required int trip,
  double surge = 1.0,
  bool upfront = false,
}) => {
  'id': id,
  'provider': provider,
  'providerName': provider,
  'productCode': id.split(':').last,
  'productName': name,
  'description': '$name rides',
  'category': category,
  'capacity': category == 'bike' ? 1 : (category == 'auto' ? 3 : 4),
  'priceType': upfront ? 'upfront' : 'estimate',
  'fare': {'min': min, 'max': max, 'upfront': upfront ? min : null, 'currency': 'INR'},
  'pickupEtaMin': eta,
  'tripDurationMin': trip,
  'distanceKm': 11,
  'surgeMultiplier': surge,
  'available': true,
  'fetchedAt': '2026-11-13T07:37:19.000Z',
  'dataSource': 'live',
};

/// Response when no provider has an authorised live integration.
Map<String, dynamic> unavailableComparisonJson() => {
  ...sampleComparisonJson(),
  'dataMode': 'unavailable',
  'options': <Map<String, dynamic>>[],
  'cheapestOptionId': null,
  'fastestOptionId': null,
  'providers': [
    for (final (id, name, reason) in [
      ('uber', 'Uber', 'Uber API access has not been approved yet'),
      ('ola', 'Ola', 'Ola partner access (X-APP-TOKEN) has not been granted yet'),
      ('rapido', 'Rapido', 'Rapido has no official fare API'),
    ])
      {
        'id': id,
        'name': name,
        'status': 'unavailable',
        'live': false,
        'optionCount': 0,
        'message': 'Live pricing unavailable',
        'reason': reason,
      },
  ],
};
