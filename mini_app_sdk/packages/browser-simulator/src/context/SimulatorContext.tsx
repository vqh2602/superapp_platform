import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import {
  BridgeRequest,
  BridgeResponse,
} from '@superapp/sdk-transport';
import {
  MockDeviceState,
  MockLogEntry,
  MockNetworkCondition,
  MockPaymentOrder,
  MockUserProfile,
  SDKMockEngine,
} from '@superapp/sdk-mock-engine';

export interface SimulatorContextType {
  mockEngine: SDKMockEngine;
  miniAppUrl: string;
  setMiniAppUrl: (url: string) => void;
  deviceType: 'iphone' | 'android';
  setDeviceType: (type: 'iphone' | 'android') => void;
  scale: number;
  setScale: (scale: number) => void;
  logs: MockLogEntry[];
  clearLogs: () => void;
  activeTab: 'bridge' | 'auth' | 'payment' | 'device' | 'storage';
  setActiveTab: (tab: 'bridge' | 'auth' | 'payment' | 'device' | 'storage') => void;
  user: MockUserProfile;
  setUser: (u: Partial<MockUserProfile>) => void;
  setUserPreset: (preset: 'standard' | 'vip' | 'lowBalance' | 'unverified') => void;
  network: MockNetworkCondition;
  setNetwork: (n: Partial<MockNetworkCondition>) => void;
  deviceState: MockDeviceState;
  setDeviceState: (d: Partial<MockDeviceState>) => void;
  manualPaymentMode: boolean;
  setManualPaymentMode: (val: boolean) => void;
  pendingPayment: { order: MockPaymentOrder; resolve: (approved: boolean) => void } | null;
  resolvePayment: (approved: boolean) => void;
  reloadIframe: () => void;
  iframeKey: number;
  sendEventToMiniApp: (event: string, payload: any) => void;
}

const SimulatorContext = createContext<SimulatorContextType | null>(null);

export const SimulatorProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [mockEngine] = useState(() => new SDKMockEngine({ autoApprovePayment: true }));
  
  // URL from query param or default localhost:3000
  const [miniAppUrl, setMiniAppUrl] = useState(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      return params.get('url') || 'http://localhost:3000';
    }
    return 'http://localhost:3000';
  });

  const [deviceType, setDeviceType] = useState<'iphone' | 'android'>('iphone');
  const [scale, setScale] = useState<number>(1);
  const [logs, setLogs] = useState<MockLogEntry[]>([]);
  const [activeTab, setActiveTab] = useState<'bridge' | 'auth' | 'payment' | 'device' | 'storage'>('bridge');
  const [manualPaymentMode, setManualPaymentMode] = useState<boolean>(false);
  const [iframeKey, setIframeKey] = useState<number>(1);
  const [pendingPayment, setPendingPayment] = useState<{
    order: MockPaymentOrder;
    resolve: (approved: boolean) => void;
  } | null>(null);

  const [user, setUserState] = useState<MockUserProfile>(() => mockEngine.store.getUser());
  const [network, setNetworkState] = useState<MockNetworkCondition>(() => mockEngine.store.getNetworkCondition());
  const [deviceState, setDeviceStateLocal] = useState<MockDeviceState>(() => mockEngine.store.getDeviceState());

  const manualResolverRef = useRef<((approved: boolean) => void) | null>(null);

  useEffect(() => {
    // Setup log listener
    const unsubscribeLogs = mockEngine.onLog((entry: MockLogEntry) => {
      setLogs((prev) => [entry, ...prev.slice(0, 150)]);
    });

    // Setup manual payment resolver on mock engine
    mockEngine.payment.setManualDecisionResolver(async (order: MockPaymentOrder) => {
      if (!manualPaymentMode) {
        return true;
      }
      return new Promise<boolean>((resolve) => {
        manualResolverRef.current = resolve;
        setPendingPayment({ order, resolve });
      });
    });

    return () => {
      unsubscribeLogs();
    };
  }, [mockEngine, manualPaymentMode]);

  // Handle postMessage from child iframe
  useEffect(() => {
    const handleMessage = async (event: MessageEvent) => {
      const data = event.data;
      if (!data || data.type !== 'SUPERAPP_BRIDGE_REQUEST') return;

      const request = data.request as BridgeRequest;
      if (!request || !request.id) return;

      // Dispatch to mock engine
      const response: BridgeResponse = await mockEngine.dispatch(request);

      // Refresh local store states that might have mutated
      setUserState(mockEngine.store.getUser());
      setDeviceStateLocal(mockEngine.store.getDeviceState());

      // Send response back to sender iframe
      if (event.source && 'postMessage' in event.source) {
        (event.source as Window).postMessage(
          {
            type: 'SUPERAPP_BRIDGE_RESPONSE',
            response,
          },
          '*'
        );
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [mockEngine]);

  const resolvePayment = (approved: boolean) => {
    if (manualResolverRef.current) {
      manualResolverRef.current(approved);
      manualResolverRef.current = null;
    }
    setPendingPayment(null);
  };

  const setUser = (u: Partial<MockUserProfile>) => {
    const updated = mockEngine.store.setUser(u);
    setUserState(updated);
  };

  const setUserPreset = (preset: 'standard' | 'vip' | 'lowBalance' | 'unverified') => {
    const updated = mockEngine.store.setUserPreset(preset);
    setUserState(updated);
  };

  const setNetwork = (n: Partial<MockNetworkCondition>) => {
    mockEngine.store.setNetworkCondition(n);
    setNetworkState(mockEngine.store.getNetworkCondition());
  };

  const setDeviceState = (d: Partial<MockDeviceState>) => {
    mockEngine.store.updateDeviceState(d);
    setDeviceStateLocal(mockEngine.store.getDeviceState());
  };

  const reloadIframe = () => {
    setIframeKey((k) => k + 1);
  };

  const sendEventToMiniApp = (event: string, payload: any) => {
    const iframes = document.querySelectorAll('iframe');
    iframes.forEach((ifr) => {
      ifr.contentWindow?.postMessage(
        {
          type: 'SUPERAPP_BRIDGE_EVENT',
          event,
          payload,
        },
        '*'
      );
    });
  };

  const clearLogs = () => {
    mockEngine.clearLogs();
    setLogs([]);
  };

  return (
    <SimulatorContext.Provider
      value={{
        mockEngine,
        miniAppUrl,
        setMiniAppUrl,
        deviceType,
        setDeviceType,
        scale,
        setScale,
        logs,
        clearLogs,
        activeTab,
        setActiveTab,
        user,
        setUser,
        setUserPreset,
        network,
        setNetwork,
        deviceState,
        setDeviceState,
        manualPaymentMode,
        setManualPaymentMode,
        pendingPayment,
        resolvePayment,
        reloadIframe,
        iframeKey,
        sendEventToMiniApp,
      }}
    >
      {children}
    </SimulatorContext.Provider>
  );
};

export const useSimulator = (): SimulatorContextType => {
  const ctx = useContext(SimulatorContext);
  if (!ctx) throw new Error('useSimulator must be used inside SimulatorProvider');
  return ctx;
};
