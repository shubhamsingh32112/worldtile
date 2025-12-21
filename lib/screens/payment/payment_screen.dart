import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/order_service.dart';
import '../../layouts/app_shell.dart';
import '../main/main_screen.dart';

/// Payment Screen
/// Displays payment details, QR code, and auto-verification
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

enum PaymentState {
  waiting,    // Waiting for payment
  checking,   // Checking payment
  confirmed,  // Payment confirmed
}

class _PaymentScreenState extends State<PaymentScreen> {
  final GlobalKey _qrKey = GlobalKey();
  PaymentState _paymentState = PaymentState.waiting;
  bool _isVerifying = false;
  bool _hasVerified = false;

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

  /// Download QR code
  Future<void> _downloadQRCode() async {
    try {
      // Capture the QR code widget as an image
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (Platform.isAndroid) {
        // Android: Save via MediaStore (appears in Gallery)
        const platform = MethodChannel('media_store_saver');
        final fileName = 'payment_qr_${widget.orderId}.png';
        
        try {
          final result = await platform.invokeMethod<bool>(
            'saveImageToGallery',
            {
              'imageBytes': pngBytes,
              'fileName': fileName,
            },
          );

          if (mounted) {
            if (result == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR code saved to Gallery → Pictures → WorldTile'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save QR code to gallery'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } on PlatformException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving QR code: ${e.message ?? "Unknown error"}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (Platform.isIOS) {
        // iOS: Save to application documents directory
        final documentsDir = await getApplicationDocumentsDirectory();
        final worldtileDir = Directory('${documentsDir.path}/worldtile');
        if (!await worldtileDir.exists()) {
          await worldtileDir.create(recursive: true);
        }

        final filePath = '${worldtileDir.path}/payment_qr_${widget.orderId}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code saved to documents'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw UnsupportedError('Platform not supported');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving QR code: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Auto-verify payment
  Future<void> _verifyPayment() async {
    // Double-click protection
    if (_isVerifying || _hasVerified) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _paymentState = PaymentState.checking;
    });

    try {
      final result = await OrderService.autoVerifyPayment(
        orderId: widget.orderId,
      );

      if (mounted) {
        final status = result['status'] as String?;
        
        if (result['success'] == true) {
          setState(() {
            _isVerifying = false;
            _hasVerified = true;
            _paymentState = PaymentState.confirmed;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Payment verified successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Auto-redirect to deed page after delay
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              // Navigate to MainScreen with Deed tab (tab index 2) selected
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainScreen(initialTabIndex: 2), // Deed tab is at index 2
                ),
                (route) => false, // Remove all previous routes
              );
            }
          });
        } else if (status == 'EXPIRED') {
          // Order expired - disable button and show error
          setState(() {
            _isVerifying = false;
            _paymentState = PaymentState.waiting;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment window expired. Slots have been released. Please place a new order.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );

          // Auto-redirect after delay
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.of(context).pop(false); // Return false to indicate failure
            }
          });
        } else if (status == 'LATE_PAYMENT') {
          // Payment received after expiry
          setState(() {
            _isVerifying = false;
            _paymentState = PaymentState.waiting;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payment received after order expiry. Please contact support for manual processing.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          // Still pending
          setState(() {
            _isVerifying = false;
            _paymentState = PaymentState.waiting;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Payment not detected yet. Please wait a few minutes and try again.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _paymentState = PaymentState.waiting;
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
    return AppShell(
      title: 'Payment',
      showBackButton: true,
      showBottomNav: false,
      child: SingleChildScrollView(
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
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
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
                    const SizedBox(height: 16),
                    // Download QR button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _downloadQRCode,
                        icon: const Icon(Icons.download),
                        label: const Text('Download QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // "I've Paid" Button
            if (_paymentState == PaymentState.waiting || _paymentState == PaymentState.checking) ...[
              Card(
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _paymentState == PaymentState.waiting
                            ? 'Waiting for Payment'
                            : 'Checking Payment',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_paymentState == PaymentState.waiting)
                        Text(
                          'After completing the payment in your wallet, click the button below to verify.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        )
                      else
                        const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Checking for payment...'),
                          ],
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyPayment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                          ),
                          child: _isVerifying
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Checking...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'I\'VE PAID',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Payment Confirmed
            if (_paymentState == PaymentState.confirmed) ...[
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
                              'Payment Confirmed',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your payment has been verified successfully. Redirecting...',
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
