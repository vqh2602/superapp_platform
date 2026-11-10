/// Shared Bridge API Contract between JS SDK (@vqh2602/mini-app-sdk)
/// and Flutter Host SuperApp Platform.
///
/// This contract serves as the Single Source of Truth (SSOT) to prevent
/// ACTION_NOT_FOUND runtime errors and ensure complete compatibility.
library;

class BridgeActionSpec {
  final String action;
  final String module;
  final String description;
  final String? requiredCapability;
  final bool requiresAuth;
  final bool isInteractive;
  final List<String> aliases;

  const BridgeActionSpec({
    required this.action,
    required this.module,
    required this.description,
    this.requiredCapability,
    this.requiresAuth = false,
    this.isInteractive = false,
    this.aliases = const [],
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'module': module,
        'description': description,
        'requiredCapability': requiredCapability,
        'requiresAuth': requiresAuth,
        'isInteractive': isInteractive,
        'aliases': aliases,
      };
}

class BridgeApiContract {
  BridgeApiContract._();

  static const List<BridgeActionSpec> actions = [
    // --- Auth Module ---
    BridgeActionSpec(
      action: 'auth.requestCode',
      module: 'auth',
      description: 'Yêu cầu mã xác thực OAuth2/PKCE',
      requiredCapability: 'auth.requestCode',
      requiresAuth: true,
    ),
    BridgeActionSpec(
      action: 'auth.exchangeCode',
      module: 'auth',
      description: 'Đổi authorization code lấy access token và refresh token',
      requiresAuth: false,
    ),
    BridgeActionSpec(
      action: 'auth.login',
      module: 'auth',
      description: 'Yêu cầu đăng nhập và lấy phiên làm việc của người dùng hiện tại',
      requiresAuth: true,
    ),
    BridgeActionSpec(
      action: 'auth.getAccessToken',
      module: 'auth',
      description: 'Lấy Access Token hiện tại của phiên đăng nhập SuperApp',
      requiresAuth: true,
    ),
    BridgeActionSpec(
      action: 'auth.getUserProfile',
      module: 'auth',
      description: 'Lấy thông tin tài khoản người dùng đang đăng nhập',
      requiredCapability: 'user.getProfile',
      requiresAuth: true,
      aliases: ['getUserProfile'],
    ),
    BridgeActionSpec(
      action: 'auth.refreshToken',
      module: 'auth',
      description: 'Làm mới token bằng refresh token',
      requiresAuth: false,
    ),
    BridgeActionSpec(
      action: 'auth.logout',
      module: 'auth',
      description: 'Đăng xuất khỏi phiên làm việc hiện tại',
      requiresAuth: true,
    ),

    // --- User Module ---
    BridgeActionSpec(
      action: 'user.getProfile',
      module: 'user',
      description: 'Truy cập thông tin chi tiết hồ sơ người dùng',
      requiredCapability: 'user.getProfile',
      requiresAuth: true,
    ),
    BridgeActionSpec(
      action: 'user.getBasicInfo',
      module: 'user',
      description: 'Truy cập thông tin cơ bản người dùng (tên, avatar)',
      requiredCapability: 'user.getBasicInfo',
      requiresAuth: true,
    ),

    // --- Payment Module ---
    BridgeActionSpec(
      action: 'payment.createOrder',
      module: 'payment',
      description: 'Khởi tạo đơn hàng thanh toán trên SuperApp',
      requiredCapability: 'payment.createOrder',
      requiresAuth: false,
    ),
    BridgeActionSpec(
      action: 'payment.openCheckout',
      module: 'payment',
      description: 'Mở giao diện thanh toán Native SuperApp',
      requiredCapability: 'payment.openCheckout',
      requiresAuth: false,
      isInteractive: true,
    ),
    BridgeActionSpec(
      action: 'payment.checkStatus',
      module: 'payment',
      description: 'Kiểm tra trạng thái giao dịch thanh toán',
      requiresAuth: false,
      aliases: ['payment.checkTransaction'],
    ),
    BridgeActionSpec(
      action: 'payment.checkTransaction',
      module: 'payment',
      description: 'Kiểm tra trạng thái giao dịch thanh toán theo ID',
      requiresAuth: false,
    ),
    BridgeActionSpec(
      action: 'payment.requestPayment',
      module: 'payment',
      description: 'Luồng thanh toán tích hợp (tạo đơn + mở checkout)',
      requiredCapability: 'payment.openCheckout',
      requiresAuth: false,
      isInteractive: true,
    ),

    // --- Navigation Module ---
    BridgeActionSpec(
      action: 'navigation.close',
      module: 'navigation',
      description: 'Đóng Mini App và quay về SuperApp Host',
      aliases: ['closeApp', 'navigation.closeApp'],
    ),
    BridgeActionSpec(
      action: 'navigation.closeApp',
      module: 'navigation',
      description: 'Đóng Mini App',
      aliases: ['closeApp', 'navigation.close'],
    ),
    BridgeActionSpec(
      action: 'navigation.minimizeApp',
      module: 'navigation',
      description: 'Thu nhỏ Mini App xuống dạng floating widget',
      aliases: ['minimizeApp', 'ui.minimizeApp'],
    ),
    BridgeActionSpec(
      action: 'navigation.openNativePage',
      module: 'navigation',
      description: 'Mở một màn hình native của SuperApp Host',
      requiredCapability: 'navigation.openNativePage',
    ),
    BridgeActionSpec(
      action: 'navigation.openMiniApp',
      module: 'navigation',
      description: 'Chuyển hướng hoặc mở một Mini App khác',
    ),

    // --- Device & Hardware Module ---
    BridgeActionSpec(
      action: 'device.getDeviceInfo',
      module: 'device',
      description: 'Lấy thông tin thiết bị phần cứng',
      aliases: ['getDeviceInfo', 'device.getSystemInfo', 'getSystemInfo'],
    ),
    BridgeActionSpec(
      action: 'device.getSystemInfo',
      module: 'device',
      description: 'Lấy thông tin hệ thống thiết bị',
      aliases: ['getSystemInfo', 'device.getDeviceInfo'],
    ),
    BridgeActionSpec(
      action: 'device.getNetworkInfo',
      module: 'device',
      description: 'Lấy thông tin kết nối mạng',
      aliases: ['getNetworkInfo'],
    ),
    BridgeActionSpec(
      action: 'device.getBatteryInfo',
      module: 'device',
      description: 'Lấy thông tin pin thiết bị',
      aliases: ['getBatteryInfo'],
    ),
    BridgeActionSpec(
      action: 'device.getLocation',
      module: 'device',
      description: 'Lấy tọa độ vị trí GPS hiện tại',
      requiredCapability: 'device.getLocation',
    ),
    BridgeActionSpec(
      action: 'device.vibrate',
      module: 'device',
      description: 'Rung phản hồi xúc giác',
      aliases: ['vibrate'],
    ),
    BridgeActionSpec(
      action: 'device.keepScreen',
      module: 'device',
      description: 'Bật/tắt giữ sáng màn hình',
      aliases: ['keepScreen', 'ui.keepScreen'],
    ),
    BridgeActionSpec(
      action: 'device.setBrightness',
      module: 'device',
      description: 'Điều chỉnh độ sáng màn hình',
      aliases: ['setBrightness'],
    ),
    BridgeActionSpec(
      action: 'device.copyToClipboard',
      module: 'device',
      description: 'Sao chép văn bản vào clipboard',
      aliases: ['copyToClipboard'],
    ),
    BridgeActionSpec(
      action: 'device.getDeviceLanguage',
      module: 'device',
      description: 'Lấy ngôn ngữ hiện tại của thiết bị',
      aliases: ['getDeviceLanguage'],
    ),

    // --- Media & Camera Module ---
    BridgeActionSpec(
      action: 'media.scanQRCode',
      module: 'media',
      description: 'Quét mã QR và mã vạch',
      requiredCapability: 'device.scanQRCode',
      isInteractive: true,
      aliases: ['scanQr', 'scanQRCode', 'device.scanQRCode', 'device.scanQr', 'device.scanBarcode', 'scanBarcode'],
    ),
    BridgeActionSpec(
      action: 'media.chooseImage',
      module: 'media',
      description: 'Chọn ảnh từ thư viện thiết bị',
      requiredCapability: 'device.pickImage',
      isInteractive: true,
      aliases: ['chooseImage', 'device.pickImage', 'getPhoto', 'media.getPhoto'],
    ),
    BridgeActionSpec(
      action: 'media.pickImages',
      module: 'media',
      description: 'Chọn nhiều ảnh từ thư viện',
      requiredCapability: 'device.pickImage',
      isInteractive: true,
      aliases: ['pickImages'],
    ),
    BridgeActionSpec(
      action: 'media.pickVideo',
      module: 'media',
      description: 'Chọn video từ thư viện thiết bị',
      isInteractive: true,
      aliases: ['pickVideo'],
    ),
    BridgeActionSpec(
      action: 'media.saveImageToGallery',
      module: 'media',
      description: 'Lưu ảnh vào thư viện máy',
      isInteractive: true,
      aliases: ['saveImageToGallery'],
    ),
    BridgeActionSpec(
      action: 'media.saveVideoToGallery',
      module: 'media',
      description: 'Lưu video vào thư viện máy',
      isInteractive: true,
      aliases: ['saveVideoToGallery'],
    ),

    // --- File Module ---
    BridgeActionSpec(
      action: 'file.pickFile',
      module: 'file',
      description: 'Chọn tập tin từ bộ nhớ thiết bị',
      isInteractive: true,
      aliases: ['pickFile'],
    ),
    BridgeActionSpec(
      action: 'file.saveFile',
      module: 'file',
      description: 'Lưu tập tin vào bộ nhớ thiết bị',
      isInteractive: true,
      aliases: ['saveFile'],
    ),
    BridgeActionSpec(
      action: 'file.filePreview',
      module: 'file',
      description: 'Xem trước tập tin tài liệu',
      isInteractive: true,
      aliases: ['filePreview'],
    ),

    // --- Storage & Credentials Module ---
    BridgeActionSpec(
      action: 'storage.setItem',
      module: 'storage',
      description: 'Lưu dữ liệu cục bộ vào sandbox storage của Mini App',
      aliases: ['setStorage'],
    ),
    BridgeActionSpec(
      action: 'storage.getItem',
      module: 'storage',
      description: 'Đọc dữ liệu cục bộ từ sandbox storage',
      aliases: ['getStorage'],
    ),
    BridgeActionSpec(
      action: 'storage.removeItem',
      module: 'storage',
      description: 'Xóa dữ liệu theo key trong sandbox storage',
      aliases: ['removeStorage'],
    ),
    BridgeActionSpec(
      action: 'storage.clear',
      module: 'storage',
      description: 'Xóa toàn bộ dữ liệu sandbox storage của Mini App',
      aliases: ['clearStorage'],
    ),
    BridgeActionSpec(
      action: 'storage.getAll',
      module: 'storage',
      description: 'Lấy tất cả các cặp key-value trong sandbox storage',
      aliases: ['getAllStorage'],
    ),
    BridgeActionSpec(
      action: 'storage.setSecureItem',
      module: 'storage',
      description: 'Lưu dữ liệu mã hóa Keychain/Keystore an toàn',
      requiredCapability: 'storage.secure',
      aliases: ['storage.setSecretData', 'setSecretData'],
    ),
    BridgeActionSpec(
      action: 'storage.getSecureItem',
      module: 'storage',
      description: 'Đọc dữ liệu mã hóa an toàn Keychain/Keystore',
      requiredCapability: 'storage.secure',
      aliases: ['storage.getSecretData', 'getSecretData'],
    ),
    BridgeActionSpec(
      action: 'storage.removeSecureItem',
      module: 'storage',
      description: 'Xóa dữ liệu mã hóa an toàn',
      requiredCapability: 'storage.secure',
      aliases: ['storage.removeSecretData', 'removeSecretData'],
    ),
    BridgeActionSpec(
      action: 'storage.setCredentials',
      module: 'storage',
      description: 'Lưu cặp tài khoản/mật khẩu vào Keychain/Keystore',
      requiredCapability: 'storage.secure',
      aliases: ['credentials.setCredentials'],
    ),
    BridgeActionSpec(
      action: 'storage.getCredentials',
      module: 'storage',
      description: 'Lấy thông tin tài khoản đã lưu từ Keychain/Keystore',
      requiredCapability: 'storage.secure',
      aliases: ['credentials.getCredentials'],
    ),
    BridgeActionSpec(
      action: 'storage.deleteCredentials',
      module: 'storage',
      description: 'Xóa thông tin tài khoản bảo mật',
      requiredCapability: 'storage.secure',
      aliases: ['credentials.deleteCredentials'],
    ),

    // --- UI Module ---
    BridgeActionSpec(
      action: 'ui.showToast',
      module: 'ui',
      description: 'Hiển thị toast thông báo nhanh trên màn hình',
      aliases: ['showToast'],
    ),
    BridgeActionSpec(
      action: 'ui.showAlert',
      module: 'ui',
      description: 'Hiển thị modal alert thông báo có nút Đóng',
      isInteractive: true,
      aliases: ['showAlert'],
    ),
    BridgeActionSpec(
      action: 'ui.showConfirm',
      module: 'ui',
      description: 'Hiển thị hộp thoại xác nhận Xác nhận / Hủy',
      isInteractive: true,
      aliases: ['showConfirm'],
    ),
    BridgeActionSpec(
      action: 'ui.setNavigationBarTitle',
      module: 'ui',
      description: 'Cập nhật tiêu đề thanh điều hướng của Mini App',
      aliases: ['setNavigationBarTitle', 'setTitle'],
    ),
    BridgeActionSpec(
      action: 'ui.setNavigationBarColor',
      module: 'ui',
      description: 'Cập nhật màu nền thanh điều hướng',
      aliases: ['setNavigationBarColor'],
    ),
    BridgeActionSpec(
      action: 'ui.setStatusBarColor',
      module: 'ui',
      description: 'Cập nhật màu thanh trạng thái (status bar)',
      aliases: ['setStatusBarColor'],
    ),
    BridgeActionSpec(
      action: 'ui.setStatusBarStyle',
      module: 'ui',
      description: 'Cập nhật kiểu icon status bar (light / dark)',
      aliases: ['setStatusBarStyle'],
    ),
    BridgeActionSpec(
      action: 'ui.configAppView',
      module: 'ui',
      description: 'Cấu hình giao diện Mini App view (header, swipe back, ...)',
      aliases: ['configAppView'],
    ),
    BridgeActionSpec(
      action: 'ui.showMiniappMenu',
      module: 'ui',
      description: 'Mở menu tùy chọn Mini App từ native',
      isInteractive: true,
      aliases: ['showMiniappMenu'],
    ),
    BridgeActionSpec(
      action: 'ui.requestSendNotification',
      module: 'ui',
      description: 'Yêu cầu quyền và gửi thông báo native',
      requiredCapability: 'notification',
      isInteractive: true,
      aliases: ['requestSendNotification', 'notification.requestSendNotification'],
    ),

    // --- Phone & Utility Module ---
    BridgeActionSpec(
      action: 'phone.openPhone',
      module: 'phone',
      description: 'Mở ứng dụng gọi điện thoại native',
      aliases: ['openPhone'],
    ),
    BridgeActionSpec(
      action: 'phone.openSMS',
      module: 'phone',
      description: 'Mở ứng dụng nhắn tin SMS native',
      aliases: ['openSMS'],
    ),
    BridgeActionSpec(
      action: 'phone.openExternalBrowser',
      module: 'phone',
      description: 'Mở liên kết URL trên trình duyệt web ngoài hệ thống',
      aliases: ['openExternalBrowser', 'navigation.openExternalBrowser'],
    ),
    BridgeActionSpec(
      action: 'phone.openDeepLink',
      module: 'phone',
      description: 'Mở custom scheme hoặc app deep link ngoài hệ thống',
      aliases: ['openDeepLink', 'navigation.openDeepLink'],
    ),
    BridgeActionSpec(
      action: 'utility.speechToText',
      module: 'utility',
      description: 'Chuyển giọng nói thành văn bản bằng micro thiết bị',
      requiredCapability: 'microphone',
      isInteractive: true,
      aliases: ['speechToText'],
    ),
    BridgeActionSpec(
      action: 'utility.hideKeyboard',
      module: 'utility',
      description: 'Ẩn bàn phím ảo thiết bị',
      aliases: ['hideKeyboard'],
    ),
    BridgeActionSpec(
      action: 'contact.getContacts',
      module: 'device',
      description: 'Lấy danh bạ người dùng',
      requiredCapability: 'user.getProfile',
      isInteractive: true,
      aliases: ['getContacts'],
    ),

    // --- Permissions Module ---
    BridgeActionSpec(
      action: 'permission.request',
      module: 'permission',
      description: 'Yêu cầu người dùng cấp quyền cụ thể',
      isInteractive: true,
    ),
    BridgeActionSpec(
      action: 'permission.check',
      module: 'permission',
      description: 'Kiểm tra trạng thái cấp quyền hiện tại',
    ),
    BridgeActionSpec(
      action: 'permission.getAll',
      module: 'permission',
      description: 'Lấy toàn bộ quyền đã cấp cho Mini App',
      requiredCapability: 'permission.getPermissions',
      aliases: ['permission.getPermissions'],
    ),

    // --- System Info Queries (Direct aliases) ---
    BridgeActionSpec(
      action: 'app.getAppInfo',
      module: 'system',
      description: 'Lấy thông tin ứng dụng SuperApp Host',
      aliases: ['getAppInfo'],
    ),
    BridgeActionSpec(
      action: 'app.getSuperAppSettings',
      module: 'system',
      description: 'Lấy cài đặt cấu hình SuperApp Host',
      aliases: ['getSuperAppSettings'],
    ),

    // --- Debug Module ---
    BridgeActionSpec(
      action: 'debug.echo',
      module: 'debug',
      description: 'Kiểm tra độ trễ phản hồi Bridge',
    ),
    BridgeActionSpec(
      action: 'debug.simulateFailure',
      module: 'debug',
      description: 'Giả lập lỗi native để Mini App kiểm tra xử lý ngoại lệ',
    ),
  ];

  /// Set of 77 exact action names invoked directly by the official JS SDK (@vqh2602/mini-app-sdk).
  static const Set<String> requiredSdkActionNames = {
    'auth.exchangeCode',
    'auth.getAccessToken',
    'auth.getUserProfile',
    'auth.login',
    'auth.logout',
    'auth.refreshToken',
    'auth.requestCode',
    'closeApp',
    'copyToClipboard',
    'debug.echo',
    'debug.simulateFailure',
    'device.getBatteryInfo',
    'device.getDeviceInfo',
    'device.getNetworkInfo',
    'device.getSystemInfo',
    'device.keepScreen',
    'device.vibrate',
    'filePreview',
    'getAppInfo',
    'getBatteryInfo',
    'getContacts',
    'getDeviceLanguage',
    'getNetworkInfo',
    'getPhoto',
    'getSuperAppSettings',
    'getSystemInfo',
    'media.chooseImage',
    'media.scanQRCode',
    'navigation.close',
    'navigation.closeApp',
    'navigation.minimizeApp',
    'navigation.openMiniApp',
    'navigation.openNativePage',
    'payment.checkStatus',
    'payment.checkTransaction',
    'payment.createOrder',
    'payment.openCheckout',
    'payment.requestPayment',
    'permission.check',
    'permission.getAll',
    'permission.request',
    'phone.openDeepLink',
    'phone.openExternalBrowser',
    'phone.openPhone',
    'phone.openSMS',
    'pickFile',
    'pickImages',
    'pickVideo',
    'saveFile',
    'saveImageToGallery',
    'saveVideoToGallery',
    'scanQr',
    'setBrightness',
    'showMiniappMenu',
    'storage.clear',
    'storage.deleteCredentials',
    'storage.getAll',
    'storage.getCredentials',
    'storage.getItem',
    'storage.getSecureItem',
    'storage.removeItem',
    'storage.removeSecureItem',
    'storage.setCredentials',
    'storage.setItem',
    'storage.setSecureItem',
    'ui.configAppView',
    'ui.minimizeApp',
    'ui.requestSendNotification',
    'ui.setNavigationBarTitle',
    'ui.showAlert',
    'ui.showConfirm',
    'ui.showToast',
    'user.getBasicInfo',
    'user.getProfile',
    'utility.hideKeyboard',
    'utility.speechToText',
    'vibrate',
  };

  /// Returns the complete set of supported action names including all canonical actions and aliases.
  static Set<String> get allExpectedActionNames {
    final names = <String>{};
    for (final spec in actions) {
      names.add(spec.action);
      names.addAll(spec.aliases);
    }
    names.addAll(requiredSdkActionNames);
    return names;
  }

  /// Finds the spec for a given action name or alias.
  static BridgeActionSpec? findSpec(String actionName) {
    for (final spec in actions) {
      if (spec.action == actionName || spec.aliases.contains(actionName)) {
        return spec;
      }
    }
    return null;
  }
}
