import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/server_config.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for the current API base URL from server config
final apiBaseUrlProvider = Provider<String>((ref) {
  return ServerConfig().apiBaseUrl;
});

/// Provider for the current bootstrap URL from server config
final bootstrapUrlProvider = Provider<String>((ref) {
  return ServerConfig().bootstrapUrl;
});

/// Provider for the current server endpoint
final currentEndpointProvider = Provider<ServerEndpoint>((ref) {
  return ServerConfig().currentEndpoint;
});

final apiClientProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Auth interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final storage = ref.read(secureStorageProvider);
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Try to refresh token
        final storage = ref.read(secureStorageProvider);
        final refreshToken = await storage.read(key: 'refresh_token');
        if (refreshToken != null) {
          try {
            final currentBaseUrl = ref.read(apiBaseUrlProvider);
            final response = await Dio().post(
              '$currentBaseUrl/auth/refresh',
              data: {'refreshToken': refreshToken},
            );
            final data = response.data['data'];
            await storage.write(key: 'access_token', value: data['accessToken']);
            await storage.write(key: 'refresh_token', value: data['refreshToken']);

            // Retry the original request
            error.requestOptions.headers['Authorization'] = 'Bearer ${data['accessToken']}';
            final retryResponse = await dio.fetch(error.requestOptions);
            handler.resolve(retryResponse);
            return;
          } catch (_) {
            // Refresh failed, clear tokens
            await storage.deleteAll();
          }
        }
      }
      handler.next(error);
    },
  ));

  // Logging interceptor (debug only)
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    logPrint: (o) => print('🌐 $o'),
  ));

  return dio;
});

final bootstrapClientProvider = Provider<Dio>((ref) {
  final bootstrapUrl = ref.watch(bootstrapUrlProvider);
  
  return Dio(BaseOptions(
    baseUrl: bootstrapUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});

/// Provider that exposes the ServerConfig singleton
final serverConfigProvider = Provider<ServerConfig>((ref) {
  return ServerConfig();
});