import 'package:flutter/material.dart';
import '../../services/area_service.dart';
import '../../services/order_service.dart';
import '../../screens/payment/payment_screen.dart';
import '../../theme/app_theme.dart';
import '../../layouts/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Area Details Page
/// Displays area information, price, highlights, and Buy Tile button
class AreaDetailsPage extends StatefulWidget {
  final String areaKey;

  const AreaDetailsPage({
    super.key,
    required this.areaKey,
  });

  @override
  State<AreaDetailsPage> createState() => _AreaDetailsPageState();
}

class _AreaDetailsPageState extends State<AreaDetailsPage> {
  Map<String, dynamic>? _areaData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPurchasing = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadAreaDetails();
  }

  Future<void> _loadAreaDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AreaService.getAreaDetails(widget.areaKey);

      if (result['success'] == true) {
        setState(() {
          _areaData = result['area'];
          // Adjust quantity if it exceeds remaining slots
          final remainingSlots = result['area']['remainingSlots'] as int? ?? 0;
          if (_quantity > remainingSlots && remainingSlots > 0) {
            _quantity = remainingSlots;
          } else if (remainingSlots == 0) {
            _quantity = 0;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load area details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading area details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkAuthentication() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleBuyTile() async {
    // Check authentication
    final isAuthenticated = await _checkAuthentication();
    if (!isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to purchase tiles'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if slots are available
    if (_areaData == null) return;
    final remainingSlots = _areaData!['remainingSlots'] as int? ?? 0;
    if (remainingSlots == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No slots available for this area'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Validate quantity
    if (_quantity < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity must be at least 1'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_quantity > remainingSlots) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only $remainingSlots slot(s) available. Please reduce quantity.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      // Get area data for state info
      if (_areaData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Area data not loaded'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final stateKey = _areaData!['stateKey'] as String?;
      final stateName = _areaData!['stateName'] as String? ?? '';

      if (stateKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('State information not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 1: Get available land slots (quantity based)
      final slotsResult = await AreaService.getAvailableSlots(
        areaKey: widget.areaKey,
        quantity: _quantity,
      );

      if (!slotsResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(slotsResult['message'] ?? 'No available slots found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final landSlots = slotsResult['landSlots'] as List<dynamic>;
      final landSlotIds = landSlots
          .map((slot) => (slot as Map<String, dynamic>)['landSlotId'] as String)
          .toList();

      // Step 2: Create order with multiple slots
      final orderResult = await OrderService.createOrder(
        state: stateKey,
        place: widget.areaKey,
        landSlotIds: landSlotIds,
      );

      if (!orderResult['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(orderResult['message'] ?? 'Failed to create order'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 3: Navigate to payment screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              orderId: orderResult['orderId'] as String,
              amount: orderResult['amount'] as String,
              address: orderResult['address'] as String,
              network: orderResult['network'] as String,
              state: stateName,
              place: _areaData!['areaName'] as String? ?? widget.areaKey,
              landSlotIds: landSlotIds,
              quantity: _quantity,
            ),
          ),
        ).then((success) {
          // Refresh area data when returning from payment screen
          if (success == true) {
            _loadAreaDetails();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Area Details',
      showBackButton: true,
      showBottomNav: false,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAreaDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _areaData == null
                  ? const Center(
                      child: Text('No data available'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Area Name
                          Text(
                            _areaData!['areaName'] as String? ?? 'Unknown',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          // State Name
                          Text(
                            _areaData!['stateName'] as String? ?? 'Unknown State',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          // Price Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Price per Tile',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_areaData!['pricePerTile']?.toString() ?? '0'}',
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Available Slots',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_areaData!['remainingSlots'] ?? 0} / ${_areaData!['totalSlots'] ?? 0}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: (_areaData!['remainingSlots'] as int? ?? 0) < 10
                                                ? Colors.orange
                                                : AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Highlights Section
                          Text(
                            'Highlights',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...((_areaData!['highlights'] as List<dynamic>?) ?? []).map((highlight) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      highlight.toString(),
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: AppTheme.textPrimary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 32),
                          // Quantity Selector
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.textSecondary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quantity',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    // Decrease button
                                    IconButton(
                                      onPressed: (_areaData!['remainingSlots'] as int? ?? 0) == 0 ||
                                              _quantity <= 1 ||
                                              _isPurchasing
                                          ? null
                                          : () {
                                              setState(() {
                                                _quantity = _quantity > 1 ? _quantity - 1 : 1;
                                              });
                                            },
                                      icon: const Icon(Icons.remove_circle_outline),
                                      color: AppTheme.primaryColor,
                                      iconSize: 32,
                                    ),
                                    // Quantity display
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          '$_quantity',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ),
                                    // Increase button
                                    IconButton(
                                      onPressed: (_areaData!['remainingSlots'] as int? ?? 0) == 0 ||
                                              _quantity >= (_areaData!['remainingSlots'] as int? ?? 0) ||
                                              _isPurchasing
                                          ? null
                                          : () {
                                              final remainingSlots = _areaData!['remainingSlots'] as int? ?? 0;
                                              setState(() {
                                                _quantity = _quantity < remainingSlots
                                                    ? _quantity + 1
                                                    : remainingSlots;
                                              });
                                            },
                                      icon: const Icon(Icons.add_circle_outline),
                                      color: AppTheme.primaryColor,
                                      iconSize: 32,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Total price display
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Price',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                    Text(
                                      '₹${((_areaData!['pricePerTile'] as int? ?? 0) * _quantity).toString()}',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Buy Tile Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (_areaData!['remainingSlots'] as int? ?? 0) == 0 ||
                                      _isPurchasing
                                  ? null
                                  : _handleBuyTile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isPurchasing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      (_areaData!['remainingSlots'] as int? ?? 0) == 0
                                          ? 'Sold Out'
                                          : 'Buy ${_quantity > 1 ? "$_quantity Tiles" : "Tile"}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

