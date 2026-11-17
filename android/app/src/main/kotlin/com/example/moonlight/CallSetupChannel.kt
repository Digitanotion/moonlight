package com.app.moonlightstream

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Checks and settings shortcuts for the "Set up calls" guide that Flutter
 * plugins don't cover: the incoming-call notification channel, full-screen
 * call alerts (Android 14+) and the phone maker's auto-start page.
 */
object CallSetupChannel {
    private const val NAME = "com.app.moonlightstream/call_setup"

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "info" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER.lowercase(),
                            "brand" to Build.BRAND.lowercase(),
                            "sdk" to Build.VERSION.SDK_INT,
                            "hasAutostartPage" to hasAutostart(),
                            "hasLockScreenSwitches" to hasLockScreenSwitches(),
                        )
                    )
                    // true = the call ringtone channel is switched off or silent.
                    "callChannelBlocked" -> {
                        val id = call.argument<String>("channelId") ?: ""
                        result.success(channelBlocked(context, id))
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreen(context))
                    // Phone makers' own lock-screen switches ("Show on Lock
                    // screen", "Open new windows while running in the
                    // background", "Background pop-ups"…). Without them the
                    // call rings but its screen is blocked while locked — seen
                    // on Xiaomi: "Show when locked PermissionDenied".
                    // Only Xiaomi's can be read; other makers' are confirmed
                    // by the user.
                    "lockScreenReadable" -> result.success(isXiaomi())
                    "lockScreenAllowed" -> result.success(xiaomiLockScreenAllowed(context))
                    "openLockScreenPermissions" -> result.success(openLockScreenPermissions(context))
                    "openChannelSettings" -> {
                        val id = call.argument<String>("channelId") ?: ""
                        result.success(openChannelSettings(context, id))
                    }
                    "openFullScreenSettings" -> result.success(openFullScreenSettings(context))
                    "openAutostart" -> result.success(openAutostart(context))
                    "openAppDetails" -> {
                        start(context, appDetails(context)); result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("call_setup", e.message, null)
            }
        }
    }

    private fun channelBlocked(context: Context, id: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val nm = context.getSystemService(NotificationManager::class.java)
        val ch = nm.getNotificationChannel(id) ?: return false // not created yet
        return ch.importance < NotificationManager.IMPORTANCE_DEFAULT
    }

    private fun isXiaomi(): Boolean {
        val who = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return listOf("xiaomi", "redmi", "poco").any { who.contains(it) }
    }

    /**
     * MIUI app-ops 10020 (show when locked) and 10021 (start activities from
     * the background). They're hidden ops, read through reflection; if that
     * fails we can't tell, so report "allowed" rather than nag.
     */
    private fun xiaomiLockScreenAllowed(context: Context): Boolean {
        if (!isXiaomi()) return true
        return try {
            val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val check = AppOpsManager::class.java.getMethod(
                "checkOpNoThrow", Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType, String::class.java
            )
            val uid = context.applicationInfo.uid
            val pkg = context.packageName
            listOf(10020, 10021).all { op ->
                (check.invoke(ops, op, uid, pkg) as Int) == AppOpsManager.MODE_ALLOWED
            }
        } catch (e: Exception) {
            true
        }
    }

    /**
     * The page holding this app's lock-screen / background-window switches:
     * Xiaomi's "Other permissions", vivo's app permission page, otherwise
     * App info (where OPPO, Tecno, Huawei… keep them).
     */
    private fun openLockScreenPermissions(context: Context): Boolean {
        val pkg = context.packageName
        val pages = listOf(
            Intent().setClassName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity"
            ).putExtra("packagename", pkg),
            Intent("miui.intent.action.APP_PERM_EDITOR").setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.permissions.PermissionsEditorActivity"
            ),
            Intent("miui.intent.action.APP_PERM_EDITOR").setClassName(
                "com.miui.securitycenter",
                "com.miui.permcenter.permissions.AppPermissionsEditorActivity"
            ),
            Intent("miui.intent.action.APP_PERM_EDITOR"),
        )
        for (i in pages) {
            if (start(context, i.putExtra("extra_pkgname", pkg))) return true
        }
        start(context, appDetails(context))
        return false
    }

    private fun canUseFullScreen(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    }

    private fun openChannelSettings(context: Context, id: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            start(context, appDetails(context)); return false
        }
        val i = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, id)
        return start(context, i) || start(context, notificationSettings(context))
    }

    private fun openFullScreenSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 34) {
            val i = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                .setData(Uri.parse("package:${context.packageName}"))
            if (start(context, i)) return true
        }
        return start(context, notificationSettings(context))
    }

    /**
     * Tries each maker's auto-start page until one opens. Checking first
     * isn't reliable (an OPPO "resolved" a Xiaomi page that then failed to
     * open), so just try them. Falls back to App info, where these phones
     * keep the same switch under Battery.
     */
    private fun openAutostart(context: Context): Boolean {
        for ((pkg, cls) in AUTOSTART_PAGES) {
            val i = Intent().setComponent(ComponentName(pkg, cls))
            if (start(context, i)) return true
        }
        start(context, appDetails(context))
        return false
    }

    /** Makers whose phones have an auto-start / background-launch switch. */
    private fun hasAutostart(): Boolean {
        val who = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return AUTOSTART_MAKERS.any { who.contains(it) }
    }

    /**
     * Makers that block an app's call screen over the lock screen unless
     * their own switches are on. Xiaomi: confirmed ("Show when locked
     * PermissionDenied"). OPPO (ColorOS 11) showed the call fine without
     * anything extra, so it's not listed.
     */
    private fun hasLockScreenSwitches(): Boolean {
        val who = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        return LOCK_SCREEN_MAKERS.any { who.contains(it) }
    }

    private val LOCK_SCREEN_MAKERS = listOf(
        "xiaomi", "redmi", "poco", "vivo", "iqoo", "huawei", "honor",
        "tecno", "infinix", "itel",
    )

    private val AUTOSTART_MAKERS = listOf(
        "xiaomi", "redmi", "poco", "oppo", "realme", "oneplus", "vivo", "iqoo",
        "huawei", "honor", "tecno", "infinix", "itel", "asus",
    )

    private fun notificationSettings(context: Context): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        else appDetails(context)

    private fun appDetails(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.parse("package:${context.packageName}"))

    private fun start(context: Context, intent: Intent): Boolean = try {
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true
    } catch (e: Exception) {
        false
    }

    private val AUTOSTART_PAGES = listOf(
        // Xiaomi / Redmi / POCO
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        // OPPO / realme (ColorOS)
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        // vivo / iQOO
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        // Huawei / Honor
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        // Tecno / Infinix / itel
        "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
        // OnePlus
        "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        // Asus
        "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
    )
}
