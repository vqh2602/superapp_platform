import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class OpenPhoneHandler implements NativeActionHandler {
  @override
  String get actionName => 'phone.openPhone';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final phoneNumber = (payload['phoneNumber'] ?? payload['phone'])
        ?.toString();
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw BridgeError.invalidParams('phoneNumber is required to dial phone');
    }

    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri);
      }
    } catch (_) {}

    if (!launched) {
      throw BridgeError.unsupported('No application can open $uri');
    }
    return {
      'success': launched,
      'phoneNumber': cleanPhone,
      'launched': launched,
    };
  }
}

class OpenSmsHandler implements NativeActionHandler {
  @override
  String get actionName => 'phone.openSMS';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final phoneNumber = (payload['phoneNumber'] ?? payload['phone'])
        ?.toString();
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw BridgeError.invalidParams('phoneNumber is required to send SMS');
    }

    final body = payload['body']?.toString() ?? '';
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: body.isNotEmpty ? {'body': body} : null,
    );

    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri);
      }
    } catch (_) {}

    if (!launched) {
      throw BridgeError.unsupported('No application can open $uri');
    }
    return {
      'success': launched,
      'phoneNumber': cleanPhone,
      'body': body,
      'launched': launched,
    };
  }
}

class OpenExternalBrowserHandler implements NativeActionHandler {
  @override
  String get actionName => 'navigation.openExternalBrowser';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final rawUrl = payload['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw BridgeError.invalidParams(
        'url is required for openExternalBrowser',
      );
    }

    final uri = Uri.parse(rawUrl);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (!launched) {
      throw BridgeError.unsupported('No application can open $uri');
    }
    return {
      'success': launched,
      'url': rawUrl,
      'mode': 'EXTERNAL_BROWSER',
      'launched': launched,
    };
  }
}

class OpenDeepLinkHandler implements NativeActionHandler {
  @override
  String get actionName => 'navigation.openDeepLink';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final rawUrl = payload['url']?.toString();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw BridgeError.invalidParams('url / deep link is required');
    }

    final uri = Uri.parse(rawUrl);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (_) {}

    if (!launched) {
      throw BridgeError.unsupported('No application can open $uri');
    }
    return {
      'success': launched,
      'url': rawUrl,
      'mode': 'IN_APP_BROWSER',
      'launched': launched,
    };
  }
}

class SpeechToTextHandler implements NativeActionHandler {
  final PermissionRepositoryImpl permissionRepo;
  SpeechToTextHandler({required this.permissionRepo});
  @override
  String get actionName => 'utility.speechToText';
  @override
  String? get requiredCapability => 'microphone';
  @override
  bool get requiresAuth => false;
  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    if (!permissionRepo.isGranted(context.appId, 'microphone')) {
      throw BridgeError.permissionDenied('microphone');
    }
    if (context.buildContext == null) {
      throw BridgeError.unsupported('Speech recognition requires native UI');
    }
    final lang =
        payload['lang']?.toString() ??
        Localizations.localeOf(context.buildContext!).toLanguageTag();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context.buildContext!,
      isScrollControlled: true,
      builder: (_) => _SpeechRecordBottomSheet(lang: lang),
    );
    if (result == null) {
      throw BridgeError.cancelled('Người dùng huỷ nhận diện giọng nói');
    }
    if (result['error'] != null) {
      throw BridgeError.unsupported(result['error'] as String);
    }
    return {
      ...result,
      'lang': lang,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class HideKeyboardHandler implements NativeActionHandler {
  @override
  String get actionName => 'utility.hideKeyboard';
  @override
  String? get requiredCapability => null;
  @override
  bool get requiresAuth => false;
  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    return {'success': true, 'hidden': true};
  }
}

class _SpeechRecordBottomSheet extends StatefulWidget {
  final String lang;
  const _SpeechRecordBottomSheet({required this.lang});
  @override
  State<_SpeechRecordBottomSheet> createState() =>
      _SpeechRecordBottomSheetState();
}

class _SpeechRecordBottomSheetState extends State<_SpeechRecordBottomSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _text = '';
  double? _confidence;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _speech.initialize()) {
        if (mounted) {
          Navigator.pop(context, {
            'error': 'Speech recognition is unavailable',
          });
        }
        return;
      }
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: widget.lang.replaceAll('-', '_'),
        ),
        onResult: (result) {
          if (mounted) {
            setState(() {
              _text = result.recognizedWords;
              _confidence = result.hasConfidenceRating
                  ? result.confidence
                  : null;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context, {'error': e.toString()});
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mic, size: 40),
        const SizedBox(height: 16),
        Text(_text.isEmpty ? 'Đang lắng nghe…' : _text),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: _text.isEmpty
                  ? null
                  : () => Navigator.pop(context, {
                      'text': _text,
                      'confidence': _confidence,
                    }),
              child: const Text('Xong'),
            ),
          ],
        ),
      ],
    ),
  );
}
