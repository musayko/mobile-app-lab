import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts
import 'package:intl/intl.dart';
import 'package:flag/flag.dart'; // Using flag package
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Services and Controllers
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  late AnimationController _animationController; // Kept if needed for other animations later
  late Animation<double> _animation;            // Kept if needed for other animations later

  // Main Conversion State
  String _fromCurrency = 'EUR';
  String _toCurrency = 'USD';
  String _result = '';
  DateTime? _lastUpdated;
  Map<String, dynamic>? _rates;
  double? _conversionRate;
  bool _isLoading = false; // Single loading state for main conversion/refresh
  String? _errorMessage;
  List<String> _currencies = ['EUR', 'USD'];

  // --- Mapping from Currency Code to Country Code (for flags) ---
  final Map<String, String> _currencyToCountryCode = {
    'USD': 'US', 'EUR': 'EU', 'GBP': 'GB', 'JPY': 'JP', 'CAD': 'CA',
    'AUD': 'AU', 'CHF': 'CH', 'CNY': 'CN', 'INR': 'IN', 'BRL': 'BR',
    'RUB': 'RU', 'KRW': 'KR', 'SGD': 'SG',
    // Add more mappings as needed
  };

 // --- REMOVED Bonus Feature State Variables ---
 // final TextEditingController _customPairController = TextEditingController();
 // String? _customRateResult;
 // bool _isBonusLoading = false;
 // String? _bonusErrorMessage;

 @override
 void initState() {
   super.initState();
   // Animation setup (kept in case needed later, like for swap)
   _animationController = AnimationController(
     duration: const Duration(milliseconds: 300),
     vsync: this,
   );
   _animation = Tween<double>(begin: 0.0, end: 0.5).animate(
     CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
   );
   _fetchRates(); // Fetch initial rates
   _amountController.addListener(_calculateResult); // Listen for amount changes
 }

 @override
 void dispose() {
   // Dispose controllers and listeners
   _animationController.dispose();
   _amountController.removeListener(_calculateResult);
   _amountController.dispose();
   // _customPairController.dispose(); // Removed
   super.dispose();
 }

  // Fetch rates for the main conversion dropdowns
  Future<void> _fetchRates({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final fetchedRates = await _apiService.getLatestRates(_fromCurrency);
      setState(() {
        _rates = fetchedRates;
        _lastUpdated = DateTime.now();
        _currencies = _rates?.keys.toList() ?? ['EUR', 'USD']; // Update currency list safely

        // print("Fetched currencies for dropdowns: $_currencies"); // Commented out

        // Ensure selections are valid
        if (!_currencies.contains(_fromCurrency)) { _fromCurrency = _currencies.isNotEmpty ? _currencies.first : 'EUR'; }
        if (!_currencies.contains(_toCurrency)) { _toCurrency = _currencies.length > 1 ? _currencies[1] : 'USD'; }

        _updateConversionRate();
        _calculateResult();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false; _rates = null; _conversionRate = null; _result = '';
      });
       // print("Error fetching rates: $e"); // Commented out
    }
  }

  // --- REMOVED Bonus Feature API Call Method ---
  // Future<void> _fetchCustomRate() async { ... }

  // Update the specific conversion rate based on the selected 'To' currency
  void _updateConversionRate() {
    if (_rates != null && _rates!.containsKey(_toCurrency)) {
      _conversionRate = _rates![_toCurrency]?.toDouble();
    } else { _conversionRate = null; }
     // print("Updated conversion rate for $_toCurrency: $_conversionRate"); // Commented out
  }

  // Calculate the conversion result based on amount and rate
  void _calculateResult() {
    if (_conversionRate == null) { setState(() => _result = ''); return; }
    final amountString = _amountController.text;
    final amount = double.tryParse(amountString);
    if (amount != null && amount > 0) {
      final calculatedValue = amount * _conversionRate!;
      setState(() {
        _result = NumberFormat("#,##0.####").format(calculatedValue);
      });
    } else { setState(() { _result = ''; }); }
  }

  // Swap the 'From' and 'To' currencies and fetch new rates
  void _swapCurrencies() {
    // Animation trigger can be added here if desired later
    // if (_animationController.status != AnimationStatus.forward) {
    //   _animationController.forward(from: 0.0);
    // }
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _rates = null; _conversionRate = null; _result = '';
      _fetchRates(isRefresh: true);
    });
     // print("Swapped currencies: $_fromCurrency / $_toCurrency"); // Commented out
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
         title: const Text('Currency Converter'),
         backgroundColor: Colors.white,
         elevation: 1.0,
         foregroundColor: const Color(0xFF212529),
         actions: [
           if (_isLoading)
             const Padding(
                 padding: EdgeInsets.only(right: 16.0),
                 child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B4D8))))),
           if (!_isLoading)
             IconButton(
                 icon: const Icon(Icons.refresh),
                 tooltip: 'Refresh rates',
                 onPressed: () => _fetchRates(isRefresh: true)), // Refresh main rate
         ],
      ),
      // AbsorbPointer now only depends on the main _isLoading state
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Conversion Card (remains the same)
                Card(
                 color: Colors.white,
                 elevation: 4.0,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                 child: Container(
                   width: screenWidth * 0.9,
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildCurrencyInputRow(
                          isLoading: _isLoading,
                          controller: _amountController,
                          selectedCurrency: _fromCurrency,
                          currencies: _currencies,
                          onChanged: (value) {
                            if (value != null && value != _fromCurrency) {
                              setState(() { _fromCurrency = value; _rates = null; _conversionRate = null; _result = ''; });
                              _fetchRates();
                            }
                          },
                          isReadOnly: false, labelText: 'Amount',
                       ),
                       const SizedBox(height: 12.0),
                       Center(
                         // child: RotationTransition( // Animation skipped
                         //   turns: _animation,
                           child: IconButton(
                             icon: const Icon(Icons.swap_horiz, size: 32.0, color: Color(0xFF5E60CE)),
                             tooltip: 'Swap currencies',
                             onPressed: _swapCurrencies,
                           ),
                         //),
                       ),
                       const SizedBox(height: 12.0),
                       _buildCurrencyInputRow(
                          isLoading: _isLoading,
                          controller: null,
                          resultText: _isLoading ? '...' : (_result.isEmpty ? null : _result),
                          selectedCurrency: _toCurrency,
                          currencies: _currencies,
                          onChanged: (value) {
                            if (value != null && value != _toCurrency) {
                              setState(() { _toCurrency = value; });
                              _updateConversionRate();
                              _calculateResult();
                            }
                          },
                          isReadOnly: true, labelText: 'Converted Amount',
                       ),
                     ],
                   ),
                 ),
                ),
                const SizedBox(height: 16.0),

                // Display Main Error Message (remains the same)
                if (_errorMessage != null)
                  Container(/* ... Error Container ... */
                    width: screenWidth * 0.9,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle( color: const Color(0xFFFF6B6B).withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500, ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Display Rate & Time Info (remains the same)
                if (_errorMessage == null)
                   Padding( /* ... Rate Text ... */
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: _isLoading
                       ? const Text( 'Loading rate...', style: TextStyle( fontSize: 16.0, fontWeight: FontWeight.w500, color: Color(0xFF6C757D)))
                       : (_conversionRate != null
                          ? Text( '1 $_fromCurrency = ${NumberFormat("0.00####").format(_conversionRate!)} $_toCurrency', style: const TextStyle( fontSize: 16.0, fontWeight: FontWeight.w500, color: Color(0xFF6C757D)))
                          : const SizedBox.shrink()
                         ),
                    ),
                if (_errorMessage == null && _lastUpdated != null && !_isLoading)
                   Text(/* ... Last Updated Text ... */
                     'Last updated: ${DateFormat.yMMMMd().add_Hm().format(_lastUpdated!.toLocal())}',
                      style: const TextStyle( fontSize: 12.0, color: Color(0xFF6C757D)),
                   ),

                // --- REMOVED Bonus Feature Section ---
                // const SizedBox(height: 24.0),
                // Text('Check Custom Rate', ...),
                // const SizedBox(height: 12.0),
                // Container( child: TextField(..._customPairController...) ),
                // const SizedBox(height: 12.0),

                // --- Repurposed Button ---
                const SizedBox(height: 20.0), // Add some space before button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF00B4D8), // Primary color
                     foregroundColor: Colors.white,
                     minimumSize: Size(screenWidth * 0.9, 48), // Wide
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                     textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  // Button action now calls _fetchRates, disable using main _isLoading
                  onPressed: _isLoading ? null : () => _fetchRates(isRefresh: true),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Refresh Rate'), // Changed button text
                ),
                const SizedBox(height: 12.0), // Space below button

                // --- REMOVED Bonus Feature Result/Error Display ---
                // if (_bonusErrorMessage != null) ...
                // if (_customRateResult != null) ...

              ], // End Main Column children
            ),
          ),
        ),
      ),
    );
  }


  // Helper method to build the input/output rows (includes flags)
  Widget _buildCurrencyInputRow({
      required String selectedCurrency,
      required List<String> currencies,
      required ValueChanged<String?> onChanged, // Corrected parameter name
      required bool isReadOnly,
      required String labelText,
      required bool isLoading,
      TextEditingController? controller,
      String? resultText
    }) {
     final dropdownValue = currencies.contains(selectedCurrency) ? selectedCurrency : (currencies.isNotEmpty ? currencies.first : null);
     final bool isEmptyResult = (resultText == null || resultText == '...');
     final String countryCode = _currencyToCountryCode[selectedCurrency] ?? 'XX'; // Map currency to country for flag

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          // Flag Widget
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Flag.fromString(
               countryCode,
               height: 24, width: 36, // Adjust size/aspect ratio
               replacement: const SizedBox(width: 36, height: 24), // Placeholder if flag not found
            ),
          ),
          // Currency Dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: dropdownValue,
              items: currencies.map((String currency) {
                // final String itemCountryCode = _currencyToCountryCode[currency] ?? 'XX'; // Optional: flag in item list
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Row(
                     children: [
                        // Flag.fromString(itemCountryCode, height: 18, width: 27, replacement: const SizedBox(width: 27)),
                        // const SizedBox(width: 8),
                        Text(currency, style: TextStyle(color: isLoading ? Colors.grey[500] : const Color(0xFF212529))),
                     ],
                  ),
                );
              }).toList(),
              onChanged: isLoading ? null : onChanged, // Use corrected parameter name 'onChanged'
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF212529)),
              icon: Icon(Icons.arrow_drop_down, color: isLoading ? Colors.grey[400] : const Color(0xFF6C757D)),
              isExpanded: true,
            ),
          ),
          const SizedBox(width: 12.0),
          // Amount Input or Result Display
          Expanded(
            flex: 3,
            child: isReadOnly
              ? Text(resultText ?? ' ', textAlign: TextAlign.right, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: isEmptyResult ? Colors.grey[400] : const Color(0xFF212529)), maxLines: 1, overflow: TextOverflow.ellipsis)
              : TextField(controller: controller, readOnly: isLoading, textAlign: TextAlign.right, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')), ], style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: isLoading ? Colors.grey[500] : const Color(0xFF212529)), decoration: InputDecoration(hintText: '0.00', border: InputBorder.none, hintStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.grey[400]))),
          ),
        ],
      ),
    );
  } // End _buildCurrencyInputRow
} // End _HomeScreenState