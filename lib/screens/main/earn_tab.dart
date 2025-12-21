import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/referral_service.dart';
import '../../services/account_service.dart';
import '../../models/user_account.dart';
import '../../widgets/glass_card.dart';

class EarnPage extends StatefulWidget {
  const EarnPage({super.key});

  @override
  State<EarnPage> createState() => _EarnPageState();
}

class _EarnPageState extends State<EarnPage> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<dynamic> _propertiesSold = [];
  String? _errorMessage;
  UserAccount? _userAccount;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
    _loadUserAccount();
  }

  /// Load referral earnings from API
  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ReferralService.getReferralEarnings();
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _summary = result['summary'] ?? {};
            _propertiesSold = result['propertiesSold'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to load earnings';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading earnings: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Format USDT amount for display
  String _formatUSDT(String amount) {
    try {
      final value = double.parse(amount);
      if (value == 0) {
        return '0.00';
      }
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

  /// Load user account data to get referral code
  Future<void> _loadUserAccount() async {
    try {
      final account = await AccountService.getMyAccount();
      if (mounted) {
        setState(() {
          _userAccount = account;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user account: $e');
      }
    }
  }

  /// Share referral code via WhatsApp
  Future<void> _shareReferralCodeViaWhatsApp(String referralCode) async {
    try {
      // Create deep link URL - you can adjust the base URL to your app's actual domain
      // Format: https://yourdomain.com?ref=CODE or worldtile://?ref=CODE
      final deepLink = 'https://worldtile.app?ref=$referralCode';
      final message = '🌟 Join WorldTile Metaverse!\n\n'
          'Buy virtual land and build your digital empire! 🏰\n\n'
          'Use my referral code: $referralCode\n\n'
          'Download and use code when signing up:\n$deepLink';
      
      // Store referral code first
      await ReferralService.storePendingReferralCode(referralCode);
      
      // Try WhatsApp URL scheme directly (skip canLaunchUrl to avoid channel issues)
      try {
        // Encode the message for WhatsApp URL
        final encodedMessage = Uri.encodeComponent(message);
        
        // WhatsApp URL scheme - works on both mobile and web
        final whatsappUrl = 'https://wa.me/?text=$encodedMessage';
        final uri = Uri.parse(whatsappUrl);
        
        // Try to launch WhatsApp directly without checking first
        // This avoids the channel establishment error
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // If we get here, WhatsApp opened successfully
        return;
      } catch (launchError) {
        // If WhatsApp launch fails, fall back to clipboard
        if (kDebugMode) {
          print('WhatsApp launch failed, using clipboard fallback: $launchError');
        }
      }
      
      // Fallback: Copy to clipboard and show message
      // This works reliably on all platforms
      await Clipboard.setData(ClipboardData(text: message));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Message copied to clipboard! Open WhatsApp and paste it to share.',
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (kDebugMode) {
        print('Error sharing referral code: $e');
      }
    }
  }

  /// Copy referral code to clipboard
  void _copyReferralCode(String referralCode) {
    Clipboard.setData(ClipboardData(text: referralCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Referral code copied to clipboard'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Handle withdrawal request
  Future<void> _handleWithdrawal() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Withdraw Earnings'),
          content: Text(
            'You are about to withdraw ${_formatUSDT(_summary['totalEarningsUSDT'] ?? '0')} USDT.\n\n'
            'Please note: Withdrawal functionality is coming soon. Contact support for assistance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        // TODO: Implement withdrawal API call when backend is ready
        // For now, just show a message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal feature coming soon. Please contact support.'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing withdrawal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEarnings,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Your Referral Earnings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_summary['agentTitle'] != null)
              Text(
                _summary['agentTitle'] ?? 'Independent Land Agent',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            const SizedBox(height: 24),

            // Loading state
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
              )
            // Error state
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEarnings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            // Content
            else ...[
              // Referral Code Card
              if (_userAccount?.referralCode != null) ...[
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.share,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Referral Code',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _userAccount!.referralCode!,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, color: AppTheme.primaryColor),
                                  onPressed: () => _copyReferralCode(_userAccount!.referralCode!),
                                  tooltip: 'Copy code',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.green),
                                  onPressed: () => _shareReferralCodeViaWhatsApp(_userAccount!.referralCode!),
                                  tooltip: 'Share on WhatsApp',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Share your code with friends and earn ${((_summary['commissionRate'] ?? 0.25) * 100).toStringAsFixed(0)}% commission on their purchases!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Total earned card
              GlassCard(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                backgroundColor: AppTheme.accentColor.withOpacity(0.2),
                child: Column(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        size: 48,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total Earned',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatUSDT(_summary['totalEarningsUSDT'] ?? '0')} USDT',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Commission rate: ${((_summary['commissionRate'] ?? 0.25) * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
              ),
              const SizedBox(height: 16),
              
              // Withdrawal button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final totalEarnings = double.tryParse(_summary['totalEarningsUSDT'] ?? '0') ?? 0.0;
                    if (totalEarnings > 0) {
                      _handleWithdrawal();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No earnings available to withdraw'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Withdraw Earnings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Properties Sold',
                      value: '${_propertiesSold.length}',
                      icon: Icons.landscape,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Active Referrals',
                      value: '${_summary['totalReferrals'] ?? 0}',
                      icon: Icons.people,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Lifetime Earnings',
                value: '${_formatUSDT(_summary['totalEarningsUSDT'] ?? '0')} USDT',
                icon: Icons.account_balance_wallet,
                color: AppTheme.accentColor,
                fullWidth: true,
              ),
              const SizedBox(height: 24),

              // Properties sold list
              if (_propertiesSold.isNotEmpty) ...[
                Text(
                  'Properties Sold',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ..._propertiesSold.map((property) => _PropertyCard(
                      property: property,
                      formatUSDT: _formatUSDT,
                      formatDate: _formatDate,
                    )),
              ] else ...[
                GlassCard(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                      children: [
                        Icon(
                          Icons.landscape_outlined,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No properties sold yet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start referring friends to earn commissions!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: fullWidth ? double.infinity : null,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final String Function(String) formatUSDT;
  final String Function(String) formatDate;

  const _PropertyCard({
    required this.property,
    required this.formatUSDT,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buyer info
            Row(
              children: [
                const Icon(
                  Icons.person,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  property['buyerName'] ?? 'Anonymous Buyer',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Location
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${property['stateName'] ?? property['state'] ?? ''}, ${property['areaName'] ?? property['area'] ?? ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Details row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tiles sold
                Row(
                  children: [
                    const Icon(
                      Icons.landscape,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(property['slots'] as List?)?.length ?? 0} tile(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                // Commission
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: AppTheme.accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${formatUSDT(property['commissionUSDT'] ?? '0')} USDT',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  formatDate(property['date'] ?? ''),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
