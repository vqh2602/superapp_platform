import React, { useEffect, useState } from 'react';
import { Battery, BatteryCharging, Wifi, WifiOff } from 'lucide-react';
import { useSimulator } from '../context/SimulatorContext.js';

export const TopStatusBar: React.FC = () => {
  const { deviceType, network, deviceState } = useSimulator();
  const [time, setTime] = useState('09:41');

  useEffect(() => {
    const updateTime = () => {
      const d = new Date();
      setTime(
        `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div
      style={{
        height: 44,
        padding: '0 20px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        backgroundColor: '#ffffff',
        color: '#000000',
        fontSize: 13,
        fontWeight: 600,
        userSelect: 'none',
        position: 'relative',
        borderTopLeftRadius: deviceType === 'iphone' ? 44 : 28,
        borderTopRightRadius: deviceType === 'iphone' ? 44 : 28,
      }}
    >
      {/* Time */}
      <span>{time}</span>

      {/* Dynamic Island / Punch hole */}
      {deviceType === 'iphone' ? (
        <div
          style={{
            position: 'absolute',
            top: 10,
            left: '50%',
            transform: 'translateX(-50%)',
            width: 110,
            height: 28,
            backgroundColor: '#000000',
            borderRadius: 18,
            zIndex: 10,
          }}
        />
      ) : (
        <div
          style={{
            position: 'absolute',
            top: 12,
            left: '50%',
            transform: 'translateX(-50%)',
            width: 14,
            height: 14,
            backgroundColor: '#000000',
            borderRadius: '50%',
            zIndex: 10,
          }}
        />
      )}

      {/* Status icons */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        {network.online ? (
          <span style={{ fontSize: 11, fontWeight: 700 }}>
            {network.type.toUpperCase()}
          </span>
        ) : (
          <span style={{ fontSize: 11, color: '#ef4444' }}>OFFLINE</span>
        )}

        {network.online ? <Wifi size={14} /> : <WifiOff size={14} color="#ef4444" />}

        <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <span style={{ fontSize: 11 }}>{deviceState.batteryLevel}%</span>
          {deviceState.isCharging ? (
            <BatteryCharging size={16} color="#10b981" />
          ) : (
            <Battery size={16} />
          )}
        </div>
      </div>
    </div>
  );
};
