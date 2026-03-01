package io.simplezen.simple_permissions_android

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
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
    val activity: Activity = mock(Activity::class.java)
    val activityBinding: ActivityPluginBinding = mock(ActivityPluginBinding::class.java)

    var providedActivity: Activity? = activity
    var providedActivityBinding: ActivityPluginBinding? = activityBinding

    val subject = PermissionsHostApiImpl(
      context = context,
      activityProvider = { providedActivity },
      activityBindingProvider = { providedActivityBinding },
    )

    init {
      `when`(context.packageName).thenReturn("io.simplezen.simple_permissions")
      `when`(context.getSystemService(Context.ROLE_SERVICE)).thenReturn(roleManager)
      `when`(context.getSystemService(Context.POWER_SERVICE)).thenReturn(powerManager)
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
    val requestIntent = Intent("role-request")
    `when`(h.roleManager.isRoleAvailable("android.app.role.SMS")).thenReturn(true)
    `when`(h.roleManager.isRoleHeld("android.app.role.SMS")).thenReturn(false)
    `when`(h.roleManager.createRequestRoleIntent("android.app.role.SMS")).thenReturn(requestIntent)

    var roleError: Throwable? = null
    h.subject.requestRole("android.app.role.SMS") { roleError = it.exceptionOrNull() }

    var batteryError: Throwable? = null
    h.subject.requestIgnoreBatteryOptimizations { batteryError = it.exceptionOrNull() }

    h.subject.onDetachedFromActivity()

    assertNotNull(roleError)
    assertEquals("Activity detached", roleError?.message)
    assertNotNull(batteryError)
    assertEquals("Activity detached", batteryError?.message)
  }
}
