// lib/models/exchange_rates_response.dart
class ExchangeRatesResponse {
  final Map<String, double> rates;
  final String baseCurrency; // Optional: if the API returns it
  final DateTime lastUpdated; // Optional: track update time

  ExchangeRatesResponse({
    required this.rates,
    required this.baseCurrency,
    required this.lastUpdated,
  });

  // Example factory constructor if API returns data like {"data": {"USD": 1.08...}}
  factory ExchangeRatesResponse.fromJson(Map<String, dynamic> json, String base) {
    // Convert dynamic rates map to Map<String, double>
     final Map<String, dynamic> rawRates = Map<String, dynamic>.from(json['data']);
     final Map<String, double> convertedRates = rawRates.map((key, value) {
        // Ensure values are doubles
        return MapEntry(key, value?.toDouble() ?? 0.0);
     });

    return ExchangeRatesResponse(
      rates: convertedRates,
      baseCurrency: base, // Pass the base currency we requested
      lastUpdated: DateTime.now(), // Set update time locally
    );
  }
}