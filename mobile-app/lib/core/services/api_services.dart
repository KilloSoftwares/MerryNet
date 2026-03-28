import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

// ============================================================
// Models
// ============================================================

class Plan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int durationHours;

  Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationHours,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'KES',
      durationHours: json['durationHours'] as int? ?? json['duration_hours'] as int? ?? 0,
    );
  }

  String get durationLabel {
    if (durationHours <= 1) return '1 Hour';
    if (durationHours <= 24) return '24 Hours';
    if (durationHours <= 168) return '7 Days';
    return '30 Days';
  }
}

class Subscription {
  final String id;
  final String planId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final bool autoRenew;
  final Plan? plan;

  Subscription({
    required this.id,
    required this.planId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.autoRenew,
    this.plan,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      planId: json['planId'] as String? ?? json['plan_id'] as String? ?? '',
      startTime: DateTime.parse(json['startTime'] ?? json['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? json['end_time'] ?? DateTime.now().toIso8601String()),
      status: json['status'] as String? ?? 'ACTIVE',
      autoRenew: json['autoRenew'] as bool? ?? json['auto_renew'] as bool? ?? false,
      plan: json['plan'] != null ? Plan.fromJson(json['plan']) : null,
    );
  }

  bool get isActive => status == 'ACTIVE' && endTime.isAfter(DateTime.now());

  Duration get timeRemaining {
    final remaining = endTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get timeRemainingLabel {
    final d = timeRemaining;
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Expired';
  }
}

class PaymentResult {
  final String checkoutRequestId;
  final String merchantRequestId;
  final String planId;
  final double amount;

  PaymentResult({
    required this.checkoutRequestId,
    required this.merchantRequestId,
    required this.planId,
    required this.amount,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      checkoutRequestId: json['checkoutRequestId'] as String,
      merchantRequestId: json['merchantRequestId'] as String,
      planId: json['planId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UserProfile {
  final String id;
  final String phone;
  final String? referralCode;
  final bool autoRenew;
  final bool isReseller;
  final Subscription? activeSubscription;

  UserProfile({
    required this.id,
    required this.phone,
    this.referralCode,
    required this.autoRenew,
    required this.isReseller,
    this.activeSubscription,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      referralCode: json['referralCode'] as String?,
      autoRenew: json['autoRenew'] as bool? ?? false,
      isReseller: json['isReseller'] as bool? ?? false,
      activeSubscription: json['activeSubscription'] != null
          ? Subscription.fromJson(json['activeSubscription'])
          : null,
    );
  }
}

// ============================================================
// Services
// ============================================================

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _dio.post('/auth/login', data: {'phone': phone});
    return response.data['data'];
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final response = await _dio.post('/auth/verify', data: {
      'phone': phone,
      'code': code,
    });
    return response.data['data'];
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    return response.data['data'];
  }

  Future<UserProfile> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return UserProfile.fromJson(response.data['data']);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }
}

class PaymentService {
  final Dio _dio;

  PaymentService(this._dio);

  Future<PaymentResult> initiatePayment({
    required String planId,
    String? phone,
    bool autoRenew = false,
  }) async {
    final response = await _dio.post('/payments/initiate', data: {
      'planId': planId,
      if (phone != null) 'phone': phone,
      'autoRenew': autoRenew,
    });
    return PaymentResult.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> checkStatus(String checkoutRequestId) async {
    final response = await _dio.get('/payments/status/$checkoutRequestId');
    return response.data['data'];
  }

  Future<List<Map<String, dynamic>>> getTransactions({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/payments/transactions', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(response.data['data']);
  }
}

class SubscriptionService {
  final Dio _dio;

  SubscriptionService(this._dio);

  Future<List<Plan>> getPlans() async {
    final response = await _dio.get('/subscriptions/plans');
    final List data = response.data['data'];
    return data.map((p) => Plan.fromJson(p)).toList();
  }

  Future<Subscription?> getActiveSubscription() async {
    final response = await _dio.get('/subscriptions/active');
    final data = response.data['data'];
    if (data == null) return null;
    return Subscription.fromJson(data);
  }

  Future<List<Subscription>> getHistory({int page = 1, int limit = 20}) async {
    final response = await _dio.get('/subscriptions', queryParameters: {
      'page': page,
      'limit': limit,
    });
    final List data = response.data['data'];
    return data.map((s) => Subscription.fromJson(s)).toList();
  }
}

// ============================================================
// Providers
// ============================================================

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.watch(apiClientProvider));
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(apiClientProvider));
});

final plansProvider = FutureProvider<List<Plan>>((ref) async {
  return ref.watch(subscriptionServiceProvider).getPlans();
});

final activeSubscriptionProvider = FutureProvider<Subscription?>((ref) async {
  return ref.watch(subscriptionServiceProvider).getActiveSubscription();
});

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  return ref.watch(authServiceProvider).getProfile();
});
