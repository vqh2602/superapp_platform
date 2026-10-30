import React, { useState } from 'react';
import { useSDK, RunnerConfig } from '../context/SDKContext';
import { superApp, authBackend } from '../sdk';
import { FeatureItem } from './FeatureItem';
import {
  Key,
  User,
  Compass,
  Smartphone,
  CreditCard,
  ShieldAlert,
  Terminal,
  LogOut,
  ImageIcon,
  Store,
  FileText,
  UserCircle,
  RefreshCw,
  Database,
  Lock,
  Unlock,
  Trash2,
  KeyRound,
  ShieldCheck,
  Wifi,
  Globe,
  Sun,
  Vibrate,
  Copy,
  Sliders,
  Menu,
  Battery,
  Camera,
  Video,
  Folder,
  Contact,
  QrCode,
  Share2,
  Eye,
  Phone,
  MessageSquare,
  ExternalLink,
  Link2,
  Mic,
  Keyboard,
  Bell,
  Minimize2,
  Type,
} from 'lucide-react';

export const FeatureCatalog: React.FC = () => {
  const { authCode, setAuthCode, refreshToken, setRefreshToken, setAccessToken } = useSDK();
  const [createdOrderId, setCreatedOrderId] = useState<string>('');

  // ==========================================
  // 2.1 SYSTEM & DEVICE INFO ITEMS
  // ==========================================
  const sysNetworkConfig: RunnerConfig = {
    id: 'sys_network',
    category: '2.1. System & Device Info',
    title: 'getNetworkInfo',
    description: 'Lấy thông tin mạng hiện tại (wifi/cellular, trạng thái kết nối).',
    actionCode: 'superApp.getNetworkInfo()',
    hasParams: false,
    run: async () => superApp.getNetworkInfo(),
  };

  const sysLanguageConfig: RunnerConfig = {
    id: 'sys_language',
    category: '2.1. System & Device Info',
    title: 'getDeviceLanguage',
    description: 'Lấy ngôn ngữ và khu vực thiết bị (vi-VN, locale).',
    actionCode: 'superApp.getDeviceLanguage()',
    hasParams: false,
    run: async () => superApp.getDeviceLanguage(),
  };

  const sysSettingsConfig: RunnerConfig = {
    id: 'sys_settings',
    category: '2.1. System & Device Info',
    title: 'getSuperAppSettings',
    description: 'Lấy cấu hình giao diện từ SuperApp (theme, ngôn ngữ, timezone, múi giờ).',
    actionCode: 'superApp.getSuperAppSettings()',
    hasParams: false,
    run: async () => superApp.getSuperAppSettings(),
  };

  const sysInfoConfig: RunnerConfig = {
    id: 'sys_info',
    category: '2.1. System & Device Info',
    title: 'getSystemInfo',
    description: 'Lấy thông tin thiết bị (hệ điều hành, model, độ phân giải màn hình).',
    actionCode: 'superApp.getSystemInfo()',
    hasParams: false,
    run: async () => superApp.getSystemInfo(),
  };

  const sysAppInfoConfig: RunnerConfig = {
    id: 'sys_app_info',
    category: '2.1. System & Device Info',
    title: 'getAppInfo',
    description: 'Lấy thông tin miniapp hiện tại theo manifest.',
    actionCode: 'superApp.getAppInfo()',
    hasParams: false,
    run: async () => superApp.getAppInfo(),
  };

  const sysBatteryConfig: RunnerConfig = {
    id: 'sys_battery',
    category: '2.1. System & Device Info',
    title: 'getBatteryInfo',
    description: 'Lấy thông tin pin thiết bị (mức pin, trạng thái sạc).',
    actionCode: 'superApp.getBatteryInfo()',
    hasParams: false,
    run: async () => superApp.getBatteryInfo(),
  };

  // ==========================================
  // 2.2 UI & SYSTEM CONTROLS ITEMS
  // ==========================================
  const uiToastConfig: RunnerConfig = {
    id: 'ui_toast',
    category: '2.2. UI & System Controls',
    title: 'showToast',
    description: 'Hiển thị thông báo ngắn (toast) ở đáy màn hình.',
    actionCode: "superApp.showToast('Giao dịch đã được ghi nhận!')",
    hasParams: true,
    defaultParams: { message: 'Chào mừng bạn đến với SuperApp!', duration: 2500 },
    run: async (p) => superApp.showToast(p.message, p.duration),
  };

  const uiVibrateConfig: RunnerConfig = {
    id: 'ui_vibrate',
    category: '2.2. UI & System Controls',
    title: 'vibrate',
    description: 'Rung thiết bị (haptic feedback nhẹ/vừa/mạnh).',
    actionCode: "superApp.vibrate('medium')",
    hasParams: true,
    defaultParams: { style: 'medium' },
    run: async (p) => superApp.vibrate(p.style),
  };

  const uiClipboardConfig: RunnerConfig = {
    id: 'ui_clipboard',
    category: '2.2. UI & System Controls',
    title: 'copyToClipboard',
    description: 'Sao chép văn bản vào clipboard hệ thống.',
    actionCode: "superApp.copyToClipboard('SUPERAPP-PROMO-2026')",
    hasParams: true,
    defaultParams: { text: 'SUPERAPP-PROMO-2026' },
    run: async (p) => superApp.copyToClipboard(p.text),
  };

  const uiBrightnessConfig: RunnerConfig = {
    id: 'ui_brightness',
    category: '2.2. UI & System Controls',
    title: 'setBrightness',
    description: 'Đặt độ sáng màn hình (từ 0.0 đến 1.0).',
    actionCode: 'superApp.setBrightness(0.8)',
    hasParams: true,
    defaultParams: { brightness: 0.8 },
    run: async (p) => superApp.setBrightness(Number(p.brightness)),
  };

  const uiNavBarTitleConfig: RunnerConfig = {
    id: 'ui_navbar_title',
    category: '2.2. UI & System Controls',
    title: 'setNavigationBarTitle',
    description: 'Đặt lại tiêu đề trên thanh điều hướng AppBar của trang hiện tại.',
    actionCode: "superApp.setNavigationBarTitle({ title: 'Sản phẩm nổi bật' })",
    hasParams: true,
    defaultParams: { title: 'Sản phẩm nổi bật' },
    run: async (p) => superApp.setNavigationBarTitle(p),
  };

  const uiConfigAppViewConfig: RunnerConfig = {
    id: 'ui_config_view',
    category: '2.2. UI & System Controls',
    title: 'configAppView',
    description: 'Cấu hình toàn diện: Màu nền AppBar, StatusBar, chữ sáng/tối, bật/tắt safe area top/bot (riêng nút action góc phải luôn giữ safe area bảo mật).',
    actionCode: `await bridge.configAppView({
  headerColor: '#0068FF',
  statusBarColor: '#0052CC',
  textColor: 'white',
  statusBar: 'transparent',
  headerTitle: 'Sản phẩm nổi bật',
  actionBarHidden: false,
  hasPaddingTop: false,   // Tắt safe area top (tràn viền lên đỉnh)
  hasPaddingBottom: false // Tắt safe area bot (tràn viền xuống đáy)
});`,
    hasParams: true,
    defaultParams: {
      headerColor: '#0068FF',
      statusBarColor: '#0052CC',
      textColor: 'white',
      statusBar: 'transparent',
      headerTitle: 'Sản phẩm nổi bật',
      actionBarHidden: false,
      hasPaddingTop: false,
      hasPaddingBottom: false,
    },
    run: async (p) => superApp.configAppView(p),
  };

  const deviceKeepScreenConfig: RunnerConfig = {
    id: 'device_keep_screen',
    category: '2.2. UI & System Controls',
    title: 'keepScreen',
    description: 'Giữ màn hình luôn sáng / bật hoặc cho phép tắt khi không hoạt động.',
    actionCode: 'superApp.keepScreen({ keepScreenOn: true })',
    hasParams: true,
    defaultParams: { keepScreenOn: true },
    run: async (p) => superApp.keepScreen(p),
  };

  const uiNotificationConfig: RunnerConfig = {
    id: 'ui_notification',
    category: '2.2. UI & System Controls',
    title: 'requestSendNotification',
    description: 'Yêu cầu người dùng cho phép ứng dụng gửi thông báo qua OA / Mini App.',
    actionCode: "superApp.requestSendNotification({ templateId: 'order_status_update', reason: 'Nhận thông báo cập nhật đơn hàng' })",
    hasParams: true,
    defaultParams: { templateId: 'order_status_update', reason: 'Nhận thông báo cập nhật đơn hàng' },
    run: async (p) => superApp.requestSendNotification(p),
  };

  const navMinimizeConfig: RunnerConfig = {
    id: 'nav_minimize_app',
    category: '2.2. UI & System Controls',
    title: 'minimizeApp',
    description: 'Thu nhỏ mini app vào dock nền / quay về màn hình trước.',
    actionCode: 'superApp.minimizeApp()',
    hasParams: false,
    run: async () => superApp.minimizeApp(),
  };

  const uiMenuConfig: RunnerConfig = {
    id: 'ui_menu',
    category: '2.2. UI & System Controls',
    title: 'showMiniappMenu',
    description: 'Hiển thị menu hành động mặc định của shell.',
    actionCode: 'superApp.showMiniappMenu()',
    hasParams: false,
    run: async () => superApp.showMiniappMenu(),
  };

  const uiCloseAppConfig: RunnerConfig = {
    id: 'ui_close_app',
    category: '2.2. UI & System Controls',
    title: 'closeApp',
    description: 'Đóng miniapp, quay lại Launcher.',
    actionCode: 'superApp.closeApp()',
    hasParams: false,
    run: async () => superApp.closeApp(),
  };

  // ==========================================
  // 2.4 CAMERA & MEDIA ITEMS (QR & BARCODE)
  // ==========================================
  const mediaScanQrConfig: RunnerConfig = {
    id: 'media_scan_qr',
    category: '2.4. Camera & Media',
    title: 'scanQr',
    description: 'Quét mã QR & Mã vạch bằng camera (hỗ trợ QR Code, EAN-13, Code-128, tải ảnh hoặc chọn mẫu thử).',
    actionCode: 'superApp.scanQr()',
    hasParams: false,
    run: async () => superApp.scanQr(),
  };

  const mediaGetPhotoConfig: RunnerConfig = {
    id: 'media_get_photo',
    category: '2.4. Camera & Media',
    title: 'getPhoto',
    description: 'Chụp ảnh từ camera hoặc chọn 1 ảnh từ thư viện.',
    actionCode: "superApp.getPhoto({ source: 'camera' })",
    hasParams: true,
    defaultParams: { source: 'camera' },
    run: async (p) => superApp.getPhoto(p),
  };

  const mediaPickImagesConfig: RunnerConfig = {
    id: 'media_pick_images',
    category: '2.4. Camera & Media',
    title: 'pickImages',
    description: 'Chọn nhiều ảnh từ thư viện thiết bị.',
    actionCode: 'superApp.pickImages({ maxCount: 3 })',
    hasParams: true,
    defaultParams: { maxCount: 3 },
    run: async (p) => superApp.pickImages({ maxCount: Number(p.maxCount) }),
  };

  const mediaSaveImageConfig: RunnerConfig = {
    id: 'media_save_image',
    category: '2.4. Camera & Media',
    title: 'saveImageToGallery',
    description: 'Lưu 1 ảnh vào thư viện ảnh máy.',
    actionCode: "superApp.saveImageToGallery('content://media/photos/sample.jpg')",
    hasParams: true,
    defaultParams: { uri: 'content://media/photos/sample_image.jpg' },
    run: async (p) => superApp.saveImageToGallery(p.uri),
  };

  const mediaPickVideoConfig: RunnerConfig = {
    id: 'media_pick_video',
    category: '2.4. Camera & Media',
    title: 'pickVideo',
    description: 'Chọn 1 video từ thư viện thiết bị.',
    actionCode: 'superApp.pickVideo()',
    hasParams: false,
    run: async () => superApp.pickVideo(),
  };

  const mediaSaveVideoConfig: RunnerConfig = {
    id: 'media_save_video',
    category: '2.4. Camera & Media',
    title: 'saveVideoToGallery',
    description: 'Lưu video vào thư viện máy.',
    actionCode: "superApp.saveVideoToGallery('content://videos/sample.mp4')",
    hasParams: true,
    defaultParams: { uri: 'content://videos/sample_video.mp4' },
    run: async (p) => superApp.saveVideoToGallery(p.uri),
  };

  // ==========================================
  // 2.5 FILE MANAGEMENT ITEMS
  // ==========================================
  const fileSaveFileConfig: RunnerConfig = {
    id: 'file_save',
    category: '2.5. File',
    title: 'saveFile',
    description: 'Mở Share Sheet để lưu hoặc chia sẻ 1 file.',
    actionCode: "superApp.saveFile({ fileName: 'bao_cao_quy_1.pdf' })",
    hasParams: true,
    defaultParams: { fileName: 'bao_cao_quy_1_2026.pdf', mimeType: 'application/pdf' },
    run: async (p) => superApp.saveFile(p),
  };

  const filePickFileConfig: RunnerConfig = {
    id: 'file_pick',
    category: '2.5. File',
    title: 'pickFile',
    description: 'Mở trình quản lý file hệ thống để chọn 1 (hoặc nhiều) file.',
    actionCode: 'superApp.pickFile({ allowMultiple: true })',
    hasParams: true,
    defaultParams: { allowMultiple: true },
    run: async (p) => superApp.pickFile(p),
  };

  const filePreviewConfig: RunnerConfig = {
    id: 'file_preview',
    category: '2.5. File',
    title: 'filePreview',
    description: 'Mở màn hình xem trước 1 file (PDF, ảnh...) trong SuperApp.',
    actionCode: "superApp.filePreview({ fileUrl, fileName })",
    hasParams: true,
    defaultParams: { fileUrl: 'https://superapp.com/files/bao_cao.pdf', fileName: 'Báo Cáo Tài Chính 2026.pdf' },
    run: async (p) => superApp.filePreview(p),
  };

  // ==========================================
  // 2.8 KEYCHAIN & KEYSTORE (SECRET DATA)
  // ==========================================
  const secSetSecretDataConfig: RunnerConfig = {
    id: 'sec_set_secret',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'setSecretData',
    description: 'Lưu dữ liệu nhạy cảm vào Keychain/Keystore theo domain.',
    actionCode: 'superApp.setSecretData(key, value, domain)',
    hasParams: true,
    defaultParams: {
      key: 'auth_jwt_token',
      value: 'jwt_secure_key_998127391_enc',
      domain: 'superapp.auth',
    },
    run: async (p) => superApp.setSecretData(p.key, p.value, p.domain),
  };

  const secGetSecretDataConfig: RunnerConfig = {
    id: 'sec_get_secret',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'getSecretData',
    description: 'Đọc dữ liệu bảo mật đã lưu từ Keychain/Keystore.',
    actionCode: 'superApp.getSecretData(key, domain)',
    hasParams: true,
    defaultParams: {
      key: 'auth_jwt_token',
      domain: 'superapp.auth',
    },
    run: async (p) => superApp.getSecretData(p.key, p.domain),
  };

  const secRemoveSecretDataConfig: RunnerConfig = {
    id: 'sec_remove_secret',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'removeSecretData',
    description: 'Xoá 1 khoá dữ liệu bảo mật khỏi Keychain/Keystore.',
    actionCode: 'superApp.removeSecretData(key, domain)',
    hasParams: true,
    defaultParams: {
      key: 'auth_jwt_token',
      domain: 'superapp.auth',
    },
    run: async (p) => superApp.removeSecretData(p.key, p.domain),
  };

  const credentialsSetConfig: RunnerConfig = {
    id: 'cred_set',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'setCredentials',
    description: 'Lưu username/password an toàn (Keychain/Keystore) theo domain.',
    actionCode: 'superApp.storage.setCredentials(domain, username, password)',
    hasParams: true,
    defaultParams: {
      domain: 'superapp.finance.vn',
      username: 'nguyenvana_vip',
      password: 'SuperSecretPassword@2026',
    },
    run: async (p) => superApp.storage.setCredentials(p.domain, p.username, p.password),
  };

  const credentialsGetConfig: RunnerConfig = {
    id: 'cred_get',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'getCredentials',
    description: 'Lấy lại username/password đã lưu an toàn theo domain.',
    actionCode: 'superApp.storage.getCredentials(domain)',
    hasParams: true,
    defaultParams: {
      domain: 'superapp.finance.vn',
    },
    run: async (p) => superApp.storage.getCredentials(p.domain),
  };

  const credentialsDeleteConfig: RunnerConfig = {
    id: 'cred_del',
    category: '2.8. Secret Data (Keychain/Keystore)',
    title: 'deleteCredentials',
    description: 'Xoá username/password đã lưu an toàn theo domain.',
    actionCode: 'superApp.storage.deleteCredentials(domain)',
    hasParams: true,
    defaultParams: {
      domain: 'superapp.finance.vn',
    },
    run: async (p) => superApp.storage.deleteCredentials(p.domain),
  };

  // ==========================================
  // 2.9 DANH BẠ (CONTACTS)
  // ==========================================
  const contactsGetConfig: RunnerConfig = {
    id: 'contacts_get',
    category: '2.9. Danh bạ',
    title: 'getContacts',
    description: "Lấy danh sách danh bạ máy (cần quyền 'contacts').",
    actionCode: 'superApp.getContacts()',
    hasParams: false,
    run: async () => superApp.getContacts(),
  };

  // ==========================================
  // AUTH & USER & PAYMENT & PERMISSIONS
  // ==========================================
  const authRequestCodeConfig: RunnerConfig = {
    id: 'auth_req_code',
    category: 'A. Authentication',
    title: 'Flow A — Request Auth Code',
    description: 'Yêu cầu mã xác thực đăng nhập từ Master App (Single-use, 60s TTL)',
    actionCode: 'superApp.auth.requestCode()',
    hasParams: false,
    run: async () => {
      const res = await superApp.auth.requestCode();
      setAuthCode(res.authCode);
      return res;
    },
  };

  const authExchangeTokenConfig: RunnerConfig = {
    id: 'auth_exchange_code',
    category: 'A. Authentication',
    title: 'Flow B — Exchange Token',
    description: 'Đổi authCode lấy Mini App Access Token và Refresh Token qua Backend API',
    actionCode: 'authBackend.exchangeCode(authCode)',
    hasParams: true,
    defaultParams: { authCode: authCode || '' },
    run: async (p) => {
      const res = await authBackend.exchangeCode(p.authCode);
      setAccessToken(res.accessToken);
      setRefreshToken(res.refreshToken);
      return res;
    },
  };

  const authRefreshTokenConfig: RunnerConfig = {
    id: 'auth_refresh_token',
    category: 'A. Authentication',
    title: 'Flow C — Refresh Token',
    description: 'Yêu cầu cấp lại Access Token mới khi token cũ hết hạn',
    actionCode: 'authBackend.refreshToken(refreshToken)',
    hasParams: true,
    defaultParams: {
      refreshToken: refreshToken || '',
    },
    run: async (p) => {
      const res = await authBackend.refreshToken(p.refreshToken);
      setAccessToken(res.accessToken);
      setRefreshToken(res.refreshToken);
      return res;
    },
  };

  const authLogoutConfig: RunnerConfig = {
    id: 'auth_logout',
    category: 'A. Authentication',
    title: 'Flow D — Logout Session',
    description: 'Đăng xuất tài khoản Master App và vô hiệu hoá session',
    actionCode: 'superApp.auth.logout()',
    hasParams: false,
    run: async () => superApp.auth.logout(),
  };

  const userGetProfileConfig: RunnerConfig = {
    id: 'user_profile',
    category: 'B. User & Profile',
    title: 'Get User Profile',
    description: 'Lấy đầy đủ thông tin cá nhân của user đang active từ Backend API',
    actionCode: 'superApp.user.getProfile()',
    hasParams: false,
    run: async () => superApp.user.getProfile(),
  };

  const userGetBasicInfoConfig: RunnerConfig = {
    id: 'user_basic_info',
    category: 'B. User & Profile',
    title: 'Get Basic Info',
    description: 'Lấy thông tin cơ bản công khai (tên hiển thị, avatar)',
    actionCode: 'superApp.user.getBasicInfo()',
    hasParams: false,
    run: async () => superApp.user.getBasicInfo(),
  };

  const navProfilePageConfig: RunnerConfig = {
    id: 'nav_profile',
    category: 'C. Native Navigation',
    title: 'Open Native Profile Screen',
    description: 'Mở màn hình Native Profile được dựng hoàn toàn bằng Flutter',
    actionCode: "superApp.navigation.openNativePage('profile')",
    hasParams: false,
    run: async () => superApp.navigation.openNativePage('profile'),
  };

  const navSwitchAppConfig: RunnerConfig = {
    id: 'nav_switch_app',
    category: 'C. Native Navigation',
    title: 'Switch to Mini App 2 (Store)',
    description: 'Chuyển đổi runtime sang Mini App mẫu thứ hai (Sample Store)',
    actionCode: "superApp.navigation.openMiniApp('sample_store')",
    hasParams: false,
    run: async () => superApp.navigation.openMiniApp('sample_store'),
  };

  const paymentCreateOrderConfig: RunnerConfig = {
    id: 'pay_create_order',
    category: 'E. Payment & Business Flows',
    title: '1. Create Order',
    description: 'Yêu cầu tạo đơn hàng qua Backend API',
    actionCode: 'superApp.payment.createOrder(params)',
    hasParams: true,
    defaultParams: {
      amount: 120000,
      description: 'Thanh toán combo nước giải khát Mini App',
      currency: 'VND',
    },
    run: async (p) => {
      const res = await superApp.payment.createOrder(p);
      setCreatedOrderId(res.orderId);
      return res;
    },
  };

  const paymentCheckoutConfig: RunnerConfig = {
    id: 'pay_checkout',
    category: 'E. Payment & Business Flows',
    title: '2. Open Native Checkout',
    description: 'Mở BottomSheet/Screen Checkout Flutter (chọn Success, Failure, Cancel)',
    actionCode: 'superApp.payment.openCheckout(orderId)',
    hasParams: true,
    defaultParams: {
      orderId: createdOrderId || 'ORD_DEMO_SAMPLE_001',
    },
    run: async (p) => superApp.payment.openCheckout(p.orderId),
  };

  const permissionGetPermissionsConfig: RunnerConfig = {
    id: 'perm_get_all',
    category: 'F. Permissions',
    title: 'getPermissions',
    description: 'Lấy danh sách quyền đã được cấp cho Mini App từ Backend API',
    actionCode: 'superApp.permission.getPermissions()',
    hasParams: false,
    run: async () => superApp.permission.getPermissions(),
  };

  const permissionRequestConfig: RunnerConfig = {
    id: 'perm_req',
    category: 'F. Permissions',
    title: 'Request Permission Dialog',
    description: 'Kích hoạt hộp thoại xin quyền Native của Flutter (Allow / Deny)',
    actionCode: "superApp.permission.request('device.scanQRCode')",
    hasParams: true,
    defaultParams: { capability: 'device.scanQRCode' },
    run: async (p) => superApp.permission.request(p.capability),
  };

  const permissionCheckConfig: RunnerConfig = {
    id: 'perm_check',
    category: 'F. Permissions',
    title: 'Check Permission State',
    description: 'Kiểm tra trạng thái quyền hiện tại trong Backend API',
    actionCode: "superApp.permission.check('device.scanQRCode')",
    hasParams: true,
    defaultParams: { capability: 'device.scanQRCode' },
    run: async (p) => superApp.permission.check(p.capability),
  };

  const debugEchoConfig: RunnerConfig = {
    id: 'dbg_echo',
    category: 'H. Debug & Testing',
    title: 'Bridge Echo / Heartbeat',
    description: 'Gửi gói tin ping kiểm tra tốc độ phản hồi 2 chiều của Flutter Bridge',
    actionCode: 'superApp.debug.echo(payload)',
    hasParams: true,
    defaultParams: { ping: 'hello_native_bridge', time: Date.now() },
    run: async (p) => superApp.debug.echo(p),
  };

  // ==========================================
  // 2.11 ĐIỆN THOẠI & LIÊN KẾT NGOÀI
  // ==========================================
  const phoneOpenPhoneConfig: RunnerConfig = {
    id: 'phone_open_phone',
    category: '2.11. Điện thoại & Liên kết ngoài',
    title: 'openPhone',
    description: 'Mở màn hình quay số điện thoại Native (tel:).',
    actionCode: "superApp.openPhone('0987654321')",
    hasParams: true,
    defaultParams: { phoneNumber: '0987654321' },
    run: async (p) => superApp.openPhone(p.phoneNumber),
  };

  const phoneOpenSmsConfig: RunnerConfig = {
    id: 'phone_open_sms',
    category: '2.11. Điện thoại & Liên kết ngoài',
    title: 'openSMS',
    description: 'Mở app nhắn tin SMS với số điện thoại & nội dung soạn sẵn.',
    actionCode: "superApp.openSMS('0987654321', 'Xin chào từ SuperApp!')",
    hasParams: true,
    defaultParams: {
      phoneNumber: '0987654321',
      body: 'Xin chào từ SuperApp!',
    },
    run: async (p) => superApp.openSMS(p.phoneNumber, p.body),
  };

  const phoneOpenExternalBrowserConfig: RunnerConfig = {
    id: 'phone_open_ext_browser',
    category: '2.11. Điện thoại & Liên kết ngoài',
    title: 'openExternalBrowser',
    description: 'Mở URL bằng trình duyệt ngoài (Safari/Chrome), rời khỏi ứng dụng.',
    actionCode: "superApp.openExternalBrowser('https://flutter.dev')",
    hasParams: true,
    defaultParams: { url: 'https://flutter.dev' },
    run: async (p) => superApp.openExternalBrowser(p.url),
  };

  const phoneOpenDeepLinkConfig: RunnerConfig = {
    id: 'phone_open_deep_link',
    category: '2.11. Điện thoại & Liên kết ngoài',
    title: 'openDeepLink',
    description: 'Mở deep link / URL trong trình duyệt in-app của SuperApp.',
    actionCode: "superApp.openDeepLink('https://dart.dev')",
    hasParams: true,
    defaultParams: { url: 'https://dart.dev' },
    run: async (p) => superApp.openDeepLink(p.url),
  };

  // ==========================================
  // 2.12 NHẬP LIỆU & TIỆN ÍCH
  // ==========================================
  const utilSpeechToTextConfig: RunnerConfig = {
    id: 'util_speech_to_text',
    category: '2.12. Nhập liệu & Tiện ích',
    title: 'speechToText',
    description: 'Mở dialog ghi âm thực tế và chuyển giọng nói thành văn bản (cần quyền microphone).',
    actionCode: "superApp.speechToText({ lang: 'vi-VN' })",
    hasParams: true,
    defaultParams: { lang: 'vi-VN' },
    run: async (p) => superApp.speechToText(p),
  };

  const utilHideKeyboardConfig: RunnerConfig = {
    id: 'util_hide_keyboard',
    category: '2.12. Nhập liệu & Tiện ích',
    title: 'hideKeyboard',
    description: 'Ẩn bàn phím ảo đang hiển thị trên màn hình.',
    actionCode: 'superApp.hideKeyboard()',
    hasParams: false,
    run: async () => superApp.hideKeyboard(),
  };

  return (
    <div className="catalog-wrapper">
      {/* 2.4 CAMERA & MEDIA (QR & BARCODE) */}
      <section className="category-section">
        <div className="category-header">
          <QrCode className="category-icon" size={18} />
          <h2 className="category-title">2.4. Camera & Media (6 actions — QR & Mã Vạch Thực)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<QrCode size={20} />} config={mediaScanQrConfig} statusText="QR & Barcode" />
          <FeatureItem icon={<Camera size={20} />} config={mediaGetPhotoConfig} statusText="Camera/Gallery" />
          <FeatureItem icon={<ImageIcon size={20} />} config={mediaPickImagesConfig} statusText="Multi Pick" />
          <FeatureItem icon={<ImageIcon size={20} />} config={mediaSaveImageConfig} statusText="Save Photo" />
          <FeatureItem icon={<Video size={20} />} config={mediaPickVideoConfig} statusText="Video Pick" />
          <FeatureItem icon={<Video size={20} />} config={mediaSaveVideoConfig} statusText="Save Video" />
        </div>
      </section>

      {/* 2.1 SYSTEM & DEVICE INFO */}
      <section className="category-section">
        <div className="category-header">
          <Smartphone className="category-icon" size={18} />
          <h2 className="category-title">2.1. System & Device Info</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Wifi size={20} />} config={sysNetworkConfig} statusText="Network State" />
          <FeatureItem icon={<Globe size={20} />} config={sysLanguageConfig} statusText="Locale/Lang" />
          <FeatureItem icon={<Sliders size={20} />} config={sysSettingsConfig} statusText="SuperApp Settings" />
          <FeatureItem icon={<Smartphone size={20} />} config={sysInfoConfig} statusText="Hardware/OS" />
          <FeatureItem icon={<FileText size={20} />} config={sysAppInfoConfig} statusText="App Manifest" />
          <FeatureItem icon={<Battery size={20} />} config={sysBatteryConfig} statusText="Battery Level" />
        </div>
      </section>

      {/* 2.2 UI & SYSTEM CONTROLS */}
      <section className="category-section">
        <div className="category-header">
          <Sliders className="category-icon" size={18} />
          <h2 className="category-title">2.2. UI & System Controls (Unified)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Compass size={20} />} config={uiConfigAppViewConfig} statusText="Unified App View" />
          <FeatureItem icon={<Type size={20} />} config={uiNavBarTitleConfig} statusText="NavBar Title" />
          <FeatureItem icon={<Sun size={20} />} config={deviceKeepScreenConfig} statusText="Keep Screen Awake" />
          <FeatureItem icon={<Bell size={20} />} config={uiNotificationConfig} statusText="OA Notification" />
          <FeatureItem icon={<Minimize2 size={20} />} config={navMinimizeConfig} statusText="Minimize App" />
          <FeatureItem icon={<Terminal size={20} />} config={uiToastConfig} statusText="Bottom Toast" />
          <FeatureItem icon={<Vibrate size={20} />} config={uiVibrateConfig} statusText="Haptic Vibrate" />
          <FeatureItem icon={<Copy size={20} />} config={uiClipboardConfig} statusText="Copy Text" />
          <FeatureItem icon={<Sun size={20} />} config={uiBrightnessConfig} statusText="Brightness" />
          <FeatureItem icon={<Menu size={20} />} config={uiMenuConfig} statusText="Shell Menu" />
          <FeatureItem icon={<LogOut size={20} />} config={uiCloseAppConfig} statusText="Close App" isDanger />
        </div>
      </section>

      {/* 2.5 FILE MANAGEMENT */}
      <section className="category-section">
        <div className="category-header">
          <Folder className="category-icon" size={18} />
          <h2 className="category-title">2.5. File Management (3 actions)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Share2 size={20} />} config={fileSaveFileConfig} statusText="Share Sheet" />
          <FeatureItem icon={<Folder size={20} />} config={filePickFileConfig} statusText="System File" />
          <FeatureItem icon={<Eye size={20} />} config={filePreviewConfig} statusText="PDF/Image View" />
        </div>
      </section>

      {/* 2.8 KEYCHAIN & KEYSTORE */}
      <section className="category-section">
        <div className="category-header">
          <Database className="category-icon" size={18} />
          <h2 className="category-title">2.8. Keychain & Keystore (Secret Data & Credentials)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Lock size={20} />} config={secSetSecretDataConfig} statusText="Keychain/Keystore" />
          <FeatureItem icon={<Unlock size={20} />} config={secGetSecretDataConfig} statusText="Decrypted Read" />
          <FeatureItem icon={<Trash2 size={20} />} config={secRemoveSecretDataConfig} statusText="Remove Key" />
          <FeatureItem icon={<KeyRound size={20} />} config={credentialsSetConfig} statusText="Domain Vault" />
          <FeatureItem icon={<KeyRound size={20} />} config={credentialsGetConfig} statusText="Retrieve Vault" />
          <FeatureItem icon={<Trash2 size={20} />} config={credentialsDeleteConfig} statusText="Delete Vault" isDanger />
        </div>
      </section>

      {/* 2.9 DANH BẠ */}
      <section className="category-section">
        <div className="category-header">
          <Contact className="category-icon" size={18} />
          <h2 className="category-title">2.9. Danh bạ (Contacts)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Contact size={20} />} config={contactsGetConfig} statusText="Requires 'contacts'" />
        </div>
      </section>

      {/* 2.11 ĐIỆN THOẠI & LIÊN KẾT NGOÀI */}
      <section className="category-section">
        <div className="category-header">
          <Phone className="category-icon" size={18} />
          <h2 className="category-title">2.11. Điện thoại & Liên kết ngoài (4 actions)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Phone size={20} />} config={phoneOpenPhoneConfig} statusText="Dialer tel:" />
          <FeatureItem icon={<MessageSquare size={20} />} config={phoneOpenSmsConfig} statusText="Native SMS" />
          <FeatureItem icon={<ExternalLink size={20} />} config={phoneOpenExternalBrowserConfig} statusText="Safari/Chrome" />
          <FeatureItem icon={<Link2 size={20} />} config={phoneOpenDeepLinkConfig} statusText="In-App View" />
        </div>
      </section>

      {/* 2.12 NHẬP LIỆU & TIỆN ÍCH */}
      <section className="category-section">
        <div className="category-header">
          <Mic className="category-icon" size={18} />
          <h2 className="category-title">2.12. Nhập liệu & Tiện ích (2 actions)</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Mic size={20} />} config={utilSpeechToTextConfig} statusText="Voice Record" />
          <FeatureItem icon={<Keyboard size={20} />} config={utilHideKeyboardConfig} statusText="Dismiss Focus" />
        </div>
      </section>

      {/* CATEGORY A: AUTH */}
      <section className="category-section">
        <div className="category-header">
          <Key className="category-icon" size={18} />
          <h2 className="category-title">A. Authentication Flow</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Key size={20} />} config={authRequestCodeConfig} statusText="60s TTL" />
          <FeatureItem icon={<RefreshCw size={20} />} config={authExchangeTokenConfig} statusText="Token Exchange" />
          <FeatureItem icon={<RefreshCw size={20} />} config={authRefreshTokenConfig} statusText="Refresh" />
          <FeatureItem icon={<LogOut size={20} />} config={authLogoutConfig} statusText="Logout" isDanger />
        </div>
      </section>

      {/* CATEGORY B: USER & PROFILE */}
      <section className="category-section">
        <div className="category-header">
          <User className="category-icon" size={18} />
          <h2 className="category-title">B. User & Profile</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<UserCircle size={20} />} config={userGetProfileConfig} statusText="Protected" />
          <FeatureItem icon={<User size={20} />} config={userGetBasicInfoConfig} statusText="Basic Info" />
        </div>
      </section>

      {/* CATEGORY E: PAYMENT */}
      <section className="category-section">
        <div className="category-header">
          <CreditCard className="category-icon" size={18} />
          <h2 className="category-title">E. Payment & Business Flows</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<CreditCard size={20} />} config={paymentCreateOrderConfig} statusText="Step 1" />
          <FeatureItem icon={<CreditCard size={20} />} config={paymentCheckoutConfig} statusText="Step 2: Native UI" />
        </div>
      </section>

      {/* CATEGORY F: CAPABILITY & PERMISSIONS */}
      <section className="category-section">
        <div className="category-header">
          <ShieldAlert className="category-icon" size={18} />
          <h2 className="category-title">F. Capability & Permissions</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<ShieldCheck size={20} />} config={permissionGetPermissionsConfig} statusText="Active Grants" />
          <FeatureItem icon={<ShieldAlert size={20} />} config={permissionRequestConfig} statusText="Native Dialog" />
          <FeatureItem icon={<ShieldAlert size={20} />} config={permissionCheckConfig} statusText="Check Status" />
        </div>
      </section>

      {/* CATEGORY H: DEBUG */}
      <section className="category-section">
        <div className="category-header">
          <Terminal className="category-icon" size={18} />
          <h2 className="category-title">H. Debug & Connectivity</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Terminal size={20} />} config={debugEchoConfig} statusText="Bridge Ping" />
          <FeatureItem icon={<Store size={20} />} config={navSwitchAppConfig} statusText="Switch App" />
          <FeatureItem icon={<UserCircle size={20} />} config={navProfilePageConfig} statusText="Native Page" />
        </div>
      </section>
    </div>
  );
};
