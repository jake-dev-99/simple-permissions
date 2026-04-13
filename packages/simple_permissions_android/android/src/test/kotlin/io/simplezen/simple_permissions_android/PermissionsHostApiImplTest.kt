package io.simplezen.simple_permissions_android

import android.app.Activity
import android.app.AlarmManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.eq
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

internal class PermissionsHostApiImplTest {

  private class Harness {
    val context: Context = mock(Context::class.java)
    val roleManager: RoleManager = mock(RoleManager::class.java)
    val powerManager: PowerManager = mock(PowerManager::class.java)
    val alarmManager: AlarmManager = mock(AlarmManager::class.java)
    val packageManager: PackageManager = mock(PackageManager::class.java)
    val activity: Activity = mock(Activity::class.java)
    val activityBinding: ActivityPluginBinding = mock(ActivityPluginBinding::class.java)

    var sdkInt: Int = 34
    var providedActivity: Activity? = activity
    var providedActivityBinding: ActivityPluginBinding? = activityBinding

    val subject = PermissionsHostApiImpl(
      context = context,
      activityProvider = { providedActivity },
      activityBindingProvider = { providedActivityBinding },
      sdkIntProvider = { sdkInt },
    )

    init {
      `when`(context.packageName).thenReturn("io.simplezen.simple_permissions")
      `when`(context.packageManager).thenReturn(packageManager)
      `when`(context.getSystemService(Context.ROLE_SERVICE)).thenReturn(roleManager)
      `when`(context.getSystemService(Context.POWER_SERVICE)).thenReturn(powerManager)
      `when`(context.getSystemService(Context.ALARM_SERVICE)).thenReturn(alarmManager)
      `when`(powerManager.isIgnoringBatteryOptimizations(context.packageName)).thenReturn(false)
    }
  }

  @Test
  fun onAttachedToActivity_registersActivityResultListener() {
    val h = Harness()

    h.subject.onAttachedToActivity(h.activityBinding)

    verify(h.activityBinding).addActivityResultListener(h.subject)
  }

  @Test
  fun onDetachedFromActivity_removesActivityResultListener() {
    val h = Harness()

    h.subject.onDetachedFromActivity()

    verify(h.activityBinding).removeActivityResultListener(h.subject)
  }

  @Test
  fun isRoleHeld_returnsTrueWhenAvailableAndHeld() {
    val h = Harness()
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(true)

    val result = h.subject.isRoleHeld("android.app.role.SMS")

    assertTrue(result)
  }

  @Test
  fun requestRole_returnsFalseWithoutActivity() {
    val h = Harness()
    h.providedActivity = null

    var callbackValue: Boolean? = null
    h.subject.requestRole("android.app.role.SMS") { callbackValue = it.getOrNull() }

    assertEquals(false, callbackValue)
  }

  @Test
  fun requestRole_returnsTrueWhenAlreadyHeld() {
    val h = Harness()
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(true)

    var callbackValue: Boolean? = null
    h.subject.requestRole("android.app.role.SMS") { callbackValue = it.getOrNull() }

    assertEquals(true, callbackValue)
  }

  @Test
  fun requestRole_launchesRoleIntent_andCompletesOnActivityResult() {
    val h = Harness()
    val requestIntent = Intent("role-request")
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(false, true)
    `when`(h.roleManager.createRequestRoleIntent("android.app.role.SMS")).thenReturn(requestIntent)

    var callbackValue: Boolean? = null
    h.subject.requestRole("android.app.role.SMS") { callbackValue = it.getOrNull() }

    verify(h.activity).startActivityForResult(any(Intent::class.java), eq(9002))

    val consumed = h.subject.onActivityResult(9002, 0, null)
    assertTrue(consumed)
    assertEquals(true, callbackValue)
  }

  @Test
  fun requestRole_returnsRequestInProgressError_whenPending() {
    val h = Harness()
    val requestIntent = Intent("role-request")
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(false)
    `when`(h.roleManager.createRequestRoleIntent("android.app.role.SMS")).thenReturn(requestIntent)

    h.subject.requestRole("android.app.role.SMS") { }

    var errorCode: String? = null
    h.subject.requestRole("android.app.role.SMS") {
      errorCode = (it.exceptionOrNull() as? FlutterError)?.code
    }

    assertEquals("request-in-progress", errorCode)
  }

  @Test
  fun requestIgnoreBatteryOptimizations_returnsTrueWhenAlreadyIgnoring() {
    val h = Harness()
    `when`(h.powerManager.isIgnoringBatteryOptimizations(h.context.packageName)).thenReturn(true)

    var callbackValue: Boolean? = null
    h.subject.requestIgnoreBatteryOptimizations { callbackValue = it.getOrNull() }

    assertEquals(true, callbackValue)
    verify(h.activity, times(0)).startActivityForResult(any(Intent::class.java), eq(9003))
  }

  @Test
  fun requestIgnoreBatteryOptimizations_launchesIntent_andCompletesOnResult() {
    val h = Harness()
    `when`(h.powerManager.isIgnoringBatteryOptimizations(h.context.packageName))
      .thenReturn(false, true)

    var callbackValue: Boolean? = null
    h.subject.requestIgnoreBatteryOptimizations { callbackValue = it.getOrNull() }

    verify(h.activity).startActivityForResult(any(Intent::class.java), eq(9003))

    val consumed = h.subject.onActivityResult(9003, 0, null)
    assertTrue(consumed)
    assertEquals(true, callbackValue)
  }

  @Test
  fun requestIgnoreBatteryOptimizations_returnsRequestInProgressError_whenPending() {
    val h = Harness()
    `when`(h.powerManager.isIgnoringBatteryOptimizations(h.context.packageName)).thenReturn(false)

    h.subject.requestIgnoreBatteryOptimizations { }

    var errorCode: String? = null
    h.subject.requestIgnoreBatteryOptimizations {
      errorCode = (it.exceptionOrNull() as? FlutterError)?.code
    }

    assertEquals("request-in-progress", errorCode)
  }

  @Test
  fun openAppSettings_startsSettingsIntent_andReturnsTrue() {
    val h = Harness()

    val opened = h.subject.openAppSettings()

    assertTrue(opened)
    verify(h.context).startActivity(any(Intent::class.java))
  }

  @Test
  fun openAppSettings_returnsFalse_whenStartActivityThrows() {
    val h = Harness()
    doThrow(RuntimeException("boom"))
      .`when`(h.context)
      .startActivity(any(Intent::class.java))

    val opened = h.subject.openAppSettings()

    assertFalse(opened)
  }

  @Test
  fun onDetachedFromActivity_failsPendingCallbacks() {
    val h = Harness()
    `when`(h.alarmManager.canScheduleExactAlarms()).thenReturn(false)
    `when`(h.packageManager.canRequestPackageInstalls()).thenReturn(false)
    val requestIntent = Intent("role-request")
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(false)
    `when`(h.roleManager.createRequestRoleIntent("android.app.role.SMS")).thenReturn(requestIntent)

    var roleError: Throwable? = null
    h.subject.requestRole("android.app.role.SMS") { roleError = it.exceptionOrNull() }

    var batteryError: Throwable? = null
    h.subject.requestIgnoreBatteryOptimizations { batteryError = it.exceptionOrNull() }

    var scheduleError: Throwable? = null
    h.subject.requestScheduleExactAlarms { scheduleError = it.exceptionOrNull() }

    var installError: Throwable? = null
    h.subject.requestInstallPackages { installError = it.exceptionOrNull() }

    var overlayError: Throwable? = null
    h.subject.requestDrawOverlays { overlayError = it.exceptionOrNull() }

    var manageExternalError: Throwable? = null
    h.subject.requestManageExternalStorage { manageExternalError = it.exceptionOrNull() }

    h.subject.onDetachedFromActivity()

    assertNotNull(roleError)
    assertEquals("Activity detached", roleError?.message)
    assertNotNull(batteryError)
    assertEquals("Activity detached", batteryError?.message)
    assertNotNull(scheduleError)
    assertEquals("Activity detached", scheduleError?.message)
    assertNotNull(installError)
    assertEquals("Activity detached", installError?.message)
    assertNotNull(overlayError)
    assertEquals("Activity detached", overlayError?.message)
    assertNotNull(manageExternalError)
    assertEquals("Activity detached", manageExternalError?.message)
  }

  @Test
  fun requestScheduleExactAlarms_launchesIntentWithPackageUri() {
    val h = Harness()
    `when`(h.alarmManager.canScheduleExactAlarms()).thenReturn(false)

    var callbackValue: Boolean? = null
    h.subject.requestScheduleExactAlarms { callbackValue = it.getOrNull() }

    val intentCaptor = ArgumentCaptor.forClass(Intent::class.java)
    verify(h.activity).startActivityForResult(intentCaptor.capture(), eq(9004))
    val intent = intentCaptor.value
    assertEquals(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, intent.action)
    assertEquals("package:io.simplezen.simple_permissions", intent.dataString)
    assertEquals(null, callbackValue)
  }

  @Test
  fun checkPermissions_respectsVersionedApplicabilityGuards() {
    data class Case(
      val permission: String,
      val sdkInt: Int,
      val expectedGranted: Boolean,
    )

    val cases = listOf(
      Case("android.permission.BLUETOOTH_CONNECT", 30, true),
      Case("android.permission.BLUETOOTH_CONNECT", 31, false),
      Case("android.permission.BLUETOOTH", 31, true),
      Case("android.permission.BLUETOOTH", 30, false),
      Case("android.permission.NEARBY_WIFI_DEVICES", 32, true),
      Case("android.permission.NEARBY_WIFI_DEVICES", 33, false),
      Case("android.permission.ACTIVITY_RECOGNITION", 28, true),
      Case("android.permission.ACTIVITY_RECOGNITION", 29, false),
      Case("android.permission.READ_MEDIA_VISUAL_USER_SELECTED", 33, true),
      Case("android.permission.READ_MEDIA_VISUAL_USER_SELECTED", 34, false),
    )

    for (case in cases) {
      val h = Harness()
      h.sdkInt = case.sdkInt
      `when`(h.context.checkPermission(eq(case.permission), anyInt(), anyInt()))
        .thenReturn(PackageManager.PERMISSION_DENIED)
      val result = h.subject.checkPermissions(listOf(case.permission))
      assertEquals(case.expectedGranted, result[case.permission])
    }
  }

  @Test
  fun requestManageExternalStorage_launchesIntentWithPackageUri() {
    val h = Harness()
    h.sdkInt = 30

    var callbackValue: Boolean? = null
    h.subject.requestManageExternalStorage { callbackValue = it.getOrNull() }

    val intentCaptor = ArgumentCaptor.forClass(Intent::class.java)
    verify(h.activity).startActivityForResult(intentCaptor.capture(), eq(9007))
    val intent = intentCaptor.value
    assertEquals(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION, intent.action)
    assertEquals("package:io.simplezen.simple_permissions", intent.dataString)
    assertEquals(null, callbackValue)
  }

  @Test
  fun requestManageExternalStorage_returnsRequestInProgressError_whenPending() {
    val h = Harness()
    h.sdkInt = 30
    h.subject.requestManageExternalStorage { }

    var errorCode: String? = null
    h.subject.requestManageExternalStorage {
      errorCode = (it.exceptionOrNull() as? FlutterError)?.code
    }

    assertEquals("request-in-progress", errorCode)
  }

  @Test
  fun canManageExternalStorage_returnsTrueBelowApi30() {
    val h = Harness()
    h.sdkInt = 29

    val result = h.subject.canManageExternalStorage()

    assertTrue(result)
  }

  // =========================================================================
  // Overlay (draw overlays) — symmetric coverage
  // =========================================================================

  @Test
  fun requestDrawOverlays_returnsTrueWhenAlreadyGranted() {
    val h = Harness()
    // Settings.canDrawOverlays is static and hard to mock, so we test via
    // SDK < M path where canDrawOverlays always returns true.
    h.sdkInt = 22

    var callbackValue: Boolean? = null
    h.subject.requestDrawOverlays { callbackValue = it.getOrNull() }

    assertEquals(true, callbackValue)
    verify(h.activity, times(0)).startActivityForResult(any(Intent::class.java), eq(9006))
  }

  @Test
  fun requestDrawOverlays_launchesIntentWithPackageUri() {
    val h = Harness()
    // Need SDK >= M (23) and canDrawOverlays returning false.
    // Since Settings.canDrawOverlays is static, we need SDK >= 23 and the
    // default mock context which will cause canDrawOverlays to return false.
    h.sdkInt = 23

    h.subject.requestDrawOverlays { }

    val intentCaptor = ArgumentCaptor.forClass(Intent::class.java)
    verify(h.activity).startActivityForResult(intentCaptor.capture(), eq(9006))
    val intent = intentCaptor.value
    assertEquals(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, intent.action)
    assertEquals("package:io.simplezen.simple_permissions", intent.dataString)
  }

  @Test
  fun requestDrawOverlays_returnsRequestInProgressError_whenPending() {
    val h = Harness()
    h.sdkInt = 23
    h.subject.requestDrawOverlays { }

    var errorCode: String? = null
    h.subject.requestDrawOverlays {
      errorCode = (it.exceptionOrNull() as? FlutterError)?.code
    }

    assertEquals("request-in-progress", errorCode)
  }

  // =========================================================================
  // Install packages — symmetric coverage
  // =========================================================================

  @Test
  fun requestInstallPackages_returnsTrueWhenAlreadyGranted() {
    val h = Harness()
    // SDK < O path where canRequestInstallPackages always returns true.
    h.sdkInt = 25

    var callbackValue: Boolean? = null
    h.subject.requestInstallPackages { callbackValue = it.getOrNull() }

    assertEquals(true, callbackValue)
    verify(h.activity, times(0)).startActivityForResult(any(Intent::class.java), eq(9005))
  }

  @Test
  fun requestInstallPackages_launchesIntentWithPackageUri() {
    val h = Harness()
    h.sdkInt = 26
    `when`(h.packageManager.canRequestPackageInstalls()).thenReturn(false)

    h.subject.requestInstallPackages { }

    val intentCaptor = ArgumentCaptor.forClass(Intent::class.java)
    verify(h.activity).startActivityForResult(intentCaptor.capture(), eq(9005))
    val intent = intentCaptor.value
    assertEquals(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, intent.action)
    assertEquals("package:io.simplezen.simple_permissions", intent.dataString)
  }

  // =========================================================================
  // Schedule exact alarms — fill gaps
  // =========================================================================

  @Test
  fun requestScheduleExactAlarms_returnsTrueWhenAlreadyGranted() {
    val h = Harness()
    `when`(h.alarmManager.canScheduleExactAlarms()).thenReturn(true)

    var callbackValue: Boolean? = null
    h.subject.requestScheduleExactAlarms { callbackValue = it.getOrNull() }

    assertEquals(true, callbackValue)
    verify(h.activity, times(0)).startActivityForResult(any(Intent::class.java), eq(9004))
  }

  @Test
  fun requestScheduleExactAlarms_returnsRequestInProgressError_whenPending() {
    val h = Harness()
    `when`(h.alarmManager.canScheduleExactAlarms()).thenReturn(false)
    h.subject.requestScheduleExactAlarms { }

    var errorCode: String? = null
    h.subject.requestScheduleExactAlarms {
      errorCode = (it.exceptionOrNull() as? FlutterError)?.code
    }

    assertEquals("request-in-progress", errorCode)
  }
}
