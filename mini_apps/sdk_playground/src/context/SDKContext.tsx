import React, { createContext, useContext, useState, useEffect } from 'react';
import { superApp, BridgeLogRecord } from '@vqh2602/mini-app-sdk';

export interface EventLogItem {
  id: string;
  event: string;
  payload: any;
  timestamp: string;
}

interface SDKContextType {
  logs: BridgeLogRecord[];
  eventLogs: EventLogItem[];
  addLog: (log: Omit<BridgeLogRecord, 'id' | 'timestamp'>) => void;
  clearLogs: () => void;
  clearEventLogs: () => void;
  authCode: string | null;
  setAuthCode: (code: string | null) => void;
  accessToken: string | null;
  setAccessToken: (token: string | null) => void;
  refreshToken: string | null;
  setRefreshToken: (token: string | null) => void;
  activeRunner: RunnerConfig | null;
  openRunner: (config: RunnerConfig) => void;
  closeRunner: () => void;
  isConnected: boolean;
  loginStatus: 'authenticated' | 'unauthenticated' | 'checking';
  setLoginStatus: (status: 'authenticated' | 'unauthenticated' | 'checking') => void;
}

export interface RunnerConfig {
  id: string;
  category: string;
  title: string;
  description: string;
  actionCode: string;
  defaultParams?: Record<string, any>;
  hasParams?: boolean;
  run: (params: any) => Promise<any>;
}

const SDKContext = createContext<SDKContextType | null>(null);

export const SDKProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [logs, setLogs] = useState<BridgeLogRecord[]>([]);
  const [eventLogs, setEventLogs] = useState<EventLogItem[]>([]);
  const [authCode, setAuthCode] = useState<string | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [refreshToken, setRefreshToken] = useState<string | null>(null);
  const [activeRunner, setActiveRunner] = useState<RunnerConfig | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(superApp.isConnected());
  const [loginStatus, setLoginStatus] = useState<'authenticated' | 'unauthenticated' | 'checking'>('checking');

  useEffect(() => {
    setIsConnected(superApp.isConnected());

    // Register lifecycle listeners
    const unsubs = [
      superApp.lifecycle.on('miniapp.ready', (p) => addEvent('miniapp.ready', p)),
      superApp.lifecycle.on('miniapp.show', (p) => addEvent('miniapp.show', p)),
      superApp.lifecycle.on('miniapp.hide', (p) => addEvent('miniapp.hide', p)),
      superApp.lifecycle.on('miniapp.resume', (p) => addEvent('miniapp.resume', p)),
      superApp.lifecycle.on('miniapp.close', (p) => addEvent('miniapp.close', p)),
      superApp.lifecycle.onSessionChanged((p) => {
        addEvent('auth.sessionChanged', p);
        if (p.state === 'logged_out') {
          setLoginStatus('unauthenticated');
          setAuthCode(null);
          setAccessToken(null);
          setRefreshToken(null);
        } else {
          setLoginStatus('authenticated');
        }
      }),
      superApp.lifecycle.onPaymentStatusChanged((p) => addEvent('payment.statusChanged', p)),
    ];

    // Check basic user info to detect initial auth status
    superApp.user
      .getBasicInfo()
      .then(() => setLoginStatus('authenticated'))
      .catch((err) => {
        if (err?.code === 'AUTH_REQUIRED') {
          setLoginStatus('unauthenticated');
        } else {
          setLoginStatus('authenticated');
        }
      });

    return () => {
      unsubs.forEach((unsub) => unsub?.());
    };
  }, []);

  const addEvent = (event: string, payload: any) => {
    const item: EventLogItem = {
      id: `evt_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      event,
      payload,
      timestamp: new Date().toLocaleTimeString(),
    };
    setEventLogs((prev) => [item, ...prev].slice(0, 100));
  };

  const addLog = (log: Omit<BridgeLogRecord, 'id' | 'timestamp'>) => {
    const newRecord: BridgeLogRecord = {
      ...log,
      id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      timestamp: new Date().toLocaleTimeString(),
    };
    setLogs((prev) => [newRecord, ...prev].slice(0, 150));
  };

  const clearLogs = () => setLogs([]);
  const clearEventLogs = () => setEventLogs([]);

  return (
    <SDKContext.Provider
      value={{
        logs,
        eventLogs,
        addLog,
        clearLogs,
        clearEventLogs,
        authCode,
        setAuthCode,
        accessToken,
        setAccessToken,
        refreshToken,
        setRefreshToken,
        activeRunner,
        openRunner: (cfg) => setActiveRunner(cfg),
        closeRunner: () => setActiveRunner(null),
        isConnected,
        loginStatus,
        setLoginStatus,
      }}
    >
      {children}
    </SDKContext.Provider>
  );
};

export const useSDK = () => {
  const ctx = useContext(SDKContext);
  if (!ctx) throw new Error('useSDK must be used within SDKProvider');
  return ctx;
};
