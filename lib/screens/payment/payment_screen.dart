import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _hasClickedPayNow = false;

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

  /// Copy amount to clipboard
  Future<void> _copyAmount() async {
    await Clipboard.setData(ClipboardData(text: widget.amount));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount copied to clipboard'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Launch wallet with TRON payment URI
  /// Attempts in order: tron: deep link (Trust Wallet/TronLink) -> Binance universal link -> Error dialog
  /// 
  /// IMPORTANT: canLaunchUrl() is ONLY used for custom schemes (tron:)
  /// For HTTPS universal links (Binance), we attempt launchUrl() directly and let the OS decide
  Future<void> _launchWallet() async {
    // Primary: TRON deep link (Trust Wallet / TronLink)
    final tronUri = Uri.parse('tron:${widget.address}?amount=${widget.amount}');
    
    // Fallback: Binance universal link (HTTPS)
    final binanceUrl = Uri.parse(
      'https://www.binance.com/en/my/wallet/account/send?coin=USDT&network=TRX&address=${widget.address}&amount=${widget.amount}',
    );

    // Step 1: Try TRON deep link first (preferred)
    // Use canLaunchUrl() ONLY for custom schemes like tron:
    try {
      if (await canLaunchUrl(tronUri)) {
        final launched = await launchUrl(
          tronUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          // Success - mark that user has clicked Pay Now
          setState(() {
            _hasClickedPayNow = true;
          });
          return;
        }
      }
    } catch (_) {
      // TRON deep link failed, continue to fallback
    }

    // Step 2: Try Binance fallback (HTTPS universal link)
    // DO NOT use canLaunchUrl() for HTTPS - let the OS decide
    // Attempt launchUrl() directly (optimistic approach)
    try {
      final launched = await launchUrl(
        binanceUrl,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        // Success - mark that user has clicked Pay Now
        setState(() {
          _hasClickedPayNow = true;
        });
        return;
      }
    } catch (_) {
      // Binance fallback failed, continue to error dialog
    }

    // Step 3: If both attempts failed, show error dialog
    if (mounted) {
      _showNoWalletDialog();
    }
  }

  /// Show dialog when no wallet is found (only after all options fail)
  void _showNoWalletDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'No Compatible Wallet Found',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: const Text(
            'We couldn\'t find a TRON-compatible wallet.\n\nInstall Trust Wallet or TronLink, or use Binance to send USDT (TRC20) manually.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _copyAddress();
              },
              child: const Text('Copy Address'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _copyAmount();
              },
              child: const Text('Copy Amount'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

            // Pay Now Button (shown initially)
            if (!_hasClickedPayNow && !_hasSubmitted) ...[
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Pay',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Click "Pay Now" to open your crypto wallet and complete the payment.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _launchWallet,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          child: const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Transaction Hash Input Card (shown after Pay Now is clicked)
            if (_hasClickedPayNow && !_hasSubmitted) ...[
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
            ],

            // Success message
            if (_hasSubmitted) ...[
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

