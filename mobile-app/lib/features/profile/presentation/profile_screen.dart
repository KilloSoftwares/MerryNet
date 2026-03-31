import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                '+254 7XX XXX XXX',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active Subscriber',
                  style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
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
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 32),
                    const SizedBox(height: 12),
                    const Text('Your Referral Code',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('MARA-XK7P',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy & Share'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Menu Items
              _MenuItem(icon: Icons.history_rounded, label: 'Transaction History', onTap: () {}),
              _MenuItem(icon: Icons.subscriptions_rounded, label: 'Subscription History', onTap: () {}),
              _MenuItem(icon: Icons.store_rounded, label: 'Become a Reseller', onTap: () {}, badge: 'Earn 20%'),
              _MenuItem(icon: Icons.auto_awesome_rounded, label: 'Auto-Renew', onTap: () {}, trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeThumbColor: AppColors.success,
              )),
              const Divider(height: 32),
              _MenuItem(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () {}),
              _MenuItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
              _MenuItem(icon: Icons.info_outline_rounded, label: 'About', onTap: () {}),
              _MenuItem(icon: Icons.logout_rounded, label: 'Logout', onTap: () {}, isDestructive: true),
              const SizedBox(height: 24),
              const Text('Maranet Zero v1.0.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
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
            color: (isDestructive ? AppColors.error : AppColors.surfaceLight).withValues(alpha: isDestructive ? 0.15 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
      ),
    );
  }
}
