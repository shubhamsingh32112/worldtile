import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../screens/account/account_screen.dart';
import '../layouts/navbar_constants.dart';

/// Global top account bar that appears on all pages
/// 
/// Glassmorphic floating navbar with user stats
/// Positioned at the top of the screen, overlaying content
class GlobalTopAccountBar extends StatefulWidget {
  const GlobalTopAccountBar({super.key});

  @override
  State<GlobalTopAccountBar> createState() => _GlobalTopAccountBarState();
}

class _GlobalTopAccountBarState extends State<GlobalTopAccountBar> {
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
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    return Positioned(
      top: safeAreaTop + NavbarConstants.topPadding,
      right: NavbarConstants.horizontalPadding,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showStats = !_showStats;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Glassmorphic account icon ONLY - no full-width bar
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: GestureDetector(
                  onTap: () {
                    // Navigate to account screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
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
                        : const Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
            // Stats overlay (shown when tapped) - borderless glass
            if (_showStats)
              Positioned(
                top: 56,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

