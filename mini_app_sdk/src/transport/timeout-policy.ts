// Interactive native screens include time spent reading permission prompts,
// aiming a camera, choosing a file, or completing a checkout.
export const INTERACTIVE_BRIDGE_TIMEOUT_MS = 5 * 60 * 1000;
export const DEFAULT_BRIDGE_TIMEOUT_MS = 60 * 1000;
export const INTERACTIVE_BRIDGE_ACTIONS = new Set([
  'scanQr', 'scanQRCode', 'scanBarcode', 'device.scanQr', 'device.scanQRCode',
  'device.scanBarcode', 'media.scanQRCode', 'getPhoto', 'pickImages', 'pickVideo',
  'chooseImage', 'device.pickImage', 'media.chooseImage', 'media.getPhoto',
  'media.pickImages', 'media.pickVideo', 'pickFile', 'saveFile', 'filePreview',
  'saveImageToGallery', 'saveVideoToGallery', 'speechToText', 'utility.speechToText',
  'permission.request', 'getContacts', 'device.getContacts', 'payment.openCheckout',
  'payment.requestPayment', 'requestSendNotification', 'ui.requestSendNotification',
  'notification.requestSendNotification', 'ui.showAlert', 'ui.showConfirm',
  'showAlert', 'showConfirm',
]);

export function bridgeTimeoutMs(action: string, override?: number): number {
  return override ?? (INTERACTIVE_BRIDGE_ACTIONS.has(action)
    ? INTERACTIVE_BRIDGE_TIMEOUT_MS : DEFAULT_BRIDGE_TIMEOUT_MS);
}
