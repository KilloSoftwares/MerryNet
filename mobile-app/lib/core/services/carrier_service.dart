import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Carrier information detected from the SIM card
class CarrierInfo {
  final String name;
  final String mcc; // Mobile Country Code
  final String mnc; // Mobile Network Code
  final String? isoCountry;
  final bool isZeroRatedAvailable;
  final String? zeroRatedDomain;

  CarrierInfo({
    required this.name,
    required this.mcc,
    required this.mnc,
    this.isoCountry,
    this.isZeroRatedAvailable = false,
    this.zeroRatedDomain,
  });

  /// Kenyan carrier detection
  static CarrierInfo fromMccMnc(String mcc, String mnc) {
    // Kenya MCC = 639
    if (mcc == '639') {
      switch (mnc) {
        case '02': // Safaricom
          return CarrierInfo(
            name: 'Safaricom',
            mcc: mcc,
            mnc: mnc,
            isoCountry: 'KE',
            isZeroRatedAvailable: true,
            zeroRatedDomain: 'free.facebook.com.maranet.app',
          );
        case '03': // Airtel Kenya
          return CarrierInfo(
            name: 'Airtel',
            mcc: mcc,
            mnc: mnc,
            isoCountry: 'KE',
            isZeroRatedAvailable: true,
            zeroRatedDomain: 'zero.airtel.maranet.app',
          );
        case '07': // Telkom Kenya
          return CarrierInfo(
            name: 'Telkom',
            mcc: mcc,
            mnc: mnc,
            isoCountry: 'KE',
            isZeroRatedAvailable: false,
          );
        default:
          return CarrierInfo(
            name: 'Unknown (KE)',
            mcc: mcc,
            mnc: mnc,
            isoCountry: 'KE',
          );
      }
    }

    return CarrierInfo(
      name: 'Unknown Carrier',
      mcc: mcc,
      mnc: mnc,
    );
  }
}

/// Service to detect the user's mobile carrier via platform channels
class CarrierDetectionService {
  static const _channel = MethodChannel('com.maranet.zero/carrier');

  /// Detect the current carrier
  Future<CarrierInfo> detectCarrier() async {
    try {
      final result = await _channel.invokeMethod('getCarrierInfo');
      if (result != null) {
        final mcc = result['mcc'] as String? ?? '';
        final mnc = result['mnc'] as String? ?? '';
        return CarrierInfo.fromMccMnc(mcc, mnc);
      }
    } on PlatformException catch (e) {
      print('Carrier detection failed: ${e.message}');
    } on MissingPluginException {
      print('Carrier detection not available on this platform');
    }

    // Fallback: assume Safaricom (most common in Kenya)
    return CarrierInfo(
      name: 'Safaricom (assumed)',
      mcc: '639',
      mnc: '02',
      isoCountry: 'KE',
      isZeroRatedAvailable: true,
      zeroRatedDomain: 'free.facebook.com.maranet.app',
    );
  }

  /// Check if zero-rated access is available
  Future<bool> checkZeroRatedAccess(String domain) async {
    try {
      final result = await _channel.invokeMethod('checkZeroRated', {
        'domain': domain,
      });
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}

// Provider
final carrierServiceProvider = Provider<CarrierDetectionService>((ref) {
  return CarrierDetectionService();
});

final carrierInfoProvider = FutureProvider<CarrierInfo>((ref) async {
  return ref.watch(carrierServiceProvider).detectCarrier();
});
