// lib/services/api_service.dart
import 'dart:convert'; // For jsonDecode
import 'package:http/http.dart' as http; // Import the http package
import '../constants/api_constants.dart'; // Import your API key

class ApiService {
  // Base URL defined once for the class
  final String _baseUrl = "https://api.freecurrencyapi.com/v1/latest";

  // Method to get the latest exchange rates for a base currency
  // Takes baseCurrency (e.g., 'EUR') and optional targetCurrencies list
  Future<Map<String, dynamic>> getLatestRates(String baseCurrency, {List<String>? targetCurrencies}) async {

    // --- Use Uri.https to build the URL safely with query parameters ---
    final Map<String, String> queryParameters = {
      'base_currency': baseCurrency,
      // Add target currencies parameter if provided
      if (targetCurrencies != null && targetCurrencies.isNotEmpty)
        'currencies': targetCurrencies.join(','), // e.g., 'USD,EUR,GBP'
    };

    // Use Uri.https for cleaner construction - uses the authority and path
    final Uri url = Uri.https('api.freecurrencyapi.com', '/v1/latest', queryParameters);

    print("Calling API URL: $url"); // For debugging

    try {
      // --- Make the GET request using HEADERS for authentication ---
      final response = await http.get(
        url,
        headers: {
          // Send the API key in the 'apikey' header as per documentation
          'apikey': apiKey, // apiKey is imported from api_constants.dart
        },
      );

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON.
        final decodedResponse = jsonDecode(response.body);

        // Check if the expected 'data' key exists and is a Map
        if (decodedResponse != null && decodedResponse['data'] is Map) {
          // Ensure values are doubles before returning
           final Map<String, dynamic> rawRates = Map<String, dynamic>.from(decodedResponse['data']);
           final Map<String, dynamic> convertedRates = rawRates.map((key, value) {
              // Convert rate value to double, default to 0.0 if null or invalid
              return MapEntry(key, value?.toDouble() ?? 0.0);
           });
           return convertedRates; // Return map with currency codes -> double rates
        } else {
          // Throw an error if the response structure is not as expected
          throw Exception('Unexpected API response format');
        }
      } else {
        // If the server did not return a 200 OK response, throw an exception.
        String responseBody = response.body;
        print("API Error Response: $responseBody"); // Log the error response from API
        throw Exception('Failed to load exchange rates (Status code: ${response.statusCode}) - Body: $responseBody');
      }
    } catch (e) {
      // Handle potential errors during the API call (network issues, parsing errors, etc.)
      print('Error fetching rates: $e');
      // Rethrow the exception to be caught by the caller (e.g., HomeScreen)
      throw Exception('Failed to fetch exchange rates: $e');
    }
  } // End of getLatestRates method

} // End of ApiService class