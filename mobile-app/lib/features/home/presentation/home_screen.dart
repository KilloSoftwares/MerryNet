import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back 👋',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Maranet Zero',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // VPN Status Card
              _VpnStatusCard(),
              const SizedBox(height: 20),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _QuickActionCard(
                    icon: Icons.flash_on_rounded,
                    label: 'Buy Bundle',
                    color: AppColors.accent,
                    onTap: () {},
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickActionCard(
                    icon: Icons.history_rounded,
                    label: 'History',
                    color: AppColors.primary,
                    onTap: () {},
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _QuickActionCard(
                    icon: Icons.share_rounded,
                    label: 'Refer',
                    color: AppColors.success,
                    onTap: () {},
                  )),
                ],
              ),
              const SizedBox(height: 24),

              // Plans Preview
              Text(
                'Popular Plans',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _PlanPreviewCard(
                title: 'Daily Bundle',
                subtitle: 'Unlimited internet for 24 hours',
                price: 'KES 30',
                icon: Icons.wb_sunny_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                ),
              ),
              const SizedBox(height: 12),
              _PlanPreviewCard(
                title: 'Weekly Bundle',
                subtitle: 'Unlimited internet for 7 days',
                price: 'KES 150',
                icon: Icons.calendar_today_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF00E676)],
                ),
              ),
              const SizedBox(height: 12),
              _PlanPreviewCard(
                title: 'Monthly Bundle',
                subtitle: 'Unlimited internet for 30 days',
                price: 'KES 500',
                icon: Icons.star_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFAB40), Color(0xFFFF5252)],
                ),
                isBestValue: true,
              ),
              const SizedBox(height: 24),

              // Stats
              Text(
                'Your Stats',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(
                    label: 'Data Used',
                    value: '2.4 GB',
                    icon: Icons.data_usage_rounded,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: 'Time Left',
                    value: '18h 32m',
                    icon: Icons.timer_rounded,
                  )),
                ],
              ),
              const SizedBox(height: 80), // Bottom nav spacing
            ],
          ),
        ),
      ),
    );
  }
}

class _VpnStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2440), Color(0xFF2A1F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'VPN Connected',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatusMetric(label: 'Download', value: '45.2 Mbps', icon: Icons.arrow_downward_rounded),
              Container(width: 1, height: 40, color: AppColors.surfaceLight),
              _StatusMetric(label: 'Upload', value: '12.8 Mbps', icon: Icons.arrow_upward_rounded),
              Container(width: 1, height: 40, color: AppColors.surfaceLight),
              _StatusMetric(label: 'Ping', value: '24 ms', icon: Icons.speed_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatusMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PlanPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final Gradient gradient;
  final bool isBestValue;

  const _PlanPreviewCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.gradient,
    this.isBestValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: isBestValue
            ? Border.all(color: AppColors.warning.withOpacity(0.4))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    if (isBestValue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Best Value', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
