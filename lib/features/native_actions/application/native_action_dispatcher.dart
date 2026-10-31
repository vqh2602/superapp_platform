import 'package:http/http.dart' as http;
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../../../core/network/app_http_client.dart';
import '../../authentication/data/auth_repository_impl.dart';
import '../../authentication/data/auth_code_service_shim.dart';
import '../../authentication/data/token_service_shim.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../device/data/device_adapter_impl.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../../permissions/presentation/permission_prompt_dialog.dart';
import '../../user_profile/data/user_repository_impl.dart';
import '../../debug_center/data/debug_log_repository.dart';
import '../../storage/data/secure_storage_repository_impl.dart';
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
  final AuthRepositoryImpl authRepo;
  final AuthCodeServiceShim authCodeService;
  final TokenServiceShim tokenService;
  final UserRepositoryImpl userRepo;
  final DeviceAdapterImpl deviceAdapter;
  final PermissionRepositoryImpl permissionRepo;
  final DebugLogRepository debugLogRepo;
  final SecureStorageRepositoryImpl secureStorageRepo;
  final http.Client? httpClient;

  final Map<String, NativeActionHandler> _handlers = {};

  NativeActionDispatcher({
    required this.authRepo,
    required this.authCodeService,
    required this.tokenService,
    required this.userRepo,
    required this.deviceAdapter,
    required this.permissionRepo,
    required this.debugLogRepo,
    SecureStorageRepositoryImpl? secureStorageRepo,
    String? miniappUrl,
    String? authUrl,
    this.httpClient,
    Function(String appId)? onSwitchMiniApp,
  }) : secureStorageRepo = secureStorageRepo ?? SecureStorageRepositoryImpl() {
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
        httpClient: httpClient,
        miniappUrl: miniappUrl,
      ),
      AuthExchangeCodeHandler(
        tokenService: tokenService,
        httpClient: httpClient,
        miniappUrl: miniappUrl,
      ),
      AuthRefreshTokenHandler(
        tokenService: tokenService,
        httpClient: httpClient,
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
      KeepScreenHandler(),
      RequestSendNotificationHandler(permissionRepo: permissionRepo),
      MinimizeAppHandler(onMinimizeApp: onSwitchMiniApp != null ? () => onSwitchMiniApp('') : null),
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
    _handlers['keepScreen'] = KeepScreenHandler();
    _handlers['ui.keepScreen'] = KeepScreenHandler();
    _handlers['requestSendNotification'] = RequestSendNotificationHandler(permissionRepo: permissionRepo);
    _handlers['notification.requestSendNotification'] = RequestSendNotificationHandler(permissionRepo: permissionRepo);
    _handlers['minimizeApp'] = MinimizeAppHandler(onMinimizeApp: onSwitchMiniApp != null ? () => onSwitchMiniApp('') : null);
    _handlers['ui.minimizeApp'] = MinimizeAppHandler(onMinimizeApp: onSwitchMiniApp != null ? () => onSwitchMiniApp('') : null);
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

    // Restore this user's saved grants before handlers inspect or prompt.
    await permissionRepo.ensurePermissionsLoaded(context.appId);

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
  final httpClient = ref.watch(appHttpClientProvider);
  return NativeActionDispatcher(
    authRepo: ref.watch(authRepositoryProvider),
    authCodeService: ref.watch(authCodeServiceProvider),
    tokenService: ref.watch(tokenServiceProvider),
    userRepo: ref.watch(userRepositoryProvider),
    deviceAdapter: ref.watch(deviceAdapterProvider),
    permissionRepo: ref.watch(permissionRepositoryProvider),
    debugLogRepo: ref.watch(debugLogRepositoryProvider),
    secureStorageRepo: ref.watch(secureStorageRepositoryProvider),
    miniappUrl: endpoint.miniappUrl,
    authUrl: endpoint.authUrl,
    httpClient: httpClient,
  );
});
