package com.example.example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * UniPluginScanSDK桥接类
 * 基于广播方式实现扫描功能
 */
class AarBridge(private val mainActivity: MainActivity) {
    private val context: Context = mainActivity
    
    private var scanReceiver: BroadcastReceiver? = null
    private var scanResultCallback: MethodChannel.Result? = null
    private var nativeToFlutterChannel: MethodChannel? = mainActivity.nativeToFlutterChannel
    private var isScanning = false
    private val logTag = "AarBridge"
    
    // 扫描相关常量
    companion object {
        const val SCAN_SETTINGS_ACTION = "com.android.broadcast.uscanner.settings"
        const val SCAN_RESULT_ACTION = "android.intent.ACTION_DECODE_DATA"
        const val BARCODE_STRING_KEY = "barcode_string"
        
        // 扫描参数键值
        const val KEY_SCANNER_ENABLE = -10        // 扫描引擎开关
        const val KEY_START_STOP_SCAN = -11       // 开始或停止扫描
        const val KEY_OUTPUT_MODE = -12           // 设置输出模式
        const val KEY_TRIGGER_MODE = -13          // 触发模式
        const val KEY_LOCK_SCAN = -14             // 锁定扫描
        const val KEY_INTENT_ACTION_NAME = 200000 // 条码广播名称
        const val KEY_INTENT_DATA_STRING_TAG = 200002 // 条码键值名称
        const val KEY_BEEP_ENABLE = 6             // 声音设置
        const val KEY_VIBRATE_ENABLE = 7          // 震动设置
    }
    
    /**
     * 处理来自Flutter的方法调用
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(logTag, "handleMethodCall -> method=${call.method} arguments=${call.arguments}")
        when (call.method) {
            "initializeScanner" -> {
                initializeScanner(result)
            }
            "startScan" -> {
                startScan(result)
            }
            "stopScan" -> {
                stopScan(result)
            }
            "setScannerEnabled" -> {
                val enabled = call.arguments as? Boolean ?: true
                setScannerEnabled(enabled, result)
            }
            "setOutputMode" -> {
                val mode = call.arguments as? Int ?: 0
                setOutputMode(mode, result)
            }
            "setTriggerMode" -> {
                val mode = call.arguments as? Int ?: 0
                setTriggerMode(mode, result)
            }
            "setScanLock" -> {
                val locked = call.arguments as? Boolean ?: false
                setScanLock(locked, result)
            }
            "setBeepEnabled" -> {
                val enabled = call.arguments as? Boolean ?: true
                setBeepEnabled(enabled, result)
            }
            "setVibrateEnabled" -> {
                val enabled = call.arguments as? Boolean ?: true
                setVibrateEnabled(enabled, result)
            }
            "getScannerInfo" -> {
                getScannerInfo(result)
            }
            "unregisterReceiver" -> {
                unregisterScanReceiver(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 初始化扫描器
     */
    private fun initializeScanner(result: MethodChannel.Result) {
        try {
            Log.i(logTag, "initializeScanner -> registering receiver and applying defaults")
            // 设置默认参数
            setScannerBroadcastSettings()
            // 注册扫描结果广播接收器
            registerScanReceiver()

            val initResult = mapOf(
                "success" to true,
                "message" to "Scanner initialized successfully",
                "version" to "UniPluginScanSDK-20250220"
            )
            
            result.success(initResult)
            Log.i(logTag, "initializeScanner -> success $initResult")
        } catch (e: Exception) {
            Log.e(logTag, "initializeScanner -> failed", e)
            result.error("INIT_ERROR", "Failed to initialize scanner: ${e.message}", null)
        }
    }
    
    /**
     * 注册扫描结果广播接收器
     */
    private fun registerScanReceiver() {
        if (scanReceiver == null) {
            Log.d(logTag, "registerScanReceiver -> creating new receiver instance")
            scanReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == SCAN_RESULT_ACTION) {
                        val barcodeString = intent.getStringExtra(BARCODE_STRING_KEY)
                        Log.d(logTag, "BroadcastReceiver -> received barcode=$barcodeString")
                        handleScanResult(barcodeString)
                    }
                }
            }
            
            val filter = IntentFilter()
            filter.addAction(SCAN_RESULT_ACTION)
            ContextCompat.registerReceiver(
                context,
                scanReceiver,
                filter,
                ContextCompat.RECEIVER_EXPORTED
            )
            Log.d(logTag, "registerScanReceiver -> receiver registered for $SCAN_RESULT_ACTION")
        } else {
            Log.d(logTag, "registerScanReceiver -> receiver already registered")
        }
    }
    
    /**
     * 处理扫描结果
     */
    private fun handleScanResult(barcodeString: String?) {
        Log.d(logTag, "handleScanResult -> barcode=$barcodeString hasCallback=${scanResultCallback != null} hasNativeToFlutterCallback=${nativeToFlutterChannel != null}")
        
        if (barcodeString != null) {
            val scanResult = mapOf(
                "success" to true,
                "barcode" to barcodeString,
                "timestamp" to System.currentTimeMillis(),
                "format" to "UNKNOWN" // SDK不提供格式信息
            )
            
            // 处理原生到Flutter的回调
            if (nativeToFlutterChannel != null) {
                try {
                    nativeToFlutterChannel?.invokeMethod("onScanResult", scanResult)
                    Log.i(logTag, "handleScanResult -> dispatched native to flutter result $scanResult")
                } catch (e: Exception) {
                    Log.e(logTag, "handleScanResult -> failed to dispatch native to flutter result", e)
                }
            }
            else {
                Log.w(logTag, "handleScanResult -> no callback registered, dropping barcode")
            }
        } else {
            Log.w(logTag, "handleScanResult -> received null barcode")
        }
    }
    
    /**
     * 设置扫描器广播参数
     */
    private fun setScannerBroadcastSettings() {
        Log.d(logTag, "setScannerBroadcastSettings -> configuring broadcast defaults")
        // 设置广播名称
        sendBroadcastSetting(KEY_INTENT_ACTION_NAME, SCAN_RESULT_ACTION)
        
        // 设置条码键值名称
        sendBroadcastSetting(KEY_INTENT_DATA_STRING_TAG, BARCODE_STRING_KEY)
        
        // 启用广播模式
        sendBroadcastSetting(KEY_OUTPUT_MODE, 0)
    }
    
    /**
     * 开始扫描
     */
    private fun startScan(result: MethodChannel.Result) {
        try {
            if (isScanning) {
                Log.w(logTag, "startScan -> already scanning, rejecting new request")
                result.error("SCAN_ERROR", "Scanner is already scanning", null)
                return
            }
            
            // 启用扫描引擎
            sendBroadcastSetting(KEY_SCANNER_ENABLE, 1)
            
            // 开始解码
            sendBroadcastSetting(KEY_START_STOP_SCAN, 1)
            
            scanResultCallback = result
            isScanning = true
            Log.i(logTag, "startScan -> broadcast sent, waiting for barcode")
            
            // 注意：这里不立即返回结果，等待扫描结果回调
        } catch (e: Exception) {
            Log.e(logTag, "startScan -> failed", e)
            result.error("SCAN_ERROR", "Failed to start scan: ${e.message}", null)
        }
    }
    
    /**
     * 停止扫描
     */
    private fun stopScan(result: MethodChannel.Result) {
        try {
            Log.i(logTag, "stopScan -> sending stop broadcast")
            // 停止解码
            sendBroadcastSetting(KEY_START_STOP_SCAN, 0)
            
            // 如果有等待中的回调，返回取消结果
            if (scanResultCallback != null) {
                scanResultCallback?.success(mapOf(
                    "success" to false,
                    "message" to "Scan cancelled",
                    "cancelled" to true
                ))
                scanResultCallback = null
            }
            
            isScanning = false
            
            result.success(mapOf(
                "success" to true,
                "message" to "Scan stopped"
            ))
            Log.i(logTag, "stopScan -> completed successfully")
        } catch (e: Exception) {
            Log.e(logTag, "stopScan -> failed", e)
            result.error("SCAN_ERROR", "Failed to stop scan: ${e.message}", null)
        }
    }
    
    /**
     * 设置扫描引擎开关
     */
    private fun setScannerEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val value = if (enabled) 1 else 0
            sendBroadcastSetting(KEY_SCANNER_ENABLE, value)
            
            result.success(mapOf(
                "success" to true,
                "enabled" to enabled
            ))
            Log.d(logTag, "setScannerEnabled -> enabled=$enabled")
        } catch (e: Exception) {
            Log.e(logTag, "setScannerEnabled -> failed", e)
            result.error("SETTING_ERROR", "Failed to set scanner enabled: ${e.message}", null)
        }
    }
    
    /**
     * 设置输出模式
     * 0：广播模式 1：键盘模式 2：广播模式+键盘模式
     */
    private fun setOutputMode(mode: Int, result: MethodChannel.Result) {
        try {
            sendBroadcastSetting(KEY_OUTPUT_MODE, mode)
            
            val modeStr = when (mode) {
                0 -> "广播模式"
                1 -> "键盘模式"
                2 -> "广播模式+键盘模式"
                else -> "未知模式"
            }
            
            result.success(mapOf(
                "success" to true,
                "mode" to mode,
                "modeDescription" to modeStr
            ))
            Log.d(logTag, "setOutputMode -> mode=$mode ($modeStr)")
        } catch (e: Exception) {
            Log.e(logTag, "setOutputMode -> failed", e)
            result.error("SETTING_ERROR", "Failed to set output mode: ${e.message}", null)
        }
    }
    
    /**
     * 设置触发模式
     * 0：自动模式 1：连扫模式 2：手动模式
     */
    private fun setTriggerMode(mode: Int, result: MethodChannel.Result) {
        try {
            sendBroadcastSetting(KEY_TRIGGER_MODE, mode)
            
            val modeStr = when (mode) {
                0 -> "自动模式"
                1 -> "连扫模式"
                2 -> "手动模式"
                else -> "未知模式"
            }
            
            result.success(mapOf(
                "success" to true,
                "mode" to mode,
                "modeDescription" to modeStr
            ))
            Log.d(logTag, "setTriggerMode -> mode=$mode ($modeStr)")
        } catch (e: Exception) {
            Log.e(logTag, "setTriggerMode -> failed", e)
            result.error("SETTING_ERROR", "Failed to set trigger mode: ${e.message}", null)
        }
    }
    
    /**
     * 设置扫描锁定
     */
    private fun setScanLock(locked: Boolean, result: MethodChannel.Result) {
        try {
            val value = if (locked) 0 else 1 // 0：锁定 1：解锁
            sendBroadcastSetting(KEY_LOCK_SCAN, value)
            
            result.success(mapOf(
                "success" to true,
                "locked" to locked
            ))
            Log.d(logTag, "setScanLock -> locked=$locked")
        } catch (e: Exception) {
            Log.e(logTag, "setScanLock -> failed", e)
            result.error("SETTING_ERROR", "Failed to set scan lock: ${e.message}", null)
        }
    }
    
    /**
     * 设置提示音
     */
    private fun setBeepEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val value = if (enabled) 1 else 0 // 0:无提示音 1：短促 2：尖锐
            sendBroadcastSetting(KEY_BEEP_ENABLE, value)
            
            result.success(mapOf(
                "success" to true,
                "enabled" to enabled
            ))
            Log.d(logTag, "setBeepEnabled -> enabled=$enabled")
        } catch (e: Exception) {
            Log.e(logTag, "setBeepEnabled -> failed", e)
            result.error("SETTING_ERROR", "Failed to set beep enabled: ${e.message}", null)
        }
    }
    
    /**
     * 设置震动
     */
    private fun setVibrateEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val value = if (enabled) 1 else 0
            sendBroadcastSetting(KEY_VIBRATE_ENABLE, value)
            
            result.success(mapOf(
                "success" to true,
                "enabled" to enabled
            ))
            Log.d(logTag, "setVibrateEnabled -> enabled=$enabled")
        } catch (e: Exception) {
            Log.e(logTag, "setVibrateEnabled -> failed", e)
            result.error("SETTING_ERROR", "Failed to set vibrate enabled: ${e.message}", null)
        }
    }
    
    /**
     * 获取扫描器信息
     */
    private fun getScannerInfo(result: MethodChannel.Result) {
        try {
            val info = mapOf(
                "name" to "UniPluginScanSDK",
                "version" to "20250220",
                "type" to "Broadcast Scanner",
                "description" to "基于广播的扫描SDK",
                "isScanning" to isScanning
            )
            result.success(info)
            Log.d(logTag, "getScannerInfo -> $info")
        } catch (e: Exception) {
            Log.e(logTag, "getScannerInfo -> failed", e)
            result.error("INFO_ERROR", "Failed to get scanner info: ${e.message}", null)
        }
    }
    
    /**
     * 发送广播设置
     */
    private fun sendBroadcastSetting(keyInt: Int, valueInt: Int) {
        val intent = Intent(SCAN_SETTINGS_ACTION)
        intent.putExtra("keyInt", keyInt)
        intent.putExtra("valueInt", valueInt)
        context.sendBroadcast(intent)
        Log.v(logTag, "sendBroadcastSetting(int) -> key=$keyInt value=$valueInt")
    }
    
    /**
     * 发送广播设置（字符串值）
     */
    private fun sendBroadcastSetting(keyInt: Int, valueStr: String) {
        val intent = Intent(SCAN_SETTINGS_ACTION)
        intent.putExtra("keyInt", keyInt)
        intent.putExtra("valueStr", valueStr)
        context.sendBroadcast(intent)
        Log.v(logTag, "sendBroadcastSetting(str) -> key=$keyInt value=$valueStr")
    }
    
    /**
     * 注销广播接收器
     */
    private fun unregisterScanReceiver(result: MethodChannel.Result) {
        try {
            Log.i(logTag, "unregisterScanReceiver -> attempting to unregister")
            scanReceiver?.let {
                context.unregisterReceiver(it)
                scanReceiver = null
                Log.i(logTag, "unregisterScanReceiver -> receiver unregistered")
            }
            
            result.success(mapOf(
                "success" to true,
                "message" to "Receiver unregistered"
            ))
            Log.i(logTag, "unregisterScanReceiver -> success response sent")
        } catch (e: Exception) {
            Log.e(logTag, "unregisterScanReceiver -> failed", e)
            result.error("UNREGISTER_ERROR", "Failed to unregister receiver: ${e.message}", null)
        }
    }
}
