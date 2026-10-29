import { BridgeRequest, BridgeResponse, BridgeError, BridgeEventListener } from './types';

declare global {
  interface Window {
    FlutterBridge?: {
      postMessage: (msg: string) => void;
    };
    SuperAppBridge?: {
      _callbacks: Record<string, (res: BridgeResponse) => void>;
      _listeners: Record<string, BridgeEventListener[]>;
      postMessage: (msg: any) => void;
      dispatchResponse: (res: BridgeResponse) => void;
      dispatchEvent: (evt: { event: string; payload: any }) => void;
      addEventListener: (event: string, handler: BridgeEventListener) => void;
      removeEventListener: (event: string, handler: BridgeEventListener) => void;
    };
  }
}

let requestSeq = 1;

export class BridgeTransport {
  private appId: string;

  constructor(appId: string = 'sdk_playground') {
    this.appId = appId;
    this.ensureSuperAppBridge();
    this.initSimulatorEventListener();
  }

  private ensureSuperAppBridge(): void {
    if (typeof window === 'undefined') return;
    if (!window.SuperAppBridge) {
      window.SuperAppBridge = {
        _callbacks: {},
        _listeners: {},
        postMessage: (msg) => {
          if (this.isConnectedToNative()) {
            window.FlutterBridge?.postMessage(JSON.stringify(msg));
          } else if (this.isConnectedToSimulator()) {
            window.parent.postMessage({ type: 'SUPERAPP_BRIDGE_REQUEST', request: msg }, '*');
          }
        },
        dispatchResponse: (res) => window.SuperAppBridge?._callbacks[res.id]?.(res),
        dispatchEvent: (evt) => {
          const list = window.SuperAppBridge?._listeners[evt.event] || [];
          list.forEach((fn) => {
            try { fn(evt.payload); } catch (e) { console.error('[BridgeTransport] Listener error:', e); }
          });
        },
        addEventListener: (event, handler) => {
          window.SuperAppBridge!._listeners[event] = window.SuperAppBridge!._listeners[event] || [];
          window.SuperAppBridge!._listeners[event].push(handler);
        },
        removeEventListener: (event, handler) => {
          if (!window.SuperAppBridge?._listeners[event]) return;
          window.SuperAppBridge._listeners[event] = window.SuperAppBridge._listeners[event].filter((h) => h !== handler);
        },
      };
    }
  }

  private initSimulatorEventListener(): void {
    if (typeof window === 'undefined') return;

    window.addEventListener('message', (event) => {
      const data = event.data;
      if (!data) return;

      if (data.type === 'SUPERAPP_BRIDGE_EVENT' && data.event) {
        this.ensureSuperAppBridge();
        if (window.SuperAppBridge?.dispatchEvent) {
          window.SuperAppBridge.dispatchEvent({ event: data.event, payload: data.payload });
        }
      }
    });
  }

  public isConnectedToNative(): boolean {
    return typeof window !== 'undefined' && !!window.FlutterBridge?.postMessage;
  }

  public isConnectedToSimulator(): boolean {
    return typeof window !== 'undefined' && !!window.parent && window.parent !== window;
  }

  public isConnected(): boolean {
    return this.isConnectedToNative() || this.isConnectedToSimulator();
  }

  public invoke<T = any>(action: string, payload: Record<string, any> = {}, timeoutMs: number = 8000): Promise<T> {
    const id = `req_${Date.now()}_${requestSeq++}`;
    const timestamp = Date.now();

    const request: BridgeRequest = {
      id,
      action,
      payload,
      appId: this.appId,
      origin: typeof window !== 'undefined' ? window.location.origin : 'miniapp://sdk_playground',
      timestamp,
    };

    return new Promise<T>((resolve, reject) => {
      // Setup timeout
      const timer = setTimeout(() => {
        if (window.SuperAppBridge?._callbacks?.[id]) {
          delete window.SuperAppBridge._callbacks[id];
        }
        reject({
          code: 'TIMEOUT',
          message: `Bridge call "${action}" timed out after ${timeoutMs}ms`,
        } as BridgeError);
      }, timeoutMs);

      // If running inside Flutter WebView with native bridge
      if (this.isConnectedToNative()) {
        if (!window.SuperAppBridge) {
          window.SuperAppBridge = {
            _callbacks: {},
            _listeners: {},
            postMessage: (msg) => window.FlutterBridge?.postMessage(JSON.stringify(msg)),
            dispatchResponse: (res) => window.SuperAppBridge?._callbacks[res.id]?.(res),
            dispatchEvent: (evt) => {
              const list = window.SuperAppBridge?._listeners[evt.event] || [];
              list.forEach((fn) => fn(evt.payload));
            },
            addEventListener: (event, handler) => {
              window.SuperAppBridge!._listeners[event] = window.SuperAppBridge!._listeners[event] || [];
              window.SuperAppBridge!._listeners[event].push(handler);
            },
            removeEventListener: (event, handler) => {
              if (!window.SuperAppBridge?._listeners[event]) return;
              window.SuperAppBridge._listeners[event] = window.SuperAppBridge._listeners[event].filter((h) => h !== handler);
            },
          };
        }

        window.SuperAppBridge._callbacks[id] = (response: BridgeResponse<T>) => {
          clearTimeout(timer);
          if (response.success) {
            resolve(response.data as T);
          } else {
            reject(response.error || { code: 'INTERNAL_ERROR', message: 'Unknown error occurred' });
          }
        };

        window.FlutterBridge!.postMessage(JSON.stringify(request));
      } else if (this.isConnectedToSimulator()) {
        // Connected to Browser Simulator parent window via PostMessage
        const handleResponse = (event: MessageEvent) => {
          const data = event.data;
          if (data && data.type === 'SUPERAPP_BRIDGE_RESPONSE') {
            const res = data.response as BridgeResponse<T>;
            if (res && res.id === id) {
              window.removeEventListener('message', handleResponse);
              clearTimeout(timer);
              if (res.success) {
                resolve(res.data as T);
              } else {
                reject(res.error || { code: 'SIMULATOR_ERROR', message: 'Request failed in simulator' });
              }
            }
          }
        };

        window.addEventListener('message', handleResponse);

        window.parent.postMessage({
          type: 'SUPERAPP_BRIDGE_REQUEST',
          request,
        }, '*');
      } else {
        // Fallback Standalone Browser Tab Simulation
        this.simulateBrowserTransport<T>(action, payload)
          .then((data) => {
            clearTimeout(timer);
            resolve(data);
          })
          .catch((err) => {
            clearTimeout(timer);
            reject(err);
          });
      }
    });
  }

  public addEventListener(event: string, handler: BridgeEventListener): () => void {
    if (typeof window === 'undefined') return () => {};
    this.ensureSuperAppBridge();

    if (!window.SuperAppBridge) return () => {};

    if (!window.SuperAppBridge._listeners[event]) {
      window.SuperAppBridge._listeners[event] = [];
    }
    window.SuperAppBridge._listeners[event].push(handler);

    return () => {
      if (window.SuperAppBridge?._listeners[event]) {
        window.SuperAppBridge._listeners[event] = window.SuperAppBridge._listeners[event].filter((h) => h !== handler);
      }
    };
  }

  /**
   * Helper: Get or initialize persistent user profile from localStorage
   */
  private getStoredUserProfile(): { id: string; name: string; phone: string; role: string; email: string; avatarUrl?: string } {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        const raw = window.localStorage.getItem('superapp_user_profile');
        if (raw) return JSON.parse(raw);
      }
    } catch (_) {}

    const profile = {
      id: 'usr_' + (typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID().substring(0, 8) : Date.now().toString(36)),
      name: 'Nguyễn Văn A',
      phone: '0988123456',
      role: 'customer',
      email: 'nguyenvana@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150',
    };

    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        window.localStorage.setItem('superapp_user_profile', JSON.stringify(profile));
      }
    } catch (_) {}

    return profile;
  }

  /**
   * Real Geolocation using browser HTML5 Geolocation API + reverse geocoding
   */
  private async getRealLocation(): Promise<{
    latitude: number;
    longitude: number;
    accuracy: number;
    altitude?: number;
    speed?: number;
    heading?: number;
    city?: string;
    country?: string;
    address?: string;
    timestamp: number;
    isMock: boolean;
  }> {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      throw {
        code: 'UNSUPPORTED',
        message: 'Thiết bị/Trình duyệt không hỗ trợ Geolocation API',
      };
    }

    const position = await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(
        resolve,
        (err) => {
          let message = 'Không thể lấy toạ độ vị trí GPS';
          if (err.code === err.PERMISSION_DENIED) {
            message = 'Người dùng từ chối cấp quyền truy cập vị trí GPS';
          } else if (err.code === err.POSITION_UNAVAILABLE) {
            message = 'Thông tin vị trí không khả dụng trên thiết bị';
          } else if (err.code === err.TIMEOUT) {
            message = 'Quá thời gian chờ lấy toạ độ vị trí';
          }
          reject({
            code: 'LOCATION_ERROR',
            message: `${message} (${err.message})`,
          });
        },
        {
          enableHighAccuracy: true,
          timeout: 12000,
          maximumAge: 10000,
        }
      );
    });

    const { latitude, longitude, accuracy, altitude, speed, heading } = position.coords;
    let city = 'Hồ Chí Minh';
    let country = 'Việt Nam';
    let addressText: string | undefined;

    // Reverse geocode via OpenStreetMap Nominatim with fast timeout
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2500);
      const resp = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=18&addressdetails=1`,
        {
          signal: controller.signal,
          headers: { 'Accept-Language': 'vi,en' },
        }
      );
      clearTimeout(timeoutId);
      if (resp.ok) {
        const geoData = await resp.json();
        if (geoData?.address) {
          city = geoData.address.city || geoData.address.town || geoData.address.county || geoData.address.state || city;
          country = geoData.address.country || country;
          addressText = geoData.display_name;
        }
      }
    } catch (_) {
      // Graceful fallback to GPS coords if offline/network timeout
    }

    return {
      latitude,
      longitude,
      accuracy: accuracy || 5.0,
      altitude: altitude ?? undefined,
      speed: speed ?? undefined,
      heading: heading ?? undefined,
      city,
      country,
      address: addressText,
      timestamp: position.timestamp || Date.now(),
      isMock: false,
    };
  }

  /**
   * Real Image Picker using native OS file dialog + FileReader base64 metadata
   */
  private async pickRealImage(): Promise<{
    uri: string;
    mimeType: string;
    width: number;
    height: number;
    sizeBytes: number;
    fileName: string;
    timestamp: number;
    isMock: boolean;
  }> {
    if (typeof document === 'undefined') {
      throw {
        code: 'UNSUPPORTED',
        message: 'Môi trường không hỗ trợ DOM File Picker',
      };
    }

    return new Promise((resolve, reject) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.style.position = 'fixed';
      input.style.top = '-9999px';
      input.style.left = '-9999px';
      input.style.opacity = '0';
      document.body.appendChild(input);

      let isHandled = false;

      const cleanup = () => {
        if (document.body.contains(input)) {
          document.body.removeChild(input);
        }
        window.removeEventListener('focus', onWindowFocus);
      };

      const onWindowFocus = () => {
        setTimeout(() => {
          if (!isHandled && (!input.files || input.files.length === 0)) {
            isHandled = true;
            cleanup();
            reject({
              code: 'CANCELLED',
              message: 'Người dùng đã huỷ chọn ảnh',
            });
          }
        }, 800);
      };

      window.addEventListener('focus', onWindowFocus);

      input.onchange = async () => {
        isHandled = true;
        const file = input.files?.[0];
        cleanup();

        if (!file) {
          reject({
            code: 'CANCELLED',
            message: 'Không có ảnh nào được chọn',
          });
          return;
        }

        try {
          const reader = new FileReader();
          reader.onload = (e) => {
            const dataUrl = e.target?.result as string;
            const img = new Image();
            img.onload = () => {
              resolve({
                uri: dataUrl,
                mimeType: file.type || 'image/jpeg',
                width: img.naturalWidth || 800,
                height: img.naturalHeight || 600,
                sizeBytes: file.size,
                fileName: file.name,
                timestamp: file.lastModified || Date.now(),
                isMock: false,
              });
            };
            img.onerror = () => {
              resolve({
                uri: dataUrl,
                mimeType: file.type || 'image/jpeg',
                width: 0,
                height: 0,
                sizeBytes: file.size,
                fileName: file.name,
                timestamp: file.lastModified || Date.now(),
                isMock: false,
              });
            };
            img.src = dataUrl;
          };
          reader.onerror = () => {
            reject({
              code: 'FILE_READ_ERROR',
              message: 'Không thể đọc file ảnh từ thiết bị',
            });
          };
          reader.readAsDataURL(file);
        } catch (err: any) {
          reject({
            code: 'FILE_READ_ERROR',
            message: err?.message || 'Lỗi khi đọc file ảnh',
          });
        }
      };

      input.click();
    });
  }

  /**
   * Real QR Code Scanner: Camera stream with BarcodeDetector and QR image file upload
   */
  private async scanRealQRCode(): Promise<{
    content: string;
    format: string;
    timestamp: number;
    isMock: boolean;
  }> {
    if (typeof document === 'undefined') {
      throw {
        code: 'UNSUPPORTED',
        message: 'Môi trường không hỗ trợ giao diện quét QR',
      };
    }

    return new Promise(async (resolve, reject) => {
      let detector: any = null;
      if (typeof window !== 'undefined' && 'BarcodeDetector' in window) {
        try {
          detector = new (window as any).BarcodeDetector({
            formats: ['qr_code', 'code_128', 'code_39', 'code_93', 'ean_13', 'ean_8', 'itf', 'upc_a', 'upc_e', 'data_matrix'],
          });
        } catch (_) {}
      }

      const overlay = document.createElement('div');
      overlay.style.position = 'fixed';
      overlay.style.inset = '0';
      overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.85)';
      overlay.style.zIndex = '99999';
      overlay.style.display = 'flex';
      overlay.style.flexDirection = 'column';
      overlay.style.alignItems = 'center';
      overlay.style.justifyContent = 'center';
      overlay.style.padding = '20px';
      overlay.style.color = '#ffffff';
      overlay.style.fontFamily = 'system-ui, -apple-system, sans-serif';

      const card = document.createElement('div');
      card.style.backgroundColor = '#18181b';
      card.style.border = '1px solid #3f3f46';
      card.style.borderRadius = '16px';
      card.style.maxWidth = '440px';
      card.style.width = '100%';
      card.style.padding = '20px';
      card.style.boxShadow = '0 25px 50px -12px rgba(0, 0, 0, 0.5)';
      card.style.display = 'flex';
      card.style.flexDirection = 'column';
      card.style.alignItems = 'center';
      card.style.gap = '12px';

      card.innerHTML = `
        <div style="font-weight: 600; font-size: 17px; text-align: center;">Quét mã QR & Mã vạch thiết bị</div>
        <div style="font-size: 13px; color: #a1a1aa; text-align: center;">Hướng camera vào mã QR/mã vạch hoặc chọn mẫu thử bên dưới.</div>
        <div id="qr-video-container" style="position: relative; width: 100%; height: 230px; background: #09090b; border-radius: 12px; overflow: hidden; display: flex; align-items: center; justify-content: center;">
          <video id="qr-camera-video" autoplay playsinline muted style="width: 100%; height: 100%; object-fit: cover;"></video>
          <div style="position: absolute; width: 180px; height: 140px; border: 2px solid #3b82f6; border-radius: 12px; pointer-events: none; box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.4);"></div>
        </div>
        
        <div style="width: 100%; display: flex; flex-direction: column; gap: 6px;">
          <div style="font-size: 11px; color: #a1a1aa; font-weight: 600;">Mẫu quét nhanh kiểm thử (Chạy ngay):</div>
          <div style="display: flex; gap: 6px; width: 100%; flex-wrap: wrap;">
            <button id="qr-preset-url" style="flex: 1; min-width: 110px; background: #27272a; color: #4ade80; border: 1px solid #3f3f46; padding: 7px 8px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 500;">
              📱 QR SuperApp Pay
            </button>
            <button id="qr-preset-ean" style="flex: 1; min-width: 110px; background: #27272a; color: #fbbf24; border: 1px solid #3f3f46; padding: 7px 8px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 500;">
              🏷️ EAN-13 Mã vạch
            </button>
            <button id="qr-preset-code128" style="flex: 1; min-width: 110px; background: #27272a; color: #38bdf8; border: 1px solid #3f3f46; padding: 7px 8px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 500;">
              📦 Code-128 Vận đơn
            </button>
          </div>
        </div>

        <div style="display: flex; gap: 8px; width: 100%; margin-top: 4px;">
          <label style="flex: 1; display: flex; align-items: center; justify-content: center; gap: 6px; background: #27272a; color: white; padding: 10px; border-radius: 8px; cursor: pointer; font-size: 13px; font-weight: 500;">
            📁 Tải ảnh QR / Barcode
            <input type="file" id="qr-file-input" accept="image/*" style="display: none;" />
          </label>
          <button id="qr-cancel-btn" style="flex: 1; background: #ef4444; color: white; border: none; padding: 10px; border-radius: 8px; cursor: pointer; font-size: 13px; font-weight: 500;">
            Đóng / Huỷ
          </button>
        </div>
      `;

      overlay.appendChild(card);
      document.body.appendChild(overlay);

      let stream: MediaStream | null = null;
      let animationFrameId: number | null = null;

      const cleanupModal = () => {
        if (animationFrameId) cancelAnimationFrame(animationFrameId);
        if (stream) {
          stream.getTracks().forEach((track) => track.stop());
        }
        if (document.body.contains(overlay)) {
          document.body.removeChild(overlay);
        }
      };

      const handleSuccess = (content: string, format: string = 'QR_CODE') => {
        cleanupModal();
        resolve({
          content,
          format,
          timestamp: Date.now(),
          isMock: false,
        });
      };

      card.querySelector('#qr-preset-url')?.addEventListener('click', () => {
        handleSuccess('https://pay.superapp.com/invoice/INV_2026_' + Math.floor(1000 + Math.random() * 9000), 'QR_CODE');
      });

      card.querySelector('#qr-preset-ean')?.addEventListener('click', () => {
        handleSuccess('8935001700125', 'EAN_13');
      });

      card.querySelector('#qr-preset-code128')?.addEventListener('click', () => {
        handleSuccess('VNPOST_' + Math.floor(100000 + Math.random() * 900000), 'CODE_128');
      });

      card.querySelector('#qr-cancel-btn')?.addEventListener('click', () => {
        cleanupModal();
        reject({
          code: 'CANCELLED',
          message: 'Người dùng đã huỷ quét mã QR / mã vạch',
        });
      });

      const fileInput = card.querySelector('#qr-file-input') as HTMLInputElement;
      fileInput?.addEventListener('change', async () => {
        const file = fileInput.files?.[0];
        if (!file) return;

        const img = new Image();
        img.onload = async () => {
          if (detector) {
            try {
              const barcodes = await detector.detect(img);
              if (barcodes.length > 0 && barcodes[0].rawValue) {
                handleSuccess(barcodes[0].rawValue, barcodes[0].format?.toUpperCase() || 'BARCODE');
                return;
              }
            } catch (_) {}
          }
          const manualCode = prompt('Nhập nội dung mã QR hoặc mã vạch:', '8935001700125');
          if (manualCode) {
            handleSuccess(manualCode, 'EAN_13');
          }
        };
        img.src = URL.createObjectURL(file);
      });

      try {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          stream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'environment' },
          });
          const video = card.querySelector('#qr-camera-video') as HTMLVideoElement;
          if (video) {
            video.srcObject = stream;
            await video.play();

            if (detector) {
              const scanLoop = async () => {
                if (video.readyState >= 2) {
                  try {
                    const barcodes = await detector.detect(video);
                    if (barcodes.length > 0 && barcodes[0].rawValue) {
                      handleSuccess(barcodes[0].rawValue);
                      return;
                    }
                  } catch (_) {}
                }
                animationFrameId = requestAnimationFrame(scanLoop);
              };
              animationFrameId = requestAnimationFrame(scanLoop);
            }
          }
        }
      } catch (camErr: any) {
        const container = card.querySelector('#qr-video-container');
        if (container) {
          container.innerHTML = `
            <div style="padding: 16px; text-align: center; color: #f87171; font-size: 13px;">
              Camera không khả dụng (${camErr.name || camErr.message || 'Không có quyền'}).<br/>
              Bạn có thể bấm <b>"Tải ảnh QR"</b> để đọc mã từ thư viện ảnh.
            </div>
          `;
        }
      }
    });
  }

  /**
   * Real Speech-to-Text Recognition with Web Speech API and Interactive Fallback Modal
   */
  private async recordRealSpeech(lang: string = 'vi-VN'): Promise<{
    text: string;
    confidence: number;
    lang: string;
    timestamp: number;
  }> {
    if (typeof document === 'undefined') {
      return {
        text: 'Tìm kiếm sản phẩm cà phê Robusta',
        confidence: 0.95,
        lang,
        timestamp: Date.now(),
      };
    }

    return new Promise(async (resolve, reject) => {
      let recognition: any = null;
      const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      if (SpeechRecognition) {
        try {
          recognition = new SpeechRecognition();
          recognition.lang = lang;
          recognition.continuous = true;
          recognition.interimResults = true;
        } catch (_) {}
      }

      try {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          await navigator.mediaDevices.getUserMedia({ audio: true });
        }
      } catch (_) {}

      const overlay = document.createElement('div');
      overlay.style.position = 'fixed';
      overlay.style.inset = '0';
      overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.85)';
      overlay.style.zIndex = '99999';
      overlay.style.display = 'flex';
      overlay.style.alignItems = 'center';
      overlay.style.justifyContent = 'center';
      overlay.style.padding = '20px';
      overlay.style.color = '#ffffff';
      overlay.style.fontFamily = 'system-ui, -apple-system, sans-serif';

      const card = document.createElement('div');
      card.style.backgroundColor = '#18181b';
      card.style.border = '1px solid #3f3f46';
      card.style.borderRadius = '16px';
      card.style.maxWidth = '440px';
      card.style.width = '100%';
      card.style.padding = '20px';
      card.style.display = 'flex';
      card.style.flexDirection = 'column';
      card.style.alignItems = 'center';
      card.style.gap = '14px';

      card.innerHTML = `
        <div style="font-weight: 600; font-size: 17px; text-align: center;">Ghi âm & Nhận diện giọng nói</div>
        <div style="font-size: 13px; color: #a1a1aa; text-align: center;">Hãy nói vào microphone hoặc chọn câu mẫu bên dưới:</div>
        
        <div style="width: 72px; height: 72px; border-radius: 50%; background: rgba(239, 68, 68, 0.15); border: 2px solid #ef4444; display: flex; align-items: center; justify-content: center; margin: 4px 0;">
          <span style="font-size: 28px;">🎙️</span>
        </div>

        <div style="width: 100%; display: flex; flex-direction: column; gap: 6px;">
          <div style="font-size: 11px; color: #a1a1aa; font-weight: 600;">Mẫu câu thử nghiệm nhanh:</div>
          <div style="display: flex; gap: 6px; width: 100%; flex-wrap: wrap;">
            <button id="speech-p1" style="flex: 1; min-width: 120px; background: #27272a; color: #fca5a5; border: 1px solid #3f3f46; padding: 7px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 500;">🗣️ Chuyển 200k cho bạn An</button>
            <button id="speech-p2" style="flex: 1; min-width: 120px; background: #27272a; color: #fca5a5; border: 1px solid #3f3f46; padding: 7px; border-radius: 6px; cursor: pointer; font-size: 11px; font-weight: 500;">🗣️ Tìm cà phê Robusta</button>
          </div>
        </div>

        <textarea id="speech-text-result" rows="3" style="width: 100%; background: #27272a; color: #ffffff; border: 1px solid #3f3f46; border-radius: 8px; padding: 10px; font-size: 13px; font-family: inherit; resize: none;" placeholder="Văn bản nhận diện giọng nói sẽ hiển thị ở đây..."></textarea>

        <div style="display: flex; gap: 10px; width: 100%;">
          <button id="speech-cancel-btn" style="flex: 1; background: #27272a; color: #f43f5e; border: 1px solid #3f3f46; padding: 10px; border-radius: 8px; cursor: pointer; font-size: 13px; font-weight: 600;">
            Huỷ
          </button>
          <button id="speech-confirm-btn" style="flex: 1; background: #ef4444; color: white; border: none; padding: 10px; border-radius: 8px; cursor: pointer; font-size: 13px; font-weight: 600;">
            Xác nhận văn bản
          </button>
        </div>
      `;

      overlay.appendChild(card);
      document.body.appendChild(overlay);

      const textarea = card.querySelector('#speech-text-result') as HTMLTextAreaElement;
      textarea.value = 'Tìm kiếm sản phẩm cà phê Robusta';

      card.querySelector('#speech-p1')?.addEventListener('click', () => {
        if (textarea) textarea.value = 'Chuyển 200k cho bạn An';
      });
      card.querySelector('#speech-p2')?.addEventListener('click', () => {
        if (textarea) textarea.value = 'Tìm kiếm sản phẩm cà phê Robusta';
      });

      const cleanup = () => {
        if (recognition) {
          try { recognition.stop(); } catch (_) {}
        }
        if (document.body.contains(overlay)) {
          document.body.removeChild(overlay);
        }
      };

      card.querySelector('#speech-cancel-btn')?.addEventListener('click', () => {
        cleanup();
        reject({ code: 'CANCELLED', message: 'Người dùng huỷ nhận diện giọng nói' });
      });

      card.querySelector('#speech-confirm-btn')?.addEventListener('click', () => {
        const text = textarea?.value?.trim() || 'Tìm kiếm sản phẩm cà phê Robusta';
        cleanup();
        resolve({
          text,
          confidence: 0.96,
          lang,
          timestamp: Date.now(),
        });
      });

      if (recognition) {
        recognition.onresult = (event: any) => {
          let transcript = '';
          for (let i = 0; i < event.results.length; i++) {
            transcript += event.results[i][0].transcript;
          }
          if (textarea && transcript) {
            textarea.value = transcript;
          }
        };
        try {
          recognition.start();
        } catch (_) {}
      }
    });
  }

  /**
   * Real Native-Styled Checkout Modal: Select real payment method and confirm
   */
  private async openRealCheckout(orderId: string): Promise<{
    orderId: string;
    status: 'SUCCESS' | 'FAILED' | 'CANCELLED';
    paymentMethod?: string;
    completedAt?: string;
    message?: string;
  }> {
    if (typeof document === 'undefined') {
      return {
        orderId,
        status: 'SUCCESS',
        paymentMethod: 'SUPERAPP_WALLET',
        completedAt: new Date().toISOString(),
      };
    }

    return new Promise((resolve) => {
      let order: any = null;
      try {
        const orders = JSON.parse(localStorage.getItem('superapp_orders') || '[]');
        order = orders.find((o: any) => o.orderId === orderId);
      } catch (_) {}

      const amountFormatted = order ? Number(order.amount).toLocaleString('vi-VN') + ' ' + (order.currency || 'VND') : '120.000 VND';
      const descriptionFormatted = order?.description || 'Thanh toán đơn hàng #' + orderId;

      const overlay = document.createElement('div');
      overlay.style.position = 'fixed';
      overlay.style.inset = '0';
      overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.75)';
      overlay.style.zIndex = '99999';
      overlay.style.display = 'flex';
      overlay.style.alignItems = 'center';
      overlay.style.justifyContent = 'center';
      overlay.style.padding = '20px';
      overlay.style.fontFamily = 'system-ui, -apple-system, sans-serif';

      const card = document.createElement('div');
      card.style.backgroundColor = '#18181b';
      card.style.color = '#ffffff';
      card.style.border = '1px solid #3f3f46';
      card.style.borderRadius = '16px';
      card.style.maxWidth = '400px';
      card.style.width = '100%';
      card.style.padding = '24px';
      card.style.boxShadow = '0 25px 50px -12px rgba(0,0,0,0.5)';
      card.style.display = 'flex';
      card.style.flexDirection = 'column';
      card.style.gap = '16px';

      card.innerHTML = `
        <div style="font-weight: 700; font-size: 18px; text-align: center;">Cổng thanh toán Master App</div>
        <div style="background: #27272a; padding: 14px; border-radius: 12px; display: flex; flex-direction: column; gap: 8px;">
          <div style="display: flex; justify-content: space-between; font-size: 13px; color: #a1a1aa;">
            <span>Mã đơn hàng:</span>
            <span style="color: #ffffff; font-family: monospace;">${orderId}</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 13px; color: #a1a1aa;">
            <span>Mô tả:</span>
            <span style="color: #ffffff;">${descriptionFormatted}</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 16px; font-weight: 700; border-top: 1px solid #3f3f46; padding-top: 8px; margin-top: 4px;">
            <span>Tổng số tiền:</span>
            <span style="color: #10b981;">${amountFormatted}</span>
          </div>
        </div>
        <div>
          <label style="font-size: 12px; color: #a1a1aa; margin-bottom: 6px; display: block;">Chọn phương thức thanh toán:</label>
          <select id="checkout-method-select" style="width: 100%; padding: 10px; border-radius: 8px; background: #27272a; color: white; border: 1px solid #3f3f46; font-size: 14px;">
            <option value="SUPERAPP_WALLET">Ví SuperApp (Khuyên dùng)</option>
            <option value="ATM_CARD">Thẻ ATM / Internet Banking</option>
            <option value="CREDIT_CARD">Thẻ Quốc Tế Visa / MasterCard</option>
            <option value="MOMO_WALLET">Ví điện tử MoMo</option>
            <option value="ZALOPAY_WALLET">Ví ZaloPay</option>
          </select>
        </div>
        <div style="display: flex; gap: 10px; margin-top: 8px;">
          <button id="checkout-cancel-btn" style="flex: 1; padding: 12px; border-radius: 8px; background: #27272a; color: #f43f5e; border: 1px solid #3f3f46; cursor: pointer; font-weight: 600;">
            Huỷ giao dịch
          </button>
          <button id="checkout-confirm-btn" style="flex: 1; padding: 12px; border-radius: 8px; background: #10b981; color: white; border: none; cursor: pointer; font-weight: 600;">
            Xác nhận thanh toán
          </button>
        </div>
      `;

      overlay.appendChild(card);
      document.body.appendChild(overlay);

      const closeCheckout = () => {
        if (document.body.contains(overlay)) {
          document.body.removeChild(overlay);
        }
      };

      card.querySelector('#checkout-cancel-btn')?.addEventListener('click', () => {
        closeCheckout();
        try {
          const orders = JSON.parse(localStorage.getItem('superapp_orders') || '[]');
          const idx = orders.findIndex((o: any) => o.orderId === orderId);
          if (idx >= 0) {
            orders[idx].status = 'CANCELLED';
            localStorage.setItem('superapp_orders', JSON.stringify(orders));
          }
        } catch (_) {}
        resolve({
          orderId,
          status: 'CANCELLED',
          message: 'Người dùng huỷ thanh toán',
        });
      });

      card.querySelector('#checkout-confirm-btn')?.addEventListener('click', () => {
        const method = (card.querySelector('#checkout-method-select') as HTMLSelectElement)?.value || 'SUPERAPP_WALLET';
        closeCheckout();
        const completedAt = new Date().toISOString();
        try {
          const orders = JSON.parse(localStorage.getItem('superapp_orders') || '[]');
          const idx = orders.findIndex((o: any) => o.orderId === orderId);
          if (idx >= 0) {
            orders[idx].status = 'SUCCESS';
            orders[idx].paymentMethod = method;
            orders[idx].completedAt = completedAt;
            localStorage.setItem('superapp_orders', JSON.stringify(orders));
          }
        } catch (_) {}
        resolve({
          orderId,
          status: 'SUCCESS',
          paymentMethod: method,
          completedAt,
          message: `Thanh toán thành công qua ${method}`,
        });
      });
    });
  }

  /**
   * Transport implementation when executing in browser runtime
   */
  private async simulateBrowserTransport<T>(action: string, payload: Record<string, any>): Promise<T> {
    await new Promise((r) => setTimeout(r, 150));

    switch (action) {
      // 1. Auth Flow
      case 'auth.requestCode': {
        const user = this.getStoredUserProfile();
        const authCode = `AUTH_${(typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID().replace(/-/g, '').substring(0, 16) : Math.random().toString(36).substring(2, 14)).toUpperCase()}`;
        const codeData = {
          authCode,
          userId: user.id,
          expiresAt: Date.now() + 60000, // 60s single-use TTL
          createdAt: new Date().toISOString(),
        };
        try {
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.setItem(`auth_code_${authCode}`, JSON.stringify(codeData));
          }
        } catch (_) {}
        return {
          authCode,
          expiresIn: 60,
          userId: user.id,
          createdAt: codeData.createdAt,
        } as any;
      }

      case 'auth.exchangeCode': {
        const rawCode = payload.authCode;
        let codeInfo: any = null;
        try {
          if (typeof sessionStorage !== 'undefined') {
            const raw = sessionStorage.getItem(`auth_code_${rawCode}`);
            if (raw) {
              codeInfo = JSON.parse(raw);
              sessionStorage.removeItem(`auth_code_${rawCode}`); // Single-use consumption
            }
          }
        } catch (_) {}

        if (!codeInfo && rawCode !== 'AUTH_SDK_PLAYGROUND_DEMO') {
          throw {
            code: 'INVALID_AUTH_CODE',
            message: 'Mã xác thực không hợp lệ hoặc đã qua thời gian sử dụng 60s',
          };
        }

        if (codeInfo && Date.now() > codeInfo.expiresAt) {
          throw {
            code: 'AUTH_CODE_EXPIRED',
            message: 'Mã xác thực đã hết hạn (TTL 60s)',
          };
        }

        const accessToken = `at_${(typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2))}`;
        const refreshToken = `rt_${(typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2))}`;
        const tokenResult = {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: 300,
          userId: codeInfo?.userId || this.getStoredUserProfile().id,
          appId: this.appId,
        };

        try {
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.setItem('superapp_active_token', JSON.stringify(tokenResult));
          }
        } catch (_) {}

        return tokenResult as any;
      }

      case 'auth.refreshToken': {
        if (payload.simulateError) {
          throw {
            code: 'TOKEN_REFRESH_FAILED',
            message: 'Mô phỏng lỗi làm mới token (Token đã bị thu hồi hoặc hết hạn)',
          };
        }
        const accessToken = `at_refreshed_${(typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2))}`;
        const refreshToken = `rt_new_${(typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).substring(2))}`;
        const tokenResult = {
          accessToken,
          refreshToken,
          tokenType: 'Bearer',
          expiresIn: 300,
          userId: this.getStoredUserProfile().id,
          appId: this.appId,
        };

        try {
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.setItem('superapp_active_token', JSON.stringify(tokenResult));
          }
        } catch (_) {}

        return tokenResult as any;
      }

      case 'auth.logout': {
        try {
          if (typeof sessionStorage !== 'undefined') {
            sessionStorage.removeItem('superapp_active_token');
          }
        } catch (_) {}
        return {
          status: 'LOGGED_OUT',
          timestamp: new Date().toISOString(),
        } as any;
      }

      // 2. User & Profile
      case 'user.getProfile': {
        const profile = this.getStoredUserProfile();
        return {
          id: profile.id,
          name: profile.name,
          phone: profile.phone,
          role: profile.role,
          email: profile.email,
          avatarUrl: profile.avatarUrl,
        } as any;
      }

      case 'user.getBasicInfo': {
        const profile = this.getStoredUserProfile();
        return {
          id: profile.id,
          name: profile.name,
          avatarUrl: profile.avatarUrl,
        } as any;
      }

      // 3. Device APIs (Real device capabilities)
      case 'scanQr':
      case 'scanQRCode':
      case 'scanBarcode':
      case 'device.scanQr':
      case 'device.scanQRCode':
      case 'device.scanBarcode':
        return (await this.scanRealQRCode()) as any;

      case 'getPhoto':
      case 'media.getPhoto':
        return (await this.pickRealImage()) as any;

      case 'pickImages':
      case 'media.pickImages': {
        const first = await this.pickRealImage();
        return {
          images: [first],
          count: 1,
        } as any;
      }

      case 'saveImageToGallery':
      case 'media.saveImageToGallery': {
        return {
          success: true,
          savedUri: 'photos://album/saved_' + Date.now() + '.jpg',
          timestamp: Date.now(),
        } as any;
      }

      case 'pickVideo':
      case 'media.pickVideo': {
        return {
          uri: 'blob:https://superapp.local/video_' + Date.now(),
          mimeType: 'video/mp4',
          durationSec: 45.2,
          sizeBytes: 8900000,
          fileName: 'video_recorded.mp4',
          width: 1920,
          height: 1080,
        } as any;
      }

      case 'saveVideoToGallery':
      case 'media.saveVideoToGallery': {
        return {
          success: true,
          savedUri: 'videos://album/saved_' + Date.now() + '.mp4',
          timestamp: Date.now(),
        } as any;
      }

      // File APIs
      case 'saveFile':
      case 'file.saveFile': {
        return {
          success: true,
          fileName: payload.fileName || 'document.pdf',
          action: 'SHARE_SHEET_OPENED',
        } as any;
      }

      case 'pickFile':
      case 'file.pickFile': {
        return {
          files: [
            {
              fileName: 'superapp_document.pdf',
              mimeType: 'application/pdf',
              sizeBytes: 524288,
              path: '/documents/superapp_document.pdf',
            },
          ],
          count: 1,
        } as any;
      }

      case 'filePreview':
      case 'file.filePreview': {
        if (typeof window !== 'undefined') {
          alert(`[SuperApp File Preview]\nĐang mở xem trước: ${payload.fileName || payload.fileUrl || 'file.pdf'}`);
        }
        return {
          success: true,
          fileUrl: payload.fileUrl,
          fileName: payload.fileName,
        } as any;
      }

      // System & Device Info
      case 'getNetworkInfo':
      case 'device.getNetworkInfo': {
        const online = typeof navigator !== 'undefined' ? navigator.onLine : true;
        const conn = typeof navigator !== 'undefined' ? (navigator as any).connection || (navigator as any).mozConnection || (navigator as any).webkitConnection : null;
        const netType = conn?.effectiveType || conn?.type || (online ? 'wifi' : 'none');
        return {
          networkType: netType,
          isConnected: online,
          signalStrength: online ? 'good' : 'none',
          downlink: conn?.downlink,
          rtt: conn?.rtt,
          ipAddress: online ? '192.168.1.105' : null,
          timestamp: Date.now(),
        } as any;
      }

      case 'getDeviceLanguage':
      case 'device.getDeviceLanguage': {
        const lang = typeof navigator !== 'undefined' ? navigator.language || 'vi-VN' : 'vi-VN';
        const parts = lang.split('-');
        return {
          language: lang,
          languageCode: parts[0] || 'vi',
          countryCode: parts[1] || 'VN',
          locale: (parts[0] || 'vi') + '_' + (parts[1] || 'VN'),
        } as any;
      }

      case 'getSuperAppSettings':
      case 'app.getSuperAppSettings': {
        return {
          theme: 'light',
          language: 'vi',
          timezone: 'Asia/Ho_Chi_Minh',
          gmtOffset: '+07:00',
          appName: 'SuperApp',
          shellVersion: '2.4.0',
        } as any;
      }

      case 'getSystemInfo':
      case 'device.getSystemInfo': {
        const w = typeof window !== 'undefined' ? window.innerWidth : 390;
        const h = typeof window !== 'undefined' ? window.innerHeight : 844;
        const dpr = typeof window !== 'undefined' ? window.devicePixelRatio || 2 : 2;
        return {
          platform: 'web',
          osVersion: '17.5',
          deviceModel: 'Web / Safari Mobile Viewport',
          screenWidth: w,
          screenHeight: h,
          pixelRatio: dpr,
          brand: 'Apple',
        } as any;
      }

      case 'getAppInfo':
      case 'app.getAppInfo': {
        return {
          appId: this.appId,
          name: 'SDK Playground',
          version: '1.2.0',
          category: 'Utilities',
          runtimeType: 'web',
          description: 'React + TypeScript Mini App test bed with interactive SDK runner',
        } as any;
      }

      case 'getBatteryInfo':
      case 'device.getBatteryInfo': {
        let level = 88;
        let isCharging = false;
        let status = 'discharging';
        if (typeof navigator !== 'undefined' && 'getBattery' in navigator) {
          try {
            const battery = await (navigator as any).getBattery();
            level = Math.round(battery.level * 100);
            isCharging = battery.charging;
            status = battery.charging ? 'charging' : (level === 100 ? 'full' : 'discharging');
          } catch (_) {}
        }
        return {
          level,
          isCharging,
          status,
          temperature: 28.5,
          timestamp: Date.now(),
        } as any;
      }

      case 'getContacts':
      case 'contact.getContacts': {
        return {
          contacts: [
            { id: 'c_01', name: 'Nguyễn Văn An', phone: '0988123456', email: 'an.nguyen@superapp.com', department: 'Product' },
            { id: 'c_02', name: 'Trần Thị Bình', phone: '0912345678', email: 'binh.tran@superapp.com', department: 'Operations' },
            { id: 'c_03', name: 'Lê Hoàng Cường', phone: '0977888999', email: 'cuong.le@superapp.com', department: 'Finance' },
          ],
          total: 3,
        } as any;
      }

      // UI & System Controls
      case 'showToast':
      case 'ui.showToast': {
        const msg = payload.message || 'Thao tác thành công';
        if (typeof document !== 'undefined') {
          const toast = document.createElement('div');
          toast.style.position = 'fixed';
          toast.style.bottom = '80px';
          toast.style.left = '50%';
          toast.style.transform = 'translateX(-50%)';
          toast.style.backgroundColor = '#18181b';
          toast.style.color = '#ffffff';
          toast.style.border = '1px solid #3f3f46';
          toast.style.padding = '10px 18px';
          toast.style.borderRadius = '24px';
          toast.style.fontSize = '13px';
          toast.style.fontWeight = '500';
          toast.style.boxShadow = '0 10px 25px -5px rgba(0,0,0,0.5)';
          toast.style.zIndex = '999999';
          toast.innerText = msg;
          document.body.appendChild(toast);
          setTimeout(() => {
            if (document.body.contains(toast)) document.body.removeChild(toast);
          }, payload.duration || 2200);
        }
        return { success: true, message: msg } as any;
      }

      case 'vibrate':
      case 'device.vibrate': {
        if (typeof navigator !== 'undefined' && navigator.vibrate) {
          navigator.vibrate(100);
        }
        return { success: true, style: payload.style || 'medium' } as any;
      }

      case 'copyToClipboard':
      case 'device.copyToClipboard': {
        if (typeof navigator !== 'undefined' && navigator.clipboard) {
          try {
            await navigator.clipboard.writeText(payload.text || '');
          } catch (_) {}
        }
        return { success: true, length: (payload.text || '').length } as any;
      }

      case 'setBrightness':
      case 'device.setBrightness': {
        const brightness = Math.max(0.1, Math.min(1.0, Number(payload.brightness ?? 0.8)));
        if (typeof document !== 'undefined') {
          document.documentElement.style.filter = brightness < 1 ? `brightness(${brightness})` : '';
        }
        return { success: true, brightness } as any;
      }

      case 'setStatusBarStyle':
      case 'ui.setStatusBarStyle': {
        return { success: true, style: payload.style || 'light' } as any;
      }

      case 'setNavigationBarTitle':
      case 'ui.setNavigationBarTitle': {
        const title = payload.title || payload.headerTitle || '';
        if (typeof document !== 'undefined') {
          document.title = title || 'SDK Playground';
        }
        return { success: true, title } as any;
      }

      case 'setStatusBarColor':
      case 'ui.setStatusBarColor': {
        return { success: true, color: payload.color || '#FFFFFF' } as any;
      }

      case 'setNavigationBarColor':
      case 'ui.setNavigationBarColor': {
        return {
          success: true,
          color: payload.color || '#0068FF',
          textColor: payload.textColor || 'white',
          statusBarColor: payload.statusBarColor,
        } as any;
      }

      case 'configAppView':
      case 'ui.configAppView': {
        const headerTitle = payload.headerTitle || (payload.header && payload.header.title);
        if (headerTitle && typeof document !== 'undefined') {
          document.title = headerTitle;
        }
        return {
          success: true,
          ...payload,
        } as any;
      }

      case 'keepScreen':
      case 'device.keepScreen': {
        const keepScreenOn = payload.keepScreenOn !== undefined ? !!payload.keepScreenOn : true;
        return { success: true, keepScreenOn } as any;
      }

      case 'requestSendNotification':
      case 'ui.requestSendNotification': {
        return {
          success: true,
          granted: true,
          subscriptionId: `sub_sim_${Date.now()}`,
          token: `notif_tok_${Date.now()}`,
          templateId: payload.templateId,
          reason: payload.reason,
        } as any;
      }

      case 'minimizeApp':
      case 'navigation.minimizeApp': {
        if (typeof window !== 'undefined' && window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'MINIAPP_MINIMIZE', appId: this.appId }, '*');
        }
        return { success: true, status: 'minimized', appId: this.appId, timestamp: Date.now() } as any;
      }

      case 'showMiniappMenu':
      case 'ui.showMiniappMenu': {
        if (typeof window !== 'undefined') {
          alert('[SuperApp Menu]\n1. Khởi động lại Mini App\n2. Cài đặt quyền riêng tư\n3. Chia sẻ Mini App\n4. Đóng ứng dụng');
        }
        return { success: true, action: 'MENU_DISPLAYED' } as any;
      }

      case 'closeApp':
      case 'navigation.closeApp': {
        if (typeof window !== 'undefined' && window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'MINIAPP_CLOSE', appId: this.appId }, '*');
        }
        return { success: true, message: 'Đã đóng Mini App' } as any;
      }

      // 2.11 Điện thoại & Liên kết ngoài
      case 'openPhone':
      case 'phone.openPhone': {
        const phone = payload.phoneNumber || payload.phone;
        if (!phone) {
          throw { code: 'INVALID_PARAMS', message: 'phoneNumber is required to dial phone' };
        }
        const cleanPhone = String(phone).replace(/[^\d+]/g, '');
        if (typeof window !== 'undefined') {
          try {
            window.location.href = `tel:${cleanPhone}`;
          } catch (_) {}
        }
        return {
          success: true,
          phoneNumber: cleanPhone,
          launched: true,
        } as any;
      }

      case 'openSMS':
      case 'phone.openSMS': {
        const phone = payload.phoneNumber || payload.phone;
        if (!phone) {
          throw { code: 'INVALID_PARAMS', message: 'phoneNumber is required to send SMS' };
        }
        const cleanPhone = String(phone).replace(/[^\d+]/g, '');
        const body = payload.body || '';
        if (typeof window !== 'undefined') {
          try {
            const encodedBody = encodeURIComponent(body);
            window.location.href = `sms:${cleanPhone}${encodedBody ? `?body=${encodedBody}` : ''}`;
          } catch (_) {}
        }
        return {
          success: true,
          phoneNumber: cleanPhone,
          body,
          launched: true,
        } as any;
      }

      case 'openExternalBrowser':
      case 'navigation.openExternalBrowser': {
        const url = payload.url;
        if (!url) {
          throw { code: 'INVALID_PARAMS', message: 'url is required for openExternalBrowser' };
        }
        if (typeof window !== 'undefined') {
          window.open(url, '_blank', 'noopener,noreferrer');
        }
        return {
          success: true,
          url,
          mode: 'external',
          launched: true,
        } as any;
      }

      case 'openDeepLink':
      case 'navigation.openDeepLink': {
        const url = payload.url;
        if (!url) {
          throw { code: 'INVALID_PARAMS', message: 'url is required for openDeepLink' };
        }
        if (typeof window !== 'undefined') {
          window.open(url, '_blank');
        }
        return {
          success: true,
          url,
          mode: 'inApp',
          launched: true,
        } as any;
      }

      // 2.12 Nhập liệu & tiện ích
      case 'speechToText':
      case 'utility.speechToText': {
        const speech = await this.recordRealSpeech(payload.lang || 'vi-VN');
        return {
          text: speech.text,
          confidence: speech.confidence,
          lang: speech.lang,
          timestamp: speech.timestamp,
        } as any;
      }

      case 'hideKeyboard':
      case 'utility.hideKeyboard': {
        if (typeof document !== 'undefined' && document.activeElement && 'blur' in document.activeElement) {
          (document.activeElement as HTMLElement).blur();
        }
        return {
          success: true,
          hidden: true,
        } as any;
      }

      // Secret Data aliases
      case 'setSecretData':
      case 'storage.setSecretData':
        return this.simulateBrowserTransport('storage.setSecureItem', payload);

      case 'getSecretData':
      case 'storage.getSecretData':
        return this.simulateBrowserTransport('storage.getSecureItem', payload);

      case 'removeSecretData':
      case 'storage.removeSecretData':
        return this.simulateBrowserTransport('storage.removeSecureItem', payload);

      case 'device.getLocation':
        return (await this.getRealLocation()) as any;

      case 'device.pickImage':
        return (await this.pickRealImage()) as any;

      // 4. Payment & Orders
      case 'payment.createOrder': {
        const amount = Number(payload.amount);
        if (!amount || amount <= 0) {
          throw {
            code: 'INVALID_AMOUNT',
            message: 'Số tiền thanh toán phải lớn hơn 0',
          };
        }
        const orderId = `ORD_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
        const order = {
          orderId,
          amount,
          currency: payload.currency || 'VND',
          description: payload.description || 'Thanh toán đơn hàng Mini App',
          status: 'PENDING',
          appId: this.appId,
          userId: this.getStoredUserProfile().id,
          createdAt: new Date().toISOString(),
        };

        try {
          if (typeof localStorage !== 'undefined') {
            const orders = JSON.parse(localStorage.getItem('superapp_orders') || '[]');
            orders.unshift(order);
            localStorage.setItem('superapp_orders', JSON.stringify(orders.slice(0, 50)));
          }
        } catch (_) {}

        return order as any;
      }

      case 'payment.openCheckout':
        return (await this.openRealCheckout(payload.orderId || 'ORD_SIM')) as any;

      // 5. Permissions
      case 'permission.request': {
        const cap = payload.capability;
        if (cap === 'device.getLocation') {
          const granted = await new Promise<boolean>((resolve) => {
            if (!navigator.geolocation) return resolve(false);
            navigator.geolocation.getCurrentPosition(
              () => resolve(true),
              () => resolve(false),
              { timeout: 5000 }
            );
          });
          return { capability: cap, granted } as any;
        }
        if (cap === 'device.scanQRCode') {
          const granted = await new Promise<boolean>((resolve) => {
            if (!navigator.mediaDevices?.getUserMedia) return resolve(true);
            navigator.mediaDevices
              .getUserMedia({ video: true })
              .then((s) => {
                s.getTracks().forEach((t) => t.stop());
                resolve(true);
              })
              .catch(() => resolve(false));
          });
          return { capability: cap, granted } as any;
        }
        return { capability: cap, granted: true } as any;
      }

      case 'permission.check': {
        const cap = payload.capability;
        if (typeof navigator !== 'undefined' && navigator.permissions?.query) {
          try {
            if (cap === 'device.getLocation') {
              const status = await navigator.permissions.query({ name: 'geolocation' });
              return { capability: cap, granted: status.state === 'granted' } as any;
            }
            if (cap === 'device.scanQRCode') {
              const status = await navigator.permissions.query({ name: 'camera' as any });
              return { capability: cap, granted: status.state === 'granted' } as any;
            }
          } catch (_) {}
        }
        return { capability: cap, granted: true } as any;
      }

      case 'permission.getPermissions':
      case 'permission.getAll': {
        return {
          appId: this.appId,
          permissions: {
            'device.scanQRCode': true,
            'device.getLocation': true,
            'device.pickImage': true,
            'payment.openCheckout': true,
            'storage.secure': true,
          },
        } as any;
      }

      // 6. Secure Storage & Credentials (Keychain/Keystore simulation)
      case 'storage.setSecureItem':
      case 'storage.setItem': {
        const { key, value, domain = 'default' } = payload;
        if (!key || value === undefined) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Key và Value là bắt buộc để lưu vào Secure Storage',
          };
        }
        const strVal = typeof value === 'string' ? value : JSON.stringify(value);
        const storageKey = `superapp_sec_${this.appId}_${domain}_${key}`;
        try {
          if (typeof localStorage !== 'undefined') {
            localStorage.setItem(storageKey, strVal);
          }
        } catch (_) {}
        return {
          key,
          domain,
          appId: this.appId,
          success: true,
          securityLevel: 'KEYCHAIN_OR_KEYSTORE',
          updatedAt: new Date().toISOString(),
        } as any;
      }

      case 'storage.getSecureItem':
      case 'storage.getItem': {
        const { key, domain = 'default' } = payload;
        if (!key) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Key là bắt buộc để truy xuất Secure Storage',
          };
        }
        const storageKey = `superapp_sec_${this.appId}_${domain}_${key}`;
        let value: string | null = null;
        let exists = false;
        try {
          if (typeof localStorage !== 'undefined') {
            value = localStorage.getItem(storageKey);
            exists = value !== null;
          }
        } catch (_) {}
        return {
          key,
          value,
          domain,
          exists,
          securityLevel: 'KEYCHAIN_OR_KEYSTORE',
        } as any;
      }

      case 'storage.removeSecureItem':
      case 'storage.removeItem': {
        const { key, domain = 'default' } = payload;
        if (!key) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Key là bắt buộc để xóa khỏi Secure Storage',
          };
        }
        const storageKey = `superapp_sec_${this.appId}_${domain}_${key}`;
        let removed = false;
        try {
          if (typeof localStorage !== 'undefined') {
            if (localStorage.getItem(storageKey) !== null) {
              localStorage.removeItem(storageKey);
              removed = true;
            }
          }
        } catch (_) {}
        return {
          key,
          domain,
          removed,
        } as any;
      }

      case 'storage.clear': {
        const { domain } = payload;
        const prefix = domain
          ? `superapp_sec_${this.appId}_${domain}_`
          : `superapp_sec_${this.appId}_`;
        let count = 0;
        try {
          if (typeof localStorage !== 'undefined') {
            const keysToRemove: string[] = [];
            for (let i = 0; i < localStorage.length; i++) {
              const k = localStorage.key(i);
              if (k && k.startsWith(prefix)) {
                keysToRemove.push(k);
              }
            }
            count = keysToRemove.length;
            keysToRemove.forEach((k) => localStorage.removeItem(k));
          }
        } catch (_) {}
        return {
          cleared: true,
          count,
        } as any;
      }

      case 'storage.setCredentials':
      case 'credentials.setCredentials': {
        const { domain, username, password } = payload;
        if (!domain || !username || !password) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Domain, Username và Password là bắt buộc để lưu credentials',
          };
        }
        const credKey = `superapp_cred_${this.appId}_${domain}`;
        const credData = {
          domain,
          username,
          password,
          savedAt: new Date().toISOString(),
          securityLevel: 'KEYCHAIN_OR_KEYSTORE',
        };
        try {
          if (typeof localStorage !== 'undefined') {
            localStorage.setItem(credKey, JSON.stringify(credData));
          }
        } catch (_) {}
        return {
          domain,
          username,
          success: true,
          securityLevel: 'KEYCHAIN_OR_KEYSTORE',
          savedAt: credData.savedAt,
        } as any;
      }

      case 'storage.getCredentials':
      case 'credentials.getCredentials': {
        const { domain } = payload;
        if (!domain) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Domain là bắt buộc để lấy credentials',
          };
        }
        const credKey = `superapp_cred_${this.appId}_${domain}`;
        let credData: any = null;
        try {
          if (typeof localStorage !== 'undefined') {
            const raw = localStorage.getItem(credKey);
            if (raw) credData = JSON.parse(raw);
          }
        } catch (_) {}
        return {
          domain,
          username: credData?.username || null,
          password: credData?.password || null,
          exists: !!credData,
          savedAt: credData?.savedAt,
          securityLevel: 'KEYCHAIN_OR_KEYSTORE',
        } as any;
      }

      case 'storage.deleteCredentials':
      case 'credentials.deleteCredentials': {
        const { domain } = payload;
        if (!domain) {
          throw {
            code: 'INVALID_PARAMS',
            message: 'Domain là bắt buộc để xóa credentials',
          };
        }
        const credKey = `superapp_cred_${this.appId}_${domain}`;
        let deleted = false;
        try {
          if (typeof localStorage !== 'undefined') {
            if (localStorage.getItem(credKey) !== null) {
              localStorage.removeItem(credKey);
              deleted = true;
            }
          }
        } catch (_) {}
        return {
          domain,
          deleted,
        } as any;
      }

      // 6. Navigation
      case 'navigation.close': {
        if (typeof window !== 'undefined' && window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'MINIAPP_CLOSE', appId: this.appId }, '*');
        }
        return { success: true, message: 'Đã gửi tín hiệu đóng Mini App' } as any;
      }

      case 'navigation.openMiniApp': {
        if (typeof window !== 'undefined' && window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'MINIAPP_SWITCH', appId: payload.appId }, '*');
        }
        return { success: true, targetAppId: payload.appId } as any;
      }

      case 'navigation.openNativePage': {
        if (typeof window !== 'undefined' && window.parent && window.parent !== window) {
          window.parent.postMessage({ type: 'NATIVE_NAVIGATE', page: payload.page, params: payload.params }, '*');
        }
        return { success: true, page: payload.page, params: payload.params } as any;
      }

      // 7. Debug Utilities
      case 'debug.echo':
        return {
          echo: payload,
          appId: this.appId,
          timestamp: Date.now(),
        } as any;

      case 'debug.simulateFailure':
        throw {
          code: payload.type === 'timeout' ? 'TIMEOUT' : 'INTERNAL_ERROR',
          message: `Browser simulated failure: ${payload.type}`,
        };

      default:
        throw {
          code: 'ACTION_NOT_FOUND',
          message: `Action not found in browser simulator: ${action}`,
        };
    }
  }
}
