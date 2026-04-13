package io.simplezen.simple_permissions_android

import android.app.Activity
import android.app.AlarmManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Implementation of [PermissionsHostApi] for Android.
 *
 * Handles runtime permissions, app roles, and system settings using
 * Android's ActivityResultLauncher pattern for async callbacks.
 */
class PermissionsHostApiImpl(
    private val context: Context,
    private val activityProvider: () -> Activity?,
    private val activityBindingProvider: () -> ActivityPluginBinding?,
    private val sdkIntProvider: () -> Int = { Build.VERSION.SDK_INT }
) : PermissionsHostApi, PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "PermissionsHostApiImpl"
        private const val REQUEST_CODE_PERMISSIONS = 9001
        private const val REQUEST_CODE_ROLE = 9002
        private const val REQUEST_CODE_BATTERY = 9003
        private const val REQUEST_CODE_SCHEDULE_EXACT_ALARM = 9004
        private const val REQUEST_CODE_INSTALL_PACKAGES = 9005
        private const val REQUEST_CODE_OVERLAY = 9006
        private const val REQUEST_CODE_MANAGE_EXTERNAL_STORAGE = 9007
    }

    /**
     * Configuration for a system-setting request that follows the
     * check → launch-intent → re-check pattern.
     */
    private data class SystemSettingConfig(
        val checkGranted: () -> Boolean,
        val intentAction: String,
        val requestCode: Int,
        val label: String,
    )

    private val roleManager: RoleManager by lazy {
        context.getSystemService(Context.ROLE_SERVICE) as RoleManager
    }

    private val powerManager: PowerManager by lazy {
        context.getSystemService(Context.POWER_SERVICE) as PowerManager
    }

    private val alarmManager: AlarmManager by lazy {
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    }

    /** System-setting configs keyed by request code. */
    private val systemSettings: Map<Int, SystemSettingConfig> by lazy {
        mapOf(
            REQUEST_CODE_BATTERY to SystemSettingConfig(
                checkGranted = ::isIgnoringBatteryOptimizations,
                intentAction = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                requestCode = REQUEST_CODE_BATTERY,
                label = "battery optimization",
            ),
            REQUEST_CODE_SCHEDULE_EXACT_ALARM to SystemSettingConfig(
                checkGranted = ::canScheduleExactAlarms,
                intentAction = Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                requestCode = REQUEST_CODE_SCHEDULE_EXACT_ALARM,
                label = "schedule-exact-alarm",
            ),
            REQUEST_CODE_INSTALL_PACKAGES to SystemSettingConfig(
                checkGranted = ::canRequestInstallPackages,
                intentAction = Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                requestCode = REQUEST_CODE_INSTALL_PACKAGES,
                label = "install-packages",
            ),
            REQUEST_CODE_OVERLAY to SystemSettingConfig(
                checkGranted = ::canDrawOverlays,
                intentAction = Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                requestCode = REQUEST_CODE_OVERLAY,
                label = "overlay",
            ),
            REQUEST_CODE_MANAGE_EXTERNAL_STORAGE to SystemSettingConfig(
                checkGranted = ::canManageExternalStorage,
                intentAction = Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION,
                requestCode = REQUEST_CODE_MANAGE_EXTERNAL_STORAGE,
                label = "manage-external-storage",
            ),
        )
    }

    // Pending callbacks for async operations
    private var pendingPermissionsCallback: ((Result<Map<String, Boolean>>) -> Unit)? = null
    private var pendingRoleCallback: ((Result<Boolean>) -> Unit)? = null
    private val pendingSettingCallbacks = mutableMapOf<Int, (Result<Boolean>) -> Unit>()
    private var pendingPermissions: Array<String>? = null
    private var pendingPermissionResult: MutableMap<String, Boolean>? = null
    private var pendingRole: String? = null

    fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addActivityResultListener(this)
    }

    fun onDetachedFromActivity() {
        activityBindingProvider()?.removeActivityResultListener(this)
        // Cancel any pending callbacks
        pendingPermissionsCallback?.invoke(Result.failure(Exception("Activity detached")))
        pendingRoleCallback?.invoke(Result.failure(Exception("Activity detached")))
        for (callback in pendingSettingCallbacks.values) {
            callback.invoke(Result.failure(Exception("Activity detached")))
        }
        clearPendingState()
    }

    private fun clearPendingState() {
        pendingPermissionsCallback = null
        pendingRoleCallback = null
        pendingSettingCallbacks.clear()
        pendingPermissions = null
        pendingPermissionResult = null
        pendingRole = null
    }

    // =========================================================================
    // PermissionsHostApi Implementation
    // =========================================================================

    override fun checkPermissions(permissions: List<String>): Map<String, Boolean> {
        return permissions.associateWith { permission ->
            isPermissionGrantedOrNotRequired(permission)
        }
    }

    override fun requestPermissions(
        permissions: List<String>,
        callback: (Result<Map<String, Boolean>>) -> Unit
    ) {
        if (pendingPermissionsCallback != null) {
            callback(
                Result.failure(
                    FlutterError(
                        "request-in-progress",
                        "A permissions request is already in progress.",
                        "requestPermissions"
                    )
                )
            )
            return
        }

        val activity = activityProvider()
        if (activity == null) {
            Log.w(TAG, "requestPermissions called without attached activity")
            callback(Result.success(checkPermissions(permissions)))
            return
        }

        if (permissions.isEmpty()) {
            callback(Result.success(emptyMap()))
            return
        }

        // Check if all permissions are already granted
        val currentStatus = checkPermissions(permissions)
        if (currentStatus.values.all { it }) {
            callback(Result.success(currentStatus))
            return
        }

        val permissionsToRequest = permissions.filter { permission ->
            isPermissionApplicable(permission) && currentStatus[permission] != true
        }

        if (permissionsToRequest.isEmpty()) {
            callback(Result.success(currentStatus))
            return
        }

        // Store callback and request permissions
        pendingPermissionsCallback = callback
        pendingPermissions = permissionsToRequest.toTypedArray()
        pendingPermissionResult = currentStatus.toMutableMap()

        ActivityCompat.requestPermissions(
            activity,
            pendingPermissions!!,
            REQUEST_CODE_PERMISSIONS
        )
    }

    override fun isRoleHeld(roleId: String): Boolean {
        return try {
            roleManager.isRoleAvailable(roleId) && roleManager.isRoleHeld(roleId)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking role $roleId", e)
            false
        }
    }

    override fun requestRole(roleId: String, callback: (Result<Boolean>) -> Unit) {
        if (pendingRoleCallback != null) {
            callback(
                Result.failure(
                    FlutterError(
                        "request-in-progress",
                        "A role request is already in progress.",
                        "requestRole"
                    )
                )
            )
            return
        }

        val activity = activityProvider()
        if (activity == null) {
            Log.w(TAG, "requestRole called without attached activity")
            callback(Result.success(false))
            return
        }

        // Check if role is available
        if (!roleManager.isRoleAvailable(roleId)) {
            Log.w(TAG, "Role $roleId is not available on this device")
            callback(Result.success(false))
            return
        }

        // Check if already held
        if (roleManager.isRoleHeld(roleId)) {
            callback(Result.success(true))
            return
        }

        // Store callback and request role
        pendingRoleCallback = callback
        pendingRole = roleId

        val intent = roleManager.createRequestRoleIntent(roleId)
        activity.startActivityForResult(intent, REQUEST_CODE_ROLE)
    }

    override fun isIgnoringBatteryOptimizations(): Boolean {
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    override fun requestIgnoreBatteryOptimizations(callback: (Result<Boolean>) -> Unit) {
        requestSystemSetting(REQUEST_CODE_BATTERY, callback)
    }

    override fun canScheduleExactAlarms(): Boolean {
        if (sdkIntProvider() < Build.VERSION_CODES.S) return true
        return alarmManager.canScheduleExactAlarms()
    }

    override fun requestScheduleExactAlarms(callback: (Result<Boolean>) -> Unit) {
        requestSystemSetting(REQUEST_CODE_SCHEDULE_EXACT_ALARM, callback)
    }

    override fun canRequestInstallPackages(): Boolean {
        if (sdkIntProvider() < Build.VERSION_CODES.O) return true
        return context.packageManager.canRequestPackageInstalls()
    }

    override fun requestInstallPackages(callback: (Result<Boolean>) -> Unit) {
        requestSystemSetting(REQUEST_CODE_INSTALL_PACKAGES, callback)
    }

    override fun canDrawOverlays(): Boolean {
        if (sdkIntProvider() < Build.VERSION_CODES.M) return true
        return Settings.canDrawOverlays(context)
    }

    override fun requestDrawOverlays(callback: (Result<Boolean>) -> Unit) {
        requestSystemSetting(REQUEST_CODE_OVERLAY, callback)
    }

    override fun canManageExternalStorage(): Boolean {
        if (sdkIntProvider() < Build.VERSION_CODES.R) return true
        return Environment.isExternalStorageManager()
    }

    override fun requestManageExternalStorage(callback: (Result<Boolean>) -> Unit) {
        requestSystemSetting(REQUEST_CODE_MANAGE_EXTERNAL_STORAGE, callback)
    }

    /**
     * Generic request flow for system settings that follow the same pattern:
     * guard pending → check already granted → require activity → launch intent.
     */
    private fun requestSystemSetting(requestCode: Int, callback: (Result<Boolean>) -> Unit) {
        val config = systemSettings[requestCode]!!

        if (pendingSettingCallbacks.containsKey(requestCode)) {
            callback(
                Result.failure(
                    FlutterError(
                        "request-in-progress",
                        "A ${config.label} request is already in progress.",
                        config.label,
                    )
                )
            )
            return
        }

        if (config.checkGranted()) {
            callback(Result.success(true))
            return
        }

        val activity = activityProvider()
        if (activity == null) {
            Log.w(TAG, "${config.label} request called without attached activity")
            callback(Result.success(false))
            return
        }

        pendingSettingCallbacks[requestCode] = callback
        val intent = Intent(config.intentAction).apply {
            data = Uri.parse("package:${context.packageName}")
        }
        activity.startActivityForResult(intent, requestCode)
    }

    override fun getSdkVersion(): Long {
        return Build.VERSION.SDK_INT.toLong()
    }

    override fun shouldShowRequestPermissionRationale(
        permissions: List<String>
    ): Map<String, Boolean> {
        val activity = activityProvider() ?: return permissions.associateWith { false }
        return permissions.associateWith { permission ->
            ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        }
    }

    override fun openAppSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings", e)
            false
        }
    }

    // =========================================================================
    // ActivityResultListener
    // =========================================================================

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_ROLE) {
            handleRoleResult()
            return true
        }
        val config = systemSettings[requestCode]
        if (config != null) {
            handleSystemSettingResult(requestCode, config)
            return true
        }
        return false
    }

    /**
     * Called by Flutter framework when permission request completes.
     * This is invoked via [PluginRegistry.RequestPermissionsResultListener].
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_PERMISSIONS) return false

        val callback = pendingPermissionsCallback ?: return false
        val result = (pendingPermissionResult ?: mutableMapOf()).toMutableMap()
        permissions.zip(grantResults.toList()).forEach { (perm, grant) ->
            result[perm] = grant == PackageManager.PERMISSION_GRANTED
        }

        callback(Result.success(result))
        pendingPermissionsCallback = null
        pendingPermissions = null
        pendingPermissionResult = null
        return true
    }

    private fun isPermissionGrantedOrNotRequired(permission: String): Boolean {
        if (!isPermissionApplicable(permission)) return true
        return ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun isPermissionApplicable(permission: String): Boolean {
        return when (permission) {
            "android.permission.READ_EXTERNAL_STORAGE" ->
                sdkIntProvider() < Build.VERSION_CODES.TIRAMISU
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
            "android.permission.READ_MEDIA_AUDIO",
            "android.permission.NEARBY_WIFI_DEVICES",
            "android.permission.POST_NOTIFICATIONS" ->
                sdkIntProvider() >= Build.VERSION_CODES.TIRAMISU
            "android.permission.READ_MEDIA_VISUAL_USER_SELECTED" ->
                sdkIntProvider() >= 34
            "android.permission.BLUETOOTH_CONNECT",
            "android.permission.BLUETOOTH_SCAN",
            "android.permission.BLUETOOTH_ADVERTISE" ->
                sdkIntProvider() >= Build.VERSION_CODES.S
            "android.permission.BLUETOOTH",
            "android.permission.BLUETOOTH_ADMIN" ->
                sdkIntProvider() <= Build.VERSION_CODES.R
            "android.permission.ACTIVITY_RECOGNITION" ->
                sdkIntProvider() >= Build.VERSION_CODES.Q
            else -> true
        }
    }

    private fun handleRoleResult() {
        val callback = pendingRoleCallback ?: return
        val role = pendingRole

        val granted = if (role != null) {
            roleManager.isRoleHeld(role)
        } else {
            false
        }

        callback(Result.success(granted))
        pendingRoleCallback = null
        pendingRole = null
    }

    private fun handleSystemSettingResult(requestCode: Int, config: SystemSettingConfig) {
        val callback = pendingSettingCallbacks.remove(requestCode) ?: return
        callback(Result.success(config.checkGranted()))
    }
}
