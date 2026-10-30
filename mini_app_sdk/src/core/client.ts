import { ITransport, TransportResolver, TransportType } from '../transport/index.js';
import { AuthModule } from './modules/auth.js';
import { DeviceModule } from './modules/device.js';
import { StorageModule } from './modules/storage.js';
import { UIModule } from './modules/ui.js';
import { NavigationModule } from './modules/navigation.js';
import { MediaModule } from './modules/media.js';
import { LifecycleModule } from './modules/lifecycle.js';
import { UserModule } from './modules/user.js';
import { PaymentModule } from './modules/payment.js';
import { PermissionsModule } from './modules/permissions.js';
import { FileModule } from './modules/file.js';
import { PhoneModule } from './modules/phone.js';
import { UtilityModule } from './modules/utility.js';
import { DebugModule } from './modules/debug.js';
import { SystemModule } from './modules/system.js';
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
  public readonly user: UserModule;
  public readonly payment: PaymentModule;
  public readonly permission: PermissionsModule;
  public readonly file: FileModule;
  public readonly phone: PhoneModule;
  public readonly utility: UtilityModule;
  public readonly debug: DebugModule;
  public readonly system: SystemModule;

  constructor(options: (SDKInitOptions & { forceTransport?: TransportType }) | string = {}) {
    const config: SDKInitOptions & { forceTransport?: TransportType } =
      typeof options === 'string' ? { appId: options } : options;

    this.transport = TransportResolver.resolve({
      appId: config.appId,
      debug: config.debug,
      timeoutMs: config.timeoutMs,
      forceTransport: config.forceTransport,
    });

    this.auth = new AuthModule(this.transport);
    this.device = new DeviceModule(this.transport);
    this.storage = new StorageModule(this.transport);
    this.ui = new UIModule(this.transport);
    this.navigation = new NavigationModule(this.transport);
    this.media = new MediaModule(this.transport);
    this.lifecycle = new LifecycleModule(this.transport);
    this.user = new UserModule(this.transport);
    this.payment = new PaymentModule(this.transport);
    this.permission = new PermissionsModule(this.transport);
    this.file = new FileModule(this.transport);
    this.phone = new PhoneModule(this.transport);
    this.utility = new UtilityModule(this.transport);
    this.debug = new DebugModule(this.transport);
    this.system = new SystemModule(this.transport);
  }

  // System & Device Shortcuts
  public getNetworkInfo() { return this.system.getNetworkInfo(); }
  public getDeviceLanguage() { return this.system.getDeviceLanguage(); }
  public getSuperAppSettings() { return this.system.getSuperAppSettings(); }
  public getSystemInfo() { return this.system.getSystemInfo(); }
  public getAppInfo() { return this.system.getAppInfo(); }
  public getBatteryInfo() { return this.system.getBatteryInfo(); }
  public getContacts(options: { query?: string } = {}) { return this.system.getContacts(options); }

  // Phone & Utility Shortcuts
  public openPhone(phoneNumber: string) { return this.phone.openPhone(phoneNumber); }
  public openSMS(phoneNumber: string, body?: string) { return this.phone.openSMS(phoneNumber, body); }
  public openExternalBrowser(url: string) { return this.phone.openExternalBrowser(url); }
  public openDeepLink(url: string) { return this.phone.openDeepLink(url); }
  public speechToText(options?: any) { return this.utility.speechToText(options); }
  public hideKeyboard() { return this.utility.hideKeyboard(); }

  // UI Shortcuts
  public showToast(options: ToastOptions | string, duration?: number): Promise<any> {
    return this.ui.showToast(options, duration);
  }
  public vibrate(style?: 'light' | 'medium' | 'heavy'): Promise<any> {
    return this.ui.vibrate(style);
  }
  public copyToClipboard(text: string) { return this.ui.copyToClipboard(text); }
  public setBrightness(brightness: number) { return this.ui.setBrightness(brightness); }
  public setStatusBarStyle(style: 'light' | 'dark') { return this.ui.setStatusBarStyle(style); }
  public setStatusBarColor(color: string) { return this.ui.setStatusBarColor(color); }
  public setNavigationBarTitle(title: string | { title: string }): Promise<any> {
    return this.ui.setNavigationBarTitle(title);
  }
  public setTitle(title: string) { return this.ui.setNavigationBarTitle(title); }
  public setNavigationBarColor(options: SetNavigationBarColorOptions | string): Promise<any> {
    return this.ui.setNavigationBarColor(options);
  }
  public configAppView(options: ConfigAppViewOptions): Promise<any> {
    return this.ui.configAppView(options);
  }
  public showMiniappMenu() { return this.ui.showMiniappMenu(); }
  public keepScreen(options?: KeepScreenOptions | boolean): Promise<{ success: boolean; keepScreenOn: boolean }> {
    return this.device.keepScreen(options);
  }
  public requestSendNotification(options?: RequestSendNotificationOptions): Promise<NotificationResult> {
    return this.ui.requestSendNotification(options);
  }
  public minimizeApp(): Promise<MinimizeAppResult> {
    return this.navigation.minimizeApp();
  }
  public closeApp(): Promise<any> {
    return this.navigation.closeApp();
  }

  // Media & File Shortcuts
  public scanQr(options?: any) { return this.media.scanQr(options); }
  public scanQRCode(prompt?: string) { return this.media.scanQRCode(prompt); }
  public getPhoto(options?: any) { return this.media.getPhoto(options); }
  public pickImages(options?: any) { return this.media.pickImages(options); }
  public saveImageToGallery(uri: string) { return this.media.saveImageToGallery(uri); }
  public pickVideo() { return this.media.pickVideo(); }
  public saveVideoToGallery(uri: string) { return this.media.saveVideoToGallery(uri); }
  public saveFile(options: any) { return this.file.saveFile(options); }
  public pickFile(options?: any) { return this.file.pickFile(options); }
  public filePreview(options: any) { return this.file.filePreview(options); }

  // Storage Shortcuts
  public setSecretData(key: string, value: any, domain?: string) { return this.storage.setSecretData(key, value, domain); }
  public getSecretData(key: string, domain?: string) { return this.storage.getSecretData(key, domain); }
  public removeSecretData(key: string, domain?: string) { return this.storage.removeSecretData(key, domain); }

  // Navigation Shortcuts
  public openNativePage(page: 'profile' | 'form' | string, params?: Record<string, any>): Promise<any> {
    return this.navigation.openNativePage(page, params);
  }
  public openMiniApp(appId: string, params?: Record<string, any>): Promise<any> {
    return this.navigation.openMiniApp(appId, params);
  }

  // Auth Shortcuts
  public login(options?: AuthLoginOptions): Promise<AuthLoginResult> {
    return this.auth.login(options);
  }
  public getUserProfile(): Promise<UserProfile> {
    return this.auth.getUserProfile();
  }

  // Connectivity
  public isConnected(): boolean {
    return this.transport.isConnected();
  }

  // Event shortcuts
  public on(event: string, callback: (payload: any) => void): () => void {
    return this.transport.on(event, callback);
  }
  public off(event: string, callback: (payload: any) => void): void {
    this.transport.off(event, callback);
  }
}
