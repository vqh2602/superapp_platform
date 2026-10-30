import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';
import '../presentation/qr_scanner_screen.dart';

void requireNativeUI(ActionContext context) {
  if (context.buildContext == null) {
    throw BridgeError.unsupported('Native UI is unavailable');
  }
}

Future<Map<String, dynamic>> imageMetadata(XFile file) async {
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final result = <String, dynamic>{
    'uri': file.path,
    'mimeType': file.mimeType ?? lookupMimeType(file.name, headerBytes: bytes),
    'width': frame.image.width,
    'height': frame.image.height,
    'sizeBytes': bytes.length,
    'fileName': file.name,
  };
  frame.image.dispose();
  codec.dispose();
  return result;
}

class ScanQrHandler implements NativeActionHandler {
  @override
  String get actionName => 'device.scanQr';
  @override
  String? get requiredCapability => 'device.scanQRCode';
  @override
  bool get requiresAuth => false;
  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final result = await QrScannerScreen.open(context.buildContext!);
    if (result == null) {
      throw BridgeError.cancelled('Người dùng đã huỷ quét mã');
    }
    return result;
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final source = payload['source']?.toString() ?? 'camera';
    if (!['camera', 'gallery'].contains(source)) {
      throw BridgeError.invalidParams('source must be camera or gallery');
    }
    final file = await _picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null) {
      throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
    }
    return {
      ...await imageMetadata(file),
      'source': source,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final count = ((payload['maxCount'] as num?)?.toInt() ?? 3).clamp(1, 100);
    final files = count == 1
        ? [
            if (await _picker.pickImage(source: ImageSource.gallery)
                case final XFile f)
              f,
          ]
        : await _picker.pickMultiImage(limit: count);
    if (files.isEmpty) {
      throw BridgeError.cancelled('Người dùng đã huỷ chọn ảnh');
    }
    final images = await Future.wait(files.map(imageMetadata));
    return {'images': images, 'count': images.length};
  }
}

class ChooseImageHandler implements NativeActionHandler {
  @override
  String get actionName => 'media.chooseImage';
  @override
  String? get requiredCapability => 'device.pickImage';
  @override
  bool get requiresAuth => false;
  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final result = await PickImagesHandler().handle({
      'maxCount': payload['count'] ?? 1,
    }, context);
    final paths = (result['images'] as List).map((f) => f['uri']).toList();
    return {'tempFilePaths': paths, 'count': paths.length};
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final uri = payload['uri']?.toString();
    if (uri == null || uri.isEmpty) {
      throw BridgeError.invalidParams('Image uri is required');
    }
    try {
      await Gal.putImage(uri);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw BridgeError.permissionDenied('photos');
      }
      rethrow;
    }
    return {
      'success': true,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      throw BridgeError.cancelled('Người dùng đã huỷ chọn video');
    }
    return {
      'uri': file.path,
      'mimeType': file.mimeType ?? lookupMimeType(file.name),
      'sizeBytes': await file.length(),
      'fileName': file.name,
      'durationSec': null,
      'width': null,
      'height': null,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final uri = payload['uri']?.toString();
    if (uri == null || uri.isEmpty) {
      throw BridgeError.invalidParams('Video uri is required');
    }
    try {
      await Gal.putVideo(uri);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw BridgeError.permissionDenied('photos');
      }
      rethrow;
    }
    return {
      'success': true,
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final name = payload['fileName']?.toString();
    final source = payload['path']?.toString() ?? payload['uri']?.toString();
    final encoded = payload['base64']?.toString();
    if (name == null || name.isEmpty || (source == null && encoded == null)) {
      throw BridgeError.invalidParams(
        'fileName and path/uri or base64 are required',
      );
    }
    final bytes = encoded != null
        ? base64Decode(encoded)
        : await File(source!).readAsBytes();
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType:
          lookupMimeType(name, headerBytes: bytes) ??
          'application/octet-stream',
    );
    if (uri == null) throw BridgeError.cancelled('Người dùng đã huỷ lưu file');
    return {'success': true, 'fileName': name, 'uri': uri.toString()};
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    requireNativeUI(context);
    final files = payload['allowMultiple'] == true
        ? await FilePicker.pickFiles()
        : [if (await FilePicker.pickFile() case final PlatformFile f) f];
    if (files.isEmpty) {
      throw BridgeError.cancelled('Người dùng đã huỷ chọn file');
    }
    final entries = files
        .map(
          (f) => {
            'fileName': f.name,
            'mimeType': lookupMimeType(f.name),
            'sizeBytes': f.lengthSync(),
            'path': f.path,
          },
        )
        .toList();
    return {'files': entries, 'count': entries.length};
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
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final url = payload['fileUrl']?.toString();
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !['https', 'http', 'file'].contains(uri.scheme)) {
      throw BridgeError.invalidParams('A valid fileUrl is required');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw BridgeError.unsupported('File viewer');
    }
    return {'success': true, 'fileUrl': url, 'fileName': payload['fileName']};
  }
}
