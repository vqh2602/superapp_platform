import '../../../../core/config/endpoint_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/data/mock_auth_code_service.dart';
import '../../authentication/data/mock_token_service.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../device/data/mock_device_adapter.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../permissions/presentation/permission_prompt_dialog.dart';
import '../../user_profile/data/mock_user_repository.dart';
import '../../debug_center/data/debug_log_repository.dart';
import '../../storage/data/mock_secure_storage_repository.dart';
import '../domain/action_context.dart';
import '../domain/action_definition.dart';
import '../handlers/auth_action_handler.dart';
import '../handlers/user_action_handler.dart';
import '../handlers/navigation_action_handler.dart';
import '../handlers/device_action_handler.dart';
import '../handlers/permission_action_handler.dart';
import '../handlers/debug_action_handler.dart';
import '../handlers/storage_action_handler.dart';
import '../handlers/system_action_handler.dart';
import '../handlers/ui_action_handler.dart';
import '../handlers/media_file_action_handler.dart';
import '../handlers/phone_utility_action_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NativeActionDispatcher {
  final MockAuthRepository authRepo;
  final MockAuthCodeService authCodeService;
  final MockTokenService tokenService;
  final MockUserRepository userRepo;
  final MockDeviceAdapter deviceAdapter;
  final MockPermissionRepository permissionRepo;
  final DebugLogRepository debugLogRepo;
  final MockSecureStorageRepository secureStorageRepo;

  final Map<String, NativeActionHandler> _handlers = {};

  NativeActionDispatcher({
    required this.authRepo,
    required this.authCodeService,
    required this.tokenService,
    required this.userRepo,
    required this.deviceAdapter,
    required this.permissionRepo,
    required this.debugLogRepo,
    MockSecureStorageRepository? secureStorageRepo,
    String? miniappUrl,
    String? authUrl,
    Function(String appId)? onSwitchMiniApp,
  }) : secureStorageRepo = secureStorageRepo ?? MockSecureStorageRepository() {
    _registerHandlers(onSwitchMiniApp, miniappUrl: miniappUrl, authUrl: authUrl);
  }

  void _registerHandlers(
    Function(String appId)? onSwitchMiniApp, {
    String? miniappUrl,
    String? authUrl,
  }) {
    final list = <NativeActionHandler>[
      // Auth
      AuthRequestCodeHandler(
        authRepo: authRepo,
        authCodeService: authCodeService,
        miniappUrl: miniappUrl,
      ),
      AuthExchangeCodeHandler(
        tokenService: tokenService,
        miniappUrl: miniappUrl,
      ),
      AuthRefreshTokenHandler(
        tokenService: tokenService,
        authUrl: authUrl,
      ),
      AuthLogoutHandler(authRepo: authRepo),

      // User
      UserGetProfileHandler(userRepo: userRepo),
      UserGetBasicInfoHandler(userRepo: userRepo),

      // Navigation
      NavigationOpenNativePageHandler(),
      NavigationCloseHandler(),
      NavigationOpenMiniAppHandler(onSwitchApp: onSwitchMiniApp),

      // Device
      DeviceScanQrHandler(deviceAdapter: deviceAdapter),
      DeviceGetLocationHandler(deviceAdapter: deviceAdapter),
      DevicePickImageHandler(deviceAdapter: deviceAdapter),

      // Permission
      PermissionRequestHandler(permissionRepo: permissionRepo),
      PermissionCheckHandler(permissionRepo: permissionRepo),
      PermissionGetPermissionsHandler(permissionRepo: permissionRepo),

      // Secure Storage & Credentials
      StorageSetSecureItemHandler(secureStorageRepo: secureStorageRepo),
      StorageGetSecureItemHandler(secureStorageRepo: secureStorageRepo),
      StorageRemoveSecureItemHandler(secureStorageRepo: secureStorageRepo),
      StorageClearHandler(secureStorageRepo: secureStorageRepo),
      StorageGetAllHandler(secureStorageRepo: secureStorageRepo),
      StorageSetCredentialsHandler(secureStorageRepo: secureStorageRepo),
      StorageGetCredentialsHandler(secureStorageRepo: secureStorageRepo),
      StorageDeleteCredentialsHandler(secureStorageRepo: secureStorageRepo),

      // Debug
      DebugEchoHandler(),
      DebugSimulateFailureHandler(),

      // System & Device Info
      GetNetworkInfoHandler(),
      GetDeviceLanguageHandler(),
      GetSuperAppSettingsHandler(),
      GetSystemInfoHandler(),
      GetAppInfoHandler(),
      GetBatteryInfoHandler(),
      GetContactsHandler(permissionRepo: permissionRepo),

      // UI & Controls
      ShowToastHandler(),
      ShowAlertHandler(),
      ShowConfirmHandler(),
      SetNavigationBarTitleHandler(),
      VibrateHandler(),
      CopyToClipboardHandler(),
      SetBrightnessHandler(),
      SetStatusBarStyleHandler(),
      SetStatusBarColorHandler(),
      SetNavigationBarColorHandler(),
      ConfigAppViewHandler(),
      ShowMiniappMenuHandler(onCloseApp: onSwitchMiniApp != null ? () => onSwitchMiniApp('') : null),
      CloseAppHandler(onCloseApp: onSwitchMiniApp != null ? () => onSwitchMiniApp('') : null),

      // Media & Files
      ScanQrHandler(),
      ChooseImageHandler(),
      GetPhotoHandler(),
      PickImagesHandler(),
      SaveImageToGalleryHandler(),
      PickVideoHandler(),
      SaveVideoToGalleryHandler(),
      SaveFileHandler(),
      PickFileHandler(),
      FilePreviewHandler(),

      // Phone & Utilities
      OpenPhoneHandler(),
      OpenSmsHandler(),
      OpenExternalBrowserHandler(),
      OpenDeepLinkHandler(),
      SpeechToTextHandler(permissionRepo: permissionRepo),
      HideKeyboardHandler(),
    ];

    for (final h in list) {
      _handlers[h.actionName] = h;
    }

    // Register convenience aliases
    final setItemHandler = StorageSetSecureItemHandler(secureStorageRepo: secureStorageRepo);
    final getItemHandler = StorageGetSecureItemHandler(secureStorageRepo: secureStorageRepo);
    final removeItemHandler = StorageRemoveSecureItemHandler(secureStorageRepo: secureStorageRepo);
    final setCredHandler = StorageSetCredentialsHandler(secureStorageRepo: secureStorageRepo);
    final getCredHandler = StorageGetCredentialsHandler(secureStorageRepo: secureStorageRepo);
    final delCredHandler = StorageDeleteCredentialsHandler(secureStorageRepo: secureStorageRepo);

    _handlers['storage.setItem'] = setItemHandler;
    _handlers['storage.getItem'] = getItemHandler;
    _handlers['storage.removeItem'] = removeItemHandler;
    _handlers['storage.clear'] = StorageClearHandler(secureStorageRepo: secureStorageRepo);
    _handlers['storage.getAll'] = StorageGetAllHandler(secureStorageRepo: secureStorageRepo);
    _handlers['getStorage'] = getItemHandler;
    _handlers['setStorage'] = setItemHandler;
    _handlers['removeStorage'] = removeItemHandler;
    _handlers['clearStorage'] = StorageClearHandler(secureStorageRepo: secureStorageRepo);
    _handlers['getAllStorage'] = StorageGetAllHandler(secureStorageRepo: secureStorageRepo);
    _handlers['credentials.setCredentials'] = setCredHandler;
    _handlers['credentials.getCredentials'] = getCredHandler;
    _handlers['credentials.deleteCredentials'] = delCredHandler;
    _handlers['permission.getAll'] = PermissionGetPermissionsHandler(permissionRepo: permissionRepo);

    // Bare action names directly matching API spec
    _handlers['getNetworkInfo'] = GetNetworkInfoHandler();
    _handlers['getDeviceLanguage'] = GetDeviceLanguageHandler();
    _handlers['getSuperAppSettings'] = GetSuperAppSettingsHandler();
    _handlers['getSystemInfo'] = GetSystemInfoHandler();
    _handlers['device.getDeviceInfo'] = GetSystemInfoHandler();
    _handlers['getDeviceInfo'] = GetSystemInfoHandler();
    _handlers['getAppInfo'] = GetAppInfoHandler();
    _handlers['getBatteryInfo'] = GetBatteryInfoHandler();
    _handlers['getContacts'] = GetContactsHandler(permissionRepo: permissionRepo);

    _handlers['showToast'] = ShowToastHandler();
    _handlers['showAlert'] = ShowAlertHandler();
    _handlers['showConfirm'] = ShowConfirmHandler();
    _handlers['setNavigationBarTitle'] = SetNavigationBarTitleHandler();
    _handlers['setTitle'] = SetNavigationBarTitleHandler();
    _handlers['vibrate'] = VibrateHandler();
    _handlers['copyToClipboard'] = CopyToClipboardHandler();
    _handlers['setBrightness'] = SetBrightnessHandler();
    _handlers['setStatusBarStyle'] = SetStatusBarStyleHandler();
    _handlers['setStatusBarColor'] = SetStatusBarColorHandler();
    _handlers['setNavigationBarColor'] = SetNavigationBarColorHandler();
    _handlers['configAppView'] = ConfigAppViewHandler();
    _handlers['showMiniappMenu'] = ShowMiniappMenuHandler();
    _handlers['closeApp'] = CloseAppHandler();

    _handlers['scanQr'] = ScanQrHandler();
    _handlers['scanQRCode'] = ScanQrHandler();
    _handlers['media.scanQRCode'] = ScanQrHandler();
    _handlers['scanBarcode'] = ScanQrHandler();
    _handlers['device.scanBarcode'] = ScanQrHandler();
    _handlers['chooseImage'] = ChooseImageHandler();
    _handlers['getPhoto'] = GetPhotoHandler();
    _handlers['pickImages'] = PickImagesHandler();
    _handlers['saveImageToGallery'] = SaveImageToGalleryHandler();
    _handlers['pickVideo'] = PickVideoHandler();
    _handlers['saveVideoToGallery'] = SaveVideoToGalleryHandler();
    _handlers['saveFile'] = SaveFileHandler();
    _handlers['pickFile'] = PickFileHandler();
    _handlers['filePreview'] = FilePreviewHandler();

    // User & Auth aliases
    final userProfileHandler = UserGetProfileHandler(userRepo: userRepo);
    _handlers['auth.getUserProfile'] = userProfileHandler;
    _handlers['getUserProfile'] = userProfileHandler;

    // Secret Data aliases for Keychain/Keystore
    _handlers['setSecretData'] = setItemHandler;
    _handlers['getSecretData'] = getItemHandler;
    _handlers['removeSecretData'] = removeItemHandler;
    _handlers['storage.setSecretData'] = setItemHandler;
    _handlers['storage.getSecretData'] = getItemHandler;
    _handlers['storage.removeSecretData'] = removeItemHandler;

    // Phone & Utility aliases
    _handlers['openPhone'] = OpenPhoneHandler();
    _handlers['openSMS'] = OpenSmsHandler();
    _handlers['openExternalBrowser'] = OpenExternalBrowserHandler();
    _handlers['openDeepLink'] = OpenDeepLinkHandler();
    _handlers['speechToText'] = SpeechToTextHandler(permissionRepo: permissionRepo);
    _handlers['hideKeyboard'] = HideKeyboardHandler();
  }

  /// Dispatches an action with all security and capability checks.
  Future<dynamic> dispatch(
    String actionName,
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    // 0. Simulation hooks from Debug Center
    if (debugLogRepo.simulateTimeout) {
      await Future.delayed(const Duration(milliseconds: 3000));
      throw BridgeError.timeout('Bridge simulation: Request timed out');
    }
    if (debugLogRepo.simulateUnauthorized) {
      throw BridgeError.authRequired('Bridge simulation: Authentication required');
    }
    if (debugLogRepo.simulatePermissionDenied) {
      throw BridgeError.permissionDenied('Bridge simulation: Permission denied');
    }
    if (debugLogRepo.simulateNativeFailure) {
      throw BridgeError.internal('Bridge simulation: Forced native failure');
    }

    // 1. Mini App identity verification
    if (context.appId.isEmpty) {
      throw BridgeError.invalidParams('Mini App identifier (appId) is missing');
    }

    // 2. Action allowlist lookup
    final handler = _handlers[actionName];
    if (handler == null) {
      throw BridgeError.actionNotFound(actionName);
    }

    // 3. Manifest capability check
    // If mini app has a manifest, the capability must be declared in it
    if (context.manifest != null && handler.requiredCapability != null) {
      final declared = context.manifest!.capabilities.contains(handler.requiredCapability);
      if (!declared) {
        throw BridgeError.permissionDenied(
          'Capability "${handler.requiredCapability}" is not declared in Mini App manifest',
        );
      }
    }

    // 4. Runtime permission check
    if (handler.requiredCapability != null) {
      final cap = handler.requiredCapability!;
      final isGranted = permissionRepo.isGranted(context.appId, cap);
      if (!isGranted) {
        // If not yet granted and context has UI, prompt user
        if (context.buildContext != null) {
          final granted = await PermissionPromptDialog.show(
            context.buildContext!,
            appName: context.manifest?.name ?? context.appId,
            capabilityKey: cap,
          );
          permissionRepo.setPermission(context.appId, cap, granted);
          if (!granted) {
            throw BridgeError.permissionDenied(cap);
          }
        } else {
          throw BridgeError.permissionDenied(cap);
        }
      }
    }

    // 5. Authentication requirement check
    if (handler.requiresAuth && !authRepo.isAuthenticated) {
      throw BridgeError.authRequired();
    }

    // 6. Execute action
    return await handler.handle(payload, context);
  }
}

final nativeActionDispatcherProvider = Provider<NativeActionDispatcher>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  return NativeActionDispatcher(
    authRepo: ref.watch(mockAuthRepositoryProvider),
    authCodeService: ref.watch(mockAuthCodeServiceProvider),
    tokenService: ref.watch(mockTokenServiceProvider),
    userRepo: ref.watch(mockUserRepositoryProvider),
    deviceAdapter: ref.watch(deviceAdapterProvider),
    permissionRepo: ref.watch(mockPermissionRepositoryProvider),
    debugLogRepo: ref.watch(debugLogRepositoryProvider),
    secureStorageRepo: ref.watch(mockSecureStorageRepositoryProvider),
    miniappUrl: endpoint.miniappUrl,
    authUrl: endpoint.authUrl,
  );
});
