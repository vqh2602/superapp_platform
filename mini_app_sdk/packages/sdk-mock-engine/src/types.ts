export interface MockUserProfile {
  id: string;
  name: string;
  phone: string;
  email: string;
  avatarUrl: string;
  role: 'CUSTOMER' | 'VIP' | 'MERCHANT' | 'ADMIN';
  isVerified: boolean;
  walletBalance: number;
}

export interface MockTokenSession {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: 'Bearer';
  issuedAt: number;
}

export interface MockPaymentOrder {
  orderId: string;
  amount: number;
  description: string;
  partnerCode?: string;
  extraData?: Record<string, any>;
}

export interface MockPaymentResult {
  transactionId: string;
  orderId: string;
  status: 'SUCCESS' | 'FAILED' | 'CANCELLED';
  amount: number;
  timestamp: number;
  paymentMethod: 'SUPERAPP_WALLET' | 'BANK_TRANSFER' | 'CREDIT_CARD';
  message: string;
}

export interface MockNetworkCondition {
  online: boolean;
  type: 'wifi' | '4g' | '5g' | '2g' | 'none';
  latencyMs: number;
}

export interface MockDeviceState {
  batteryLevel: number;
  isCharging: boolean;
  platform: 'ios' | 'android' | 'web';
  language: string;
  systemName: string;
  systemVersion: string;
  model: string;
}

export interface MockPermissions {
  camera: 'granted' | 'denied' | 'prompt';
  location: 'granted' | 'denied' | 'prompt';
  notification: 'granted' | 'denied' | 'prompt';
  photos: 'granted' | 'denied' | 'prompt';
}

export interface MockEngineOptions {
  autoApprovePayment?: boolean;
  autoApproveAuth?: boolean;
  simulatedLatencyMs?: number;
  storageKeyPrefix?: string;
}
