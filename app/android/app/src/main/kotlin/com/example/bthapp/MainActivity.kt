package com.example.bthapp

import android.Manifest
import android.app.AlertDialog
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val PERM_CHANNEL = "perm.channel"
    private val MDNS_CHANNEL = "mdns.channel"

    private val REQ_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    // ---- mDNS ----
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---------- Permisos ----------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasWifiPermission" -> result.success(hasWifiPerm())
                    "requestWifiPermission" -> requestDirect(result)
                    "requestWifiPermissionWithPrompt" -> {
                        val title = call.argument<String>("title")
                        val message = call.argument<String>("message")
                        requestWithPrompt(result, title, message)
                    }
                    "isLocationServiceEnabled" -> {
                        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
                        val on = lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                                 lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                        result.success(on)
                    }
                    else -> result.notImplemented()
                }
            }

        // ---------- mDNS (MulticastLock) ----------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MDNS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            if (multicastLock?.isHeld != true) {
                                multicastLock = wm.createMulticastLock("mdns-lock")
                                multicastLock?.setReferenceCounted(true)
                                multicastLock?.acquire()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "release" -> {
                        try {
                            if (multicastLock?.isHeld == true) multicastLock?.release()
                            multicastLock = null
                            result.success(null) // void
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // -------- helpers de permiso --------

    private fun currentPermission(): String =
        if (Build.VERSION.SDK_INT >= 33)
            Manifest.permission.NEARBY_WIFI_DEVICES
        else
            Manifest.permission.ACCESS_FINE_LOCATION

    private fun hasWifiPerm(): Boolean {
        val perm = currentPermission()
        return ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestDirect(result: MethodChannel.Result) {
        val perm = currentPermission()
        if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(this, arrayOf(perm), REQ_CODE)
    }

    private fun requestWithPrompt(
        result: MethodChannel.Result,
        title: String?,
        message: String?
    ) {
        val perm = currentPermission()
        if (ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        AlertDialog.Builder(this)
            .setTitle(title ?: "Permiso necesario")
            .setMessage(message ?: "Para detectar y configurar tu dispositivo por Wi-Fi, " +
                    "necesitamos este permiso. Toca “Continuar” y luego “Permitir”.")
            .setCancelable(false)
            .setNegativeButton("Cancelar") { _, _ -> result.success(false) }
            .setPositiveButton("Continuar") { _, _ ->
                pendingResult = result
                ActivityCompat.requestPermissions(this, arrayOf(perm), REQ_CODE)
            }
            .show()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CODE) {
            val ok = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(ok)
            pendingResult = null
        }
    }
}
