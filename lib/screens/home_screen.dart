import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart'; 
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Services ---
  final ApiService _apiService = ApiService(); // Instance of our API service

  // --- State Variables ---
  String _fromCurrency = 'EUR';
  String _toCurrency = 'USD';
  final TextEditingController _amountController = TextEditingController();
  String _result = '';
  DateTime? _lastUpdated; // Time of the last successful API fetch
  Map<String, dynamic>? _rates; // To store the fetched rates map { 'USD': 1.08, ... }
  double? _conversionRate; // The specific rate for _fromCurrency -> _toCurrency

  // UI State
  bool _isLoading = false; // To show loading indicator
  String? _errorMessage; // To display errors from API

  // Available currencies - will be updated from API response
  List<String> _currencies = ['EUR', 'USD']; // Start with defaults

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _fetchRates(); // Fetch rates when the screen loads initially
    _amountController.addListener(_calculateResult); // Recalculate when amount changes
  }

  @override
  void dispose() {
    _amountController.removeListener(_calculateResult); // Clean up listener
    _amountController.dispose();
    super.dispose();
  }

  // --- API Fetching ---
  Future<void> _fetchRates({bool isRefresh = false}) async {
    // Don't fetch if already loading, unless it's a manual refresh
    if (_isLoading && !isRefresh) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      // Fetch rates based on the _fromCurrency
      final fetchedRates = await _apiService.getLatestRates(_fromCurrency);

      setState(() {
        _rates = fetchedRates;
        _lastUpdated = DateTime.now(); // Record update time

        // Update the list of available currencies from the fetched rates
        _currencies = _rates!.keys.toList();
        // Ensure current selections are still valid (might happen if API changes)
        if (!_currencies.contains(_fromCurrency)) {
            _fromCurrency = _currencies.isNotEmpty ? _currencies.first : 'EUR'; // Fallback
        }
         if (!_currencies.contains(_toCurrency)) {
            _toCurrency = _currencies.length > 1 ? _currencies[1] : 'USD'; // Fallback
        }

        _updateConversionRate(); // Get the specific rate for the selected pair
        _calculateResult(); // Recalculate with the new rate
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString(); // Store error message
        _isLoading = false;
        _rates = null; // Clear rates on error
        _conversionRate = null;
        _result = ''; // Clear result on error
      });
      print("Error fetching rates: $e");
    }
  }

  // --- Calculation Logic ---
  void _updateConversionRate() {
    if (_rates != null && _rates!.containsKey(_toCurrency)) {
      // Get the rate for the target currency from the fetched map
      _conversionRate = _rates![_toCurrency]?.toDouble();
    } else {
      _conversionRate = null; // Rate not available
    }
     print("Updated conversion rate for $_toCurrency: $_conversionRate");
  }

  void _calculateResult() {
    if (_conversionRate == null) {
      setState(() => _result = ''); // No rate, no result
      return;
    }

    final amountString = _amountController.text;
    final amount = double.tryParse(amountString); // Safely parse the input

    if (amount != null && amount > 0) {
      final calculatedValue = amount * _conversionRate!;
      setState(() {
        // Basic formatting - consider using intl package for locale-specific formatting
        _result = calculatedValue.toStringAsFixed(4); // Show 4 decimal places
      });
    } else {
      setState(() {
        _result = ''; // Clear result if input is invalid or zero
      });
    }
  }

  // --- UI Actions ---
  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;

      // After swapping, we need to fetch rates for the new base currency (_fromCurrency)
      // OR try to calculate using inverse if rates for both were fetched (more complex)
      // Simplest approach: Fetch new rates for the new base currency.
      _rates = null; // Clear old rates
      _conversionRate = null;
      _result = ''; // Clear result
      _fetchRates(isRefresh: true); // Fetch rates for the new base currency

      // Optional: Clear amount on swap?
      // _amountController.clear();
    });
     print("Swapped currencies: $_fromCurrency / $_toCurrency");
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Currency Converter',
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212529),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // Show loading indicator or refresh icon
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Color(0xFF212529),
                  ),
                  onPressed: () => _fetchRates(isRefresh: true), // Call fetch on refresh press
                ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column( // Use Column for Card + Rate info below it
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: Colors.white,
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Container(
                  width: screenWidth * 0.9,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Row 1: Amount Input & From Currency ---
                      _buildCurrencyInputRow(
                        controller: _amountController,
                        selectedCurrency: _fromCurrency,
                        currencies: _currencies, // Pass available currencies
                        onCurrencyChanged: (value) {
                          if (value != null && value != _fromCurrency) {
                            setState(() {
                              _fromCurrency = value;
                              // Need to fetch new rates based on the new _fromCurrency
                              _rates = null;
                              _conversionRate = null;
                              _result = '';
                              _fetchRates(); // Fetch for new base
                            });
                          }
                        },
                        isReadOnly: false,
                        labelText: 'Amount',
                      ),
                      const SizedBox(height: 12.0),
                      // --- Row 2: Swap Button ---
                      Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.swap_horiz,
                            size: 32.0,
                            color: Color(0xFF5E60CE),
                          ),
                          onPressed: _swapCurrencies,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      // --- Row 3: Result Display & To Currency ---
                      _buildCurrencyInputRow(
                        controller: null, // No controller for result display
                        resultText: _isLoading ? '...' : (_result.isEmpty ? ' ' : _result), // Show loading or result
                        selectedCurrency: _toCurrency,
                        currencies: _currencies, // Pass available currencies
                        onCurrencyChanged: (value) {
                          if (value != null && value != _toCurrency) {
                            setState(() {
                              _toCurrency = value;
                              // Only need to update the specific rate, no need to re-fetch
                              _updateConversionRate();
                              _calculateResult(); // Recalculate with new target rate
                            });
                          }
                        },
                        isReadOnly: true,
                        labelText: 'Converted Amount',
                      ),
                    ],
                  ),
                ),
              ), // End of Card

              const SizedBox(height: 16.0), // Space below card

              // --- Display Error Message ---
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // --- Display Exchange Rate Info ---
              if (_conversionRate != null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    // Format the rate to 2 decimal places using intl
                    '1 $_fromCurrency = ${NumberFormat("0.00").format(_conversionRate)} $_toCurrency',
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6C757D), // Secondary text color
                    ),
                  ),
                ),
              if (_lastUpdated != null && !_isLoading)
                Text(
                    // Format the date and time using intl
                    // Example: "April 7, 2025 10:41"
                    'Last updated: ${DateFormat.yMMMMd().add_Hm().format(_lastUpdated!.toLocal())}',
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: Color(0xFF6C757D), // Secondary text color
                    ),
                ),
              // TODO: Add Bonus Input section later
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Method for Currency Rows ---
  // Updated to accept list of currencies
  Widget _buildCurrencyInputRow({
      required String selectedCurrency,
      required List<String> currencies, // Now takes the list of currencies
      required ValueChanged<String?> onCurrencyChanged,
      required bool isReadOnly,
      required String labelText, // Keep label for context if needed later
      TextEditingController? controller,
      String? resultText
    }) {
     // Ensure the selected currency is actually in the list, if not, fallback
     // This prevents errors if the state updates faster than the API response provides the list
     final dropdownValue = currencies.contains(selectedCurrency) ? selectedCurrency : (currencies.isNotEmpty ? currencies.first : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          // Currency Dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: dropdownValue, // Use the validated dropdownValue
              items: currencies.map((String currency) { // Use dynamic list
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              onChanged: currencies.isEmpty ? null : onCurrencyChanged, // Disable if list is empty
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                 fontSize: 16,
                 fontWeight: FontWeight.w500,
                 color: Color(0xFF212529)
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6C757D)),
              isExpanded: true, // Ensure dropdown takes available space
            ),
          ),
          const SizedBox(width: 12.0),
          // Amount Input OR Result Display
          Expanded(
            flex: 3,
            child: isReadOnly
              ? Text(
                  resultText ?? ' ',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                    // Handle loading state color?
                    color: resultText == '...' ? Colors.grey[400] : Color(0xFF212529),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Prevent overflow
                )
              : TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                  ],
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212529)
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[400],
                    ),
                  ),
                  // onChanged handled by listener added in initState
                ),
          ),
        ],
      ),
    );
  }
}