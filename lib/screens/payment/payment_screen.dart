import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';

/// Payment Screen
/// Displays payment details, QR code, and transaction hash input
class PaymentScreen extends StatefulWidget {
  final String orderId;
  final String amount;
  final String address;
  final String network;
  final String state;
  final String place;
  final List<String> landSlotIds;
  final int quantity;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.address,
    required this.network,
    required this.state,
    required this.place,
    required this.landSlotIds,
    required this.quantity,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _txHashController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _txHashController.dispose();
    super.dispose();
  }

  /// Generate QR code payload in TRON format: tron:<ADDRESS>?amount=<AMOUNT>
  String _generateQRPayload() {
    return 'tron:${widget.address}?amount=${widget.amount}';
  }

  /// Copy address to clipboard
  Future<void> _copyAddress() async {
    await Clipboard.setData(ClipboardData(text: widget.address));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address copied to clipboard'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Submit transaction hash
  Future<void> _submitTransactionHash() async {
    final txHash = _txHashController.text.trim();

    if (txHash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a transaction hash'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate transaction hash format (64 hex characters)
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(txHash)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid transaction hash format. Must be 64 hexadecimal characters.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await OrderService.submitTransactionHash(
        orderId: widget.orderId,
        txHash: txHash,
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _hasSubmitted = true;
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Transaction submitted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Optionally navigate back after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop(true); // Return true to indicate success
            }
          });
        } else {
          setState(() {
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to submit transaction hash'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Info Card
            Card(
              color: AppTheme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('State', widget.state),
                    _buildInfoRow('Area', widget.place),
                    _buildInfoRow('Quantity', '${widget.quantity} tile(s)'),
                    if (widget.quantity == 1)
                      _buildInfoRow('Land Slot', widget.landSlotIds.first)
                    else
                      _buildInfoRow('Land Slots', '${widget.landSlotIds.length} slots'),
                    _buildInfoRow('Order ID', widget.orderId),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Payment Details Card
            Card(
              color: AppTheme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    // Amount (Read-only) - Total for all tiles
                    _buildReadOnlyField(
                      label: 'Total Amount',
                      value: '${widget.amount} USDT (${widget.quantity} tile${widget.quantity > 1 ? 's' : ''})',
                      icon: Icons.attach_money,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Network (Read-only)
                    _buildReadOnlyField(
                      label: 'Network',
                      value: widget.network,
                      icon: Icons.network_check,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Address (Read-only with copy button)
                    Row(
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            label: 'USDT Address',
                            value: widget.address,
                            icon: Icons.account_balance_wallet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          color: AppTheme.primaryColor,
                          onPressed: _copyAddress,
                          tooltip: 'Copy address',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // QR Code Card
            Card(
              color: AppTheme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Scan to Pay',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _generateQRPayload(),
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Send only USDT on TRC20 network',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Do not use any other network',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Transaction Hash Input Card
            if (!_hasSubmitted) ...[
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit Transaction Hash',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _txHashController,
                        decoration: InputDecoration(
                          labelText: 'Transaction Hash',
                          hintText: 'Enter 64-character transaction hash',
                          prefixIcon: const Icon(Icons.receipt_long),
                          helperText: 'After payment, paste your transaction hash here',
                          helperMaxLines: 2,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitTransactionHash,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.backgroundColor,
                                    ),
                                  ),
                                )
                              : const Text('Submit Transaction Hash'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Success message
              Card(
                color: Colors.green.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transaction Submitted',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Verification pending. You can close this screen.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Show list of land slots if multiple
            if (widget.quantity > 1) ...[
              const SizedBox(height: 24),
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Land Slots (${widget.landSlotIds.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.landSlotIds.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slotId = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  slotId,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppTheme.surfaceColor.withOpacity(0.5),
      ),
      style: const TextStyle(
        color: AppTheme.textPrimary,
      ),
    );
  }
}

