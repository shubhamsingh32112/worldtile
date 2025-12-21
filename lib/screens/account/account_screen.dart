import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/account_service.dart';
import '../../models/user_account.dart';
import '../../layouts/app_shell.dart';
import '../onboarding/onboarding_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  UserAccount? _account;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAddingReferral = false;
  final TextEditingController _referralCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final account = await AccountService.getMyAccount();
      if (mounted) {
        setState(() {
          _account = account;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is AccountException && e.isUnauthorized) {
        // Force logout on unauthorized
        await _handleLogout(context);
        return;
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAddReferralCode() async {
    final code = _referralCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showToast('Please enter a referral code');
      return;
    }

    setState(() {
      _isAddingReferral = true;
    });

    try {
      final updatedAccount = await AccountService.addReferralCode(code);
      if (mounted) {
        setState(() {
          _account = updatedAccount;
          _referralCodeController.clear();
          _isAddingReferral = false;
        });
        _showToast('Referral linked successfully', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAddingReferral = false;
        });
        _showToast(e.toString());
      }
    }
  }

  void _showToast(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('firebase_uid');
    await prefs.remove('authenticated');

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('Copied to clipboard', isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppShell(
        title: 'Account',
        showBackButton: true,
        showBottomNav: false,
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading account...',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAccountData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_account == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logout button (top right)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.textPrimary),
                onPressed: () => _handleLogout(context),
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Glass Profile Card
          _buildGlassProfileCard(_account!),
          const SizedBox(height: 24),

          // 2. Agent Stats (3 glass cards)
          _buildAgentStats(_account!),
          const SizedBox(height: 24),

          // 3. Referral Code Section (Conditional)
          _buildReferralCodeSection(_account!),
          const SizedBox(height: 24),

          // 4. Your Referral Code (Always Visible)
          _buildYourReferralCode(_account!),
          const SizedBox(height: 24),

          // 5. Wallet Section
          _buildWalletSection(_account!),
        ],
      ),
    );
  }

  // 1. Glass Profile Card
  Widget _buildGlassProfileCard(UserAccount account) {
    return _GlassCard(
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.secondaryColor.withOpacity(0.3),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: account.photoUrl != null && account.photoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      account.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          account.initials,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      account.initials,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            account.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            account.email,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Agent Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Text(
              account.agentProfile.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Agent Stats (3 glass cards)
  Widget _buildAgentStats(UserAccount account) {
    return Row(
      children: [
        Expanded(
          child: _GlassStatCard(
            icon: Icons.percent,
            label: 'Commission',
            value: '${account.agentProfile.commissionRatePercent}%',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassStatCard(
            icon: Icons.account_balance_wallet,
            label: 'Earnings',
            value: '${account.referralStats.earningsAsDouble.toStringAsFixed(2)} USDT',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassStatCard(
            icon: Icons.people,
            label: 'Referrals',
            value: '${account.referralStats.totalReferrals}',
            color: AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }

  // 3. Referral Code Section (Conditional)
  Widget _buildReferralCodeSection(UserAccount account) {
    if (account.isReferred) {
      // Case A: Already referred - show locked state
      return _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Referral code locked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You were referred by another agent',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      );
    } else {
      // Case B: Not referred - show input
      return _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Referral Code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referralCodeController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter referral code',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () => _referralCodeController.clear(),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) {
                // Auto uppercase
                if (value != value.toUpperCase()) {
                  _referralCodeController.value = TextEditingValue(
                    text: value.toUpperCase(),
                    selection: _referralCodeController.selection,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAddingReferral
                    ? null
                    : _handleAddReferralCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAddingReferral
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
                    : const Text(
                        'Apply Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // 4. Your Referral Code (Always Visible)
  Widget _buildYourReferralCode(UserAccount account) {
    if (account.referralCode == null) {
      return const SizedBox.shrink();
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Referral Code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  account.referralCode!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppTheme.primaryColor,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppTheme.primaryColor),
                  onPressed: () => _copyToClipboard(account.referralCode!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Earn ${account.agentProfile.commissionRatePercent}% commission on every purchase made using your code',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // 5. Wallet Section
  Widget _buildWalletSection(UserAccount account) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Wallet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (account.walletAddress != null && account.walletAddress!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _maskAddress(account.walletAddress!),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: AppTheme.textSecondary,
                      onPressed: () => _copyToClipboard(account.walletAddress!),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              'Connect wallet (coming soon)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
        ],
      ),
    );
  }

  String _maskAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

// Glass Card Widget
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GlassCard({
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Glass Stat Card Widget
class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _GlassStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
