export interface BridgeRequestPayload {
  [key: string]: any;
}

export interface BridgeRequest {
  id: string;
  action: string;
  payload: BridgeRequestPayload;
  appId: string;
  origin?: string;
  timestamp: number;
}

export interface BridgeError {
  code:
    | 'AUTH_REQUIRED'
    | 'PERMISSION_DENIED'
    | 'ACTION_NOT_FOUND'
    | 'INVALID_PARAMS'
    | 'UNSUPPORTED'
    | 'TIMEOUT'
    | 'CANCELLED'
    | 'INTERNAL_ERROR';
  message: string;
  details?: Record<string, any>;
}

export interface BridgeResponse<T = any> {
  id: string;
  success: boolean;
  data?: T;
  error?: BridgeError;
  executionTimeMs: number;
}

export type BridgeEventListener = (payload: any) => void;

export interface MiniAppTokenResult {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  userId: string;
  appId: string;
}

export interface UserProfile {
  id: string;
  name: string;
  phone: string;
  role: string;
  email: string;
  avatarUrl?: string;
}

export interface BasicUserInfo {
  id: string;
  name: string;
  avatarUrl?: string;
}

export interface MockOrder {
  orderId: string;
  amount: number;
  currency: string;
  description: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | 'CANCELLED';
  appId: string;
  userId: string;
  createdAt: string;
  completedAt?: string;
}

export interface BridgeLogRecord {
  id: string;
  method: string;
  params: any;
  status: 'success' | 'error' | 'pending';
  response?: any;
  error?: BridgeError | string;
  executionTimeMs: number;
  timestamp: string;
}
