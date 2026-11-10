import React, { createContext, useContext, useEffect, useState } from 'react';
import { NativeBridgeTransport, isNativeBridgeAvailable } from '@vqh2602/sdk-transport';
import type { BridgeRequest, BridgeResponse } from '@vqh2602/sdk-transport';

export interface BridgeLogEntry {
  id: string;
  action: string;
  payload: any;
  success: boolean;
  response?: any;
  error?: any;
  durationMs: number;
  timestamp: number;
}

export function isAllowedMiniAppUrl(rawUrl: string): boolean {
  if (!rawUrl || typeof rawUrl !== 'string') return false;
  try {
    const parsed = new URL(rawUrl.trim());
    // 1. Strictly block dangerous schemes
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }
    // 2. Reject credentials embedded in URL
    if (parsed.username || parsed.password) {
      return false;
    }
    // 3. For http, only allow local loopback origins
    if (parsed.protocol === 'http:') {
      return (
        parsed.hostname === 'localhost' ||
        parsed.hostname === '127.0.0.1' ||
        parsed.hostname === '[::1]' ||
        parsed.hostname.endsWith('.localhost')
      );
    }
    // 4. For https, allow valid remote web hosts
    return parsed.protocol === 'https:';
  } catch (_) {
    return false;
  }
}

interface State {
  miniAppUrl: string;
  setMiniAppUrl: (url: string) => void;
  urlError: string | null;
  clearUrlError: () => void;
  deviceType: 'iphone' | 'android';
  setDeviceType: (type: 'iphone' | 'android') => void;
  scale: number;
  setScale: (scale: number) => void;
  logs: BridgeLogEntry[];
  clearLogs: () => void;
  reloadIframe: () => void;
  iframeKey: number;
}

const Context = createContext<State | null>(null);

export const SimulatorProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [urlError, setUrlError] = useState<string | null>(() => {
    const initialParam = new URLSearchParams(location.search).get('url');
    if (initialParam && !isAllowedMiniAppUrl(initialParam)) {
      return 'URL không an toàn hoặc không hợp lệ. Simulator chỉ chấp nhận http://localhost, http://127.0.0.1 hoặc HTTPS.';
    }
    return null;
  });

  const [miniAppUrl, setMiniAppUrlState] = useState<string>(() => {
    const initialParam = new URLSearchParams(location.search).get('url');
    if (initialParam && isAllowedMiniAppUrl(initialParam)) {
      return initialParam.trim();
    }
    return 'http://localhost:3000';
  });

  const [deviceType, setDeviceType] = useState<'iphone' | 'android'>('iphone');
  const [scale, setScale] = useState(1);
  const [logs, setLogs] = useState<BridgeLogEntry[]>([]);
  const [iframeKey, setIframeKey] = useState(1);

  const setMiniAppUrl = (url: string) => {
    const trimmed = url.trim();
    if (isAllowedMiniAppUrl(trimmed)) {
      setUrlError(null);
      setMiniAppUrlState(trimmed);
    } else {
      setUrlError('URL không an toàn hoặc không hợp lệ. Simulator chỉ chấp nhận http://localhost, http://127.0.0.1 hoặc HTTPS.');
    }
  };

  const clearUrlError = () => setUrlError(null);

  useEffect(() => {
    const transport = new NativeBridgeTransport();
    const onMessage = async (event: MessageEvent) => {
      const iframe = document.querySelector('iframe');
      if (!iframe || event.source !== iframe.contentWindow || event.origin !== new URL(miniAppUrl).origin) return;

      // Handle Mini App handshake
      if (event.data?.type === 'SUPERAPP_BRIDGE_HANDSHAKE') {
        iframe.contentWindow?.postMessage({
          type: 'SUPERAPP_SIMULATOR_HANDSHAKE_ACK',
          hostOrigin: window.location.origin,
          timestamp: Date.now(),
        }, event.origin);
        return;
      }

      const request: BridgeRequest = event.data?.type === 'SUPERAPP_BRIDGE_REQUEST' ? event.data.request : event.data;
      if (!request?.id || typeof request.action !== 'string') return;
      const start = Date.now();
      let response: BridgeResponse;
      try {
        if (!isNativeBridgeAvailable()) throw { code: 'NATIVE_NOT_AVAILABLE', message: 'Open this miniapp in SuperApp to access native data' };
        const data = await transport.invoke(request.action, request.payload);
        response = { id: request.id, action: request.action, success: true, data, sessionNonce: request.sessionNonce };
      } catch (error) {
        response = {
          id: request.id,
          action: request.action,
          success: false,
          error: (error && typeof error === 'object' && 'code' in error) ? error as any : { code: 'INTERNAL_ERROR', message: String(error) },
          sessionNonce: request.sessionNonce,
        };
      }
      setLogs(old => [{
        id: request.id,
        action: request.action,
        payload: request.payload,
        success: response.success,
        response: response.data,
        error: response.error,
        durationMs: Date.now() - start,
        timestamp: Date.now(),
      }, ...old].slice(0, 150));
      iframe.contentWindow?.postMessage({ type: 'SUPERAPP_BRIDGE_RESPONSE', response }, event.origin);
    };

    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [miniAppUrl, iframeKey]);

  return (
    <Context.Provider
      value={{
        miniAppUrl,
        setMiniAppUrl,
        urlError,
        clearUrlError,
        deviceType,
        setDeviceType,
        scale,
        setScale,
        logs,
        clearLogs: () => setLogs([]),
        iframeKey,
        reloadIframe: () => setIframeKey(k => k + 1),
      }}
    >
      {children}
    </Context.Provider>
  );
};

export function useSimulator(): State {
  const value = useContext(Context);
  if (!value) throw new Error('Missing SimulatorProvider');
  return value;
}
