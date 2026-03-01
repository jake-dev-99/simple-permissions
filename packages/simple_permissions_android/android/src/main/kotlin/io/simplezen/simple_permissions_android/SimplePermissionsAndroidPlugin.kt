package io.simplezen.simple_permissions_android

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter plugin for unified permission handling.
 *
 * Provides a Pigeon-based API for:
 * - Runtime permission checks and requests
 * - App role management (SMS, Dialer)
 * - Battery optimization exemption
 */
class SimplePermissionsAndroidPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var applicationContext: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var permissionsHostApiImpl: PermissionsHostApiImpl? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        permissionsHostApiImpl = PermissionsHostApiImpl(
            context = applicationContext,
            activityProvider = { activity },
            activityBindingProvider = { activityBinding }
        )

        PermissionsHostApi.setUp(binding.binaryMessenger, permissionsHostApiImpl)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PermissionsHostApi.setUp(binding.binaryMessenger, null)
        permissionsHostApiImpl = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        permissionsHostApiImpl?.onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        permissionsHostApiImpl?.onDetachedFromActivity()
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        permissionsHostApiImpl?.onDetachedFromActivity()
        activityBinding = null
        activity = null
    }

    // =========================================================================
    // RequestPermissionsResultListener
    // =========================================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        return permissionsHostApiImpl?.onRequestPermissionsResult(
            requestCode, permissions, grantResults
        ) ?: false
    }
}
