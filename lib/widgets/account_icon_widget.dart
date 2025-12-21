import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../screens/account/account_screen.dart';

/// Account icon widget that displays user stats (lands owned, referral earnings)
/// Shows an account icon in the top right with stats overlay on tap
class AccountIconWidget extends StatefulWidget {
  const AccountIconWidget({super.key});

  @override
  State<AccountIconWidget> createState() => _AccountIconWidgetState();
}

class _AccountIconWidgetState extends State<AccountIconWidget> {
  bool _isLoading = true;
  int _landsOwned = 0;
  String _referralEarningsUSDT = '0';
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  /// Load user statistics from API
  Future<void> _loadUserStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await UserService.getUserStats();
      if (result['success'] == true && mounted) {
        final stats = result['stats'] as Map<String, dynamic>;
        setState(() {
          _landsOwned = stats['landsOwned'] ?? 0;
          _referralEarningsUSDT = stats['referralEarningsUSDT'] ?? '0';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
        return '0';
      }
      // Format to 2 decimal places, remove trailing zeros
      return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    } catch (e) {
      return '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showStats = !_showStats;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Account icon button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      onPressed: () {
                        // Navigate to account screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AccountScreen(),
                          ),
                        );
                      },
                    ),
            ),
            // Stats overlay (shown when tapped)
            if (_showStats)
              Positioned(
                top: 56,
                right: 0,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lands owned
                      Row(
                        children: [
                          const Icon(
                            Icons.landscape,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lands Owned',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                                Text(
                                  '$_landsOwned',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Referral earnings
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.accentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Referral Earnings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                ),
                                Text(
                                  '${_formatUSDT(_referralEarningsUSDT)} USDT',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

