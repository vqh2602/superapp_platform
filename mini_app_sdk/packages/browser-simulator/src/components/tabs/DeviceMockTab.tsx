import React from 'react';
import { BatteryCharging, PlayCircle, Radio, Wifi } from 'lucide-react';
import { useSimulator } from '../../context/SimulatorContext.js';

export const DeviceMockTab: React.FC = () => {
  const {
    deviceState,
    setDeviceState,
    network,
    setNetwork,
    mockEngine,
    sendEventToMiniApp,
  } = useSimulator();

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, fontSize: 13, color: '#f1f5f9' }}>
      {/* Battery */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
            <BatteryCharging size={16} color="#38bdf8" /> Giả lập Pin thiết bị
          </div>
          <span style={{ fontWeight: 700, color: '#38bdf8' }}>{deviceState.batteryLevel}%</span>
        </div>

        <input
          type="range"
          min="0"
          max="100"
          value={deviceState.batteryLevel}
          onChange={(e) => setDeviceState({ batteryLevel: parseInt(e.target.value, 10) })}
          style={{ width: '100%', accentColor: '#0284c7' }}
        />

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ color: '#94a3b8', fontSize: 12 }}>Đang cắm sạc (Charging):</span>
          <input
            type="checkbox"
            checked={deviceState.isCharging}
            onChange={(e) => setDeviceState({ isCharging: e.target.checked })}
            style={{ width: 16, height: 16, accentColor: '#0284c7' }}
          />
        </div>
      </div>

      {/* Network */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}
      >
        <div style={{ fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
          <Wifi size={16} color="#38bdf8" /> Mạng kết nối (Network Profile)
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
          {(['wifi', '5g', '4g', '2g', 'none'] as const).map((type) => (
            <button
              key={type}
              onClick={() => setNetwork({ type, online: type !== 'none' })}
              style={{
                padding: '6px 4px',
                backgroundColor: network.type === type ? '#0284c7' : '#1e293b',
                border: '1px solid #334155',
                borderRadius: 6,
                color: 'white',
                fontSize: 11,
                fontWeight: 600,
                cursor: 'pointer',
                textTransform: 'uppercase',
              }}
            >
              {type}
            </button>
          ))}
        </div>
      </div>

      {/* Latency Injection */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontWeight: 600, display: 'flex', alignItems: 'center', gap: 6 }}>
            <Radio size={16} color="#38bdf8" /> Độ trễ Bridge (Latency Injection)
          </div>
          <span style={{ fontWeight: 700, color: '#38bdf8' }}>{network.latencyMs} ms</span>
        </div>

        <input
          type="range"
          min="0"
          max="1500"
          step="50"
          value={network.latencyMs}
          onChange={(e) => {
            const ms = parseInt(e.target.value, 10);
            setNetwork({ latencyMs: ms });
            mockEngine.setLatency(ms);
          }}
          style={{ width: '100%', accentColor: '#0284c7' }}
        />
      </div>

      {/* Lifecycle Push Events */}
      <div
        style={{
          backgroundColor: '#0f172a',
          borderRadius: 8,
          padding: 12,
          border: '1px solid #1e293b',
          display: 'flex',
          flexDirection: 'column',
          gap: 8,
        }}
      >
        <div style={{ fontWeight: 600, color: '#94a3b8' }}>Giả lập sự kiện vòng đời (Lifecycle Events):</div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            onClick={() => sendEventToMiniApp('appShow', { timestamp: Date.now() })}
            style={{
              flex: 1,
              padding: '8px 10px',
              backgroundColor: '#065f46',
              color: '#34d399',
              border: '1px solid #047857',
              borderRadius: 6,
              fontWeight: 600,
              fontSize: 12,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 4,
            }}
          >
            <PlayCircle size={14} /> appShow
          </button>
          <button
            onClick={() => sendEventToMiniApp('appHide', { timestamp: Date.now() })}
            style={{
              flex: 1,
              padding: '8px 10px',
              backgroundColor: '#374151',
              color: '#d1d5db',
              border: '1px solid #4b5563',
              borderRadius: 6,
              fontWeight: 600,
              fontSize: 12,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 4,
            }}
          >
            <PlayCircle size={14} /> appHide
          </button>
        </div>
      </div>
    </div>
  );
};
