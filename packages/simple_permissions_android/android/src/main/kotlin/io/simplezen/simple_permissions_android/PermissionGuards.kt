package io.simplezen.simple_permissions_android

import android.app.role.RoleManager
import android.content.Context
import android.content.Context.ROLE_SERVICE
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

/**
 * Native-side helpers that sibling Flutter plugins can call when they
 * need to **check** (read-only) whether a runtime permission is
 * granted or whether the app currently holds a default-app role.
 *
 * This keeps the single-source-of-truth stance for access state
 * across the plugin family: any *request* (surface a system dialog,
 * grant a role) goes through the Dart API on
 * `simple_permissions_native`; any *check* in native code can call
 * these helpers instead of reaching for [ContextCompat] /
 * [RoleManager] directly.
 *
 * ### Why this exists
 *
 * Plugins such as `simple_sms` and `simple_telephony` have code
 * paths that gate silent-fail behavior on a permission being held
 * (e.g. *"don't query SMS unless READ_SMS is granted, to avoid a
 * SecurityException"*). Those checks used to be written inline with
 * Android primitives (`ActivityCompat.checkSelfPermission(...)`),
 * which works but drifts from the "simple_permissions owns every
 * access-state vocabulary" rule established in
 * `simple_permissions_native` v1.2.
 *
 * [PermissionGuards] is the bridge — a thin, allocation-free
 * wrapper over the Android primitives that lives in the one place
 * that's already the vocabulary owner. Callers get a
 * documentation-by-import signal: the call site reads as
 * *"ask simple-permissions whether this is granted"*, not
 * *"ask Android"*.
 *
 * ### Gradle wiring for consumers
 *
 * Sibling plugins' Android modules that want to use these helpers
 * need a compile-time Gradle reference to this package. The minimum
 * wiring, in the consuming plugin's `android/build.gradle`:
 *
 * ```groovy
 * dependencies {
 *   implementation project(":simple_permissions_android")
 * }
 * ```
 *
 * A Flutter pub dep on `simple_permissions_native` alone is not
 * enough — Flutter's plugin system wires plugins into the app's
 * classpath but doesn't add them to other plugins' compile
 * classpaths. The project-dep line above is what makes
 * `PermissionGuards` importable.
 *
 * ### No requesting from here
 *
 * These helpers deliberately do not expose a "request permission"
 * equivalent. Request flows surface UI and route through activity
 * bindings — they belong in `PermissionsHostApiImpl` where the
 * Pigeon contract already marshals the lifecycle. Anything that
 * needs to *request* should go through the Dart API
 * (`SimplePermissionsNative.instance.request(...)`) so the prompt
 * is scoped by the user's consent flow, not by a random native
 * callsite.
 */
object PermissionGuards {

    /**
     * True iff [permission] is currently granted to this app.
     *
     * Read-only — does not surface any UI, does not trigger a
     * request, does not touch the permission state. Thread-safe.
     *
     * Equivalent to
     * `ContextCompat.checkSelfPermission(context, permission) ==
     *  PackageManager.PERMISSION_GRANTED`. Prefer this helper over
     * the primitive so access-state reads route through one API.
     *
     * [permission] is the manifest string (e.g.
     * `"android.permission.READ_SMS"`,
     * `android.Manifest.permission.READ_PHONE_STATE`). Unknown or
     * invalid strings return `false` — the platform treats them as
     * not-granted.
     */
    @JvmStatic
    fun isPermissionGranted(context: Context, permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) ==
                PackageManager.PERMISSION_GRANTED
    }

    /**
     * Convenience for [isPermissionGranted] over multiple
     * permissions. Returns true iff **all** of [permissions] are
     * granted — matches the semantics of a runtime precondition gate
     * (*"I need all of these before I can proceed"*). Use the
     * single-permission overload when you want to gate on an
     * individual permission.
     */
    @JvmStatic
    fun areAllPermissionsGranted(
        context: Context,
        permissions: Collection<String>,
    ): Boolean {
        return permissions.all { isPermissionGranted(context, it) }
    }

    /**
     * True iff this app currently holds the Android app role
     * identified by [roleId] (e.g.
     * [RoleManager.ROLE_SMS], [RoleManager.ROLE_DIALER]).
     *
     * Returns false on devices below Android 10 (API 29) because
     * [RoleManager] isn't installed — `getSystemService(ROLE_SERVICE)`
     * returns null there, which the null-check below catches. We
     * don't gate on SDK_INT explicitly to keep the helper testable
     * under JVM unit tests (where `Build.VERSION.SDK_INT` defaults
     * to zero and would short-circuit a naive guard).
     *
     * Returns false for role ids the platform considers unavailable
     * on this device. Read-only — does not prompt. For the request
     * flow, call `SimplePermissionsNative.instance.request(DefaultSmsApp())`
     * (or the appropriate role type) from Dart.
     */
    @JvmStatic
    fun isRoleHeld(context: Context, roleId: String): Boolean {
        val manager = context.getSystemService(ROLE_SERVICE) as? RoleManager
            ?: return false
        if (!manager.isRoleAvailable(roleId)) return false
        return manager.isRoleHeld(roleId)
    }
}
