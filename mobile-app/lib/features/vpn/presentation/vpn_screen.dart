import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class VpnScreen extends ConsumerStatefulWidget {
  const VpnScreen({super.key});

  @override
  ConsumerState<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends ConsumerState<VpnScreen>
    with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  bool _isConnecting = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleVpn() async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isConnected = !_isConnected;
      _isConnecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Text('VPN Shield', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                _isConnected ? 'Your connection is secured' : 'Tap to connect',
                style: TextStyle(
                  color: _isConnected ? AppColors.success : AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
              const Spacer(),

              // VPN Toggle Button
              GestureDetector(
                onTap: _toggleVpn,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse rings
                        if (_isConnected) ...[
                          _PulseRing(
                            animation: _pulseController,
                            size: 220,
                            color: AppColors.success,
                          ),
                          _PulseRing(
                            animation: _pulseController,
                            size: 260,
                            color: AppColors.success,
                            delay: 0.3,
                          ),
                        ],

                        // Main circle
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isConnected
                                ? AppColors.vpnActiveGradient
                                : LinearGradient(
                                    colors: [
                                      AppColors.surfaceLight,
                                      AppColors.card,
                                    ],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: _isConnected
                                    ? AppColors.success.withOpacity(0.3)
                                    : AppColors.primary.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isConnecting)
                                const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              else
                                Icon(
                                  _isConnected
                                      ? Icons.shield_rounded
                                      : Icons.power_settings_new_rounded,
                                  color: Colors.white,
                                  size: 56,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                _isConnecting
                                    ? 'Connecting...'
                                    : _isConnected
                                        ? 'Connected'
                                        : 'Disconnected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Spacer(),

              // Connection Details
              if (_isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _DetailRow('Server', 'Nairobi, Kenya 🇰🇪'),
                      const Divider(height: 24),
                      _DetailRow('IP Address', '10.0.1.42'),
                      const Divider(height: 24),
                      _DetailRow('Protocol', 'WireGuard'),
                      const Divider(height: 24),
                      _DetailRow('Time Left', '23h 14m'),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'You need an active subscription to connect',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Browse Plans'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }
}

class _PulseRing extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final Color color;
  final double delay;

  const _PulseRing({
    required this.animation,
    required this.size,
    required this.color,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = ((animation.value + delay) % 1.0);
        return Container(
          width: size * (0.8 + progress * 0.2),
          height: size * (0.8 + progress * 0.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3 * (1 - progress)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
