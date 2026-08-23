package com.matrouh.nurse.nurse_matrouh

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.matrouh.nurse/app_installer"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }

                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (err: Exception) {
                            result.error("SETTINGS_ERROR", "Could not open unknown sources settings: ${e.message}", null)
                        }
                    }
                }

                "getDownloadDirectory" -> {
                    val downloadDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)?.absolutePath
                        ?: filesDir.absolutePath
                    result.success(downloadDir)
                }

                "verifyApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be null or empty", null)
                        return@setMethodCallHandler
                    }

                    val apkFile = File(filePath)
                    if (!apkFile.exists() || !apkFile.canRead()) {
                        result.success(mapOf(
                            "isValid" to false,
                            "error" to "APK file does not exist or is unreadable"
                        ))
                        return@setMethodCallHandler
                    }

                    try {
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            PackageManager.GET_SIGNING_CERTIFICATES
                        } else {
                            @Suppress("DEPRECATION")
                            PackageManager.GET_SIGNATURES
                        }

                        val packageInfo: PackageInfo? = packageManager.getPackageArchiveInfo(filePath, flags)
                        if (packageInfo == null) {
                            result.success(mapOf(
                                "isValid" to false,
                                "error" to "Failed to parse APK archive metadata (file may be corrupted)"
                            ))
                            return@setMethodCallHandler
                        }

                        val targetPackage = packageInfo.packageName
                        val isMatchingPackage = targetPackage == packageName

                        val archiveVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            packageInfo.versionCode.toLong()
                        }

                        result.success(mapOf(
                            "isValid" to isMatchingPackage,
                            "packageName" to targetPackage,
                            "expectedPackageName" to packageName,
                            "versionCode" to archiveVersionCode,
                            "versionName" to (packageInfo.versionName ?: ""),
                            "fileSizeBytes" to apkFile.length(),
                            "error" to if (!isMatchingPackage) "Package name ($targetPackage) does not match expected ($packageName)" else null
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "isValid" to false,
                            "error" to "Exception inspecting APK: ${e.message}"
                        ))
                    }
                }

                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "File path cannot be null or empty", null)
                        return@setMethodCallHandler
                    }

                    val apkFile = File(filePath)
                    if (!apkFile.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file was not found at $filePath", null)
                        return@setMethodCallHandler
                    }

                    // Check unknown apps install permission on Android 8.0+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            result.success(mapOf(
                                "success" to false,
                                "permissionRequired" to true,
                                "error" to "Permission REQUEST_INSTALL_PACKAGES not granted"
                            ))
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        val apkUri: Uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            apkFile
                        )

                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(installIntent)
                        result.success(mapOf(
                            "success" to true,
                            "permissionRequired" to false
                        ))
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", "Failed to launch package installer: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
