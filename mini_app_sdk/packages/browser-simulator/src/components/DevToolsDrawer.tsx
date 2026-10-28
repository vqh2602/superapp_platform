import React from 'react';
import { Activity, Database, Smartphone, User } from 'lucide-react';
import { useSimulator } from '../context/SimulatorContext.js';
import { BridgeInspectorTab } from './tabs/BridgeInspectorTab.js';
import { AuthMockTab } from './tabs/AuthMockTab.js';
import { DeviceMockTab } from './tabs/DeviceMockTab.js';
import { StorageInspectorTab } from './tabs/StorageInspectorTab.js';

export const DevToolsDrawer: React.FC = () => {
  const { activeTab, setActiveTab, logs, user } = useSimulator();

  const tabs = [
    { id: 'bridge', label: 'Bridge Inspector', icon: Activity, count: logs.length },
    { id: 'auth', label: 'Auth & Persona', icon: User, note: user.name.split(' ')[0] },
    { id: 'device', label: 'Device & Hardware', icon: Smartphone },
    { id: 'storage', label: 'Storage', icon: Database },
  ] as const;

  return (
    <div
      style={{
        flex: 1,
        backgroundColor: '#0b1120',
        borderRadius: 16,
        border: '1px solid #1e293b',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        minWidth: 420,
        maxWidth: 600,
        height: '100%',
        boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.4)',
      }}
    >
      {/* Tab Header Bar */}
      <div
        style={{
          display: 'flex',
          backgroundColor: '#0f172a',
          borderBottom: '1px solid #1e293b',
          overflowX: 'auto',
          padding: '4px 6px',
          gap: 4,
        }}
      >
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                padding: '8px 12px',
                borderRadius: 8,
                backgroundColor: isActive ? '#1e293b' : 'transparent',
                color: isActive ? '#38bdf8' : '#94a3b8',
                border: 'none',
                cursor: 'pointer',
                fontWeight: isActive ? 600 : 500,
                fontSize: 12,
                whiteSpace: 'nowrap',
                transition: 'all 0.15s ease',
              }}
            >
              <Icon size={15} />
              <span>{tab.label}</span>
              {'count' in tab && tab.count > 0 && (
                <span
                  style={{
                    backgroundColor: isActive ? '#0284c7' : '#334155',
                    color: 'white',
                    fontSize: 10,
                    fontWeight: 700,
                    padding: '1px 6px',
                    borderRadius: 10,
                  }}
                >
                  {tab.count}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Tab Body */}
      <div style={{ flex: 1, padding: 16, overflowY: 'auto' }}>
        {activeTab === 'bridge' && <BridgeInspectorTab />}
        {activeTab === 'auth' && <AuthMockTab />}
        {activeTab === 'device' && <DeviceMockTab />}
        {activeTab === 'storage' && <StorageInspectorTab />}
      </div>
    </div>
  );
};
