export interface UserProfile {
  id: string;
  name: string;
  phone?: string;
  email?: string;
  avatarUrl?: string;
  role?: string;
  isVerified?: boolean;
}

export interface AuthLoginOptions {
  scopes?: ('user.profile' | 'user.phone' | 'user.email')[];
  prompt?: boolean;
}

export interface AuthLoginResult {
  authCode: string;
  accessToken: string;
  expiresIn: number;
  user: UserProfile;
}

export interface AccessTokenResult {
  accessToken: string;
  tokenType: string;
  expiresIn: number;
}

export interface BatteryInfo {
  batteryLevel: number;
  isCharging: boolean;
}

export interface NetworkInfo {
  isConnected: boolean;
  networkType: string;
  isWifi: boolean;
  isMobile: boolean;
}

export interface DeviceInfo {
  model: string;
  platform: string;
  systemName: string;
  systemVersion: string;
  language: string;
  screenWidth: number;
  screenHeight: number;
  pixelRatio: number;
}

export interface ToastOptions {
  message: string;
  duration?: number;
}

export interface AlertOptions {
  title: string;
  message: string;
  buttonText?: string;
}

export interface ConfirmOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
}

export interface QRCodeResult {
  content: string;
  format: string;
}

export interface ChooseImageOptions {
  count?: number;
}

export interface ChooseImageResult {
  tempFilePaths: string[];
  count: number;
}

export interface SDKInitOptions {
  appId?: string;
  timeoutMs?: number;
  debug?: boolean;
}

export interface ConfigAppViewOptions {
  headerColor?: string;
  headerTitle?: string;
  textColor?: 'white' | 'black';
  statusBar?: 'transparent' | 'hidden' | 'light' | 'dark';
  actionBarHidden?: boolean;
  hideAndroidBottomNavigationBar?: boolean;
  hasPadding?: boolean;
  bottomNavColor?: string;
  header?: {
    color?: string;
    title?: string;
    textColor?: 'white' | 'black';
    hidden?: boolean;
    hide?: boolean;
  };
  bottomNav?: {
    color?: string;
    hidden?: boolean;
    hide?: boolean;
  };
}

export interface SetNavigationBarColorOptions {
  color: string;
  textColor?: 'white' | 'black';
  statusBarColor?: string;
}

export interface KeepScreenOptions {
  keepScreenOn?: boolean;
}

export interface RequestSendNotificationOptions {
  templateId?: string;
  reason?: string;
}

export interface NotificationResult {
  success: boolean;
  granted: boolean;
  subscriptionId?: string;
  token?: string;
  templateId?: string;
  reason?: string;
  message?: string;
  error?: string;
}

export interface MinimizeAppResult {
  success: boolean;
  status: string;
  appId: string;
  timestamp?: number;
}
