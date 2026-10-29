import { ComponentAction } from '../types';
import superApp from '@vqh2602/mini-app-sdk';

export function invokeNativeBridge(actionName: string, payload: Record<string, any> = {}, appId: string = 'schema_app'): Promise<any> {
  // Use official @vqh2602/mini-app-sdk transport
  if (actionName === 'navigation.close') {
    return superApp.closeApp();
  }
  if (actionName === 'navigation.minimizeApp') {
    return superApp.minimizeApp();
  }
  if (actionName === 'navigation.openNativePage') {
    return superApp.openNativePage(payload.page || 'profile', payload.params);
  }
  if (actionName === 'navigation.openMiniApp') {
    return superApp.openMiniApp(payload.appId, payload.params);
  }
  if (actionName === 'ui.showToast') {
    return superApp.showToast(payload.message || payload.title || 'Notification');
  }
  if (actionName === 'ui.configAppView') {
    return superApp.configAppView(payload as any);
  }
  if (actionName === 'device.vibrate') {
    return superApp.vibrate(payload.style);
  }
  if (actionName === 'device.keepScreen') {
    return superApp.keepScreen(payload);
  }
  if (actionName === 'ui.requestSendNotification') {
    return superApp.requestSendNotification(payload);
  }

  return superApp.transport.invoke(actionName, payload);
}

export async function executeAction(
  action: ComponentAction,
  options: {
    appId: string;
    onNavigate: (pageId: string) => void;
    showNotification?: (msg: string, type?: 'success' | 'error' | 'info') => void;
  },
): Promise<any> {
  const notify = options.showNotification || ((msg) => alert(msg));

  if (action.type === 'navigate' && action.targetPageId) {
    options.onNavigate(action.targetPageId);
    return;
  }

  if (action.type === 'native_action' && action.action) {
    try {
      const act = action.action;
      const params = action.params || {};

      // Smart payment composite flow
      if (act === 'payment.openCheckout' && (params.amount || params.price)) {
        notify('Đang khởi tạo đơn hàng...', 'info');
        const order = await invokeNativeBridge(
          'payment.createOrder',
          {
            amount: params.amount || params.price || 50000,
            description: params.description || params.title || 'Thanh toán đơn hàng No-Code',
            currency: params.currency || 'VND',
          },
          options.appId,
        );

        notify(`Đơn hàng ${order.orderId} đã tạo. Đang mở cổng thanh toán Native...`, 'info');
        const res = await invokeNativeBridge(
          'payment.openCheckout',
          { orderId: order.orderId },
          options.appId,
        );

        if (res.status === 'SUCCESS') {
          notify(`🎉 Thanh toán thành công đơn hàng ${order.orderId}!`, 'success');
        } else if (res.status === 'CANCELLED') {
          notify(`Đã hủy thanh toán đơn hàng.`, 'info');
        } else {
          notify(`Thanh toán thất bại: ${res.status}`, 'error');
        }
        return res;
      }

      // Standard native action dispatch
      const res = await invokeNativeBridge(act, params, options.appId);
      if (act === 'device.scanQRCode') {
        notify(`Kết quả quét QR: ${res.content || JSON.stringify(res)}`, 'success');
      } else if (act === 'device.getLocation') {
        notify(`Tọa độ: ${res.latitude}, ${res.longitude} (${res.city || ''})`, 'success');
      } else if (act === 'navigation.close' || act === 'navigation.closeApp') {
        // Closed
      } else if (act === 'navigation.openNativePage' || act === 'navigation.openMiniApp') {
        // Navigated directly to native screen
      } else {
        notify(`Thực thi ${act} thành công!`, 'success');
      }
      return res;
    } catch (err: any) {
      notify(`Lỗi thực thi Native Action: ${err.message || JSON.stringify(err)}`, 'error');
      throw err;
    }
  }

  if (action.type === 'url' && action.params?.url) {
    window.open(action.params.url, '_blank');
  }
}
