import { ComponentAction } from '../types';

declare global {
  interface Window {
    FlutterBridge?: {
      postMessage: (msg: string) => void;
    };
    SuperAppBridge?: {
      _callbacks: Record<string, any>;
      _listeners: Record<string, any>;
    };
  }
}

let reqSeq = 1;

export function invokeNativeBridge(actionName: string, payload: Record<string, any> = {}, appId: string = 'schema_app'): Promise<any> {
  return new Promise((resolve, reject) => {
    const id = `req_schema_${Date.now()}_${reqSeq++}`;
    const request = {
      id,
      action: actionName,
      payload,
      appId,
      timestamp: Date.now(),
    };

    if (typeof window !== 'undefined' && window.FlutterBridge && window.FlutterBridge.postMessage) {
      window.SuperAppBridge = window.SuperAppBridge || { _callbacks: {}, _listeners: {} } as any;
      window.SuperAppBridge!._callbacks = window.SuperAppBridge!._callbacks || {};
      window.SuperAppBridge!._callbacks[id] = (res: any) => {
        if (res.success) {
          resolve(res.data);
        } else {
          reject(res.error || { code: 'INTERNAL_ERROR', message: 'Action failed' });
        }
      };
      window.FlutterBridge.postMessage(JSON.stringify(request));
    } else {
      // Browser preview simulator fallback
      console.log(`[SchemaRuntime Simulator] Native action dispatched: ${actionName}`, payload);
      setTimeout(() => {
        if (actionName === 'payment.createOrder') {
          resolve({ orderId: `ORD_SIM_${Date.now()}`, amount: payload.amount, status: 'PENDING' });
        } else if (actionName === 'payment.openCheckout') {
          resolve({ orderId: payload.orderId, status: 'SUCCESS', message: 'Simulated payment approved' });
        } else if (actionName === 'device.scanQRCode') {
          resolve({ content: 'https://superapp.mock/pay?demo=123', isMock: true });
        } else if (actionName === 'navigation.close') {
          resolve({ closed: true });
        } else {
          resolve({ success: true, action: actionName, payload });
        }
      }, 350);
    }
  });
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
      } else if (act === 'navigation.close') {
        // Closed
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
