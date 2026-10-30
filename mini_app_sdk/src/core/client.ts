import { ITransport, TransportResolver, TransportType } from '../transport/index.js';
import { AuthModule } from './modules/auth.js';
import { DeviceModule } from './modules/device.js';
import { StorageModule } from './modules/storage.js';
import { UIModule } from './modules/ui.js';
import { NavigationModule } from './modules/navigation.js';
import { MediaModule } from './modules/media.js';
import { LifecycleModule } from './modules/lifecycle.js';
import {
  AuthLoginOptions,
  AuthLoginResult,
  ConfigAppViewOptions,
  KeepScreenOptions,
  MinimizeAppResult,
  NotificationResult,
  RequestSendNotificationOptions,
  SDKInitOptions,
  SetNavigationBarColorOptions,
  ToastOptions,
  UserProfile,
} from './types/index.js';

export class SuperAppSDK {
  public readonly version = '1.0.7';
  public readonly transport: ITransport;


  // Domain modules
  public readonly auth: AuthModule;
  public readonly device: DeviceModule;
  public readonly storage: StorageModule;
  public readonly ui: UIModule;
  public readonly navigation: NavigationModule;
  public readonly media: MediaModule;
  public readonly lifecycle: LifecycleModule;

  constructor(options: SDKInitOptions & { forceTransport?: TransportType } = {}) {
    this.transport = TransportResolver.resolve({
      appId: options.appId,
      debug: options.debug,
      timeoutMs: options.timeoutMs,
      forceTransport: options.forceTransport,
    });

    this.auth = new AuthModule(this.transport);
    this.device = new DeviceModule(this.transport);
    this.storage = new StorageModule(this.transport);
    this.ui = new UIModule(this.transport);
    this.navigation = new NavigationModule(this.transport);
    this.media = new MediaModule(this.transport);
    this.lifecycle = new LifecycleModule(this.transport);
  }

  public getNetworkInfo() { return this.device.getNetworkInfo(); }
  public getSystemInfo() { return this.device.getSystemInfo(); }
  public getBatteryInfo() { return this.device.getBatteryInfo(); }
  public getContacts(options: { query?: string } = {}) { return this.device.getContacts(options); }

  // Top-level shortcuts
  public login(options?: AuthLoginOptions): Promise<AuthLoginResult> {
    return this.auth.login(options);
  }

  public getUserProfile(): Promise<UserProfile> {
    return this.auth.getUserProfile();
  }

  public showToast(options: ToastOptions | string): Promise<any> {
    return this.ui.showToast(options);
  }

  public vibrate(style?: 'light' | 'medium' | 'heavy'): Promise<any> {
    return this.device.vibrate(style);
  }

  public openNativePage(page: 'profile' | 'form' | string, params?: Record<string, any>): Promise<any> {
    return this.navigation.openNativePage(page, params);
  }

  public openMiniApp(appId: string, params?: Record<string, any>): Promise<any> {
    return this.navigation.openMiniApp(appId, params);
  }

  public closeApp(): Promise<any> {
    return this.navigation.closeApp();
  }

  public minimizeApp(): Promise<MinimizeAppResult> {
    return this.navigation.minimizeApp();
  }

  public configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.ui.configAppView(options);
  }

  public setNavigationBarTitle(title: string | { title: string }): Promise<any> {
    return this.ui.setNavigationBarTitle(title);
  }

  public setNavigationBarColor(options: SetNavigationBarColorOptions | string): Promise<any> {
    return this.ui.setNavigationBarColor(options);
  }

  public keepScreen(options?: KeepScreenOptions | boolean): Promise<{ success: boolean; keepScreenOn: boolean }> {
    return this.device.keepScreen(options);
  }

  public requestSendNotification(options?: RequestSendNotificationOptions): Promise<NotificationResult> {
    return this.ui.requestSendNotification(options);
  }

  public on(event: string, callback: (payload: any) => void): () => void {
    return this.transport.on(event, callback);
  }

  public off(event: string, callback: (payload: any) => void): void {
    this.transport.off(event, callback);
  }
}
