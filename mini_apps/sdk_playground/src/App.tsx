import React, { useState } from 'react';
import { useSDK } from './context/SDKContext';
import { Header } from './components/Header';
import { FeatureCatalog } from './components/FeatureCatalog';
import { EventLogViewer } from './components/EventLogViewer';
import { DebugCenter } from './components/DebugCenter';
import { RunnerModal } from './components/RunnerModal';
import { Layers, Activity, Bug } from 'lucide-react';
import './App.css';

export const App: React.FC = () => {
  const { activeRunner, closeRunner } = useSDK();
  const [activeTab, setActiveTab] = useState<'catalog' | 'events' | 'debug'>('catalog');

  return (
    <div className="playground-app">
      <Header />

      {/* Navigation Tabs */}
      <nav className="tab-bar">
        <button
          className={`tab-btn ${activeTab === 'catalog' ? 'tab-active' : ''}`}
          onClick={() => setActiveTab('catalog')}
        >
          <Layers size={16} />
          <span>Tính năng SDK</span>
        </button>
        <button
          className={`tab-btn ${activeTab === 'events' ? 'tab-active' : ''}`}
          onClick={() => setActiveTab('events')}
        >
          <Activity size={16} />
          <span>Sự kiện G. (Events)</span>
        </button>
        <button
          className={`tab-btn ${activeTab === 'debug' ? 'tab-active' : ''}`}
          onClick={() => setActiveTab('debug')}
        >
          <Bug size={16} />
          <span>Debug Center</span>
        </button>
      </nav>

      {/* Main Content Area */}
      <main className="main-content">
        {activeTab === 'catalog' && <FeatureCatalog />}
        {activeTab === 'events' && <EventLogViewer />}
        {activeTab === 'debug' && <DebugCenter />}
      </main>

      {/* Runner Modal popup */}
      {activeRunner && <RunnerModal config={activeRunner} onClose={closeRunner} />}
    </div>
  );
};
