import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = 'http://localhost:3000/api/v1';
const String _bootstrapUrl = 'http://localhost:8080';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
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
            final response = await Dio().post(
              '$_baseUrl/auth/refresh',
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
  return Dio(BaseOptions(
    baseUrl: _bootstrapUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
});
