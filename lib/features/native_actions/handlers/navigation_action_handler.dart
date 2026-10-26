import 'package:flutter/material.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../debug_center/presentation/native_form_screen.dart';
import '../../user_profile/presentation/native_profile_screen.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class NavigationOpenNativePageHandler implements NativeActionHandler {
  static const Set<String> allowedPages = {'profile', 'form'};

  @override
  String get actionName => 'navigation.openNativePage';

  @override
  String? get requiredCapability => 'navigation.openNativePage';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final page = payload['page'] as String?;
    if (page == null || !allowedPages.contains(page)) {
      throw BridgeError.invalidParams('Page not in allowlist: $page. Allowed: $allowedPages');
    }

    if (context.buildContext == null) {
      throw BridgeError.internal('BuildContext is null');
    }

    final buildCtx = context.buildContext!;
    Widget targetWidget;

    if (page == 'profile') {
      targetWidget = const NativeProfileScreen();
    } else if (page == 'form') {
      final initialData = payload['params'] as Map<String, dynamic>?;
      targetWidget = NativeFormScreen(initialData: initialData);
    } else {
      throw BridgeError.actionNotFound('Page not found: $page');
    }

    final result = await Navigator.push(
      buildCtx,
      MaterialPageRoute(builder: (_) => targetWidget),
    );

    return {
      'page': page,
      'closed': true,
      'result': result,
    };
  }
}

class NavigationCloseHandler implements NativeActionHandler {
  @override
  String get actionName => 'navigation.close';

  @override
  String? get requiredCapability => 'navigation.close';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (context.buildContext != null && Navigator.canPop(context.buildContext!)) {
      Navigator.pop(context.buildContext!);
      return {'closed': true};
    }
    return {'closed': false, 'message': 'Cannot pop root navigator'};
  }
}

class NavigationOpenMiniAppHandler implements NativeActionHandler {
  final Function(String appId)? onSwitchApp;

  NavigationOpenMiniAppHandler({this.onSwitchApp});

  @override
  String get actionName => 'navigation.openMiniApp';

  @override
  String? get requiredCapability => 'navigation.openMiniApp';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final targetAppId = payload['appId'] as String?;
    if (targetAppId == null || targetAppId.isEmpty) {
      throw BridgeError.invalidParams('Target appId is required');
    }

    if (onSwitchApp != null) {
      onSwitchApp!(targetAppId);
      return {'switchedTo': targetAppId};
    }

    return {'status': 'requested', 'targetAppId': targetAppId};
  }
}
