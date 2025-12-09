import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class EarnTab extends StatelessWidget {
  const EarnTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earning opportunities card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentColor.withOpacity(0.3),
                    AppTheme.secondaryColor.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
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
                    '\$0.00',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Earning Opportunities',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _EarnCard(
            title: 'Rent Your Land',
            description: 'Earn passive income by renting out your virtual land tiles',
            icon: Icons.home,
            color: AppTheme.primaryColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rent your land feature coming soon'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _EarnCard(
            title: 'Referral Program',
            description: 'Invite friends and earn rewards for each referral',
            icon: Icons.people,
            color: AppTheme.secondaryColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Referral program coming soon'),
                  backgroundColor: AppTheme.secondaryColor,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _EarnCard(
            title: 'Staking Rewards',
            description: 'Stake your tokens and earn daily rewards',
            icon: Icons.account_balance_wallet,
            color: AppTheme.accentColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Staking rewards coming soon'),
                  backgroundColor: AppTheme.accentColor,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _EarnCard(
            title: 'Marketplace Sales',
            description: 'Sell your virtual assets on the marketplace',
            icon: Icons.store,
            color: AppTheme.primaryColor,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Marketplace coming soon'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EarnCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _EarnCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

