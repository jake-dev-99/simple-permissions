package io.simplezen.simple_permissions_android

import android.app.role.RoleManager
import android.content.Context
import android.content.pm.PackageManager
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

internal class PermissionGuardsTest {

  private class Harness {
    val context: Context = mock(Context::class.java)
    val roleManager: RoleManager = mock(RoleManager::class.java)

    init {
      `when`(context.getSystemService(Context.ROLE_SERVICE))
        .thenReturn(roleManager)
      // Default: deny everything. Individual tests flip specific
      // permissions to granted. Matches ContextCompat.checkSelfPermission
      // fallthrough when the platform doesn't know the permission.
      `when`(context.checkPermission(anyString(), anyInt(), anyInt()))
        .thenReturn(PackageManager.PERMISSION_DENIED)
    }

    fun grant(permission: String) {
      `when`(
        context.checkPermission(
          org.mockito.ArgumentMatchers.eq(permission),
          anyInt(),
          anyInt(),
        )
      ).thenReturn(PackageManager.PERMISSION_GRANTED)
    }
  }

  // ── isPermissionGranted ───────────────────────────────────────────────

  @Test
  fun isPermissionGranted_trueWhenGranted() {
    val h = Harness()
    h.grant("android.permission.READ_SMS")
    assertTrue(
      PermissionGuards.isPermissionGranted(
        h.context, "android.permission.READ_SMS"
      )
    )
  }

  @Test
  fun isPermissionGranted_falseWhenDenied() {
    val h = Harness()
    // Defaults to denied; no grant() call.
    assertFalse(
      PermissionGuards.isPermissionGranted(
        h.context, "android.permission.READ_SMS"
      )
    )
  }

  @Test
  fun isPermissionGranted_falseForUnknownString() {
    val h = Harness()
    assertFalse(
      PermissionGuards.isPermissionGranted(h.context, "not.a.real.permission")
    )
  }

  // ── areAllPermissionsGranted ──────────────────────────────────────────

  @Test
  fun areAllPermissionsGranted_trueWhenAllGranted() {
    val h = Harness()
    h.grant("android.permission.READ_SMS")
    h.grant("android.permission.SEND_SMS")
    assertTrue(
      PermissionGuards.areAllPermissionsGranted(
        h.context,
        listOf("android.permission.READ_SMS", "android.permission.SEND_SMS")
      )
    )
  }

  @Test
  fun areAllPermissionsGranted_falseWhenAnyDenied() {
    val h = Harness()
    h.grant("android.permission.READ_SMS")
    // SEND_SMS stays at default-denied.
    assertFalse(
      PermissionGuards.areAllPermissionsGranted(
        h.context,
        listOf("android.permission.READ_SMS", "android.permission.SEND_SMS")
      )
    )
  }

  @Test
  fun areAllPermissionsGranted_emptyCollectionReturnsTrue() {
    // Vacuously true — no required permissions means nothing to
    // check. Matches `List.all` semantics; documenting here so a
    // future reader doesn't re-litigate.
    val h = Harness()
    assertTrue(
      PermissionGuards.areAllPermissionsGranted(h.context, emptyList())
    )
  }

  // ── isRoleHeld ────────────────────────────────────────────────────────

  @Test
  fun isRoleHeld_trueWhenAvailableAndHeld() {
    val h = Harness()
    `when`(h.roleManager.isRoleAvailable(RoleManager.ROLE_SMS)).thenReturn(true)
    `when`(h.roleManager.isRoleHeld(RoleManager.ROLE_SMS)).thenReturn(true)
    assertTrue(PermissionGuards.isRoleHeld(h.context, RoleManager.ROLE_SMS))
  }

  @Test
  fun isRoleHeld_falseWhenNotHeld() {
    val h = Harness()
    `when`(h.roleManager.isRoleAvailable(RoleManager.ROLE_SMS)).thenReturn(true)
    `when`(h.roleManager.isRoleHeld(RoleManager.ROLE_SMS)).thenReturn(false)
    assertFalse(PermissionGuards.isRoleHeld(h.context, RoleManager.ROLE_SMS))
  }

  @Test
  fun isRoleHeld_falseWhenRoleNotAvailableOnThisDevice() {
    val h = Harness()
    `when`(h.roleManager.isRoleAvailable("unknown.role")).thenReturn(false)
    assertFalse(PermissionGuards.isRoleHeld(h.context, "unknown.role"))
  }
}
