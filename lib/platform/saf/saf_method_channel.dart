import 'package:flutter/services.dart';
import 'saf_platform_interface.dart';

/// Implementierung von [SafPlatformInterface] ueber Flutter MethodChannel.
class SafMethodChannel implements SafPlatformInterface {
  SafMethodChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.nocturne.audio/saf');

  final MethodChannel _channel;

  @override
  Future<SafNativeDirectoryPayload?> openDocumentTree() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('openDocumentTree');
      if (result == null) {
        return null;
      }
      return SafNativeDirectoryPayload.fromMap(result);
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELLED') {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<bool> takePersistableUriPermission(String uri) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'takePersistableUriPermission',
        {'uri': uri},
      );
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  @override
  Future<bool> releasePersistableUriPermission(String uri) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'releasePersistableUriPermission',
        {'uri': uri},
      );
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  @override
  Future<List<SafNativeDirectoryPayload>> getPersistedUriPermissions() async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'getPersistedUriPermissions',
      );
      if (result == null) {
        return const [];
      }
      return result
          .map((item) => SafNativeDirectoryPayload.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } on PlatformException {
      rethrow;
    }
  }

  @override
  Future<bool> isUriAccessible(String uri) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isUriAccessible',
        {'uri': uri},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<SafNativeFilePayload>> listFiles(
    String uri,
    List<String> extensions,
  ) async {
    try {
      final result = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'listFiles',
        {
          'uri': uri,
          'extensions': extensions,
        },
      );
      if (result == null) {
        return const [];
      }
      return result
          .map((item) => SafNativeFilePayload.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } on PlatformException {
      rethrow;
    }
  }
}
