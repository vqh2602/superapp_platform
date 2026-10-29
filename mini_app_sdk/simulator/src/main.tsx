import React from 'react';
import ReactDOM from 'react-dom/client';
import { AppContent } from './App.js';
import { SimulatorProvider } from './context/SimulatorContext.js';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <SimulatorProvider>
      <AppContent />
    </SimulatorProvider>
  </React.StrictMode>
);
