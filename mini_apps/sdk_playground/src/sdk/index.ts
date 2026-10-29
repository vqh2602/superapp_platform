import officialSuperApp, { SuperAppSDK as BaseSuperAppSDK } from '@vqh2602/mini-app-sdk';
export { BaseSuperAppSDK };
import { BridgeTransport } from './bridgeTransport';
import { AuthModule, MockAuthBackend } from './modules/auth';
import { UserModule } from './modules/user';
import { NavigationModule } from './modules/navigation';
import { DeviceModule } from './modules/device';
import { PaymentModule } from './modules/payment';
import { PermissionsModule } from './modules/permissions';
import { StorageModule } from './modules/storage';
import { SystemModule } from './modules/system';
import { UIModule } from './modules/ui';
import { MediaModule } from './modules/media';
import { FileModule } from './modules/file';
import { PhoneModule } from './modules/phone';
import { UtilityModule } from './modules/utility';
import { LifecycleModule } from './modules/lifecycle';
import { DebugModule } from './modules/debug';

export * from './types';
export * from './modules/storage';
export * from './modules/system';
export * from './modules/ui';
export * from './modules/media';
export * from './modules/file';
export * from './modules/phone';
export * from './modules/utility';
export { BridgeTransport } from './bridgeTransport';

export class SuperAppSDK {
  public readonly version = '1.0.0';
  public readonly transport: BridgeTransport;

  public readonly auth: AuthModule;
  public readonly user: UserModule;
  public readonly navigation: NavigationModule;
  public readonly device: DeviceModule;
  public readonly payment: PaymentModule;
  public readonly permission: PermissionsModule;
  public readonly storage: StorageModule;
  public readonly system: SystemModule;
  public readonly ui: UIModule;
  public readonly media: MediaModule;
  public readonly file: FileModule;
  public readonly phone: PhoneModule;
  public readonly utility: UtilityModule;
  public readonly lifecycle: LifecycleModule;
  public readonly debug: DebugModule;

  constructor(appId: string = 'sdk_playground') {
    this.transport = new BridgeTransport(appId);
    this.auth = new AuthModule(this.transport);
    this.user = new UserModule(this.transport);
    this.navigation = new NavigationModule(this.transport);
    this.device = new DeviceModule(this.transport);
    this.payment = new PaymentModule(this.transport);
    this.permission = new PermissionsModule(this.transport);
    this.storage = new StorageModule(this.transport);
    this.system = new SystemModule(this.transport);
    this.ui = new UIModule(this.transport);
    this.media = new MediaModule(this.transport);
    this.file = new FileModule(this.transport);
    this.phone = new PhoneModule(this.transport);
    this.utility = new UtilityModule(this.transport);
    this.lifecycle = new LifecycleModule(this.transport);
    this.debug = new DebugModule(this.transport);
  }

  // Direct convenience shortcuts matching exact API specification
  public getNetworkInfo() { return this.system.getNetworkInfo(); }
  public getDeviceLanguage() { return this.system.getDeviceLanguage(); }
  public getSuperAppSettings() { return this.system.getSuperAppSettings(); }
  public getSystemInfo() { return this.system.getSystemInfo(); }
  public getAppInfo() { return this.system.getAppInfo(); }
  public getBatteryInfo() { return this.system.getBatteryInfo(); }
  public getContacts() { return this.system.getContacts(); }

  public openPhone(phoneNumber: string) { return this.phone.openPhone(phoneNumber); }
  public openSMS(phoneNumber: string, body?: string) { return this.phone.openSMS(phoneNumber, body); }
  public openExternalBrowser(url: string) { return this.phone.openExternalBrowser(url); }
  public openDeepLink(url: string) { return this.phone.openDeepLink(url); }

  public speechToText(options?: any) { return this.utility.speechToText(options); }
  public hideKeyboard() { return this.utility.hideKeyboard(); }

  public showToast(message: string, duration?: number) { return this.ui.showToast(message, duration); }
  public vibrate(style?: 'light' | 'medium' | 'heavy') { return this.ui.vibrate(style); }
  public copyToClipboard(text: string) { return this.ui.copyToClipboard(text); }
  public setBrightness(brightness: number) { return this.ui.setBrightness(brightness); }
  public setStatusBarStyle(style: 'light' | 'dark') { return this.ui.setStatusBarStyle(style); }
  public setStatusBarColor(color: string) { return this.ui.setStatusBarColor(color); }
  public setNavigationBarTitle(options: string | { title: string }) { return officialSuperApp.setNavigationBarTitle(options); }
  public setTitle(title: string) { return officialSuperApp.setNavigationBarTitle(title); }
  public setNavigationBarColor(options: any) { return officialSuperApp.setNavigationBarColor(options); }
  public configAppView(options: any) { return officialSuperApp.configAppView(options); }
  public showMiniappMenu() { return this.ui.showMiniappMenu(); }
  public keepScreen(options?: boolean | { keepScreenOn: boolean }) { return officialSuperApp.keepScreen(options); }
  public requestSendNotification(options?: any) { return officialSuperApp.requestSendNotification(options); }
  public minimizeApp() { return officialSuperApp.minimizeApp(); }
  public closeApp() { return officialSuperApp.closeApp(); }

  public scanQr(options?: any) { return this.media.scanQr(options); }
  public getPhoto(options?: any) { return this.media.getPhoto(options); }
  public pickImages(options?: any) { return this.media.pickImages(options); }
  public saveImageToGallery(uri: string) { return this.media.saveImageToGallery(uri); }
  public pickVideo() { return this.media.pickVideo(); }
  public saveVideoToGallery(uri: string) { return this.media.saveVideoToGallery(uri); }

  public saveFile(options: any) { return this.file.saveFile(options); }
  public pickFile(options?: any) { return this.file.pickFile(options); }
  public filePreview(options: any) { return this.file.filePreview(options); }

  public setSecretData(key: string, value: any, domain?: string) { return this.storage.setSecretData(key, value, domain); }
  public getSecretData(key: string, domain?: string) { return this.storage.getSecretData(key, domain); }
  public removeSecretData(key: string, domain?: string) { return this.storage.removeSecretData(key, domain); }

  public isConnected(): boolean {
    return this.transport.isConnected();
  }
}

// Global default instances
export const superApp = new SuperAppSDK('sdk_playground');
export const mockAuthBackend = new MockAuthBackend(superApp.transport);
export { officialSuperApp };

if (typeof window !== 'undefined') {
  (window as any).superApp = superApp;
  (window as any).bridge = superApp;
  (window as any).officialSuperApp = officialSuperApp;
}
