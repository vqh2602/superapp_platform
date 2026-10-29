import React, { useState } from 'react';
import { ExternalLink, Layers, RefreshCw, Smartphone, Sparkles, ZoomIn } from 'lucide-react';
import { useSimulator } from './context/SimulatorContext.js';
import { DeviceFrame } from './components/DeviceFrame.js';
import { DevToolsDrawer } from './components/DevToolsDrawer.js';

export const AppContent: React.FC = () => {
  const {
    miniAppUrl,
    setMiniAppUrl,
    reloadIframe,
    deviceType,
    setDeviceType,
    scale,
    setScale,
  } = useSimulator();

  const [inputUrl, setInputUrl] = useState(miniAppUrl);

  const handleUrlSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputUrl.trim()) {
      setMiniAppUrl(inputUrl.trim());
      reloadIframe();
    }
  };

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100vh',
        width: '100vw',
        overflow: 'hidden',
        backgroundColor: '#030712',
      }}
    >
      {/* Top Navbar */}
      <header
        style={{
          height: 56,
          backgroundColor: '#0f172a',
          borderBottom: '1px solid #1e293b',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 20px',
          gap: 16,
          zIndex: 20,
        }}
      >
        {/* Brand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: 8,
              backgroundColor: '#0068FF',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'white',
              fontWeight: 800,
              fontSize: 16,
            }}
          >
            S
          </div>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14, color: '#f8fafc', display: 'flex', alignItems: 'center', gap: 6 }}>
              SuperApp Browser Simulator
              <span style={{ fontSize: 10, backgroundColor: '#0284c7', color: 'white', padding: '1px 6px', borderRadius: 10 }}>
                v1.0
              </span>
            </div>
            <div style={{ fontSize: 11, color: '#64748b' }}>Mini App Developer Workbench</div>
          </div>
        </div>

        {/* URL Bar Form */}
        <form onSubmit={handleUrlSubmit} style={{ display: 'flex', alignItems: 'center', flex: 1, maxWidth: 520, gap: 6 }}>
          <input
            type="text"
            value={inputUrl}
            onChange={(e) => setInputUrl(e.target.value)}
            placeholder="http://localhost:3000"
            style={{
              flex: 1,
              padding: '7px 12px',
              backgroundColor: '#020617',
              border: '1px solid #334155',
              borderRadius: 8,
              color: '#38bdf8',
              fontSize: 13,
              fontFamily: 'monospace',
            }}
          />
          <button
            type="submit"
            style={{
              padding: '7px 14px',
              backgroundColor: '#0284c7',
              color: 'white',
              border: 'none',
              borderRadius: 8,
              fontSize: 12,
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
            }}
          >
            <RefreshCw size={13} /> Nạp URL
          </button>
        </form>

        {/* Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {/* Device Model Switcher */}
          <div style={{ display: 'flex', backgroundColor: '#020617', padding: 2, borderRadius: 8, border: '1px solid #334155' }}>
            <button
              onClick={() => setDeviceType('iphone')}
              style={{
                padding: '4px 10px',
                borderRadius: 6,
                backgroundColor: deviceType === 'iphone' ? '#1e293b' : 'transparent',
                color: deviceType === 'iphone' ? '#38bdf8' : '#94a3b8',
                border: 'none',
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              iPhone 15
            </button>
            <button
              onClick={() => setDeviceType('android')}
              style={{
                padding: '4px 10px',
                borderRadius: 6,
                backgroundColor: deviceType === 'android' ? '#1e293b' : 'transparent',
                color: deviceType === 'android' ? '#38bdf8' : '#94a3b8',
                border: 'none',
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: 600,
              }}
            >
              Android
            </button>
          </div>

          {/* Scale Zoom */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#94a3b8', fontSize: 12 }}>
            <ZoomIn size={14} />
            <select
              value={scale}
              onChange={(e) => setScale(parseFloat(e.target.value))}
              style={{
                backgroundColor: '#020617',
                color: '#f8fafc',
                border: '1px solid #334155',
                borderRadius: 6,
                padding: '4px 8px',
                fontSize: 12,
                cursor: 'pointer',
              }}
            >
              <option value="0.75">75%</option>
              <option value="0.85">85%</option>
              <option value="0.9">90%</option>
              <option value="1">100%</option>
            </select>
          </div>
        </div>
      </header>

      {/* Main Workspace */}
      <main
        style={{
          flex: 1,
          display: 'flex',
          gap: 24,
          padding: 20,
          overflow: 'hidden',
          justifyContent: 'center',
          alignItems: 'flex-start',
        }}
      >
        {/* Left Side: Mobile Phone Device Viewport */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'flex-start',
            overflowY: 'auto',
            maxHeight: 'calc(100vh - 96px)',
            padding: '10px 20px',
          }}
        >
          <DeviceFrame />
        </div>

        {/* Right Side: DevTools Drawer */}
        <DevToolsDrawer />
      </main>
    </div>
  );
};
