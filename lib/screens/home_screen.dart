import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // Using Google Fonts
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:flag/flag.dart'; 

class HomeScreen extends StatefulWidget {
  // Use const constructor for StatefulWidget
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String _fromCurrency = 'EUR';
  String _toCurrency = 'USD';
  final TextEditingController _amountController = TextEditingController();
  String _result = '';
  DateTime? _lastUpdated;
  Map<String, dynamic>? _rates;
  double? _conversionRate;
  bool _isLoading = false; // Loading state for main conversion
  String? _errorMessage; // Error for main conversion
  List<String> _currencies = ['EUR', 'USD']; // Default, should be updated by API
  late AnimationController _animationController;
  late Animation<double> _animation;

  // --- State Variables for Bonus Feature ---
  final TextEditingController _customPairController = TextEditingController(); // Input like "GBP/JPY"
  String? _customRateResult; // To display "1 GBP = 145.xx JPY" or error
  bool _isBonusLoading = false; // Loading state specifically for the bonus feature
  String? _bonusErrorMessage; // Error specifically for the bonus feature

  final Map<String, String> _currencyToCountryCode = {
    'USD': 'US', // US Dollar -> USA
    'EUR': 'EU', // Euro -> European Union (check if 'EU' flag works, else use 'DE', 'FR', etc.)
    'GBP': 'GB', // British Pound -> Great Britain
    'JPY': 'JP', // Japanese Yen -> Japan
    'CAD': 'CA', // Canadian Dollar -> Canada
    'AUD': 'AU', // Australian Dollar -> Australia
    'CHF': 'CH', // Swiss Franc -> Switzerland
    'CNY': 'CN', // Chinese Yuan -> China
    'INR': 'IN', // Indian Rupee -> India
    'BRL': 'BR', // Brazilian Real -> Brazil
    'RUB': 'RU', // Russian Ruble -> Russia
    'KRW': 'KR', // South Korean Won -> South Korea
    'SGD': 'SG', // Singapore Dollar -> Singapore
    // Add more mappings as needed for currencies you expect
  };

 @override
 void initState() {
   super.initState();
   _animationController = AnimationController(
     duration: const Duration(milliseconds: 300), // const added
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
   // Dispose all controllers and listeners to prevent memory leaks
   _animationController.dispose();
   _amountController.removeListener(_calculateResult);
   _amountController.dispose();
   _customPairController.dispose();
   super.dispose();
 }

  // Fetch rates for the main conversion dropdowns
  Future<void> _fetchRates({bool isRefresh = false}) async {
    // Prevent fetching if already loading, unless manually refreshed
    if (_isLoading && !isRefresh) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Fetch all available rates based on the selected _fromCurrency
      final fetchedRates = await _apiService.getLatestRates(_fromCurrency);
      setState(() {
        _rates = fetchedRates;
        _lastUpdated = DateTime.now();
        _currencies = _rates!.keys.toList(); // Update the list of available currencies

        // --- DEBUG PRINT (Commented out) ---
        // Check if the full list is being received from the API
        // print("Fetched currencies for dropdowns: $_currencies");
        // --- END DEBUG PRINT ---

        // Ensure currently selected currencies are still valid after fetch
        if (!_currencies.contains(_fromCurrency)) { _fromCurrency = _currencies.isNotEmpty ? _currencies.first : 'EUR'; }
        if (!_currencies.contains(_toCurrency)) { _toCurrency = _currencies.length > 1 ? _currencies[1] : 'USD'; }

        _updateConversionRate(); // Calculate the specific rate for the selected pair
        _calculateResult();    // Calculate the initial result if amount exists
        _isLoading = false;     // Update loading state
      });
    } catch (e) {
      // Handle errors during API fetch
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", ""); // Store cleaned error message
        _isLoading = false; _rates = null; _conversionRate = null; _result = ''; // Reset state on error
      });
       // print("Error fetching rates: $e"); // Commented out
    }
  }

  // Fetch rate for the custom currency pair entered by the user
  Future<void> _fetchCustomRate() async {
    final String pairInput = _customPairController.text.trim().toUpperCase();
    // Basic validation for the input format
    if (pairInput.isEmpty) {
      setState(() { _bonusErrorMessage = "Please enter a currency pair (e.g., GBP/JPY)"; });
      return;
    }
    final parts = pairInput.split('/');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty || parts[0].length < 3 || parts[1].length < 3) {
      setState(() { _bonusErrorMessage = "Invalid format. Use FROM/TO (e.g., GBP/JPY)"; });
      return;
    }
    final String customFrom = parts[0];
    final String customTo = parts[1];

    // Set loading state specific to the bonus section
    setState(() { _isBonusLoading = true; _bonusErrorMessage = null; _customRateResult = null; });

    try {
      // Call API to get only the specific rate needed (efficient)
      final ratesMap = await _apiService.getLatestRates(customFrom, targetCurrencies: [customTo]);

      // Process the response
      if (ratesMap.containsKey(customTo)) {
        final rate = ratesMap[customTo]?.toDouble();
        if (rate != null) {
          setState(() {
            // Format and store the result string
            _customRateResult = '1 $customFrom = ${NumberFormat("0.00####").format(rate)} $customTo';
            _isBonusLoading = false;
          });
        } else { throw Exception("Rate for $customTo not found in response."); }
      } else { throw Exception("Could not find rate for the pair $customFrom/$customTo."); }
    } catch (e) {
      // Handle errors during the custom rate fetch
      setState(() {
        _bonusErrorMessage = e.toString().replaceFirst("Exception: ", ""); // Store cleaned error
        _isBonusLoading = false; _customRateResult = null; // Reset state on error
      });
       // print("Error fetching custom rate: $e"); // Commented out
    }
  }

  // Update the specific conversion rate based on the selected 'To' currency
  void _updateConversionRate() {
    if (_rates != null && _rates!.containsKey(_toCurrency)) {
      _conversionRate = _rates![_toCurrency]?.toDouble();
    } else { _conversionRate = null; }
     // print("Updated conversion rate for $_toCurrency: $_conversionRate"); // Commented out
  }

  // Calculate the conversion result based on amount and rate
  void _calculateResult() {
    if (_conversionRate == null) { setState(() => _result = ''); return; } // Exit if no rate
    final amountString = _amountController.text;
    final amount = double.tryParse(amountString); // Safely parse input amount
    if (amount != null && amount > 0) {
      final calculatedValue = amount * _conversionRate!;
      setState(() {
        // Format the result using intl package
        _result = NumberFormat("#,##0.####").format(calculatedValue);
      });
    } else { setState(() { _result = ''; }); } // Clear result if input is invalid/zero
  }

  // Swap the 'From' and 'To' currencies and fetch new rates
  void _swapCurrencies() {
    // Trigger animation if implemented and desired
    // if (_animationController.status != AnimationStatus.forward) {
    //   _animationController.forward(from: 0.0);
    // }

    // Update state: swap currencies, clear old data, trigger refresh
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _rates = null; _conversionRate = null; _result = '';
      _fetchRates(isRefresh: true); // Fetch rates for the new base currency
    });
     // print("Swapped currencies: $_fromCurrency / $_toCurrency"); // Commented out
  }

  // Build the main UI
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
         title: const Text('Currency Converter'), // Use theme's font
         backgroundColor: Colors.white,
         elevation: 1.0, // Subtle elevation
         foregroundColor: const Color(0xFF212529), // Icon/text color
         actions: [
           // Show loading indicator in AppBar or Refresh button
           if (_isLoading)
             const Padding(
                 padding: EdgeInsets.only(right: 16.0),
                 child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B4D8))))), // Primary color spinner
           if (!_isLoading)
             IconButton(
                 icon: const Icon(Icons.refresh),
                 tooltip: 'Refresh rates',
                 onPressed: () => _fetchRates(isRefresh: true)),
         ],
      ),
      // Disable interactions on content below AppBar while loading
      body: AbsorbPointer(
        absorbing: _isLoading || _isBonusLoading,
        child: Center(
          // Use SingleChildScrollView to prevent overflow if content is long
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Fit content vertically
              children: [
                // Main Conversion Card
                Card(
                 color: Colors.white,
                 elevation: 4.0,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(16.0),
                 ),
                 child: Container(
                   width: screenWidth * 0.9, // 90% width
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Row 1: Amount Input & 'From' Currency Dropdown
                       _buildCurrencyInputRow(
                          isLoading: _isLoading,
                          controller: _amountController,
                          selectedCurrency: _fromCurrency,
                          currencies: _currencies,
                          onChanged: (value) { // Corrected parameter name
                            if (value != null && value != _fromCurrency) {
                              setState(() { _fromCurrency = value; _rates = null; _conversionRate = null; _result = ''; });
                              _fetchRates(); // Fetch rates for new base
                            }
                          },
                          isReadOnly: false,
                          labelText: 'Amount',
                       ),
                       const SizedBox(height: 12.0),
                       // Row 2: Swap Button (Animation skipped for now)
                       Center(
                         // child: RotationTransition( // Animation skipped
                         //   turns: _animation,
                           child: IconButton(
                             icon: const Icon(Icons.swap_horiz, size: 32.0, color: Color(0xFF5E60CE)), // Accent color
                             tooltip: 'Swap currencies',
                             onPressed: _swapCurrencies,
                           ),
                         //),
                       ),
                       const SizedBox(height: 12.0),
                       // Row 3: Result Display & 'To' Currency Dropdown
                       _buildCurrencyInputRow(
                          isLoading: _isLoading,
                          controller: null,
                          resultText: _isLoading ? '...' : (_result.isEmpty ? null : _result), // Show loading/result/placeholder
                          selectedCurrency: _toCurrency,
                          currencies: _currencies,
                          onChanged: (value) { // Corrected parameter name
                            if (value != null && value != _toCurrency) {
                              setState(() { _toCurrency = value; }); // Update target currency
                              _updateConversionRate();            // Get new rate from fetched data
                              _calculateResult();                 // Recalculate result
                            }
                          },
                          isReadOnly: true,
                          labelText: 'Converted Amount',
                       ),
                     ],
                   ),
                 ),
                ), // End of Card
                const SizedBox(height: 16.0),

                // Display Main Error Message (Styled)
                if (_errorMessage != null)
                  Container(
                    width: screenWidth * 0.9,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.15), // Light error bg
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.5)), // Error border
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            _errorMessage!, // Safe due to surrounding check
                            style: TextStyle( color: const Color(0xFFFF6B6B).withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500, ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Display Rate & Time Info (Styled and handles loading state)
                if (_errorMessage == null) // Show only if no error
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: _isLoading
                       ? const Text( 'Loading rate...', style: TextStyle( fontSize: 16.0, fontWeight: FontWeight.w500, color: Color(0xFF6C757D)))
                       : (_conversionRate != null
                          ? Text( '1 $_fromCurrency = ${NumberFormat("0.00####").format(_conversionRate!)} $_toCurrency', style: const TextStyle( fontSize: 16.0, fontWeight: FontWeight.w500, color: Color(0xFF6C757D)))
                          : const SizedBox.shrink() // Hide if rate is null (initial state)
                         ),
                   ),
                if (_errorMessage == null && _lastUpdated != null && !_isLoading) // Show only if no error/load and time exists
                   Text(
                      'Last updated: ${DateFormat.yMMMMd().add_Hm().format(_lastUpdated!.toLocal())}', // Formatted time
                      style: const TextStyle( fontSize: 12.0, color: Color(0xFF6C757D)),
                   ),

                // --- Bonus Feature Section ---
                const SizedBox(height: 24.0),
                // Section Title
                Text(
                  'Check Custom Rate',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF212529)),
                ),
                const SizedBox(height: 12.0),
                // Custom Pair Input Field
                Container(
                  width: screenWidth * 0.9,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: TextField(
                    controller: _customPairController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textCapitalization: TextCapitalization.characters, // Auto uppercase
                    decoration: InputDecoration(
                      hintText: 'e.g., GBP/JPY',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
                // Show Rate Button (Handles loading state)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF00B4D8), // Primary color
                     foregroundColor: Colors.white,
                     minimumSize: Size(screenWidth * 0.9, 48), // Wide
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                     textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isBonusLoading ? null : _fetchCustomRate, // Disable when loading
                  child: _isBonusLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) // Loading spinner
                      : const Text('Show Rate'),
                ),
                const SizedBox(height: 12.0),
                // Display Bonus Result or Error
                if (_bonusErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Error: $_bonusErrorMessage!', // Safe due to check
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                 if (_customRateResult != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                     child: Text(
                       _customRateResult!, // Safe due to check
                       style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF00B4D8)), // Primary color for result
                       textAlign: TextAlign.center,
                     ),
                   ),

              ], // End Main Column children
            ),
          ),
        ),
      ),
    );
  }


  // Helper method to build the input/output rows consistently
  Widget _buildCurrencyInputRow({
      required String selectedCurrency,
      required List<String> currencies,
      required ValueChanged<String?> onChanged,
      required bool isReadOnly,
      required String labelText,
      required bool isLoading,
      TextEditingController? controller,
      String? resultText
    }) {
    final dropdownValue = currencies.contains(selectedCurrency) ? selectedCurrency : (currencies.isNotEmpty ? currencies.first : null);
    final bool isEmptyResult = (resultText == null || resultText == '...');

    // --- Get Country Code from Mapping ---
    // Look up the country code, provide a fallback if not found
    final String countryCode = _currencyToCountryCode[selectedCurrency] ?? 'XX'; // 'XX' or another placeholder

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          // --- Flag Widget ('flag' package) ---
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // Use Flag.fromString with the mapped country code
            child: Flag.fromString(
              countryCode, // Use the looked-up country code
              height: 24, // Adjust size as needed
              width: 36, // Width might be needed too, depending on desired aspect ratio
              replacement: const SizedBox(width: 36, height: 24), // What to show if flag not found
            ),
          ),
          // --- End Flag Widget ---

          // --- Currency Dropdown ---
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: dropdownValue,
              items: currencies.map((String currency) {
                // Optional: Get country code for flag inside dropdown item
                // final String itemCountryCode = _currencyToCountryCode[currency] ?? 'XX';
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Row(
                    children: [
                        // Optional: Small flag inside dropdown item
                        // Flag.fromString(itemCountryCode, height: 18, width: 27, replacement: const SizedBox(width: 27)),
                        // const SizedBox(width: 8),
                        Text(currency, style: TextStyle(color: isLoading ? Colors.grey[500] : const Color(0xFF212529))),
                    ],
                  ),
                );
              }).toList(),
              onChanged: isLoading ? null : onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF212529)),
              icon: Icon(Icons.arrow_drop_down, color: isLoading ? Colors.grey[400] : const Color(0xFF6C757D)),
              isExpanded: true,
            ),
          ),
          // --- End Currency Dropdown ---

          const SizedBox(width: 12.0),

          // --- Amount Input or Result Display Text ---
          Expanded(
            flex: 3,
            child: isReadOnly
              ? Text( /* ... Text widget code ... */
                  resultText ?? ' ',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: isEmptyResult ? Colors.grey[400] : const Color(0xFF212529)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : TextField( /* ... TextField widget code ... */
                  controller: controller,
                  readOnly: isLoading,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')), ],
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: isLoading ? Colors.grey[500] : const Color(0xFF212529)),
                  decoration: InputDecoration(hintText: '0.00', border: InputBorder.none, hintStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.grey[400])),
                ),
          ),
          // --- End Amount Input / Result ---
        ],
      ),
    );
  } // End _buildCurrencyInputRow
} // End _HomeScreenState