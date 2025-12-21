import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/deed_model.dart';
import '../../services/deed_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../layouts/app_shell.dart';

/// Deed Detail Page - Displays a single digital land ownership deed
/// This is a full-screen page (not a modal) that shows deed details
class DeedDetailPage extends StatefulWidget {
  final String propertyId; // landSlotId

  const DeedDetailPage({
    super.key,
    required this.propertyId,
  });

  @override
  State<DeedDetailPage> createState() => _DeedDetailPageState();
}

class _DeedDetailPageState extends State<DeedDetailPage> {
  DeedModel? _deed;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDeed();
  }

  /// Fetch deed data from API
  Future<void> _fetchDeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DeedService.getDeedByPropertyId(
        propertyId: widget.propertyId,
      );

      if (!mounted) return;

      if (result['success'] == true && result['deed'] != null) {
        setState(() {
          _deed = result['deed'] as DeedModel;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load deed';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading deed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppShell(
        title: 'Deed',
        showBackButton: true,
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : _errorMessage != null
                  ? _buildErrorState()
                  : _deed != null
                      ? _buildDeedContent()
                      : _buildErrorState(),
        ),
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Fetching blockchain deed...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to load deed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchDeed,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build deed content
  Widget _buildDeedContent() {
    final deed = _deed!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),
          
          // Subtitle
          _buildSubtitle(),
          const SizedBox(height: 32),
          
          // Deed title
          _buildDeedTitle(),
          const SizedBox(height: 32),
          
          // Owner statement
          _buildOwnerStatement(deed.ownerName),
          const SizedBox(height: 32),
          
          // Details table (GlassCard)
          _buildDetailsTable(deed),
          const SizedBox(height: 32),
          
          // Issued info
          _buildIssuedInfo(deed.issuedAt),
          const SizedBox(height: 48),
          
          // Verified seal (bottom-right)
          _buildVerifiedSeal(deed.sealNo),
        ],
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Text(
      'WORLD TILE',
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            shadows: [
              Shadow(
                color: AppTheme.primaryColor.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
    );
  }

  /// Build subtitle
  Widget _buildSubtitle() {
    return Text(
      'Digital Land Registry • Blockchain Secured',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            letterSpacing: 1.5,
            color: AppTheme.textSecondary,
          ),
    );
  }

  /// Build deed title
  Widget _buildDeedTitle() {
    return Text(
      'DIGITAL LAND OWNERSHIP DEED',
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
      textAlign: TextAlign.center,
    );
  }

  /// Build owner statement
  Widget _buildOwnerStatement(String ownerName) {
    return Column(
      children: [
        Text(
          'This deed certifies that',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          ownerName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                shadows: [
                  Shadow(
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'is the verified digital owner of the following WorldTile land parcel,\npermanently recorded on the blockchain.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build details table
  Widget _buildDetailsTable(DeedModel deed) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      backgroundColor: Colors.white.withOpacity(0.1),
      child: Column(
        children: [
          // Row 1: Owner Name / Plot ID
          _buildDetailRow(
            label: 'Owner Name',
            value: deed.ownerName,
            isFirst: true,
          ),
          _buildDivider(),
          _buildDetailRow(
            label: 'Plot ID',
            value: deed.plotId,
          ),
          _buildDivider(),
          
          // Row 2: City / Region / NFT Token ID
          _buildDetailRow(
            label: 'City / Region',
            value: deed.city,
          ),
          _buildDivider(),
          _buildDetailRow(
            label: 'NFT Token ID',
            value: deed.nft.tokenId,
          ),
          _buildDivider(),
          
          // Row 3: NFT Contract / Blockchain
          _buildDetailRow(
            label: 'NFT Contract',
            value: _truncateAddress(deed.nft.contractAddress),
          ),
          _buildDivider(),
          _buildDetailRow(
            label: 'Blockchain',
            value: deed.nft.blockchain,
          ),
          _buildDivider(),
          
          // Row 4: Latitude / Longitude
          _buildDetailRow(
            label: 'Latitude',
            value: deed.latitude.toStringAsFixed(6),
          ),
          _buildDivider(),
          _buildDetailRow(
            label: 'Longitude',
            value: deed.longitude.toStringAsFixed(6),
          ),
          _buildDivider(),
          
          // Row 5: Payment Transaction ID / Payment Receiver
          _buildDetailRow(
            label: 'Payment Transaction ID',
            value: _truncateAddress(deed.payment.transactionId),
          ),
          _buildDivider(),
          _buildDetailRow(
            label: 'Payment Receiver',
            value: _truncateAddress(deed.payment.receiver),
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Build a detail row (2-column layout)
  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : 12,
        bottom: isLast ? 0 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column (label)
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                  ),
            ),
          ),
          const SizedBox(width: 16),
          // Right column (value)
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build divider
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.1),
    );
  }

  /// Truncate address for display
  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
  }

  /// Build issued info
  Widget _buildIssuedInfo(DateTime issuedAt) {
    return Column(
      children: [
        Text(
          'Issued: ${_formatDate(issuedAt)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Issued by\nWorldTile Registry',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Digitally Generated • No Physical Signature Required',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary.withOpacity(0.6),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Build verified seal (bottom-right)
  Widget _buildVerifiedSeal(String sealNo) {
    return Align(
      alignment: Alignment.centerRight,
      child: Transform.rotate(
        angle: -0.0523599, // -3 degrees in radians
        child: GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: BorderRadius.circular(100),
          backgroundColor: Colors.white.withOpacity(0.1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'WORLD TILE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'VERIFIED',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'DIGITAL LAND REGISTRY',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 1,
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(height: 8),
              Text(
                'SEAL NO',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 1,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 10,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                sealNo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

