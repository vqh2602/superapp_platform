import React from 'react';
import { useSimulator } from '../context/SimulatorContext.js';
import { TopStatusBar } from './TopStatusBar.js';
import { AppHeaderBar } from './AppHeaderBar.js';

export const DeviceFrame: React.FC = () => {
  const { deviceType, scale, miniAppUrl, iframeKey } = useSimulator();

  const width = deviceType === 'iphone' ? 390 : 412;
  const height = deviceType === 'iphone' ? 844 : 880;

  return (
    <div
      style={{
        transform: `scale(${scale})`,
        transformOrigin: 'top center',
        transition: 'transform 0.2s ease',
      }}
    >
      <div
        style={{
          width,
          height,
          backgroundColor: '#000000',
          borderRadius: deviceType === 'iphone' ? 52 : 36,
          padding: 10,
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(255, 255, 255, 0.15)',
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Screen container */}
        <div
          style={{
            flex: 1,
            backgroundColor: '#ffffff',
            borderRadius: deviceType === 'iphone' ? 44 : 28,
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            position: 'relative',
          }}
        >
          {/* Top Status Bar */}
          <TopStatusBar />

          {/* SuperApp Capsule App Header */}
          <AppHeaderBar title="SuperApp Mini App" />

          {/* Iframe hosting Mini App */}
          <div style={{ flex: 1, position: 'relative', overflow: 'hidden' }}>
            <iframe
              key={iframeKey}
              src={miniAppUrl}
              title="Mini App Simulator View"
              style={{
                width: '100%',
                height: '100%',
                border: 'none',
                backgroundColor: '#f8fafc',
              }}
              allow="geolocation; camera; microphone"

            />


          </div>

          {/* iPhone Home Indicator bar */}
          {deviceType === 'iphone' && (
            <div
              style={{
                height: 20,
                backgroundColor: '#ffffff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <div
                style={{
                  width: 130,
                  height: 4,
                  backgroundColor: '#0f172a',
                  borderRadius: 2,
                }}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
