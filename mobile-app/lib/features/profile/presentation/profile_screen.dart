import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_services.dart';
import '../../../core/network/api_client.dart';
import 'package:go_router/go_router.dart';

// Provider to check if user has credentials
final hasCredentialsProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final token = await storage.read(key: 'access_token');
  return token != null && token.isNotEmpty;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCredentialsAsync = ref.watch(hasCredentialsProvider);

    return Scaffold(
      body: SafeArea(
        child: hasCredentialsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          data: (hasCredentials) {
            if (!hasCredentials) {
              // Fallback UI when no credentials
              return _buildNoCredentialsUI(context);
            }
            // Show profile when credentials exist
            return _buildProfileContent(context, ref);
          },
          error: (error, stack) => _buildNoCredentialsUI(context),
        ),
      ),
    );
  }

  Widget _buildNoCredentialsUI(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Sign In to Access Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Please sign in to view your profile,\nmanage subscriptions, and more.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Failed to load profile'),
            const SizedBox(height: 8),
            const Text(
              'Your session may have expired. Please sign in again.',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Clear any stale tokens and show login
                    ref.read(secureStorageProvider).deleteAll();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign In Again'),
                ),
              ),
            ),
          ],
        ),
      ),
      data: (userProfile) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              userProfile.phone,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userProfile.activeSubscription != null
                    ? 'Active Subscriber'
                    : 'No Active Subscription',
                style: TextStyle(
                  color: userProfile.activeSubscription != null
                      ? AppColors.success
                      : AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Referral Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1F5E), Color(0xFF1E2440)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.card_giftcard_rounded,
                      color: AppColors.accent, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Referral Code',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userProfile.referralCode ?? 'N/A',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _copyReferralCode(
                        context, userProfile.referralCode),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy & Share'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Menu Items
            _MenuItem(
                icon: Icons.history_rounded,
                label: 'Transaction History',
                onTap: () => _showComingSoon(context)),
            _MenuItem(
                icon: Icons.subscriptions_rounded,
                label: 'Subscription History',
                onTap: () => _showComingSoon(context)),
            _MenuItem(
                icon: Icons.store_rounded,
                label: 'Become a Reseller',
                onTap: () => _showComingSoon(context),
                badge: userProfile.isReseller ? null : 'Earn 20%'),
            _MenuItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Auto-Renew',
                onTap: () {},
                trailing: Switch(
                  value: userProfile.autoRenew,
                  onChanged: (value) =>
                      _toggleAutoRenew(context, ref, value),
                  activeThumbColor: AppColors.success,
                )),
            const Divider(height: 32),
            _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () => _showComingSoon(context)),
            _MenuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => _showComingSoon(context)),
            _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'About',
                onTap: () => _showComingSoon(context)),
            _MenuItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                onTap: () => _logout(context, ref),
                isDestructive: true),
            const SizedBox(height: 24),
            const Text(
              'Maranet Zero v1.0.0',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _copyReferralCode(BuildContext context, String? code) {
    if (code != null) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code copied to clipboard')),
      );
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  Future<void> _toggleAutoRenew(
      BuildContext context, WidgetRef ref, bool value) async {
    // TODO: Implement API call to update auto-renew setting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto-renew ${value ? 'enabled' : 'disabled'}')),
    );
    // Invalidate profile to refresh data
    ref.invalidate(userProfileProvider);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storage = ref.read(secureStorageProvider);
        final refreshToken = await storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          final authService = ref.read(authServiceProvider);
          await authService.logout(refreshToken);
        }

        // Clear stored tokens
        await storage.delete(key: 'access_token');
        await storage.delete(key: 'refresh_token');

        if (context.mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
        }
      }
    }
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Widget? trailing;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    final iconColor = isDestructive ? AppColors.error : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDestructive ? AppColors.error : AppColors.surfaceLight)
                .withValues(alpha: isDestructive ? 0.15 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 15, fontWeight: FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 22),
      ),
    );
  }
}
