package com.example.pda

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val FLUTTER_TO_NATIVE_CHANNEL = "com.example.pda/flutter_to_native"
    private val NATIVE_TO_FLUTTER_CHANNEL = "com.example.pda/native_to_flutter"
    private lateinit var aarBridge: AarBridge
    var nativeToFlutterChannel: MethodChannel? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.i(TAG, "configureFlutterEngine -> starting configuration for AAR bridge")
        super.configureFlutterEngine(flutterEngine)
        
        // 先设置原生调用Flutter的通道
        nativeToFlutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_TO_FLUTTER_CHANNEL)
        Log.i(TAG, "configureFlutterEngine -> Native to Flutter channel created")
        
        // 再初始化AAR桥接类
        aarBridge = AarBridge(this)
        Log.i(TAG, "configureFlutterEngine -> AarBridge instance created")
        
        // 设置Flutter调用原生的通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLUTTER_TO_NATIVE_CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Flutter to Native -> received call: ${call.method}")
            aarBridge.handleMethodCall(call, result)
        }
        Log.i(TAG, "configureFlutterEngine -> Flutter to Native channel handler registered")
    }
    
}
