import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import { SDKProvider } from './context/SDKContext';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <SDKProvider>
      <App />
    </SDKProvider>
  </React.StrictMode>
);
