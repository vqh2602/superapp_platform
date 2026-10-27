import React, { useState, useEffect } from 'react';
import { MiniAppSchema } from './types';
import { SchemaRenderer } from './SchemaRenderer';
import { sampleMiniAppSchemas, coffeeShopSchema } from './sampleSchemas';
import { Loader2, AlertCircle, Sparkles } from 'lucide-react';

declare global {
  interface Window {
    __MINIAPP_SCHEMA__?: MiniAppSchema;
    __MINIAPP_APP_ID__?: string;
    FlutterBridge?: {
      postMessage: (msg: string) => void;
    };
  }
}

export const App: React.FC = () => {
  const [schema, setSchema] = useState<MiniAppSchema | null>(null);
  const [appId, setAppId] = useState<string>('coffee_shop');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [isNativeBridge, setIsNativeBridge] = useState<boolean>(false);

  useEffect(() => {
    const hasBridge = typeof window !== 'undefined' && !!(window.FlutterBridge && window.FlutterBridge.postMessage);
    setIsNativeBridge(hasBridge);

    // 1. Check window.__MINIAPP_SCHEMA__ injected directly by SuperApp WebViewController
    if (typeof window !== 'undefined' && window.__MINIAPP_SCHEMA__) {
      setSchema(window.__MINIAPP_SCHEMA__);
      if (window.__MINIAPP_APP_ID__) setAppId(window.__MINIAPP_APP_ID__);
      setLoading(false);
      return;
    }

    // 2. Listen to schema loaded event from Flutter Bridge
    const onSchemaEvent = (e: any) => {
      if (e.detail?.schema) {
        setSchema(e.detail.schema);
        if (e.detail.appId) setAppId(e.detail.appId);
        setLoading(false);
      }
    };
    window.addEventListener('miniapp.schema_loaded', onSchemaEvent);

    // 3. Check URL search param and sample schemas fallback
    const params = new URLSearchParams(window.location.search);
    const targetAppId = params.get('appId') || window.__MINIAPP_APP_ID__ || 'coffee_shop';
    setAppId(targetAppId);

    const fallbackSample = sampleMiniAppSchemas[targetAppId] || sampleMiniAppSchemas.coffee_shop || coffeeShopSchema;

    // Fetch schema from Catalog API if available, otherwise use local sample
    const catalogBaseUrl = 'http://localhost:3000/api/v1/catalog';
    fetch(`${catalogBaseUrl}/apps/${targetAppId}`)
      .then(async (res) => {
        if (!res.ok) {
          throw new Error(`Catalog API returned HTTP ${res.status}`);
        }
        const data = await res.json();
        if (data.schema) {
          setSchema(data.schema);
        } else {
          setSchema(fallbackSample);
        }
      })
      .catch((err) => {
        console.warn(`[SchemaRuntime] Using built-in sample schema for "${targetAppId}": ${err.message}`);
        setSchema(fallbackSample);
      })
      .finally(() => {
        setLoading(false);
      });

    return () => {
      window.removeEventListener('miniapp.schema_loaded', onSchemaEvent);
    };
  }, []);

  const handleSelectSampleApp = (selectedId: string) => {
    setAppId(selectedId);
    const selectedSchema = sampleMiniAppSchemas[selectedId] || coffeeShopSchema;
    setSchema(selectedSchema);
  };

  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100vh',
          backgroundColor: '#F8FAFC',
          gap: '12px',
          color: '#64748B',
        }}
      >
        <Loader2 size={32} className="spin" color="#2563EB" />
        <p style={{ fontSize: '13px', fontWeight: 600 }}>Đang nạp Schema No-Code...</p>
      </div>
    );
  }

  if (error || !schema) {
    return (
      <div
        style={{
          padding: '30px',
          textAlign: 'center',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '12px',
        }}
      >
        <AlertCircle size={40} color="#EF4444" />
        <h3 style={{ margin: 0 }}>Không thể tải Mini App</h3>
        <p style={{ color: '#64748B', fontSize: '13px' }}>{error || 'Dữ liệu schema không hợp lệ.'}</p>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative' }}>
      {/* Floating Demo MiniApp Switcher for standalone browser preview mode */}
      {!isNativeBridge && (
        <div
          style={{
            position: 'sticky',
            top: 0,
            zIndex: 99999,
            backgroundColor: '#0F172A',
            color: '#F8FAFC',
            padding: '8px 12px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '8px',
            fontSize: '12px',
            borderBottom: '1px solid #334155',
            boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 700 }}>
            <Sparkles size={14} color="#38BDF8" />
            <span>Schema Demo:</span>
          </div>
          <select
            value={appId}
            onChange={(e) => handleSelectSampleApp(e.target.value)}
            style={{
              backgroundColor: '#1E293B',
              color: '#FFFFFF',
              border: '1px solid #475569',
              borderRadius: '6px',
              padding: '4px 8px',
              fontSize: '12px',
              fontWeight: 600,
              cursor: 'pointer',
              outline: 'none',
            }}
          >
            <option value="shopee">🛍️ Shopee Super Mall</option>
            <option value="tiktok">🎵 TikTok Hub & Creator</option>
            <option value="coffee_shop">☕ The Coffee House</option>
            <option value="youtube">🎬 YouTube Streaming</option>
            <option value="viettel_tammi">📶 Viettel Tammi Data</option>
            <option value="free_fire">🎮 Free Fire MAX Top-up</option>
            <option value="capcut">✂️ CapCut Video Studio</option>
            <option value="messenger">💬 Messenger Community</option>
          </select>
        </div>
      )}

      <SchemaRenderer schema={schema} appId={appId} />
    </div>
  );
};
