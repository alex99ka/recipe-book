package com.alex99ka.recipes

import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity, not FlutterActivity: local_auth shows the system
// biometric prompt as a fragment, and on a plain activity every fingerprint
// attempt fails with "The current Activity must be a FragmentActivity".
class MainActivity : FlutterFragmentActivity() {

    companion object {
        // Whether the app is on screen; a staged update waits while it is.
        @Volatile var visible = false

        // A shared photo or PDF bigger than the server takes is refused there anyway.
        const val MAX_SHARE = 15 * 1024 * 1024
    }

    // "Share to ספר מתכונים" from another app: waits here until Dart takes it
    // (lib/core/share_in.dart), so one arriving before Flutter is ready isn't lost.
    @Volatile private var shared: Map<String, Any?>? = null
    private var shareChannel: MethodChannel? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readShare(intent)
    }

    private fun readShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
        intent.action = null // opened again from recents, it isn't a new share
        // Reading the file is kept off the UI thread.
        Thread {
            var bytes: ByteArray? = null
            var name: String? = null
            if (uri != null) runCatching {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { if (it.moveToFirst()) name = it.getString(0) }
                contentResolver.openInputStream(uri)?.use {
                    val data = it.readBytes()
                    if (data.size <= MAX_SHARE) bytes = data
                }
                if (name == null) name = when (contentResolver.getType(uri)) {
                    "application/pdf" -> "shared.pdf"
                    "image/png" -> "shared.png"
                    else -> "shared.jpg"
                }
            }
            shared = mapOf("text" to text, "bytes" to bytes, "name" to name)
            runOnUiThread { shareChannel?.invokeMethod("shared", null) }
        }.start()
    }

    override fun onStart() {
        super.onStart()
        visible = true
        UpdateReceiver.arm(this, false)
    }

    override fun onStop() {
        super.onStop()
        visible = false
        if (!isChangingConfigurations) UpdateReceiver.arm(this, true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // The in-app updater (lib/core/update.dart).
        MethodChannel(messenger, "app/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        packageManager.canRequestPackageInstalls()
                )
                "allowInstalls" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                // Copying the APK into the session is kept off the UI thread.
                "stage" -> {
                    val path = call.argument<String>("path")
                    Thread {
                        val staged = path != null && runCatching {
                            UpdateReceiver.stage(this, File(path))
                        }.getOrDefault(false)
                        runOnUiThread { result.success(staged) }
                    }.start()
                }
                "unmetered" -> result.success(
                    !getSystemService(ConnectivityManager::class.java).isActiveNetworkMetered
                )
                "unstage" -> {
                    runCatching { UpdateReceiver.unstage(this) }
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("no-path", "no file to install", null)
                    } else try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
                        startActivity(
                            Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                // CLEAR_TASK: an earlier attempt cancelled or timed out
                                // in Play Protect leaves the installer at "App not
                                // installed", and NEW_TASK alone brings that screen back.
                                .addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TASK
                                )
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install-failed", e.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        shareChannel = MethodChannel(messenger, "app/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(shared)
                        shared = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        readShare(intent) // the share that started the app

        // Turning the fingerprint lock on when nothing is enrolled: the phone's
        // own enrollment screen (lib/core/lock.dart waits for the return).
        MethodChannel(messenger, "app/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "enrollBiometrics" -> {
                    val intent = when {
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                            Intent(Settings.ACTION_BIOMETRIC_ENROLL).putExtra(
                                Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                                android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG
                            )
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ->
                            @Suppress("DEPRECATION") Intent(Settings.ACTION_FINGERPRINT_ENROLL)
                        else -> Intent(Settings.ACTION_SECURITY_SETTINGS)
                    }
                    try {
                        startActivity(intent)
                    } catch (e: Exception) {
                        // Some phones lack the direct screen: security settings instead.
                        startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                    }
                    result.success(null)
                }
                // A link in the app that owns it, as its own task: url_launcher starts
                // it in this app's task, so TikTok showed up inside the recipe book too.
                "openLink" -> try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("no_app", e.message, null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
