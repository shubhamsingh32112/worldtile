import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/referral_service.dart';

/// Dialog to capture referral code before Google sign-in
class ReferralCodeDialog extends StatefulWidget {
  const ReferralCodeDialog({super.key});

  @override
  State<ReferralCodeDialog> createState() => _ReferralCodeDialogState();
}

class _ReferralCodeDialogState extends State<ReferralCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim().toUpperCase();
      await ReferralService.storePendingReferralCode(code);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate code was entered
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error storing referral code: ${e.toString()}'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('Enter Referral Code'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Have a referral code? Enter it below (optional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Referral Code',
                hintText: 'ABC12345',
                prefixIcon: const Icon(Icons.code),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length < 4) {
                    return 'Referral code must be at least 4 characters';
                  }
                }
                return null; // Optional field
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}

