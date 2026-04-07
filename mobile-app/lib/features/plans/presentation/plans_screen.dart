import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose Plan',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                'Unlimited data, pay only for time',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              const _PlanCard(
                planId: 'wifi_2h',
                name: '2 Hours WiFi',
                duration: '2 Hours',
                price: 10,
                icon: Icons.flash_on_rounded,
                color: Color(0xFF00D9FF),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Fast speeds'
                ],
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                planId: 'wifi_3h',
                name: '3 Hours WiFi',
                duration: '3 Hours',
                price: 15,
                icon: Icons.router_rounded,
                color: Color(0xFF00E5FF),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Standard speeds'
                ],
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                planId: 'wifi_12h',
                name: '12 Hours WiFi',
                duration: '12 Hours',
                price: 40,
                icon: Icons.cloud_rounded,
                color: Color(0xFF0097A7),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Fast speeds',
                  'Save 39% vs hourly'
                ],
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                planId: 'wifi_1d',
                name: 'Daily WiFi',
                duration: '24 Hours',
                price: 80,
                icon: Icons.wb_sunny_rounded,
                color: Color(0xFF6C63FF),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Fast speeds',
                  'Save 50% vs 12h'
                ],
                isPopular: true,
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                planId: 'wifi_1w',
                name: 'Weekly WiFi',
                duration: '7 Days',
                price: 350,
                icon: Icons.calendar_today_rounded,
                color: Color(0xFF00E676),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Fast speeds',
                  'Save 38% vs daily'
                ],
              ),
              const SizedBox(height: 16),
              const _PlanCard(
                planId: 'wifi_1m',
                name: 'Monthly WiFi',
                duration: '30 Days',
                price: 700,
                icon: Icons.star_rounded,
                color: Color(0xFFFFAB40),
                features: [
                  'Unlimited data',
                  'All sites accessible',
                  'Fastest speeds',
                  'Save 33% vs weekly',
                  'Priority support'
                ],
                isBestValue: true,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String planId;
  final String name;
  final String duration;
  final int price;
  final IconData icon;
  final Color color;
  final List<String> features;
  final bool isPopular;
  final bool isBestValue;

  const _PlanCard({
    required this.planId,
    required this.name,
    required this.duration,
    required this.price,
    required this.icon,
    required this.color,
    required this.features,
    this.isPopular = false,
    this.isBestValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: (isPopular || isBestValue)
            ? Border.all(color: color.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: (isPopular || isBestValue)
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              )),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Popular',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          if (isBestValue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Best Value',
                                style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(duration,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$price',
                      style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: color, size: 18),
                            const SizedBox(width: 8),
                            Text(f,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Buy button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showPaymentDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withOpacity(0.15),
                  foregroundColor: color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Buy $name — KES $price',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text('$name Bundle',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Unlimited internet for $duration',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16)),
                  Text('KES $price',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('📱 Check your phone for M-Pesa prompt')),
                    );
                  },
                  icon: const Icon(Icons.phone_android_rounded),
                  label: const Text('Pay with M-Pesa',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
