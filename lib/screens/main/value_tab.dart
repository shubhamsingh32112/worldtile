import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ValueTab extends StatelessWidget {
  const ValueTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total value card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondaryColor.withOpacity(0.3),
                    AppTheme.primaryColor.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Portfolio Value',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$0.00',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+0% (24h)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Value breakdown
          Text(
            'Value Breakdown',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _ValueItem(
            label: 'Land Tiles',
            value: '\$0.00',
            percentage: 0.0,
          ),
          const SizedBox(height: 12),
          _ValueItem(
            label: 'Crypto Holdings',
            value: '\$0.00',
            percentage: 0.0,
          ),
          const SizedBox(height: 12),
          _ValueItem(
            label: 'NFTs',
            value: '\$0.00',
            percentage: 0.0,
          ),
          const SizedBox(height: 24),
          // Chart placeholder
          Card(
            child: Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: AppTheme.primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Value Chart',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your portfolio performance over time',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueItem extends StatelessWidget {
  final String label;
  final String value;
  final double percentage;

  const _ValueItem({
    required this.label,
    required this.value,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: percentage >= 0
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

