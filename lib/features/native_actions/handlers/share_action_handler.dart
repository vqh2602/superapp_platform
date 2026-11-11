import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/bridge_error.dart';
import '../domain/action_context.dart';
import '../domain/action_definition.dart';

class ShareActionHandler implements NativeActionHandler {
  @override
  String get actionName => 'utility.share';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<Map<String, String>> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final text = _optionalString(payload, 'text');
    final url = _optionalString(payload, 'url');
    final title = _optionalString(payload, 'title');
    final subject = _optionalString(payload, 'subject');
    if (text == null && url == null) {
      throw BridgeError.invalidParams('text or url is required');
    }

    final uri = url == null ? null : Uri.tryParse(url);
    if (url != null &&
        (uri == null ||
            !const {'http', 'https'}.contains(uri.scheme) ||
            uri.host.isEmpty)) {
      throw BridgeError.invalidParams('url must be an absolute HTTP(S) URL');
    }

    return context.runInteractive(() async {
      final buildContext = context.buildContext;
      if (buildContext == null || !buildContext.mounted) {
        throw BridgeError.unsupported('Sharing requires an active Mini App UI');
      }

      final box = buildContext.findRenderObject();
      final origin = box is RenderBox && box.hasSize && !box.size.isEmpty
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text != null && url != null ? '$text\n$url' : text,
          uri: text == null ? uri : null,
          title: title,
          subject: subject,
          sharePositionOrigin: origin,
        ),
      );
      context.checkCancelled();
      return {'status': result.status.name};
    });
  }

  String? _optionalString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw BridgeError.invalidParams('$key must be a non-empty string');
    }
    return value;
  }
}
