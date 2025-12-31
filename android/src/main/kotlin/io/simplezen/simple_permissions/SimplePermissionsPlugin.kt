package io.simplezen.simple_permissions

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/**
 * Flutter plugin for unified permission handling.
 *
 * Provides a Pigeon-based API for:
 * - Runtime permission checks and requests
 * - App role management (SMS, Dialer)
 * - Battery optimization exemption
 */
class SimplePermissionsPlugin : FlutterPlugin, ActivityAware {

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
        permissionsHostApiImpl?.onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        permissionsHostApiImpl?.onDetachedFromActivity()
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        permissionsHostApiImpl?.onDetachedFromActivity()
        activityBinding = null
        activity = null
    }
}
