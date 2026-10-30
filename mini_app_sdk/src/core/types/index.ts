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
  level: number;
  status: string;
  temperature: number | null;
  timestamp: number;
  isCharging: boolean;
}

export interface NetworkInfo {
  isConnected: boolean; networkType: string; isWifi: boolean; isMobile: boolean;
  ssid: string | null; bssid: string | null; ipAddress: string | null;
  signalStrength: string | null; timestamp: number;
}
export interface DeviceInfo {
  platform: string; osVersion: string | null; deviceModel: string | null; brand: string | null;
  screenWidth: number | null; screenHeight: number | null; pixelRatio: number | null;
  statusBarHeight: number | null; safeAreaBottom: number | null; timestamp: number;
}
export interface ContactInfo {
  id: string; displayName: string; phoneNumber: string | null; email: string | null;
  phoneNumbers: string[]; emails: string[]; department: string | null;
}
export interface ContactsResult { contacts: ContactInfo[]; total: number; }

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
  statusBarColor?: string;
  actionBarHidden?: boolean;
  hideAndroidBottomNavigationBar?: boolean;
  hasPadding?: boolean;
  hasPaddingTop?: boolean;
  hasPaddingBottom?: boolean;
  safeAreaTop?: boolean;
  safeAreaBottom?: boolean;
  safeArea?: boolean | { top?: boolean; bottom?: boolean };
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
