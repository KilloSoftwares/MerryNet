package com.maranet.zero

import android.os.Bundle
import android.telephony.TelephonyManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CARRIER_CHANNEL = "com.maranet.zero/carrier"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CARRIER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCarrierInfo" -> {
                    try {
                        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                        val networkOperator = telephonyManager.networkOperator

                        if (networkOperator.length >= 5) {
                            val mcc = networkOperator.substring(0, 3)
                            val mnc = networkOperator.substring(3)
                            val carrierName = telephonyManager.networkOperatorName
                            val simCountry = telephonyManager.simCountryIso?.uppercase() ?: ""

                            val carrierInfo = mapOf(
                                "mcc" to mcc,
                                "mnc" to mnc,
                                "name" to carrierName,
                                "country" to simCountry,
                                "simState" to telephonyManager.simState
                            )
                            result.success(carrierInfo)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("CARRIER_ERROR", e.message, null)
                    }
                }
                "checkZeroRated" -> {
                    val domain = call.argument<String>("domain")
                    // In production, perform a test HTTP request to the domain
                    // to check if it's accessible without data balance
                    result.success(domain != null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
