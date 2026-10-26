import React, { useState } from 'react';
import { useSDK, RunnerConfig } from '../context/SDKContext';
import { superApp, mockAuthBackend } from '../sdk';
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
  Scan,
  MapPin,
  Image,
  Store,
  FileText,
  UserCircle,
  RefreshCw,
} from 'lucide-react';

export const FeatureCatalog: React.FC = () => {
  const { authCode, setAuthCode, refreshToken, setRefreshToken, setAccessToken } = useSDK();
  const [createdOrderId, setCreatedOrderId] = useState<string>('');

  // 1. Auth items
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
    description: 'Đổi authCode lấy Mini App Access Token và Refresh Token qua Mock Backend',
    actionCode: 'mockAuthBackend.exchangeCode(authCode)',
    hasParams: true,
    defaultParams: { authCode: authCode || 'AUTH_SDK_PLAYGROUND_DEMO' },
    run: async (p) => {
      const res = await mockAuthBackend.exchangeCode(p.authCode);
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
    actionCode: 'mockAuthBackend.refreshToken(refreshToken)',
    hasParams: true,
    defaultParams: {
      refreshToken: refreshToken || 'mini_rt_demo_example',
      simulateError: false,
    },
    run: async (p) => {
      const res = await mockAuthBackend.refreshToken(p.refreshToken, p.simulateError);
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
    run: async () => {
      return superApp.auth.logout();
    },
  };

  // 2. User Profile items
  const userGetProfileConfig: RunnerConfig = {
    id: 'user_profile',
    category: 'B. User & Profile',
    title: 'Get User Profile',
    description: 'Lấy đầy đủ thông tin cá nhân của user đang active từ MockAuthRepository',
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

  // 3. Navigation items
  const navProfilePageConfig: RunnerConfig = {
    id: 'nav_profile',
    category: 'C. Native Navigation',
    title: 'Open Native Profile Screen',
    description: 'Mở màn hình Native Profile được dựng hoàn toàn bằng Flutter',
    actionCode: "superApp.navigation.openNativePage('profile')",
    hasParams: false,
    run: async () => superApp.navigation.openNativePage('profile'),
  };

  const navFormPageConfig: RunnerConfig = {
    id: 'nav_form',
    category: 'C. Native Navigation',
    title: 'Open Native Form Screen',
    description: 'Mở màn hình Form Flutter thu thập dữ liệu và trả kết quả về React',
    actionCode: "superApp.navigation.openNativePage('form', params)",
    hasParams: true,
    defaultParams: { title: 'Feedback từ Mini App', category: 'Support' },
    run: async (p) => superApp.navigation.openNativePage('form', p),
  };

  const navCloseConfig: RunnerConfig = {
    id: 'nav_close',
    category: 'C. Native Navigation',
    title: 'Close Mini App',
    description: 'Đóng Mini App runtime và trở về danh mục Master App',
    actionCode: 'superApp.navigation.close()',
    hasParams: false,
    run: async () => superApp.navigation.close(),
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

  // 4. Device items
  const deviceScanQrConfig: RunnerConfig = {
    id: 'device_qr',
    category: 'D. Device APIs',
    title: 'Scan QR Code',
    description: 'Quét mã QR qua Mock Device Adapter (hỗ trợ bật Real Device Mode)',
    actionCode: 'superApp.device.scanQRCode()',
    hasParams: false,
    run: async () => superApp.device.scanQRCode(),
  };

  const deviceLocationConfig: RunnerConfig = {
    id: 'device_location',
    category: 'D. Device APIs',
    title: 'Get GPS Location',
    description: 'Truy vấn tọa độ địa lý mẫu (TP. Hồ Chí Minh) qua Mock Adapter',
    actionCode: 'superApp.device.getLocation()',
    hasParams: false,
    run: async () => superApp.device.getLocation(),
  };

  const deviceImageConfig: RunnerConfig = {
    id: 'device_image',
    category: 'D. Device APIs',
    title: 'Pick Image',
    description: 'Chọn ảnh từ thư viện thiết bị (trả metadata ảnh)',
    actionCode: 'superApp.device.pickImage()',
    hasParams: false,
    run: async () => superApp.device.pickImage(),
  };

  // 5. Payment items
  const paymentCreateOrderConfig: RunnerConfig = {
    id: 'pay_create_order',
    category: 'E. Payment & Business Flows',
    title: '1. Create Order',
    description: 'Khởi tạo đơn hàng giả lập trong MockOrderRepository',
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

  // 6. Permissions items
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
    description: 'Kiểm tra trạng thái quyền hiện tại trong MockPermissionRepository',
    actionCode: "superApp.permission.check('device.scanQRCode')",
    hasParams: true,
    defaultParams: { capability: 'device.scanQRCode' },
    run: async (p) => superApp.permission.check(p.capability),
  };

  // 7. Debug items
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

  return (
    <div className="catalog-wrapper">
      {/* Category A */}
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

      {/* Category B */}
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

      {/* Category C */}
      <section className="category-section">
        <div className="category-header">
          <Compass className="category-icon" size={18} />
          <h2 className="category-title">C. Native Navigation</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<UserCircle size={20} />} config={navProfilePageConfig} statusText="Flutter Page" />
          <FeatureItem icon={<FileText size={20} />} config={navFormPageConfig} statusText="Native Form" />
          <FeatureItem icon={<Store size={20} />} config={navSwitchAppConfig} statusText="Switch Mini App" />
          <FeatureItem icon={<LogOut size={20} />} config={navCloseConfig} statusText="Exit Mini App" />
        </div>
      </section>

      {/* Category D */}
      <section className="category-section">
        <div className="category-header">
          <Smartphone className="category-icon" size={18} />
          <h2 className="category-title">D. Device APIs</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Scan size={20} />} config={deviceScanQrConfig} statusText="Mock QR" />
          <FeatureItem icon={<MapPin size={20} />} config={deviceLocationConfig} statusText="Mock GPS" />
          <FeatureItem icon={<Image size={20} />} config={deviceImageConfig} statusText="Mock Image" />
        </div>
      </section>

      {/* Category E */}
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

      {/* Category F */}
      <section className="category-section">
        <div className="category-header">
          <ShieldAlert className="category-icon" size={18} />
          <h2 className="category-title">F. Capability & Permissions</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<ShieldAlert size={20} />} config={permissionRequestConfig} statusText="Native Dialog" />
          <FeatureItem icon={<ShieldAlert size={20} />} config={permissionCheckConfig} statusText="Check Status" />
        </div>
      </section>

      {/* Category H */}
      <section className="category-section">
        <div className="category-header">
          <Terminal className="category-icon" size={18} />
          <h2 className="category-title">H. Debug & Connectivity</h2>
        </div>
        <div className="feature-grid">
          <FeatureItem icon={<Terminal size={20} />} config={debugEchoConfig} statusText="Bridge Ping" />
        </div>
      </section>
    </div>
  );
};
