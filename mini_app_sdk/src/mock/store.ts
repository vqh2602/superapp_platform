import { MOCK_USER_PRESETS } from './presets.js';
import {
  MockDeviceState,
  MockNetworkCondition,
  MockPaymentResult,
  MockPermissions,
  MockTokenSession,
  MockUserProfile,
} from './types.js';

export class MockStateStore {
  private user: MockUserProfile;
  private session: MockTokenSession | null = null;
  private transactions: MockPaymentResult[] = [];
  private appStorage: Map<string, Map<string, string>> = new Map();
  private deviceState: MockDeviceState;
  private networkCondition: MockNetworkCondition;
  private permissions: MockPermissions;

  constructor(prefix: string = 'superapp_mock_state') {
    this.user = { ...MOCK_USER_PRESETS.standard };
    this.deviceState = {
      batteryLevel: 85,
      isCharging: false,
      platform: 'ios',
      language: 'vi-VN',
      systemName: 'iOS',
      systemVersion: '18.2',
      model: 'iPhone 15 Pro Max',
    };
    this.networkCondition = {
      online: true,
      type: 'wifi',
      latencyMs: 50,
    };
    this.permissions = {
      camera: 'granted',
      location: 'granted',
      notification: 'granted',
      photos: 'granted',
    };
    this.initDefaultSession();
  }

  private initDefaultSession(): void {
    const now = Date.now();
    this.session = {
      accessToken: `mock_jwt_${Math.random().toString(36).substring(2)}${Date.now()}`,
      refreshToken: `mock_refresh_${Math.random().toString(36).substring(2)}`,
      expiresIn: 3600,
      tokenType: 'Bearer',
      issuedAt: now,
    };
  }

  // User & Auth
  public getUser(): MockUserProfile {
    return { ...this.user };
  }

  public setUser(user: Partial<MockUserProfile>): MockUserProfile {
    this.user = { ...this.user, ...user };
    return this.getUser();
  }

  public setUserPreset(presetKey: keyof typeof MOCK_USER_PRESETS): MockUserProfile {
    const preset = MOCK_USER_PRESETS[presetKey] || MOCK_USER_PRESETS.standard;
    this.user = { ...preset };
    return this.getUser();
  }

  public getSession(): MockTokenSession | null {
    if (!this.session) return null;
    const isExpired = Date.now() > this.session.issuedAt + this.session.expiresIn * 1000;
    if (isExpired) {
      return null;
    }
    return { ...this.session };
  }

  public createSession(): MockTokenSession {
    this.initDefaultSession();
    return this.getSession()!;
  }

  public clearSession(): void {
    this.session = null;
  }

  // Payment
  public getBalance(): number {
    return this.user.walletBalance;
  }

  public deductBalance(amount: number): boolean {
    if (this.user.walletBalance < amount) {
      return false;
    }
    this.user.walletBalance -= amount;
    return true;
  }

  public addTransaction(result: MockPaymentResult): void {
    this.transactions.unshift(result);
  }

  public getTransactions(): MockPaymentResult[] {
    return [...this.transactions];
  }

  public getTransaction(txId: string): MockPaymentResult | undefined {
    return this.transactions.find((t) => t.transactionId === txId);
  }

  // Device & System
  public getDeviceState(): MockDeviceState {
    return { ...this.deviceState };
  }

  public updateDeviceState(update: Partial<MockDeviceState>): void {
    this.deviceState = { ...this.deviceState, ...update };
  }

  public getNetworkCondition(): MockNetworkCondition {
    return { ...this.networkCondition };
  }

  public setNetworkCondition(condition: Partial<MockNetworkCondition>): void {
    this.networkCondition = { ...this.networkCondition, ...condition };
  }

  // Permissions
  public getPermissions(): MockPermissions {
    return { ...this.permissions };
  }

  public setPermission(perm: keyof MockPermissions, status: 'granted' | 'denied' | 'prompt'): void {
    this.permissions[perm] = status;
  }

  // Storage
  public getStorage(appId: string): Map<string, string> {
    if (!this.appStorage.has(appId)) {
      this.appStorage.set(appId, new Map());
    }
    return this.appStorage.get(appId)!;
  }

  public setStorageItem(appId: string, key: string, value: string): void {
    this.getStorage(appId).set(key, value);
  }

  public getStorageItem(appId: string, key: string): string | null {
    return this.getStorage(appId).get(key) ?? null;
  }

  public removeStorageItem(appId: string, key: string): void {
    this.getStorage(appId).delete(key);
  }

  public clearStorage(appId: string): void {
    this.getStorage(appId).clear();
  }
}
