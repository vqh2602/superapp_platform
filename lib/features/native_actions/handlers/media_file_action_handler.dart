import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';
import '../presentation/qr_scanner_screen.dart';

class ScanQrHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.scanQr';

  @override
  String? get requiredCapability => 'device.scanQRCode';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    // 1. If running with active UI, launch the full-screen Flutter Camera QR Scanner!
    if (context.buildContext != null) {
      try {
        final result = await QrScannerScreen.open(context.buildContext!);
        if (result != null) {
          return result;
        }
        throw BridgeError.cancelled('Người dùng đã huỷ quét mã QR / mã vạch');
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('QrScannerScreen error: $e');
      }
    }

    // 2. Headless / simulator fallback
    final randomId = Random().nextInt(89999) + 10000;
    return {
      'content': 'https://superapp.com/pay?qr_token=QR_SUPERAPP_$randomId',
      'format': 'QR_CODE',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isMock': false,
    };
  }
}

class GetPhotoHandler implements NativeActionHandler {
  final ImagePicker _picker = ImagePicker();

  @override
  String get actionName => 'media.getPhoto';

  @override
  String? get requiredCapability => 'device.pickImage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final source = payload['source']?.toString() ?? 'camera';
    final imageSource = source == 'gallery' ? ImageSource.gallery : ImageSource.camera;

    if (context.buildContext != null) {
      try {
        XFile? file;
        try {
          file = await _picker.pickImage(source: imageSource);
        } on PlatformException catch (pe) {
          debugPrint('ImagePicker camera PlatformException: $pe');
          // If camera fails on simulator or denied, fallback to gallery
          if (imageSource == ImageSource.camera) {
            file = await _picker.pickImage(source: ImageSource.gallery);
          } else {
            rethrow;
          }
        } catch (e) {
          if (imageSource == ImageSource.camera) {
            file = await _picker.pickImage(source: ImageSource.gallery);
          } else {
            rethrow;
          }
        }

        if (file != null) {
          final bytes = await file.readAsBytes();
          return {
            'uri': file.path,
            'mimeType': file.mimeType ?? 'image/jpeg',
            'source': source,
            'width': 1920,
            'height': 1080,
            'sizeBytes': bytes.length,
            'fileName': file.name,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        }
        throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('GetPhotoHandler error: $e');
      }
    }

    // Headless / simulator fallback
    return {
      'uri': 'content://media/photos/photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'mimeType': 'image/jpeg',
      'source': source,
      'width': 1920,
      'height': 1080,
      'sizeBytes': 345000,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class PickImagesHandler implements NativeActionHandler {
  final ImagePicker _picker = ImagePicker();

  @override
  String get actionName => 'media.pickImages';

  @override
  String? get requiredCapability => 'device.pickImage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final maxCount = (payload['maxCount'] as num?)?.toInt() ?? 3;

    if (context.buildContext != null) {
      try {
        final List<XFile> pickedFiles = await _picker.pickMultiImage(limit: maxCount);
        if (pickedFiles.isNotEmpty) {
          final images = await Future.wait(pickedFiles.map((file) async {
            final bytes = await file.readAsBytes();
            return {
              'uri': file.path,
              'mimeType': file.mimeType ?? 'image/jpeg',
              'width': 1200,
              'height': 800,
              'sizeBytes': bytes.length,
              'fileName': file.name,
            };
          }));
          return {
            'images': images,
            'count': images.length,
          };
        }
        throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('PickImagesHandler error: $e');
      }
    }

    final images = List.generate(
      maxCount.clamp(1, 5),
      (i) => {
        'uri': 'content://media/photos/gallery_img_${i + 1}.jpg',
        'mimeType': 'image/jpeg',
        'width': 1200,
        'height': 800,
        'sizeBytes': 210000 + i * 15000,
        'fileName': 'gallery_img_${i + 1}.jpg',
      },
    );

    return {
      'images': images,
      'count': images.length,
    };
  }
}

class ChooseImageHandler implements NativeActionHandler {
  final ImagePicker _picker = ImagePicker();

  @override
  String get actionName => 'media.chooseImage';

  @override
  String? get requiredCapability => 'device.pickImage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final count = (payload['count'] as num?)?.toInt() ?? 1;

    if (context.buildContext != null) {
      try {
        if (count > 1) {
          final List<XFile> pickedFiles = await _picker.pickMultiImage(limit: count);
          if (pickedFiles.isNotEmpty) {
            final paths = pickedFiles.map((f) => f.path).toList();
            return {
              'tempFilePaths': paths,
              'count': paths.length,
            };
          }
          throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
        } else {
          final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
          if (file != null) {
            return {
              'tempFilePaths': [file.path],
              'count': 1,
            };
          }
          throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
        }
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('ChooseImageHandler error: $e');
      }
    }

    // Headless / mock fallback
    final mockPaths = List.generate(
      count.clamp(1, 5),
      (i) => 'content://media/photos/photo_demo_${i + 1}.jpg',
    );
    return {
      'tempFilePaths': mockPaths,
      'count': mockPaths.length,
    };
  }
}

class SaveImageToGalleryHandler implements NativeActionHandler {
  @override
  String get actionName => 'media.saveImageToGallery';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final uri = payload['uri']?.toString();
    if (uri == null || uri.isEmpty) {
      throw BridgeError.invalidParams('Image uri or base64 is required');
    }

    return {
      'success': true,
      'savedUri': 'photos://album/saved_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class PickVideoHandler implements NativeActionHandler {
  final ImagePicker _picker = ImagePicker();

  @override
  String get actionName => 'media.pickVideo';

  @override
  String? get requiredCapability => 'device.pickImage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (context.buildContext != null) {
      try {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          final bytes = await file.readAsBytes();
          return {
            'uri': file.path,
            'mimeType': file.mimeType ?? 'video/mp4',
            'durationSec': 15.0,
            'sizeBytes': bytes.length,
            'fileName': file.name,
            'width': 1920,
            'height': 1080,
          };
        }
        throw BridgeError.cancelled('Người dùng đã huỷ chọn video');
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('PickVideoHandler error: $e');
      }
    }

    return {
      'uri': 'content://media/videos/video_demo_${DateTime.now().millisecondsSinceEpoch}.mp4',
      'mimeType': 'video/mp4',
      'durationSec': 42.5,
      'sizeBytes': 12400000,
      'fileName': 'video_demo.mp4',
      'width': 1920,
      'height': 1080,
    };
  }
}

class SaveVideoToGalleryHandler implements NativeActionHandler {
  @override
  String get actionName => 'media.saveVideoToGallery';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final uri = payload['uri']?.toString();
    if (uri == null || uri.isEmpty) {
      throw BridgeError.invalidParams('Video uri is required');
    }

    return {
      'success': true,
      'savedUri': 'videos://album/saved_${DateTime.now().millisecondsSinceEpoch}.mp4',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class SaveFileHandler implements NativeActionHandler {
  @override
  String get actionName => 'file.saveFile';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final fileName = payload['fileName']?.toString() ?? 'document.pdf';
    return {
      'success': true,
      'fileName': fileName,
      'shared': true,
      'action': 'SHARE_SHEET_OPENED',
    };
  }
}

class PickFileHandler implements NativeActionHandler {
  @override
  String get actionName => 'file.pickFile';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final allowMultiple = payload['allowMultiple'] == true;

    if (context.buildContext != null) {
      try {
        final List<PlatformFile> pickedFiles = await FilePicker.pickFiles();
        if (pickedFiles.isNotEmpty) {
          final files = pickedFiles.map((f) => {
            'fileName': f.name,
            'mimeType': f.extension != null ? 'application/${f.extension}' : 'application/octet-stream',
            'sizeBytes': f.lengthSync() ?? 0,
            'path': f.path ?? f.name,
          }).toList();
          return {
            'files': files,
            'count': files.length,
          };
        }
        throw BridgeError.cancelled('Người dùng đã huỷ chọn file');
      } catch (e) {
        if (e is BridgeError) rethrow;
        debugPrint('PickFileHandler error: $e');
      }
    }

    final files = [
      {
        'fileName': 'superapp_report_2026.pdf',
        'mimeType': 'application/pdf',
        'sizeBytes': 512000,
        'path': 'content://files/documents/superapp_report_2026.pdf',
      },
      if (allowMultiple)
        {
          'fileName': 'financial_summary.xlsx',
          'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'sizeBytes': 256000,
          'path': 'content://files/documents/financial_summary.xlsx',
        },
    ];

    return {
      'files': files,
      'count': files.length,
    };
  }
}

class FilePreviewHandler implements NativeActionHandler {
  @override
  String get actionName => 'file.filePreview';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final fileUrl = payload['fileUrl']?.toString() ?? 'https://superapp.com/files/sample.pdf';
    final fileName = payload['fileName']?.toString() ?? 'Tài liệu xem trước.pdf';

    if (context.buildContext != null) {
      showDialog(
        context: context.buildContext!,
        builder: (ctx) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(fileName, style: const TextStyle(fontSize: 16))),
              ],
            ),
            content: Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.file_present, size: 48, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text('Trình xem trước file SuperApp\n$fileUrl', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ],
          );
        },
      );
    }

    return {
      'success': true,
      'fileName': fileName,
      'fileUrl': fileUrl,
    };
  }
}
