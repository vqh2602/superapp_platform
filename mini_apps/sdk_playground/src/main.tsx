import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import { SDKProvider } from './context/SDKContext';
import { ErrorBoundary } from './components/ErrorBoundary';

function mount() {
  const rootEl = document.getElementById('root');
  if (rootEl) {
    ReactDOM.createRoot(rootEl).render(
      <React.StrictMode>
        <ErrorBoundary>
          <SDKProvider>
            <App />
          </SDKProvider>
        </ErrorBoundary>
      </React.StrictMode>
    );
  } else {
    if (document.readyState === 'loading') {
      window.addEventListener('DOMContentLoaded', mount, { once: true });
    } else {
      setTimeout(mount, 50);
    }
  }
}

mount();
