import React from 'react';
import { useSDK } from '../context/SDKContext';
import { ShieldCheck, Wifi, WifiOff, UserCheck, UserX, Cpu } from 'lucide-react';

export const Header: React.FC = () => {
  const { isConnected, loginStatus } = useSDK();

  return (
    <header className="header-container">
      <div className="header-top">
        <div className="app-title-group">
          <div className="app-icon-badge">
            <Cpu size={20} className="icon-pulse" />
          </div>
          <div>
            <h1 className="app-title">SDK Playground (React)</h1>
            <p className="app-subtitle">Super App React Mini App Runtime</p>
          </div>
        </div>
        <div className="version-tag">SDK v1.0.0</div>
      </div>

      <div className="status-bar">
        {/* Connection status */}
        <div className={`status-pill ${isConnected ? 'status-connected' : 'status-simulated'}`}>
          {isConnected ? <Wifi size={13} /> : <WifiOff size={13} />}
          <span>{isConnected ? 'Native Bridge' : 'Browser Mode'}</span>
        </div>

        {/* User Login status */}
        <div className={`status-pill ${loginStatus === 'authenticated' ? 'status-auth' : 'status-no-auth'}`}>
          {loginStatus === 'authenticated' ? <UserCheck size={13} /> : <UserX size={13} />}
          <span>{loginStatus === 'authenticated' ? 'Master User Active' : 'Auth Required'}</span>
        </div>

        {/* Security badge */}
        <div className="status-pill status-secure">
          <ShieldCheck size={13} />
          <span>Capability Sandbox</span>
        </div>
      </div>
    </header>
  );
};
