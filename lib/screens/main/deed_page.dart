import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/user_service.dart';
import '../../widgets/glass_card.dart';
import '../deed/deed_detail_page.dart';

/// Deed page showing all lands owned by the user
class DeedPage extends StatefulWidget {
  const DeedPage({super.key});

  @override
  State<DeedPage> createState() => _DeedPageState();
}

class _DeedPageState extends State<DeedPage> {
  bool _isLoading = true;
  List<dynamic> _lands = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserLands();
  }

  /// Load user lands from API
  Future<void> _loadUserLands() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await UserService.getUserLands();
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _lands = result['lands'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load lands';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading lands: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Get state name from land data (prefer stateName, fallback to formatted stateKey)
  String _getStateName(Map<String, dynamic> land) {
    if (land['stateName'] != null && land['stateName'].toString().isNotEmpty) {
      return land['stateName'];
    }
    final stateKey = land['stateKey'] ?? '';
    if (stateKey.isEmpty) return stateKey;
    return stateKey[0].toUpperCase() + stateKey.substring(1).replaceAll('_', ' ');
  }

  /// Get area name from land data (prefer areaName, fallback to formatted areaKey)
  String _getAreaName(Map<String, dynamic> land) {
    if (land['areaName'] != null && land['areaName'].toString().isNotEmpty) {
      return land['areaName'];
    }
    final areaKey = land['areaKey'] ?? '';
    if (areaKey.isEmpty) return areaKey;
    return areaKey[0].toUpperCase() + areaKey.substring(1).replaceAll('_', ' ');
  }

  /// Format USDT amount for display
  String _formatUSDT(String amount) {
    try {
      final value = double.parse(amount);
      return value.toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  /// Format date for display
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Deeds',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (!_isLoading)
                  TextButton.icon(
                    onPressed: _loadUserLands,
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUserLands,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _lands.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.landscape_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No lands owned yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Purchases will appear here',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUserLands,
                            color: AppTheme.primaryColor,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _lands.length,
                              itemBuilder: (context, index) {
                                final land = _lands[index];
                                return _buildLandCard(context, land);
                              },
                            ),
                          ),
          ),
        ],
    );
  }

  /// Build a card for a single land
  Widget _buildLandCard(BuildContext context, Map<String, dynamic> land) {
    final stateKey = land['stateKey'] ?? '';
    final areaKey = land['areaKey'] ?? '';
    final landSlotId = land['landSlotId'] ?? '';
    final purchasePrice = land['purchasePriceUSDT'] ?? '0';
    final purchasedAt = land['purchasedAt'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeedDetailPage(propertyId: landSlotId),
          ),
        );
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Land slot ID
            Row(
              children: [
                const Icon(
                  Icons.landscape,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    landSlotId,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location info
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_getStateName(land)}, ${_getAreaName(land)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Purchase details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Purchase date
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(purchasedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                // Purchase price
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: AppTheme.accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatUSDT(purchasePrice)} USDT',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // View Deed button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeedDetailPage(propertyId: landSlotId),
                    ),
                  );
                },
                icon: const Icon(Icons.description, size: 18),
                label: const Text('View Deed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

