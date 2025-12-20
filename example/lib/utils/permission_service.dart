import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限管理服务
class PermissionService {
  /// 请求外部存储权限
  static Future<bool> requestStoragePermission() async {
    try {
      // 检查当前权限状态
      final status = await Permission.storage.status;

      if (kDebugMode) {
        print('[Permission] 当前存储权限状态: $status');
      }

      if (status.isGranted) {
        if (kDebugMode) {
          print('[Permission] 存储权限已授予');
        }
        return true;
      }

      if (status.isDenied) {
        // 请求权限
        if (kDebugMode) {
          print('[Permission] 请求存储权限...');
        }
        final result = await Permission.storage.request();
        if (result.isGranted) {
          if (kDebugMode) {
            print('[Permission] 存储权限请求成功');
          }
          return true;
        }
      }

      if (status.isPermanentlyDenied) {
        if (kDebugMode) {
          print('[Permission] 存储权限被永久拒绝，需要手动开启');
        }
        // 引导用户到设置页面
        await openAppSettings();
        return false;
      }

      if (kDebugMode) {
        print('[Permission] 存储权限请求失败: $status');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[Permission] 权限请求异常: $e');
      }
      return false;
    }
  }

  /// 请求管理外部存储权限 (Android 11+)
  static Future<bool> requestManageExternalStoragePermission() async {
    try {
      final status = await Permission.manageExternalStorage.status;

      if (kDebugMode) {
        print('[Permission] 当前管理外部存储权限状态: $status');
      }

      if (status.isGranted) {
        if (kDebugMode) {
          print('[Permission] 管理外部存储权限已授予');
        }
        return true;
      }

      if (status.isDenied) {
        if (kDebugMode) {
          print('[Permission] 请求管理外部存储权限...');
        }
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) {
          if (kDebugMode) {
            print('[Permission] 管理外部存储权限请求成功');
          }
          return true;
        }
      }

      if (kDebugMode) {
        print('[Permission] 管理外部存储权限请求失败: $status');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[Permission] 管理外部存储权限请求异常: $e');
      }
      return false;
    }
  }

  /// 检查是否已有存储权限（不请求）
  static Future<bool> hasStoragePermissions() async {
    try {
      final basicStatus = await Permission.storage.status;
      final manageStatus = await Permission.manageExternalStorage.status;
      
      final hasPermission = basicStatus.isGranted || manageStatus.isGranted;
      
      if (kDebugMode) {
        print('[Permission] 权限检查结果 - 基本权限: ${basicStatus.isGranted}, 管理权限: ${manageStatus.isGranted}, 最终结果: $hasPermission');
      }
      
      return hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('[Permission] 权限检查异常: $e');
      }
      return false;
    }
  }

  /// 请求所有必要的存储权限
  static Future<bool> requestAllStoragePermissions() async {
    if (kDebugMode) {
      print('[Permission] 开始请求所有存储权限...');
    }

    // 先请求基本存储权限
    final basicPermission = await requestStoragePermission();

    // 再请求管理外部存储权限 (Android 11+)
    final managePermission = await requestManageExternalStoragePermission();

    final hasPermission = basicPermission || managePermission;

    if (kDebugMode) {
      print(
          '[Permission] 权限请求结果 - 基本权限: $basicPermission, 管理权限: $managePermission, 最终结果: $hasPermission');
    }

    return hasPermission;
  }
}
